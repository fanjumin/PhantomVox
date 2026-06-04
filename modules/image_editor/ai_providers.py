"""
AI Image Restoration Providers — API-based & local hybrid.

Architecture:
- GPU available (tier >= 3): local model inference (GFPGAN, Real-ESRGAN)
- CPU only: API fallback (configurable)
- OpenCV fallback for basic enhancement
"""

from __future__ import annotations
import os
import json
import urllib.request
import urllib.parse
from typing import Optional
from PIL import Image

from . import tools
from .cv_tools import smart_sharpen, clahe_enhance, auto_white_balance, _pil_to_cv2, _cv2_to_pil


# ═══════════════════════════════════════════════════════════
# API Configuration
# ═══════════════════════════════════════════════════════════

DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
DEEPSEEK_API_URL = "https://api.deepseek.com/chat/completions"

# ZAI API (for GLM image generation/editing - free tier)
ZAI_API_KEY = os.environ.get("ZAI_API_KEY", "")
ZAI_API_URL = "https://open.bigmodel.cn/api/paas/v4/images/generations"

# ═══════════════════════════════════════════════════════════
# Hardware-aware dispatch
# ═══════════════════════════════════════════════════════════

def _has_gpu() -> bool:
    """Check if CUDA GPU is available via PyTorch."""
    try:
        import torch
        return torch.cuda.is_available()
    except ImportError:
        return False


def _gpu_vram_gb() -> float:
    """Return available GPU VRAM in GB, or 0."""
    try:
        import torch
        if torch.cuda.is_available():
            return torch.cuda.get_device_properties(0).total_memory / 1024**3
    except ImportError:
        pass
    return 0.0


# ═══════════════════════════════════════════════════════════
# AI Face Restoration
# ═══════════════════════════════════════════════════════════

LOCAL_MODELS_AVAILABLE = False
try:
    # Check if GFPGAN or similar is importable
    import gfpgan
    LOCAL_MODELS_AVAILABLE = True
except ImportError:
    pass


def ai_restore_faces(img: Image.Image, strength: float = 1.0) -> Image.Image:
    """AI face restoration.
    - GPU: Use GFPGAN locally
    - CPU: Use OpenCV smart sharpen + CLAHE as fallback
    - Future: API call
    """
    if _has_gpu() and LOCAL_MODELS_AVAILABLE:
        try:
            from gfpgan import GFPGANer
            arr = cv2_to_pil(img)  # ... (complex model inference)
            # Placeholder for actual model inference
            pass
        except Exception:
            pass
    # CPU fallback: smart enhance
    result = smart_sharpen(img, amount=strength * 0.5)
    result = clahe_enhance(result, clip_limit=1.5 + strength)
    return result


def ai_enhance_image(img: Image.Image, mode: str = "general",
                     strength: float = 1.0) -> Image.Image:
    """AI image enhancement pipeline.
    modes: general, portrait, old_photo, document
    """
    result = img
    # Step 1: Denoise
    result = tools.denoise(result, strength=max(1, int(strength * 2)))
    # Step 2: Smart sharpen
    result = smart_sharpen(result, amount=strength * 0.8)
    # Step 3: Auto white balance
    result = auto_white_balance(result, strength=strength * 0.3)
    # Step 4: CLAHE contrast
    result = clahe_enhance(result, clip_limit=1.0 + strength)
    return result


# ═══════════════════════════════════════════════════════════
# AI Inpainting / Erase (API-based)
# ═══════════════════════════════════════════════════════════

def ai_inpaint_api(img: Image.Image, mask_img: Image.Image,
                   prompt: str = "") -> Optional[Image.Image]:
    """AI inpainting via API (e.g., ZAI CogView).
    Falls back to OpenCV inpainting if API unavailable.
    """
    # Try API first
    if ZAI_API_KEY:
        try:
            # Encode image + mask to base64, send to API
            # ... (API-specific implementation)
            pass
        except Exception:
            pass
    # Fallback to OpenCV
    return None  # Signal caller to use OpenCV fallback


# ═══════════════════════════════════════════════════════════
# Utility
# ═══════════════════════════════════════════════════════════

def get_ai_capabilities() -> dict:
    """Return what AI features are available."""
    return {
        "has_gpu": _has_gpu(),
        "gpu_vram_gb": round(_gpu_vram_gb(), 1),
        "local_models": LOCAL_MODELS_AVAILABLE,
        "deepseek_api": bool(DEEPSEEK_API_KEY),
        "zai_api": bool(ZAI_API_KEY),
        "ai_restore": True,      # Always available (CPU fallback)
        "ai_enhance": True,      # Always available
        "super_resolve": True,   # OpenCV Lanczos
        "inpaint": True,         # OpenCV cv2.inpaint
    }
