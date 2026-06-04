"""
Image Editor Engine — PhantomVox AI 图像编辑器

Architecture:
- Basic editing: local Pillow (no GPU, instant)
- AI restoration: hardware-aware dispatch (local if GPU, API if CPU)
"""

from __future__ import annotations
from typing import Optional

from . import tools
from .providers import detect_capabilities, remove_background

__all__ = [
    "tools",
    "detect_capabilities",
    "remove_background",
    "ImageEditorEngine",
]


class ImageEditorEngine:
    """Image Editor Engine — wraps tools + providers."""

    def __init__(self, hardware=None):
        self._hardware = hardware
        self._current_image = None
        self._current_path = None
        self.capabilities = detect_capabilities(hardware)

    @property
    def current_image(self):
        return self._current_image

    # ── Session management ────────────────────────────

    def load(self, path_or_bytes):
        """Load image into session. Returns info dict."""
        self._current_image = tools.open_image(path_or_bytes)
        self._current_path = path_or_bytes if isinstance(path_or_bytes, str) else None
        return tools.image_info(self._current_image)

    def export(self, output_path: str, fmt: Optional[str] = None, quality: int = 95):
        """Export current image to file."""
        if self._current_image is None:
            raise ValueError("No image loaded")
        return tools.export_image(self._current_image, output_path, fmt, quality)

    def to_base64(self, fmt: str = "PNG") -> str:
        """Return current image as base64."""
        if self._current_image is None:
            raise ValueError("No image loaded")
        return tools.image_to_base64(self._current_image, fmt)

    def info(self) -> dict:
        """Return current image info."""
        if self._current_image is None:
            return {"loaded": False}
        info = tools.image_info(self._current_image)
        info["loaded"] = True
        return info

    # ── Operations (delegate to tools) ────────────────

    def crop(self, x: int, y: int, w: int, h: int):
        self._current_image = tools.crop(self._current_image, x, y, w, h)
        return self.info()

    def resize(self, width: int, height: int, keep_aspect: bool = False):
        self._current_image = tools.resize(self._current_image, width, height, keep_aspect)
        return self.info()

    def rotate(self, angle: float, expand: bool = True):
        self._current_image = tools.rotate(self._current_image, angle, expand)
        return self.info()

    def flip(self, direction: str = "horizontal"):
        self._current_image = tools.flip(self._current_image, direction)
        return self.info()

    def adjust_brightness(self, factor: float):
        self._current_image = tools.adjust_brightness(self._current_image, factor)
        return self.info()

    def adjust_contrast(self, factor: float):
        self._current_image = tools.adjust_contrast(self._current_image, factor)
        return self.info()

    def adjust_saturation(self, factor: float):
        self._current_image = tools.adjust_saturation(self._current_image, factor)
        return self.info()

    def adjust_sharpness(self, factor: float):
        self._current_image = tools.adjust_sharpness(self._current_image, factor)
        return self.info()

    def apply_filter(self, filter_name: str):
        filters = {
            "grayscale": tools.apply_grayscale,
            "sepia": tools.apply_sepia,
            "blur": lambda img: tools.apply_blur(img, 5),
            "invert": tools.apply_invert,
        }
        fn = filters.get(filter_name)
        if fn:
            self._current_image = fn(self._current_image)
        return self.info()

    def add_text(self, text: str, x: int = 10, y: int = 10, **kwargs):
        self._current_image = tools.add_text(self._current_image, text, x, y, **kwargs)
        return self.info()

    def add_watermark(self, watermark_data: bytes, **kwargs):
        wm_img = tools.open_image(watermark_data)
        self._current_image = tools.add_watermark(self._current_image, wm_img, **kwargs)
        return self.info()

    def blur_region(self, x: int, y: int, w: int, h: int, radius: int = 20):
        self._current_image = tools.blur_region(self._current_image, x, y, w, h, radius)
        return self.info()

    def denoise(self, strength: int = 3):
        self._current_image = tools.denoise(self._current_image, strength)
        return self.info()

    # ── AI operations ─────────────────────────────────

    def remove_background(self):
        self._current_image = remove_background(self._current_image)
        return self.info()

    def get_capabilities(self) -> dict:
        return self.capabilities
