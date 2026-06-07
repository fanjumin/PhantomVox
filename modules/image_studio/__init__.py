"""Image Studio — FastAPI + OpenCV image editor backend.

References:
  - OpenCV docs: https://docs.opencv.org/4.x/
  - Layer compositing: Porter-Duff src-over alpha blend
  - API design: Photopea / Photoshop industry standard
"""

from __future__ import annotations

import base64, io, os, uuid, json
from typing import Optional
from io import BytesIO

import cv2
import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# Data model — Layer
# ---------------------------------------------------------------------------

class Layer:
    """Single image layer in the document stack.

    Attributes:
        image: BGRA uint8 np.ndarray, shape=(H, W, 4)
        name: human-readable label
        opacity: 0.0–1.0
        visible: visibility toggle
        blend_mode: normal | multiply | screen | overlay | darken | lighten
        mask: optional single-channel uint8 mask
        locked: prevents modification when True
    """

    __slots__ = ("image", "name", "opacity", "visible", "blend_mode", "mask", "locked")

    BLEND_MODES = (
        "normal", "multiply", "screen", "overlay",
        "darken", "lighten", "difference", "exclusion",
        "hard_light", "soft_light",
    )

    def __init__(
        self,
        image: np.ndarray,
        name: str = "Layer",
        opacity: float = 1.0,
        visible: bool = True,
        blend_mode: str = "normal",
        mask: np.ndarray | None = None,
        locked: bool = False,
    ):
        assert image.dtype == np.uint8, "Layer image must be uint8"
        assert image.shape[2] == 4, "Layer image must be BGRA (H,W,4)"
        assert 0.0 <= opacity <= 1.0, "Opacity must be 0-1"
        self.image = image
        self.name = name
        self.opacity = opacity
        self.visible = visible
        self.blend_mode = blend_mode if blend_mode in self.BLEND_MODES else "normal"
        self.mask = mask
        self.locked = locked

    @property
    def width(self) -> int:
        return self.image.shape[1]

    @property
    def height(self) -> int:
        return self.image.shape[0]

    def copy(self) -> Layer:
        return Layer(
            image=self.image.copy(),
            name=self.name,
            opacity=self.opacity,
            visible=self.visible,
            blend_mode=self.blend_mode,
            mask=self.mask.copy() if self.mask is not None else None,
            locked=self.locked,
        )

# ---------------------------------------------------------------------------
# History — Command-pattern undo/redo
# ---------------------------------------------------------------------------

_MAX_HISTORY = 50
# Maximum total memory for all snapshots (bytes)
_MAX_SNAPSHOT_MEMORY = 256 * 1024 * 1024  # 256 MB


class _Snapshot:
    """Stores serialised state of all layers at a point in time."""

    def __init__(self, layers: list[Layer], doc_width: int, doc_height: int):
        self.data = {
            "w": doc_width,
            "h": doc_height,
            "layers": [
                {
                    "image_b64": _encode_bgra(layer.image),
                    "name": layer.name,
                    "opacity": layer.opacity,
                    "visible": layer.visible,
                    "blend_mode": layer.blend_mode,
                    "locked": layer.locked,
                }
                for layer in layers
            ],
        }

    def _approx_size(self) -> int:
        """Approximate memory used by this snapshot (sum of base64 string lengths)."""
        total = 0
        for ld in self.data["layers"]:
            total += len(ld["image_b64"])
        return total

    def restore(self) -> tuple[list[Layer], int, int]:
        layers = []
        for ld in self.data["layers"]:
            img = _decode_bgra(ld["image_b64"])
            layers.append(Layer(
                image=img,
                name=ld["name"],
                opacity=ld["opacity"],
                visible=ld["visible"],
                blend_mode=ld["blend_mode"],
                locked=ld["locked"],
            ))
        return layers, self.data["w"], self.data["h"]


# ---------------------------------------------------------------------------
# Composite engine
# ---------------------------------------------------------------------------

def composite_layers(layers: list[Layer], width: int, height: int) -> np.ndarray:
    """Composite all visible layers bottom-to-top into a single BGRA image."""
    result = np.zeros((height, width, 4), dtype=np.uint8)
    for layer in layers:
        if not layer.visible:
            continue
        img = layer.image.copy()
        # Resize if layer size doesn't match document size
        if img.shape[:2] != (height, width):
            import cv2
            img = cv2.resize(img, (width, height), interpolation=cv2.INTER_LINEAR)
        # Apply opacity
        if layer.opacity < 1.0:
            alpha = img[:, :, 3].astype(np.float32) * layer.opacity
            img[:, :, 3] = alpha.astype(np.uint8)
        # Apply per-pixel mask
        if layer.mask is not None:
            mask_resized = cv2.resize(layer.mask, (width, height), interpolation=cv2.INTER_LINEAR) if layer.mask.shape[:2] != (height, width) else layer.mask
            img[:, :, 3] = (img[:, :, 3].astype(np.float32) * (mask_resized.astype(np.float32) / 255.0)).astype(np.uint8)
        # Alpha blend
        result = _alpha_blend(img, result, layer.blend_mode)
    return result


def _alpha_blend(src: np.ndarray, dst: np.ndarray, mode: str = "normal") -> np.ndarray:
    """Porter-Duff src-over alpha blending with blend mode support."""
    src_f = src.astype(np.float32) / 255.0
    dst_f = dst.astype(np.float32) / 255.0

    src_a = src_f[:, :, 3:4]
    dst_a = dst_f[:, :, 3:4]
    src_rgb = src_f[:, :, :3]
    dst_rgb = dst_f[:, :, :3]

    # Blend RGB channels based on mode
    if mode == "normal":
        blended_rgb = src_rgb
    elif mode == "multiply":
        blended_rgb = src_rgb * dst_rgb
    elif mode == "screen":
        blended_rgb = 1.0 - (1.0 - src_rgb) * (1.0 - dst_rgb)
    elif mode == "overlay":
        blended_rgb = np.where(
            dst_rgb < 0.5,
            2.0 * src_rgb * dst_rgb,
            1.0 - 2.0 * (1.0 - src_rgb) * (1.0 - dst_rgb),
        )
    elif mode == "darken":
        blended_rgb = np.minimum(src_rgb, dst_rgb)
    elif mode == "lighten":
        blended_rgb = np.maximum(src_rgb, dst_rgb)
    elif mode == "difference":
        blended_rgb = np.abs(src_rgb - dst_rgb)
    elif mode == "exclusion":
        blended_rgb = src_rgb + dst_rgb - 2.0 * src_rgb * dst_rgb
    elif mode == "hard_light":
        blended_rgb = np.where(
            src_rgb < 0.5,
            2.0 * src_rgb * dst_rgb,
            1.0 - 2.0 * (1.0 - src_rgb) * (1.0 - dst_rgb),
        )
    elif mode == "soft_light":
        blended_rgb = (1.0 - 2.0 * src_rgb) * dst_rgb * dst_rgb + 2.0 * src_rgb * dst_rgb
    else:
        blended_rgb = src_rgb

    # Standard src-over alpha compositing
    out_a = src_a + dst_a * (1.0 - src_a)
    out_rgb = np.where(
        out_a > 1e-6,
        (blended_rgb * src_a + dst_rgb * dst_a * (1.0 - src_a)) / out_a,
        0.0,
    )

    result = np.concatenate([out_rgb, out_a], axis=2)
    result = np.clip(result, 0.0, 1.0)
    return (result * 255.0).astype(np.uint8)


# ---------------------------------------------------------------------------
# Image encode/decode helpers
# ---------------------------------------------------------------------------

def _encode_bgra(arr: np.ndarray) -> str:
    """BGRA uint8 → base64 PNG string."""
    # BGRA → RGBA for PIL
    rgba = cv2.cvtColor(arr, cv2.COLOR_BGRA2RGBA)
    pil_img = Image.fromarray(rgba, "RGBA")
    buf = BytesIO()
    pil_img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def _decode_bgra(b64: str) -> np.ndarray:
    """base64 PNG string → BGRA uint8 ndarray."""
    import cv2
    raw = base64.b64decode(b64)
    pil_img = Image.open(BytesIO(raw)).convert("RGBA")
    rgba = np.array(pil_img)
    return cv2.cvtColor(rgba, cv2.COLOR_RGBA2BGRA)


def _pil_to_bgra(pil_img: Image.Image) -> np.ndarray:
    """PIL Image (any mode) → BGRA uint8 ndarray."""
    import cv2
    rgba = np.array(pil_img.convert("RGBA"))
    return cv2.cvtColor(rgba, cv2.COLOR_RGBA2BGRA)


def _bgra_to_pil(arr: np.ndarray) -> Image.Image:
    """BGRA uint8 → PIL RGBA Image."""
    rgba = cv2.cvtColor(arr, cv2.COLOR_BGRA2RGBA)
    return Image.fromarray(rgba, "RGBA")



# ---------------------------------------------------------------------------
# Document — the core editor model
# ---------------------------------------------------------------------------

class Document:
    """Represents a single open image document with undo/redo history."""

    def __init__(self, bg_image: np.ndarray | None = None, width: int = 1920, height: int = 1080):
        if bg_image is not None:
            self.width = bg_image.shape[1]
            self.height = bg_image.shape[0]
            bg_layer = Layer(image=bg_image.copy(), name="Background")
            self.layers = [bg_layer]
        else:
            self.width = width
            self.height = height
            self.layers = []

        self._undo_stack: list[_Snapshot] = []
        self._redo_stack: list[_Snapshot] = []

    # -- Save snapshot (AFTER operation) --

    def _save_snapshot(self):
        snap = _Snapshot(self.layers, self.width, self.height)
        self._undo_stack.append(snap)
        self._redo_stack.clear()
        # Enforce max count
        if len(self._undo_stack) > _MAX_HISTORY:
            self._undo_stack.pop(0)
        # Enforce max memory — pop oldest until under limit
        total = sum(s._approx_size() for s in self._undo_stack)
        while total > _MAX_SNAPSHOT_MEMORY and len(self._undo_stack) > 1:
            removed = self._undo_stack.pop(0)
            total -= removed._approx_size()

    # -- Composite preview --

    def render(self) -> np.ndarray:
        """Return composite preview of all visible layers."""
        return composite_layers(self.layers, self.width, self.height)

    def to_base64(self) -> str:
        return _encode_bgra(self.render())

    def to_thumbnail_base64(self, max_size: int = 320) -> str:
        """Return base64 of a downscaled preview (max side = max_size px)."""
        rendered = self.render()
        h, w = rendered.shape[:2]
        scale = min(max_size / w, max_size / h, 1.0)
        if scale < 1.0:
            import cv2
            thumb = cv2.resize(rendered, None, fx=scale, fy=scale,
                               interpolation=cv2.INTER_LINEAR)
            return _encode_bgra(thumb)
        return _encode_bgra(rendered)

    # -- Layer operations --

    def add_layer(self, layer: Layer):
        self._save_snapshot()
        self.layers.append(layer)

    def delete_layer(self, index: int):
        if 0 <= index < len(self.layers):
            self._save_snapshot()
            self.layers.pop(index)

    def reorder_layer(self, old_index: int, new_index: int):
        if old_index < 0 or old_index >= len(self.layers) or new_index < 0 or new_index >= len(self.layers):
            return
        self._save_snapshot()
        layer = self.layers.pop(old_index)
        self.layers.insert(new_index, layer)

    def merge_layers(self, indices: list[int]):
        if len(indices) < 2:
            return
        self._save_snapshot()
        # Filter valid sorted indices
        valid = sorted([i for i in indices if 0 <= i < len(self.layers)], reverse=True)
        if len(valid) < 2:
            return
        # Composite selected layers from bottom to top
        selected = [self.layers[i] for i in sorted(valid)]
        merged_img = composite_layers(selected, self.width, self.height)
        merged_layer = Layer(image=merged_img, name="Merged")
        # Remove selected and add merged at bottommost position
        for i in valid:
            self.layers.pop(i)
        insert_pos = min(valid)
        self.layers.insert(insert_pos, merged_layer)

    def set_layer_properties(self, index: int, **props):
        if 0 <= index < len(self.layers):
            self._save_snapshot()
            layer = self.layers[index]
            if "opacity" in props:
                layer.opacity = max(0.0, min(1.0, props["opacity"]))
            if "visible" in props:
                layer.visible = bool(props["visible"])
            if "blend_mode" in props and props["blend_mode"] in Layer.BLEND_MODES:
                layer.blend_mode = props["blend_mode"]
            if "name" in props:
                layer.name = str(props["name"])
            if "locked" in props:
                layer.locked = bool(props["locked"])

    # -- History --

    def undo(self):
        if not self._undo_stack:
            raise ValueError("Nothing to undo")
        self._redo_stack.append(_Snapshot(self.layers, self.width, self.height))
        snap = self._undo_stack.pop()
        self.layers, self.width, self.height = snap.restore()

    def redo(self):
        if not self._redo_stack:
            raise ValueError("Nothing to redo")
        self._undo_stack.append(_Snapshot(self.layers, self.width, self.height))
        snap = self._redo_stack.pop()
        self.layers, self.width, self.height = snap.restore()

    def get_history_state(self) -> dict:
        return {
            "can_undo": len(self._undo_stack) > 0,
            "can_redo": len(self._redo_stack) > 0,
            "undo_count": len(self._undo_stack),
            "redo_count": len(self._redo_stack),
        }

    # -- I/O --

    def info(self) -> dict:
        return {
            "width": self.width,
            "height": self.height,
            "layers": len(self.layers),
            "visible_layers": sum(1 for l in self.layers if l.visible),
        }

    def export(self, path: str, fmt: str = "png", quality: int = 95) -> str:
        """Export composite to file."""
        img = _bgra_to_pil(self.render())
        save_kwargs = {}
        if fmt.lower() in ("jpg", "jpeg"):
            save_kwargs["quality"] = quality
        img.save(path, format=fmt.upper(), **save_kwargs)
        return os.path.abspath(path)

    def to_dict(self) -> dict:
        return {
            "width": self.width,
            "height": self.height,
            "layers": [self._layer_to_dict(l) for l in self.layers],
            "history": self.get_history_state(),
        }

    def _layer_to_dict(self, layer: Layer) -> dict:
        return {
            "name": layer.name,
            "width": layer.width,
            "height": layer.height,
            "opacity": layer.opacity,
            "visible": layer.visible,
            "blend_mode": layer.blend_mode,
            "locked": layer.locked,
        }
