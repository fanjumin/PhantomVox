"""Pixel-level image editing tools — text, brush, shape, fill, eyedropper.

References:
  - OpenCV drawing: https://docs.opencv.org/4.x/d6/d6e/group__imgproc__drawing.html
  - Pillow text: https://pillow.readthedocs.io/en/stable/reference/ImageDraw.html
"""

from __future__ import annotations

import glob
import os
from pathlib import Path

import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont


# ── TrueType font discovery ──────────────────────────────────────────────
_FONT_DIRS = [
    "/usr/share/fonts",
    "/usr/local/share/fonts",
    os.path.expanduser("~/.fonts"),
    os.path.expanduser("~/.local/share/fonts"),
]

_SYSTEM_FONTS: dict[str, str] = {}  # family → ttf_path


def _discover_fonts() -> dict[str, str]:
    """Scan system font directories and return {family_name: file_path}."""
    fonts: dict[str, str] = {}
    for d in _FONT_DIRS:
        if not os.path.isdir(d):
            continue
        for ext in ("*.ttf", "*.ttc", "*.otf"):
            for fp in glob.glob(os.path.join(d, "**", ext), recursive=True):
                try:
                    # Use Pillow to read the font and get its family name
                    pil_font = ImageFont.truetype(fp, 14)
                    # Try to get name via getattr (Pillow API)
                    family = Path(fp).stem
                    # Prefer shorter names for well-known fonts
                    fp_lower = fp.lower()
                    if "noto" in fp_lower:
                        for kw in ["sans", "serif", "mono"]:
                            if kw in fp_lower:
                                if "cjk" in fp_lower:
                                    family = f"Noto {kw.capitalize()} CJK"
                                else:
                                    family = f"Noto {kw.capitalize()}"
                                # Prefer regular weight
                                if "regular" in fp_lower or "medium" in fp_lower:
                                    pass  # prefer this
                                elif f"noto{kw}" in fonts:
                                    continue  # already have a better match
                    elif "dejavu" in fp_lower:
                        for kw in ["sans", "serif", "mono"]:
                            if kw in fp_lower:
                                family = f"DejaVu {kw.capitalize()}"
                    elif "droid" in fp_lower:
                        family = "Droid Sans"
                    elif "wenquanyi" in fp_lower or "文泉驿" in fp_lower:  # WenQuanYi font family
                        family = "WenQuanYi"
                    elif "arphic" in fp_lower:
                        family = "AR PL Fonts"
                    elif "unifont" in fp_lower:
                        family = "Unifont"
                    fonts[family] = fp
                except Exception:
                    continue
    # Ensure common families have at least one entry
    if not any("sans" in k.lower() for k in fonts):
        # Fallback to any available TTF
        for fp in glob.glob("/usr/share/fonts/**/*.ttf", recursive=True):
            fonts["sans-serif"] = fp
            break
    return fonts


def get_system_fonts() -> dict[str, str]:
    """Return cached font map {family: file_path}."""
    global _SYSTEM_FONTS
    if not _SYSTEM_FONTS:
        _SYSTEM_FONTS = _discover_fonts()
    return _SYSTEM_FONTS


# ── OpenCV font fallback (when no TTF is available) ──────────────────────
_CV_FONTS = {
    "sans-serif": cv2.FONT_HERSHEY_SIMPLEX,
    "serif": cv2.FONT_HERSHEY_COMPLEX,
    "monospace": cv2.FONT_HERSHEY_PLAIN,
}


def _get_cv_font(family: str) -> int:
    return _CV_FONTS.get(family, cv2.FONT_HERSHEY_SIMPLEX)


def _bgr_with_alpha(
    rgb_color: tuple[int, int, int], opacity: float
) -> tuple[int, int, int, int]:
    """Convert RGB tuple to BGRA tuple for OpenCV drawing functions."""
    if not isinstance(rgb_color, (list, tuple)) or len(rgb_color) < 3:
        rgb_color = (255, 255, 255)
    b, g, r = rgb_color[2], rgb_color[1], rgb_color[0]
    a = min(255, max(0, int(opacity * 255)))
    return (b, g, r, a)


# ── Text rendering ───────────────────────────────────────────────────────
def add_text(
    img: np.ndarray,
    text: str,
    x: int,
    y: int,
    font_size: int = 24,
    color: tuple[int, int, int] = (255, 255, 255),
    opacity: float = 1.0,
    font_path: str | None = None,
    font_family: str = "sans-serif",
    stroke_width: int = 0,
    stroke_color: tuple[int, int, int] | None = None,
    shadow_blur: int = 0,
    shadow_color: tuple[int, int, int] = (0, 0, 0),
    shadow_offset: tuple[int, int] = (2, 2),
) -> np.ndarray:
    """Add text to image using system TrueType fonts (Pillow) with OpenCV fallback."""
    result = img.copy()
    alpha = result[:, :, 3] / 255.0 if img.shape[2] >= 4 else None

    # Try to load TrueType font
    ttf_path = font_path
    if ttf_path is None and font_family:
        ttf_path = get_system_fonts().get(font_family)

    if ttf_path and os.path.isfile(ttf_path):
        # ── Pillow rendering with TrueType ──
        result = _render_text_pil(result, text, x, y, font_size, color, opacity,
                                   ttf_path, stroke_width, stroke_color,
                                   shadow_blur, shadow_color, shadow_offset)
    else:
        # ── OpenCV fallback ──
        result = _render_text_cv(result, text, x, y, font_size, color, opacity,
                                  font_family, stroke_width, stroke_color,
                                  shadow_blur, shadow_color, shadow_offset)
    return result


def _render_text_pil(
    img: np.ndarray, text: str, x: int, y: int,
    font_size: int, color: tuple, opacity: float,
    font_path: str, stroke_width: int, stroke_color: tuple | None,
    shadow_blur: int, shadow_color: tuple, shadow_offset: tuple,
) -> np.ndarray:
    """Render text using Pillow with TrueType font."""
    # Convert OpenCV BGR(A) to PIL RGB(A)
    if img.shape[2] >= 4:
        pil_img = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGRA2RGBA))
    else:
        pil_img = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))

    draw = ImageDraw.Draw(pil_img, "RGBA")
    try:
        font = ImageFont.truetype(font_path, font_size)
    except Exception:
        font = ImageFont.load_default()

    # Convert color to RGBA
    r, g, b = color[0], color[1], color[2]
    a = int(opacity * 255)

    # Shadow
    if shadow_blur > 0:
        sr, sg, sb = shadow_color[0], shadow_color[1], shadow_color[2]
        sa = int(opacity * 128)
        sx, sy = x + shadow_offset[0], y + shadow_offset[1]
        draw.text((sx, sy), text, font=font, fill=(sr, sg, sb, sa))

    # Stroke + fill — Pillow 8.0.0+ supports stroke_width natively
    if stroke_width > 0 and stroke_color is not None:
        sr, sg, sb = stroke_color[0], stroke_color[1], stroke_color[2]
        draw.text((x, y), text, font=font, fill=(r, g, b, a),
                  stroke_width=stroke_width, stroke_fill=(sr, sg, sb, a))
    else:
        # Fill only
        draw.text((x, y), text, font=font, fill=(r, g, b, a))

    # Convert back to OpenCV BGR(A)
    if img.shape[2] >= 4:
        result = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGBA2BGRA)
    else:
        result = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
    return result


def _render_text_cv(
    img: np.ndarray, text: str, x: int, y: int,
    font_size: int, color: tuple, opacity: float,
    font_family: str, stroke_width: int, stroke_color: tuple | None,
    shadow_blur: int, shadow_color: tuple, shadow_offset: tuple,
) -> np.ndarray:
    """Render text using OpenCV Hershey fonts (fallback)."""
    result = img.copy()
    font = _get_cv_font(font_family)
    font_scale = font_size / 30.0
    bgr_color = _bgr_with_alpha(color, opacity)

    if shadow_blur > 0:
        shadow_bgr = _bgr_with_alpha(shadow_color, opacity * 0.5)
        cv2.putText(result, text,
                    (x + shadow_offset[0], y + shadow_offset[1]),
                    font, font_scale, shadow_bgr, stroke_width + 1, cv2.LINE_AA)

    if stroke_width > 0 and stroke_color is not None:
        stroke_bgr = _bgr_with_alpha(stroke_color, opacity)
        cv2.putText(result, text, (x, y), font, font_scale, stroke_bgr,
                    stroke_width + 2, cv2.LINE_AA)

    cv2.putText(result, text, (x, y), font, font_scale, bgr_color,
                stroke_width + 1, cv2.LINE_AA)
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
