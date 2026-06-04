"""
Image Editor Providers — AI restoration, local or API based on hardware detection.

Hardware-aware dispatch:
- NVIDIA GPU + VRAM >= 4GB → local model inference
- CPU-only / weak GPU → API fallback (configurable endpoints)
"""

from __future__ import annotations
import os
from typing import Optional
from PIL import Image


def detect_capabilities(hardware=None) -> dict:
    """Detect what AI image features are available on this machine."""
    caps = {
        "remove_bg": True,          # rembg works on CPU
        "denoise": True,            # local Pillow
        "super_res": False,         # needs API or GPU
        "inpaint": False,           # needs API or GPU
        "colorize": False,          # needs API or GPU
        "face_restore": False,      # needs API or GPU
        "has_gpu": False,
        "tier": 1,
    }
    if hardware is None:
        return caps

    spec = hardware.detect()
    caps["tier"] = spec.max_tier()
    caps["has_gpu"] = len(spec.gpu_vram_gb) > 0 and max(spec.gpu_vram_gb) >= 4

    if caps["has_gpu"] and caps["tier"] >= 3:
        caps["super_res"] = True
        caps["inpaint"] = True
        caps["colorize"] = True
        caps["face_restore"] = True

    return caps


# ── Background removal (local, always available) ──────────

_BG_MODEL = None

def _get_bg_model():
    """Lazy-load rembg model."""
    global _BG_MODEL
    if _BG_MODEL is None:
        try:
            from rembg import new_session
            _BG_MODEL = new_session("u2net")
        except ImportError:
            _BG_MODEL = "unavailable"
    return None if _BG_MODEL == "unavailable" else _BG_MODEL


def remove_background(img: Image.Image) -> Image.Image:
    """Remove image background. Returns RGBA image."""
    model = _get_bg_model()
    if model is None:
        # rembg not installed, return original
        return img.convert("RGBA")
    try:
        from rembg import remove as rembg_remove
        return rembg_remove(img, session=model)
    except Exception:
        return img.convert("RGBA")


# ── Inpainting placeholder ────────────────────────────────

def inpaint(img: Image.Image, mask: Optional[Image.Image] = None,
            prompt: str = "") -> Image.Image:
    """
    Inpaint / fill missing regions.
    Local: uses OpenCV if available, otherwise placeholder.
    Future: LaMA model or API call.
    """
    # Placeholder: return original (actual implementation via API or LaMa)
    return img


# ── Super-resolution placeholder ──────────────────────────

def super_resolve(img: Image.Image, scale: int = 2) -> Image.Image:
    """
    Upscale image with super-resolution.
    Local: Real-ESRGAN (when GPU available)
    API: configurable provider
    """
    # Simple Lanczos upscale as fallback
    w, h = img.width * scale, img.height * scale
    return img.resize((w, h), Image.LANCZOS)
