"""
Image Editor — basic editing tools (Pillow + OpenCV).
All operations are local, no GPU needed, instant results.
"""

from __future__ import annotations
import io
import base64
import os
from typing import Optional, Tuple, List
from PIL import Image, ImageEnhance, ImageFilter as PILFilter, ImageDraw, ImageFont


def open_image(path_or_bytes: str | bytes) -> Image.Image:
    """Load image from file path or bytes."""
    if isinstance(path_or_bytes, str):
        return Image.open(path_or_bytes).convert("RGB")
    return Image.open(io.BytesIO(path_or_bytes)).convert("RGB")


def image_to_base64(img: Image.Image, fmt: str = "PNG") -> str:
    """Convert Pillow image to base64 string."""
    buf = io.BytesIO()
    img.save(buf, format=fmt)
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def image_info(img: Image.Image) -> dict:
    """Return image metadata."""
    return {
        "width": img.width,
        "height": img.height,
        "format": img.format or "PNG",
        "mode": img.mode,
    }


# ── Crop ───────────────────────────────────────────────────

def crop(img: Image.Image, x: int, y: int, w: int, h: int) -> Image.Image:
    """Crop to region (x, y, x+w, y+h)."""
    return img.crop((x, y, x + w, y + h))


# ── Resize ─────────────────────────────────────────────────

def resize(img: Image.Image, width: int, height: int,
           keep_aspect: bool = False) -> Image.Image:
    """Resize image. If keep_aspect, fit inside (width, height)."""
    if keep_aspect:
        img.thumbnail((width, height), Image.LANCZOS)
        return img
    return img.resize((width, height), Image.LANCZOS)


# ── Rotate / Flip ──────────────────────────────────────────

def rotate(img: Image.Image, angle: float,
           expand: bool = True) -> Image.Image:
    """Rotate by angle (degrees)."""
    return img.rotate(angle, expand=expand, resample=Image.BICUBIC,
                      fillcolor=(255, 255, 255))


def flip(img: Image.Image, direction: str = "horizontal") -> Image.Image:
    """Flip image. direction: 'horizontal' or 'vertical'."""
    if direction == "horizontal":
        return img.transpose(Image.FLIP_LEFT_RIGHT)
    return img.transpose(Image.FLIP_TOP_BOTTOM)


# ── Color Adjust ───────────────────────────────────────────

def adjust_brightness(img: Image.Image, factor: float) -> Image.Image:
    """Adjust brightness. 1.0 = no change, <1 darker, >1 brighter."""
    return ImageEnhance.Brightness(img).enhance(factor)


def adjust_contrast(img: Image.Image, factor: float) -> Image.Image:
    """Adjust contrast. 1.0 = no change."""
    return ImageEnhance.Contrast(img).enhance(factor)


def adjust_saturation(img: Image.Image, factor: float) -> Image.Image:
    """Adjust saturation. 1.0 = no change."""
    return ImageEnhance.Color(img).enhance(factor)


def adjust_sharpness(img: Image.Image, factor: float) -> Image.Image:
    """Adjust sharpness. 1.0 = no change."""
    return ImageEnhance.Sharpness(img).enhance(factor)


# ── Filters ────────────────────────────────────────────────

def apply_grayscale(img: Image.Image) -> Image.Image:
    """Convert to grayscale (3-channel)."""
    return img.convert("L").convert("RGB")


def apply_sepia(img: Image.Image) -> Image.Image:
    """Apply sepia tone."""
    from PIL import ImageOps
    gray = img.convert("L")
    sepia = ImageOps.colorize(gray, (62, 30, 10), (255, 230, 180))
    return sepia.convert("RGB")


def apply_blur(img: Image.Image, radius: int = 5) -> Image.Image:
    """Apply Gaussian blur."""
    return img.filter(PILFilter.GaussianBlur(radius=radius))


def apply_invert(img: Image.Image) -> Image.Image:
    """Invert colors."""
    from PIL import ImageOps
    return ImageOps.invert(img.convert("RGB"))


# ── Text / Watermark ───────────────────────────────────────

def add_text(img: Image.Image, text: str, x: int, y: int,
             font_path: Optional[str] = None, font_size: int = 24,
             color: Tuple[int, int, int] = (255, 255, 255),
             opacity: float = 1.0) -> Image.Image:
    """Add text to image."""
    img = img.copy()
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    try:
        font = ImageFont.truetype(font_path or "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                                  font_size)
    except (OSError, IOError):
        font = ImageFont.load_default()
    alpha = int(255 * opacity)
    draw.text((x, y), text, font=font, fill=(*color, alpha))
    return Image.alpha_composite(img, overlay).convert("RGB")


def add_watermark(img: Image.Image, watermark_img: Image.Image,
                  position: str = "bottom_right",
                  opacity: float = 0.5,
                  scale: float = 0.2) -> Image.Image:
    """Add image watermark. position: top_left, top_right, bottom_left, bottom_right, center."""
    img = img.copy()
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    # Scale watermark
    wm_w = int(img.width * scale)
    wm_h = int(watermark_img.height * wm_w / watermark_img.width)
    wm = watermark_img.resize((wm_w, wm_h), Image.LANCZOS)
    if wm.mode != "RGBA":
        wm = wm.convert("RGBA")

    # Position
    margin = 10
    positions = {
        "top_left": (margin, margin),
        "top_right": (img.width - wm_w - margin, margin),
        "bottom_left": (margin, img.height - wm_h - margin),
        "bottom_right": (img.width - wm_w - margin, img.height - wm_h - margin),
        "center": ((img.width - wm_w) // 2, (img.height - wm_h) // 2),
    }
    pos = positions.get(position, positions["bottom_right"])

    # Apply opacity
    r, g, b, a = wm.split()
    a = a.point(lambda x: int(x * opacity))
    wm = Image.merge("RGBA", (r, g, b, a))

    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    overlay.paste(wm, pos, wm)
    return Image.alpha_composite(img, overlay).convert("RGB")


# ── Blur region (mosaic) ──────────────────────────────────

def blur_region(img: Image.Image, x: int, y: int, w: int, h: int,
                radius: int = 20) -> Image.Image:
    """Apply Gaussian blur to a rectangular region."""
    img = img.copy()
    region = img.crop((x, y, x + w, y + h))
    blurred = region.filter(PILFilter.GaussianBlur(radius=radius))
    img.paste(blurred, (x, y))
    return img


# ── Export ─────────────────────────────────────────────────

def export_image(img: Image.Image, output_path: str,
                 fmt: Optional[str] = None,
                 quality: int = 95) -> str:
    """Save image to file. Returns absolute path."""
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    if fmt is None:
        fmt = os.path.splitext(output_path)[1].lstrip(".").upper() or "PNG"
        if fmt == "JPG":
            fmt = "JPEG"
    img.save(output_path, format=fmt, quality=quality)
    return os.path.abspath(output_path)


# ── Denoise (Pillow only) ─────────────────────────────────

def denoise(img: Image.Image, strength: int = 3) -> Image.Image:
    """Denoise using Pillow's built-in filters."""
    if strength <= 0:
        return img
    img = img.filter(PILFilter.MinFilter(strength))
    img = img.filter(PILFilter.MedianFilter(strength))
    return img
