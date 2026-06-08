"""Zhipu CogView-4 — cloud-based AI inpainting via Zhipu (智谱) API.

Uses the Zhipu image generation API (CogView-4 / GLM-4V) to perform
image-to-image generation with mask guidance.

Requires a Zhipu API key in config:
  config.yaml:
    api_keys:
      zhipu: "zai_xxxxxxxxxxxx"

You already have this key (ZAI_API_KEY).
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

ZHIPU_API = "https://open.bigmodel.cn/api/paas/v4/images/generations"
DEFAULT_MODEL = "cogview-4"  # or "cogview-4-plus", "glm-4v-plus"


class ZhipuRepair(BaseRepairProvider):
    """Zhipu CogView-4 image repair via image-to-image generation."""

    def __init__(self, api_key: str = ""):
        self.api_key = api_key or os.environ.get("ZAI_API_KEY", "")

    def _call_zhipu(self, img_b64: str, mask_b64: str, prompt: str) -> np.ndarray:
        """Call Zhipu CogView-4 API with image + mask as a composite."""
        if not self.api_key:
            raise RuntimeError("Zhipu API key not set")

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        # CogView-4 supports image-to-image with mask:
        # We pass the original image and let the model regenerate the masked area.
        # For simplicity, we send the image and describe the repair in the prompt.
        payload = {
            "model": DEFAULT_MODEL,
            "prompt": prompt or "自然修复背景，无痕迹，保持原有风格和色调",
            "size": None,  # auto from input
            "n": 1,
            "image": f"data:image/png;base64,{img_b64}",
            "mask": f"data:image/png;base64,{mask_b64}",
        }

        logger.info("Sending to Zhipu %s...", DEFAULT_MODEL)
        resp = requests.post(ZHIPU_API, json=payload, headers=headers, timeout=120)
        resp.raise_for_status()
        data = resp.json()

        # Parse response — Zhipu returns generated images in data[].url or b64_json
        choices = data.get("data", [])
        if not choices:
            logger.error("Zhipu returned no data: %s", json.dumps(data, ensure_ascii=False)[:200])
            raise RuntimeError("Zhipu returned no generated image")

        result_url = choices[0].get("url") or choices[0].get("b64_json")
        if result_url and result_url.startswith("http"):
            img_resp = requests.get(result_url, timeout=30)
            img_resp.raise_for_status()
            pil = Image.open(io.BytesIO(img_resp.content)).convert("RGBA")
            return cv2.cvtColor(np.array(pil), cv2.COLOR_RGBA2BGRA)
        elif result_url:
            # base64
            raw = base64.b64decode(result_url)
            pil = Image.open(io.BytesIO(raw)).convert("RGBA")
            return cv2.cvtColor(np.array(pil), cv2.COLOR_RGBA2BGRA)

        raise RuntimeError(f"Unexpected Zhipu response: {json.dumps(data, ensure_ascii=False)[:200]}")

    def repair(
        self,
        image: np.ndarray,
        mask: np.ndarray,
        prompt: str = "",
        negative_prompt: str = "",
    ) -> np.ndarray:
        # Convert image to PIL PNG base64
        img_rgb = cv2.cvtColor(image[:, :, :3], cv2.COLOR_BGR2RGB)
        img_pil = Image.fromarray(img_rgb)

        mask_gray = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY) if mask.ndim == 3 else mask
        mask_pil = Image.fromarray(mask_gray)

        buf_img = io.BytesIO()
        img_pil.save(buf_img, format="PNG")
        img_b64 = base64.b64encode(buf_img.getvalue()).decode()

        buf_mask = io.BytesIO()
        mask_pil.save(buf_mask, format="PNG")
        mask_b64 = base64.b64encode(buf_mask.getvalue()).decode()

        return self._call_zhipu(img_b64, mask_b64, prompt)
