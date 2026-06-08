"""Replicate FLUX.1 Fill [pro] — cloud-based AI inpainting.

Requires a Replicate API token in config:
  config.yaml:
    api_keys:
      replicate: "r8_xxxxxxxxxxxx"

Get a token at: https://replicate.com/account/api-tokens

FLUX.1 Fill [pro] is currently the strongest cloud inpainting model.
"""

from __future__ import annotations

import base64
import io
import logging
import time

import cv2
import numpy as np
import requests
from PIL import Image

from .base import BaseRepairProvider

logger = logging.getLogger(__name__)

POLL_INTERVAL = 2.0  # seconds between status checks
MAX_POLL_ATTEMPTS = 60  # 2 min timeout
REPLICATE_API = "https://api.replicate.com/v1/predictions"
FLUX_FILL_VERSION = "black-forest-labs/flux-fill-pro"


class ReplicateRepair(BaseRepairProvider):
    """Replicate FLUX.1 Fill [pro] inpainting client."""

    def __init__(self, api_key: str = ""):
        self.api_key = api_key

    # ── helpers ────────────────────────────────────────────────

    @staticmethod
    def _pil_to_data_url(pil_img: Image.Image) -> str:
        buf = io.BytesIO()
        pil_img.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode()
        return f"data:image/png;base64,{b64}"

    @staticmethod
    def _download_result(url: str) -> np.ndarray:
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        pil = Image.open(io.BytesIO(resp.content)).convert("RGBA")
        return cv2.cvtColor(np.array(pil), cv2.COLOR_RGBA2BGRA)

    # ── main ──────────────────────────────────────────────────

    def repair(
        self,
        image: np.ndarray,
        mask: np.ndarray,
        prompt: str = "",
        negative_prompt: str = "",
    ) -> np.ndarray:
        if not self.api_key:
            logger.warning("Replicate API key not set — falling back")
            raise RuntimeError("No Replicate API key")

        # Convert to PIL
        img_rgb = cv2.cvtColor(image[:, :, :3], cv2.COLOR_BGR2RGB)
        img_pil = Image.fromarray(img_rgb)
        mask_gray = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY) if mask.ndim == 3 else mask
        mask_pil = Image.fromarray(mask_gray)

        headers = {
            "Authorization": f"Token {self.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "version": FLUX_FILL_VERSION,
            "input": {
                "image": self._pil_to_data_url(img_pil),
                "mask": self._pil_to_data_url(mask_pil),
                "prompt": prompt or "fill naturally, seamless blend",
                "num_outputs": 1,
            },
        }

        logger.info("Sending to Replicate FLUX Fill...")
        resp = requests.post(REPLICATE_API, json=payload, headers=headers, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        prediction_id = data.get("id")
        if not prediction_id:
            logger.error("Replicate: no prediction id in response: %s", data)
            raise RuntimeError("Replicate returned no prediction id")

        # Poll for completion
        poll_url = f"{REPLICATE_API}/{prediction_id}"
        for attempt in range(1, MAX_POLL_ATTEMPTS + 1):
            time.sleep(POLL_INTERVAL)
            r = requests.get(poll_url, headers=headers, timeout=30)
            r.raise_for_status()
            d = r.json()
            status = d.get("status", "")
            logger.debug("Replicate poll %d/%d: %s", attempt, MAX_POLL_ATTEMPTS, status)

            if status == "succeeded":
                output = d.get("output", [])
                if isinstance(output, list) and output:
                    return self._download_result(output[0])
                elif isinstance(output, str):
                    return self._download_result(output)
                logger.error("Replicate succeeded but no output: %s", output)
                return image.copy()

            if status == "failed":
                error = d.get("error", "unknown error")
                logger.error("Replicate prediction failed: %s", error)
                raise RuntimeError(f"Replicate failed: {error}")

            if status == "canceled":
                logger.warning("Replicate prediction was canceled")
                return image.copy()

        logger.error("Replicate poll timed out after %d attempts", MAX_POLL_ATTEMPTS)
        raise TimeoutError("Replicate FLUX Fill timed out")
