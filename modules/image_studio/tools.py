"""Pixel-level image editing tools — text, brush, shape, fill, eyedropper.

References:
  - OpenCV drawing: https://docs.opencv.org/4.x/d6/d6e/group__imgproc__drawing.html
"""

from __future__ import annotations

import numpy as np
import cv2


def _bgr_with_alpha(
    rgb_color: tuple[int, int, int], opacity: float
) -> tuple[int, int, int, int]:
    """Convert RGB tuple to BGRA tuple for OpenCV drawing functions."""
    if not isinstance(rgb_color, (list, tuple)) or len(rgb_color) < 3:
        rgb_color = (255, 255, 255)
    b, g, r = rgb_color[2], rgb_color[1], rgb_color[0]
    a = min(255, max(0, int(opacity * 255)))
    return (b, g, r, a)


def add_text(
    img: np.ndarray,
    text: str,
    x: int,
    y: int,
    font_size: int = 24,
    color: tuple[int, int, int] = (255, 255, 255),
    opacity: float = 1.0,
    font_path: str | None = None,
    stroke_width: int = 0,
    stroke_color: tuple[int, int, int] | None = None,
    shadow_blur: int = 0,
    shadow_color: tuple[int, int, int] = (0, 0, 0),
    shadow_offset: tuple[int, int] = (2, 2),
) -> np.ndarray:
    """Add text to image using OpenCV putText."""
    result = img.copy()
    bgr_color = _bgr_with_alpha(color, opacity)
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = font_size / 30.0

    if shadow_blur > 0:
        shadow_bgr = _bgr_with_alpha(shadow_color, opacity * 0.5)
        cv2.putText(
            result, text,
            (x + shadow_offset[0], y + shadow_offset[1]),
            font, font_scale, shadow_bgr,
            stroke_width + 1, cv2.LINE_AA,
        )

    if stroke_width > 0 and stroke_color is not None:
        stroke_bgr = _bgr_with_alpha(stroke_color, opacity)
        cv2.putText(
            result, text, (x, y), font, font_scale, stroke_bgr,
            stroke_width + 2, cv2.LINE_AA,
        )

    cv2.putText(
        result, text, (x, y), font, font_scale, bgr_color,
        stroke_width + 1, cv2.LINE_AA,
    )
    return result


def draw_brush(
    img: np.ndarray,
    points: list[tuple[int, int]],
    color: tuple[int, int, int] = (255, 255, 255),
    size: int = 5,
    opacity: float = 1.0,
) -> np.ndarray:
    """Draw freehand brush stroke from a list of (x,y) points."""
    result = img.copy()
    if len(points) < 2:
        if len(points) == 1:
            cv2.circle(result, points[0], size // 2, _bgr_with_alpha(color, opacity), -1)
        return result
    for i in range(1, len(points)):
        cv2.line(
            result, points[i - 1], points[i],
            _bgr_with_alpha(color, opacity),
            thickness=size, lineType=cv2.LINE_AA,
        )
    cv2.circle(result, points[0], size // 2, _bgr_with_alpha(color, opacity), -1)
    cv2.circle(result, points[-1], size // 2, _bgr_with_alpha(color, opacity), -1)
    return result


def draw_shape(
    img: np.ndarray,
    shape_type: str,
    x: int, y: int, w: int, h: int,
    fill_color: tuple[int, int, int] | None = None,
    stroke_color: tuple[int, int, int] = (255, 255, 255),
    stroke_width: int = 2,
) -> np.ndarray:
    """Draw a shape (rect/ellipse/circle/line/arrow)."""
    result = img.copy()
    fill = None
    if fill_color is not None:
        fill = _bgr_with_alpha(fill_color, 1.0)
    stroke = _bgr_with_alpha(stroke_color, 1.0)

    if shape_type == "rect":
        pt1, pt2 = (x, y), (x + w, y + h)
        if fill_color is not None:
            cv2.rectangle(result, pt1, pt2, fill, -1)
        cv2.rectangle(result, pt1, pt2, stroke, stroke_width)
    elif shape_type == "ellipse":
        center = (x + w // 2, y + h // 2)
        axes = (w // 2, h // 2)
        if fill_color is not None:
            cv2.ellipse(result, center, axes, 0, 0, 360, fill, -1)
        cv2.ellipse(result, center, axes, 0, 0, 360, stroke, stroke_width)
    elif shape_type == "circle":
        center = (x, y)
        radius = w
        if fill_color is not None:
            cv2.circle(result, center, radius, fill, -1)
        cv2.circle(result, center, radius, stroke, stroke_width)
    elif shape_type == "line":
        cv2.line(result, (x, y), (x + w, y + h), stroke, stroke_width, cv2.LINE_AA)
    elif shape_type == "arrow":
        cv2.arrowedLine(result, (x, y), (x + w, y + h), stroke, stroke_width, cv2.LINE_AA)
    return result


def flood_fill(
    img: np.ndarray,
    x: int, y: int,
    color: tuple[int, int, int],
    threshold: float = 10.0,
) -> np.ndarray:
    """Flood fill from (x,y) with color. Operates on RGB, preserves alpha."""
    h, w = img.shape[:2]
    if x < 0 or x >= w or y < 0 or y >= h:
        return img.copy()
    threshold = max(1.0, threshold)
    result = img.copy()
    alpha = result[:, :, 3].copy()
    bgr = (color[2], color[1], color[0])
    mask = np.zeros((h + 2, w + 2), np.uint8)
    rgb_view = result[:, :, :3].copy()
    cv2.floodFill(
        rgb_view, mask, (x, y), bgr,
        (threshold,) * 3, (threshold,) * 3,
        cv2.FLOODFILL_FIXED_RANGE,
    )
    result[:, :, :3] = rgb_view
    result[:, :, 3] = alpha
    return result


def eyedropper(img: np.ndarray, x: int, y: int) -> tuple[int, int, int]:
    """Pick color at (x,y). Returns (R, G, B) tuple."""
    h, w = img.shape[:2]
    x, y = max(0, min(x, w - 1)), max(0, min(y, h - 1))
    b, g, r = img[y, x, 0:3]
    return (int(r), int(g), int(b))


# Alias for backward compatibility
fill_region = flood_fill
