"""Polygon crop — arbitrary polygon cropping using OpenCV.

Reference implementation from the project requirements:
  - cv2.fillPoly to create mask
  - cv2.bitwise_and to extract region
  - Alpha channel merge for transparent PNG output

Usage:
  from modules.crop.polygon_crop import polygon_crop
  result = polygon_crop(pil_image, points)
"""

from __future__ import annotations
from typing import List, Tuple
import numpy as np
from PIL import Image

try:
    import cv2
    _HAVE_OPENCV = True
except ImportError:
    cv2 = None
    _HAVE_OPENCV = False


def _pil_to_cv2(img: Image.Image) -> np.ndarray:
    """PIL RGB/RGBA → OpenCV BGR/BGRA."""
    arr = np.array(img)
    if arr.ndim < 3:
        arr = np.stack([arr] * 3, axis=-1)
    if arr.shape[2] == 4:
        return cv2.cvtColor(arr, cv2.COLOR_RGBA2BGRA)
    return cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)


def polygon_crop(
    img: Image.Image,
    points: List[Tuple[int, int]],
) -> Image.Image:
    """Crop an image to an arbitrary polygon region.

    Args:
        img: PIL Image (RGB or RGBA).
        points: List of (x, y) vertex coordinates (3+ points).

    Returns:
        PIL Image (RGBA) — polygon interior preserved, exterior transparent.
    """
    if not _HAVE_OPENCV:
        raise ImportError("OpenCV (cv2) is required for polygon crop.")

    if not points or len(points) < 3:
        raise ValueError("Need at least 3 points for polygon crop.")

    # Convert to OpenCV BGR
    arr = _pil_to_cv2(img)
    h, w = arr.shape[:2]

    # Create polygon mask
    pts = np.array(points, dtype=np.int32).reshape((-1, 1, 2))
    mask = np.zeros((h, w), dtype=np.uint8)
    cv2.fillPoly(mask, [pts], 255)

    # Apply mask: keep polygon interior, black out exterior
    result_bgr = cv2.bitwise_and(arr, arr, mask=mask)

    # Split BGR channels and merge with alpha
    b, g, r = cv2.split(result_bgr)
    rgba = cv2.merge([b, g, r, mask])

    return Image.fromarray(cv2.cvtColor(rgba, cv2.COLOR_BGRA2RGBA))
