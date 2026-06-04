"""
Image Editor Engine — PhantomVox AI 图像编辑器

Architecture:
- Basic editing: local Pillow (no GPU, instant)
- AI restoration: hardware-aware dispatch (local if GPU, API if CPU)
- Undo/redo: in-memory history stack (max 30 states)
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

MAX_HISTORY = 30


class ImageEditorEngine:
    """Image Editor Engine — wraps tools + providers + undo/redo."""

    def __init__(self, hardware=None):
        self._hardware = hardware
        self._current_image = None
        self._current_path = None
        self.capabilities = detect_capabilities(hardware)
        self._history: list = []       # list of PIL Image copies
        self._history_pos: int = -1    # current position in _history
        # Counter for undo label
        self._mutations_since_load: int = 0

    @property
    def current_image(self):
        return self._current_image

    # ── History / Undo-Redo ────────────────────────────

    def _save_snapshot(self):
        """Save current image state into history, truncating any redo branches."""
        if self._current_image is None:
            return
        # Truncate any future (redo) states
        if self._history_pos < len(self._history) - 1:
            self._history = self._history[:self._history_pos + 1]
        # Snapshot: copy the PIL image
        snapshot = self._current_image.copy()
        self._history.append(snapshot)
        # Enforce max size
        if len(self._history) > MAX_HISTORY:
            self._history = self._history[-MAX_HISTORY:]
        self._history_pos = len(self._history) - 1

    @property
    def can_undo(self) -> bool:
        return self._history_pos > 0

    @property
    def can_redo(self) -> bool:
        return self._history_pos < len(self._history) - 1

    @property
    def undo_label(self) -> str:
        """Return a short description of what undo would revert to."""
        if self.can_undo:
            return f"Step {self._history_pos}/{len(self._history) - 1}"
        return ""

    def undo(self):
        if not self.can_undo:
            raise ValueError("Nothing to undo")
        self._history_pos -= 1
        self._current_image = self._history[self._history_pos].copy()
        return self.info()

    def redo(self):
        if not self.can_redo:
            raise ValueError("Nothing to redo")
        self._history_pos += 1
        self._current_image = self._history[self._history_pos].copy()
        return self.info()

    def get_history_state(self) -> dict:
        return {
            "can_undo": self.can_undo,
            "can_redo": self.can_redo,
            "undo_label": self.undo_label,
            "total_steps": len(self._history),
        }

    # ── Session management ────────────────────────────

    def load(self, path_or_bytes):
        """Load image into session. Clears history."""
        self._current_image = tools.open_image(path_or_bytes)
        self._current_path = path_or_bytes if isinstance(path_or_bytes, str) else None
        self._history = []
        self._history_pos = -1
        self._mutations_since_load = 0
        # Save initial state as first history entry
        self._save_snapshot()
        self._history_pos = 0
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

    # ── Operations (delegate to tools, with history) ───

    def crop(self, x: int, y: int, w: int, h: int):
        self._save_snapshot()
        self._current_image = tools.crop(self._current_image, x, y, w, h)
        return self.info()

    def resize(self, width: int, height: int, keep_aspect: bool = False):
        self._save_snapshot()
        self._current_image = tools.resize(self._current_image, width, height, keep_aspect)
        return self.info()

    def rotate(self, angle: float, expand: bool = True):
        self._save_snapshot()
        self._current_image = tools.rotate(self._current_image, angle, expand)
        return self.info()

    def flip(self, direction: str = "horizontal"):
        self._save_snapshot()
        self._current_image = tools.flip(self._current_image, direction)
        return self.info()

    def adjust_brightness(self, factor: float):
        self._save_snapshot()
        self._current_image = tools.adjust_brightness(self._current_image, factor)
        return self.info()

    def adjust_contrast(self, factor: float):
        self._save_snapshot()
        self._current_image = tools.adjust_contrast(self._current_image, factor)
        return self.info()

    def adjust_saturation(self, factor: float):
        self._save_snapshot()
        self._current_image = tools.adjust_saturation(self._current_image, factor)
        return self.info()

    def adjust_sharpness(self, factor: float):
        self._save_snapshot()
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
            self._save_snapshot()
            self._current_image = fn(self._current_image)
        return self.info()

    def add_text(self, text: str, x: int = 10, y: int = 10, **kwargs):
        self._save_snapshot()
        self._current_image = tools.add_text(self._current_image, text, x, y, **kwargs)
        return self.info()

    def add_watermark(self, watermark_data: bytes, **kwargs):
        self._save_snapshot()
        wm_img = tools.open_image(watermark_data)
        self._current_image = tools.add_watermark(self._current_image, wm_img, **kwargs)
        return self.info()

    def blur_region(self, x: int, y: int, w: int, h: int, radius: int = 20):
        self._save_snapshot()
        self._current_image = tools.blur_region(self._current_image, x, y, w, h, radius)
        return self.info()

    def denoise(self, strength: int = 3):
        self._save_snapshot()
        self._current_image = tools.denoise(self._current_image, strength)
        return self.info()

    # ── AI operations ─────────────────────────────────

    def remove_background(self):
        self._save_snapshot()
        self._current_image = remove_background(self._current_image)
        return self.info()

    def get_capabilities(self) -> dict:
        return self.capabilities
