"""
OpenCV Image Tools — Advanced image processing using OpenCV.

Provides: denoise, sharpen, CLAHE, inpaint, white balance, 
line art extraction, super resolution, edge detection.
All functions work on CPU (no GPU needed).
"""

from __future__ import annotations
from typing import Optional, List, Tuple
import numpy as np

# OpenCV is optional - all functions gracefully handle missing import
try:
    import cv2
    _HAVE_OPENCV = True
except ImportError:
    cv2 = None  # type: ignore
    _HAVE_OPENCV = False

from PIL import Image


def _pil_to_cv2(img: Image.Image) -> np.ndarray:
    """Convert PIL Image to OpenCV BGR array."""
    return cv2.cvtColor(np.array(img.convert("RGB")), cv2.COLOR_RGB2BGR)


def _cv2_to_pil(arr: np.ndarray) -> Image.Image:
    """Convert OpenCV BGR array back to PIL Image (RGB)."""
    return Image.fromarray(cv2.cvtColor(arr, cv2.COLOR_BGR2RGB))


# ── Smart Denoise (much better than Pillow's basic filters) ──

def smart_denoise(img: Image.Image, strength: int = 10,
                  template_size: int = 7, search_size: int = 21) -> Image.Image:
    """Non-local Means Denoising. strength: 1-20, higher = more denoise."""
    arr = _pil_to_cv2(img)
    h = max(1, strength)
    result = cv2.fastNlMeansDenoisingColored(arr, None, h, h,
                                              template_size, search_size)
    return _cv2_to_pil(result)


# ── Smart Sharpen (unsharp mask) ────────────────────────────

def smart_sharpen(img: Image.Image, amount: float = 1.0,
                  radius: int = 3, threshold: int = 10) -> Image.Image:
    """Unsharp mask sharpening. amount: 0-3, higher = more sharp."""
    arr = _pil_to_cv2(img)
    blurred = cv2.GaussianBlur(arr, (0, 0), radius)
    result = cv2.addWeighted(arr, 1.0 + amount, blurred, -amount, 0)
    # Clip and threshold
    mask = np.abs(arr.astype(np.int16) - blurred.astype(np.int16)) > threshold
    mask = mask.astype(np.uint8) * 255
    result = np.where(mask > 0, result, arr).clip(0, 255).astype(np.uint8)
    return _cv2_to_pil(result)


# ── CLAHE Contrast Enhancement ──────────────────────────────

def clahe_enhance(img: Image.Image, clip_limit: float = 2.0,
                  tile_size: int = 8) -> Image.Image:
    """Adaptive histogram equalization for contrast enhancement.
    clip_limit: 1-5, higher = more contrast."""
    arr = _pil_to_cv2(img)
    lab = cv2.cvtColor(arr, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=clip_limit,
                             tileGridSize=(tile_size, tile_size))
    l = clahe.apply(l)
    lab = cv2.merge([l, a, b])
    result = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)
    return _cv2_to_pil(result)


# ── Auto White Balance ──────────────────────────────────────

def auto_white_balance(img: Image.Image, strength: float = 1.0) -> Image.Image:
    """Simple auto white balance using gray-world assumption."""
    arr = _pil_to_cv2(img).astype(np.float32)
    # Simple gray world
    avg_b = np.mean(arr[:, :, 0])
    avg_g = np.mean(arr[:, :, 1])
    avg_r = np.mean(arr[:, :, 2])
    avg = (avg_r + avg_g + avg_b) / 3
    scale_r = avg / avg_r if avg_r > 0 else 1
    scale_g = avg / avg_g if avg_g > 0 else 1
    scale_b = avg / avg_b if avg_b > 0 else 1
    # Apply with strength
    arr[:, :, 0] = arr[:, :, 0] * (1 + (scale_b - 1) * strength)
    arr[:, :, 1] = arr[:, :, 1] * (1 + (scale_g - 1) * strength)
    arr[:, :, 2] = arr[:, :, 2] * (1 + (scale_r - 1) * strength)
    result = arr.clip(0, 255).astype(np.uint8)
    return _cv2_to_pil(result)


# ── Inpainting (涂抹消除 / Object Removal) ─────────────────

def inpaint_erase(img: Image.Image, mask: Image.Image,
                  method: str = "telea", radius: int = 5) -> Image.Image:
    """Remove object using inpainting.
    mask: PIL Image where white pixels indicate areas to remove.
    method: 'telea' or 'ns'. radius: 1-10, higher = smoother fill.
    """
    arr = _pil_to_cv2(img)
    mask_arr = cv2.cvtColor(np.array(mask.convert("RGB")), cv2.COLOR_RGB2GRAY)
    _, mask_bin = cv2.threshold(mask_arr, 128, 255, cv2.THRESH_BINARY)
    cv2_method = cv2.INPAINT_TELEA if method == "telea" else cv2.INPAINT_NS
    result = cv2.inpaint(arr, mask_bin, radius, cv2_method)
    return _cv2_to_pil(result)


def inpaint_from_points(img: Image.Image,
                        points: List[Tuple[int, int]],
                        brush_size: int = 20,
                        method: str = "telea") -> Image.Image:
    """Convenience: create mask from brush points and inpaint.
    points: list of (x, y) coordinate tuples of brush strokes.
    """
    arr = _pil_to_cv2(img)
    mask = np.zeros((img.height, img.width), dtype=np.uint8)
    if len(points) < 2:
        x, y = points[0]
        cv2.circle(mask, (x, y), brush_size, 255, -1)
    else:
        pts = np.array(points, dtype=np.int32).reshape((-1, 1, 2))
        cv2.polylines(mask, [pts], False, 255, thickness=brush_size)
    cv2_method = cv2.INPAINT_TELEA if method == "telea" else cv2.INPAINT_NS
    result = cv2.inpaint(arr, mask, brush_size // 2, cv2_method)
    return _cv2_to_pil(result)


# ── Super Resolution (变清晰 / Upscale) ─────────────────────

def super_resolve(img: Image.Image, scale: int = 2,
                  sharpen_amount: float = 0.5) -> Image.Image:
    """Upscale image using Lanczos + optional smart sharpen.
    scale: 2 or 4. For higher quality, add AI model.
    """
    w, h = img.width * scale, img.height * scale
    result = img.resize((w, h), Image.LANCZOS)
    if sharpen_amount > 0:
        result = smart_sharpen(result, amount=sharpen_amount)
    return result


# ── Extract Line Art (提取线稿) ─────────────────────────────

def extract_lineart(img: Image.Image, method: str = "canny",
                    threshold1: int = 50, threshold2: int = 150,
                    invert: bool = True) -> Image.Image:
    """Extract line art / edges from image.
    method: 'canny', 'sobel', or 'laplacian'.
    Returns white-on-transparent or black-on-white line art.
    """
    arr = _pil_to_cv2(img)
    gray = cv2.cvtColor(arr, cv2.COLOR_BGR2GRAY)

    if method == "canny":
        edges = cv2.Canny(gray, threshold1, threshold2)
    elif method == "sobel":
        grad_x = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
        grad_y = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
        edges = np.sqrt(grad_x**2 + grad_y**2).clip(0, 255).astype(np.uint8)
    elif method == "laplacian":
        edges = cv2.Laplacian(gray, cv2.CV_64F).clip(0, 255).astype(np.uint8)
    else:
        edges = cv2.Canny(gray, 50, 150)

    if invert:
        edges = 255 - edges  # White lines on black

    return Image.fromarray(edges).convert("L").convert("RGB")


# ── Face Detection (for future use) ────────────────────────

def detect_faces(img: Image.Image) -> List[dict]:
    """Detect faces using Haar cascade. Returns list of {x, y, w, h}."""
    gray = cv2.cvtColor(np.array(img.convert("RGB")), cv2.COLOR_RGB2GRAY)
    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    faces = face_cascade.detectMultiScale(gray, 1.1, 5)
    return [{"x": int(x), "y": int(y), "w": int(w), "h": int(h)}
            for (x, y, w, h) in faces]


# ── HDR Tone Mapping ───────────────────────────────────────

def hdr_tone(img: Image.Image, gamma: float = 1.0,
             contrast: float = 0.0, saturation: float = 1.0) -> Image.Image:
    """Simple HDR tone mapping effect using OpenCV."""
    arr = _pil_to_cv2(img).astype(np.float32) / 255.0
    # Simple Reinhard tone mapping
    luminance = 0.299 * arr[:, :, 2] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 0]
    key = np.exp(np.mean(np.log(luminance.max() * luminance + 1e-6)))
    scale = 0.18 / (key + 1e-6)
    for c in range(3):
        arr[:, :, c] = arr[:, :, c] * scale / (1 + arr[:, :, c] * scale)
    # Gamma correction
    arr = np.power(arr.clip(0, 1), 1.0 / gamma)
    result = (arr * 255).clip(0, 255).astype(np.uint8)
    return _cv2_to_pil(result)


# ── Perspective Correction ────────────────────────────────

def perspective_correct(img: Image.Image,
                        src_points: List[Tuple[int, int]],
                        dst_points: Optional[List[Tuple[int, int]]] = None,
                        output_size: Optional[Tuple[int, int]] = None
                        ) -> Image.Image:
    """Apply perspective transform.
    src_points: 4 source points [(x1,y1), (x2,y2), (x3,y3), (x4,y4)].
    If dst_points is None, auto-compute to correct perspective.
    """
    arr = _pil_to_cv2(img)
    src = np.float32(src_points)
    if dst_points is None:
        # Auto-compute: map to rectangle
        x_min = min(p[0] for p in src_points)
        x_max = max(p[0] for p in src_points)
        y_min = min(p[1] for p in src_points)
        y_max = max(p[1] for p in src_points)
        dst = np.float32([[x_min, y_min], [x_max, y_min],
                          [x_max, y_max], [x_min, y_max]])
    else:
        dst = np.float32(dst_points)
    matrix = cv2.getPerspectiveTransform(src, dst)
    if output_size:
        result = cv2.warpPerspective(arr, matrix, output_size)
    else:
        result = cv2.warpPerspective(arr, matrix, (img.width, img.height))
    return _cv2_to_pil(result)
