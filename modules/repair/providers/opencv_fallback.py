"""OpenCV fallback — CPU-only traditional inpainting.

Zero dependencies beyond opencv-python and numpy.
Mask white pixels = area to repair.
"""

from __future__ import annotations

import cv2
import numpy as np

from .base import BaseRepairProvider


class OpenCVFallback(BaseRepairProvider):
    """Pure OpenCV inpainting — offline fallback, no API key needed.

    Uses Telea algorithm (cv2.INPAINT_TELEA) which propagates
    surrounding texture into the masked region.
    """

    def repair(
        self,
        image: np.ndarray,
        mask: np.ndarray,
        prompt: str = "",
        negative_prompt: str = "",
    ) -> np.ndarray:
        # Ensure mask is single-channel binary
        if mask.ndim == 3:
            mask = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY)
        _, bin_mask = cv2.threshold(mask, 127, 255, cv2.THRESH_BINARY)

        # If nothing to repair, return original
        if not np.any(bin_mask):
            return image.copy()

        bgr = image[:, :, :3]
        alpha = image[:, :, 3] if image.shape[2] >= 4 else np.full(image.shape[:2], 255, np.uint8)

        result_bgr = cv2.inpaint(bgr, bin_mask, inpaintRadius=3, flags=cv2.INPAINT_TELEA)
        return np.dstack([result_bgr, alpha])
