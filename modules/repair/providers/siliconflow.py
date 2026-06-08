"""SiliconFlow image repair provider via Qwen-Image-Edit-2509 (inpainting with mask).

Uses SiliconFlow's API as relay for Qwen/Qwen-Image-Edit-2509 which supports
image-to-image generation with mask-based inpainting.

Cost: ¥0.02-0.05/image (very affordable)
"""
from __future__ import annotations

import base64
import io
import json
import logging
import os

import cv2
import numpy as np
import requests
from PIL import Image

from .base import BaseRepairProvider

logger = logging.getLogger(__name__)

API_URL = "https://api.siliconflow.cn/v1/image/generations"
MODEL = "Qwen/Qwen-Image-Edit-2509"


class SiliconFlowRepair(BaseRepairProvider):
    """SiliconFlow relay for Qwen-Image-Edit-2509 inpainting."""

    def __init__(self, api_key: str = ""):
        self.api_key = api_key or os.environ.get("SILICONFLOW_KEY", "")

    def _call_api(self, img_b64: str, mask_b64: str, prompt: str) -> np.ndarray:
        """Call SiliconFlow Qwen-Image-Edit-2509 with image + mask."""
        if not self.api_key:
            raise RuntimeError("SiliconFlow API key not set (SILICONFLOW_KEY)")

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": MODEL,
            "prompt": prompt,
            "image": f"data:image/png;base64,{img_b64}",
            "mask": f"data:image/png;base64,{mask_b64}",
            "n": 1,
        }

        logger.info("Calling SiliconFlow %s (prompt=%r)", MODEL, prompt[:60])
        resp = requests.post(API_URL, json=payload, headers=headers, timeout=120)
        resp.raise_for_status()
        data = resp.json()

        images = data.get("images", [])
        if not images:
            raise RuntimeError(f"SiliconFlow returned no images: {json.dumps(data, ensure_ascii=False)[:200]}")

        result_url = images[0].get("url", "")
        if not result_url:
            raise RuntimeError("No URL in SiliconFlow response")

        # Download the result
        img_resp = requests.get(result_url, timeout=30)
        img_resp.raise_for_status()
        pil = Image.open(io.BytesIO(img_resp.content)).convert("RGBA")
        return cv2.cvtColor(np.array(pil), cv2.COLOR_RGBA2BGRA)

    def repair(
        self,
        image: np.ndarray,
        mask: np.ndarray,
        prompt: str = "",
        negative_prompt: str = "",
    ) -> np.ndarray:
        """Repair masked region using Qwen-Image-Edit-2509 inpainting."""
        # Convert image BGRA → PIL RGB
        img_rgb = cv2.cvtColor(image[:, :, :3], cv2.COLOR_BGR2RGB)
        img_pil = Image.fromarray(img_rgb)

        # Convert mask to single-channel PIL
        mask_gray = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY) if mask.ndim == 3 else mask
        mask_pil = Image.fromarray(mask_gray)

        buf_img = io.BytesIO()
        img_pil.save(buf_img, format="PNG")
        img_b64 = base64.b64encode(buf_img.getvalue()).decode()

        buf_mask = io.BytesIO()
        mask_pil.save(buf_mask, format="PNG")
        mask_b64 = base64.b64encode(buf_mask.getvalue()).decode()

        return self._call_api(img_b64, mask_b64, prompt)
