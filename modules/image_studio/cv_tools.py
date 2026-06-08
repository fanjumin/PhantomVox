"""OpenCV image processing tools.

References: https://docs.opencv.org/4.x/
  - Image filtering: d4/d86/group__imgproc__filter.html
  - Color conversions: df/d3d/group__imgproc__color.html
  - Geometric transforms: da/d6e/tutorial_py_geometric_transformations.html
"""

from __future__ import annotations

import numpy as np
import cv2


# ═══════════════════════════════════════════════════════════════════════
# Filters
# ═══════════════════════════════════════════════════════════════════════

def apply_gaussian_blur(img: np.ndarray, ksize: int = 5) -> np.ndarray:
    """Gaussian blur. ksize must be odd; auto-enforced."""
    ksize = max(3, ksize | 1)
    result = img.copy()
    result[:, :, :3] = cv2.GaussianBlur(img[:, :, :3], (ksize, ksize), 0)
    return result


def apply_median_blur(img: np.ndarray, ksize: int = 5) -> np.ndarray:
    """Median blur — removes salt-and-pepper noise. ksize must be odd."""
    ksize = max(3, ksize | 1)
    result = img.copy()
    result[:, :, :3] = cv2.medianBlur(img[:, :, :3], ksize)
    return result


def apply_bilateral_filter(
    img: np.ndarray, d: int = 9, sigma_color: float = 75, sigma_space: float = 75
) -> np.ndarray:
    """Bilateral filter — edge-preserving smoothing."""
    result = img.copy()
    result[:, :, :3] = cv2.bilateralFilter(img[:, :, :3], d, sigma_color, sigma_space)
    return result


def apply_sharpen(img: np.ndarray, amount: float = 1.0) -> np.ndarray:
    """Sharpen using unsharp-mask-style kernel."""
    kernel = np.array([[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]], np.float32) * amount
    kernel[1, 1] = kernel[1, 1] + (1.0 - amount) * 8.0
    result = img.copy()
    result[:, :, :3] = cv2.filter2D(img[:, :, :3], -1, kernel)
    return np.clip(result, 0, 255).astype(np.uint8)


def apply_emboss(img: np.ndarray) -> np.ndarray:
    """Emboss effect."""
    kernel = np.array([[-2, -1, 0], [-1, 1, 1], [0, 1, 2]], np.float32)
    result = img.copy()
    result[:, :, :3] = cv2.filter2D(img[:, :, :3], -1, kernel) + 128
    return np.clip(result, 0, 255).astype(np.uint8)


def apply_edge_detect(
    img: np.ndarray, threshold1: float = 50, threshold2: float = 150
) -> np.ndarray:
    """Canny edge detection as white edges on black."""
    gray = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, threshold1, threshold2)
    result = img.copy()
    result[:, :, :3] = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
    return result


def apply_grayscale(img: np.ndarray) -> np.ndarray:
    """Convert to grayscale (keep alpha)."""
    gray = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2GRAY)
    result = img.copy()
    result[:, :, :3] = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    return result


def apply_sepia(img: np.ndarray) -> np.ndarray:
    """Sepia tone effect via colour matrix transform."""
    sepia_kernel = np.array(
        [[0.272, 0.534, 0.131], [0.349, 0.686, 0.168], [0.393, 0.769, 0.189]],
        dtype=np.float32,
    )
    result = img.copy()
    bgr = img[:, :, :3].astype(np.float32)
    bgr_sepia = cv2.transform(bgr, sepia_kernel)
    result[:, :, :3] = np.clip(bgr_sepia, 0, 255).astype(np.uint8)
    return result


def apply_invert(img: np.ndarray) -> np.ndarray:
    """Invert colours (keep alpha)."""
    result = img.copy()
    result[:, :, :3] = 255 - img[:, :, :3]
    return result


def apply_custom_kernel(img: np.ndarray, kernel: list[list[float]]) -> np.ndarray:
    """Apply arbitrary convolution kernel."""
    k = np.array(kernel, np.float32)
    result = img.copy()
    result[:, :, :3] = cv2.filter2D(img[:, :, :3], -1, k)
    return np.clip(result, 0, 255).astype(np.uint8)


# ═══════════════════════════════════════════════════════════════════════
# Colour adjustments
# ═══════════════════════════════════════════════════════════════════════

def adjust_brightness(img: np.ndarray, factor: float) -> np.ndarray:
    """Adjust brightness. factor=1.0 = no change, 0=black, 2=2x brighter."""
    result = img.copy()
    hsv = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2HSV).astype(np.float32)
    hsv[:, :, 2] = np.clip(hsv[:, :, 2] * factor, 0, 255)
    result[:, :, :3] = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)
    return result


def adjust_contrast(img: np.ndarray, factor: float) -> np.ndarray:
    """Adjust contrast. factor=1.0 = no change, 0=gray, 2=2x."""
    result = img.copy()
    mean = cv2.mean(img[:, :, :3])[:3]
    bgr = img[:, :, :3].astype(np.float32)
    adjusted = np.clip((bgr - mean) * factor + mean, 0, 255).astype(np.uint8)
    result[:, :, :3] = adjusted
    return result


def adjust_saturation(img: np.ndarray, factor: float) -> np.ndarray:
    """Adjust saturation. factor=1.0 = no change, 0=gray, 2=2x."""
    result = img.copy()
    hsv = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2HSV).astype(np.float32)
    hsv[:, :, 1] = np.clip(hsv[:, :, 1] * factor, 0, 255)
    result[:, :, :3] = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)
    return result


def adjust_hue(img: np.ndarray, shift: float) -> np.ndarray:
    """Shift hue by degrees (0-360). OpenCV H range is 0-179, so divide by 2."""
    result = img.copy()
    hsv = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2HSV).astype(np.float32)
    hsv[:, :, 0] = (hsv[:, :, 0] + shift / 2.0) % 180
    result[:, :, :3] = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)
    return result


def apply_clahe(
    img: np.ndarray, clip_limit: float = 2.0, tile_size: int = 8
) -> np.ndarray:
    """CLAHE contrast enhancement on L channel in LAB space."""
    result = img.copy()
    lab = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=clip_limit, tileGridSize=(tile_size, tile_size))
    l = clahe.apply(l)
    result[:, :, :3] = cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)
    return result


def auto_white_balance(img: np.ndarray, strength: float = 1.0) -> np.ndarray:
    """Auto white balance using OpenCV xphoto SimpleWB (Gray World).

    References:
      - https://docs.opencv.org/4.x/d7/d70/group__xphoto.html#gad3ff26b6c717ee5b4e893ffbe652c88c
    """
    result = img.copy()
    wb = cv2.xphoto.createSimpleWB()
    wb.setP(2.0 * strength)  # interpolate P between 0 (no effect) and 2.0 (full)
    result[:, :, :3] = wb.balanceWhite(img[:, :, :3])
    return result


# ═══════════════════════════════════════════════════════════════════════
# Geometric transforms
# ═══════════════════════════════════════════════════════════════════════

def resize_image(
    img: np.ndarray, width: int, height: int, keep_aspect: bool = False
) -> np.ndarray:
    """Resize image to new dimensions."""
    if keep_aspect:
        h, w = img.shape[:2]
        scale = min(width / w, height / h)
        new_w, new_h = int(w * scale), int(h * scale)
        resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
        result = np.zeros((height, width, 4), dtype=np.uint8)
        y_off = (height - new_h) // 2
        x_off = (width - new_w) // 2
        result[y_off : y_off + new_h, x_off : x_off + new_w] = resized
        return result
    return cv2.resize(img, (width, height), interpolation=cv2.INTER_LINEAR)


def rotate_image(img: np.ndarray, angle: float, expand: bool = True) -> np.ndarray:
    """Rotate image by angle degrees clockwise."""
    h, w = img.shape[:2]
    center = (w / 2, h / 2)
    scale = 1.0
    if expand:
        cos_a = abs(np.cos(np.radians(angle)))
        sin_a = abs(np.sin(np.radians(angle)))
        new_w = int(h * sin_a + w * cos_a)
        new_h = int(h * cos_a + w * sin_a)
        matrix = cv2.getRotationMatrix2D(center, -angle, scale)
        matrix[0, 2] += new_w / 2 - w / 2
        matrix[1, 2] += new_h / 2 - h / 2
        return cv2.warpAffine(
            img,
            matrix,
            (new_w, new_h),
            flags=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=(0, 0, 0, 0),
        )
    else:
        matrix = cv2.getRotationMatrix2D(center, -angle, scale)
        return cv2.warpAffine(
            img,
            matrix,
            (w, h),
            flags=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=(0, 0, 0, 0),
        )


def flip_image(img: np.ndarray, direction: str = "horizontal") -> np.ndarray:
    """Flip image. direction: 'horizontal' (1), 'vertical' (0), 'both' (-1)."""
    code = {"horizontal": 1, "vertical": 0, "both": -1}.get(direction, 1)
    return cv2.flip(img, code)


# ═══════════════════════════════════════════════════════════════════════
# Advanced OpenCV tools
# ═══════════════════════════════════════════════════════════════════════

def smart_denoise(img: np.ndarray, h: float = 10) -> np.ndarray:
    """Non-local means denoising (3-channel only, alpha preserved)."""
    denoised = cv2.fastNlMeansDenoisingColored(img[:, :, :3], None, h, h, 7, 21)
    return np.dstack([denoised, img[:, :, 3]])


def apply_posterize(img: np.ndarray, levels: int = 4) -> np.ndarray:
    """Reduce color levels per channel for a posterization effect."""
    result = img.copy()
    step = 256 // max(2, levels)
    result[:, :, :3] = (img[:, :, :3].astype(np.int32) // step) * step + step // 2
    return np.clip(result, 0, 255).astype(np.uint8)


def apply_pixelate(img: np.ndarray, block: int = 8) -> np.ndarray:
    """Pixelate / mosaic effect by downscaling then upscaling."""
    h, w = img.shape[:2]
    block = max(2, block)
    small = cv2.resize(img, (max(1, w // block), max(1, h // block)),
                       interpolation=cv2.INTER_NEAREST)
    result = cv2.resize(small, (w, h), interpolation=cv2.INTER_NEAREST)
    return result


def apply_vignette(img: np.ndarray, strength: float = 0.5) -> np.ndarray:
    """Add dark vignette corners. strength 0-1."""
    h, w = img.shape[:2]
    kernel_x = cv2.getGaussianKernel(w, w * 0.4)
    kernel_y = cv2.getGaussianKernel(h, h * 0.4)
    mask = kernel_y * kernel_x.T
    mask = mask / mask.max()
    mask = 1.0 - (1.0 - mask) * strength
    result = img.copy()
    for c in range(3):
        result[:, :, c] = (result[:, :, c].astype(np.float32) * mask).clip(0, 255).astype(np.uint8)
    return result


def apply_sketch(img: np.ndarray, blur_size: int = 7) -> np.ndarray:
    """Pencil sketch effect using edge detection + Gaussian blur."""
    gray = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2GRAY)
    blur_size = max(3, blur_size | 1)
    blurred = cv2.GaussianBlur(gray, (blur_size, blur_size), 0)
    edges = cv2.adaptiveThreshold(blurred, 255,
                                   cv2.ADAPTIVE_THRESH_MEAN_C,
                                   cv2.THRESH_BINARY, 9, 10)
    result = img.copy()
    result[:, :, :3] = cv2.cvtColor(255 - edges, cv2.COLOR_GRAY2BGR)
    return result


def apply_threshold(img: np.ndarray, method: str = "otsu", value: int = 128) -> np.ndarray:
    """Apply binary threshold. method: binary / otsu / adaptive."""
    gray = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2GRAY)
    if method == "adaptive":
        thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                        cv2.THRESH_BINARY, 11, 2)
    elif method == "otsu":
        _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    else:
        _, thresh = cv2.threshold(gray, value, 255, cv2.THRESH_BINARY)
    result = img.copy()
    result[:, :, :3] = cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)
    return result


def apply_morphology(img: np.ndarray, op: str = "dilate", ksize: int = 3) -> np.ndarray:
    """Morphological operation: dilate / erode / open / close."""
    gray = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2GRAY)
    _, binary = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (ksize, ksize))
    op_map = {
        "dilate": cv2.MORPH_DILATE,
        "erode": cv2.MORPH_ERODE,
        "open": cv2.MORPH_OPEN,
        "close": cv2.MORPH_CLOSE,
    }
    morphed = cv2.morphologyEx(binary, op_map.get(op, cv2.MORPH_DILATE), kernel)
    result = img.copy()
    result[:, :, :3] = cv2.cvtColor(morphed, cv2.COLOR_GRAY2BGR)
    return result


def smart_sharpen(img: np.ndarray, amount: float = 1.0) -> np.ndarray:
    """Unsharp mask sharpen."""
    kernel = np.array(
        [[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]], np.float32
    )
    kernel[1, 1] = kernel[1, 1] + (1.0 - amount) * 8.0
    result = img.copy()
    result[:, :, :3] = cv2.filter2D(img[:, :, :3], -1, kernel)
    return np.clip(result, 0, 255).astype(np.uint8)


def super_resolve(img: np.ndarray, scale: int = 2) -> np.ndarray:
    """Lanczos upscale + light sharpen. Non-AI, just interpolation."""
    h, w = img.shape[:2]
    new_size = (w * scale, h * scale)
    upscaled = cv2.resize(img, new_size, interpolation=cv2.INTER_LANCZOS4)
    kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]], np.float32)
    upscaled[:, :, :3] = cv2.filter2D(upscaled[:, :, :3], -1, kernel)
    return np.clip(upscaled, 0, 255).astype(np.uint8)


def extract_lineart(
    img: np.ndarray, method: str = "canny"
) -> np.ndarray:
    """Extract line art. method: canny / sobel / laplacian."""
    gray = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2GRAY)
    if method == "canny":
        edges = cv2.Canny(gray, 50, 150)
    elif method == "sobel":
        edges = cv2.Sobel(gray, cv2.CV_8U, 1, 1, ksize=3)
    elif method == "laplacian":
        edges = cv2.Laplacian(gray, cv2.CV_8U, ksize=3)
    else:
        edges = cv2.Canny(gray, 50, 150)
    result = img.copy()
    result[:, :, :3] = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
    return result


def hdr_tone(
    img: np.ndarray,
    gamma: float = 1.5,
    contrast: float = 1.2,
    saturation: float = 1.3,
) -> np.ndarray:
    """Simple HDR tone mapping via gamma + contrast + saturation."""
    f = img.astype(np.float32) / 255.0
    f[:, :, :3] = np.power(f[:, :, :3], 1.0 / gamma)
    mean = np.mean(f[:, :, :3], axis=(0, 1), keepdims=True)
    f[:, :, :3] = (f[:, :, :3] - mean) * contrast + mean
    hsv = cv2.cvtColor(f[:, :, :3], cv2.COLOR_BGR2HSV)
    hsv[:, :, 1] = np.clip(hsv[:, :, 1] * saturation, 0, 1)
    f[:, :, :3] = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)
    return np.clip(f * 255, 0, 255).astype(np.uint8)


def remove_background(img: np.ndarray) -> np.ndarray:
    """Remove background using GrabCut with center rectangle as foreground seed."""
    h, w = img.shape[:2]
    mask = np.zeros((h, w), np.uint8)
    bgd_model = np.zeros((1, 65), np.float64)
    fgd_model = np.zeros((1, 65), np.float64)
    rect = (int(w * 0.1), int(h * 0.1), int(w * 0.8), int(h * 0.8))
    cv2.grabCut(img[:, :, :3], mask, rect, bgd_model, fgd_model, 5, cv2.GC_INIT_WITH_RECT)
    mask2 = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype("uint8")
    result = img.copy()
    result[:, :, 3] = mask2
    return result


def inpaint_erase(
    img: np.ndarray, x: int, y: int, w: int, h: int, radius: int = 3
) -> np.ndarray:
    """Erase region by inpainting with Telea algorithm."""
    img_h, img_w = img.shape[:2]
    mask = np.zeros((img_h, img_w), np.uint8)
    x1, y1 = max(0, x), max(0, y)
    x2, y2 = min(img_w, x + w), min(img_h, y + h)
    mask[y1:y2, x1:x2] = 255
    if not np.any(mask):
        return img.copy()
    bgr = img[:, :, :3].copy()
    alpha = img[:, :, 3].copy() if img.shape[2] == 4 else np.full((img_h, img_w), 255, np.uint8)
    inpainted = cv2.inpaint(bgr, mask, radius, cv2.INPAINT_TELEA)
    return np.dstack([inpainted, alpha])


def blur_region(
    img: np.ndarray, x: int, y: int, w: int, h: int, ksize: int = 15
) -> np.ndarray:
    """Gaussian blur a rectangular region."""
    result = img.copy()
    ksize = max(3, ksize | 1)
    x1, y1 = max(0, x), max(0, y)
    x2, y2 = min(img.shape[1], x + w), min(img.shape[0], y + h)
    roi = result[y1:y2, x1:x2]
    if roi.size > 0:
        roi[:, :, :3] = cv2.GaussianBlur(roi[:, :, :3], (ksize, ksize), 0)
    return result


# ═══════════════════════════════════════════════════════════════════════
# Crop (NumPy slice — no OpenCV needed)
# ═══════════════════════════════════════════════════════════════════════

def crop_image(img: np.ndarray, x: int, y: int, w: int, h: int) -> np.ndarray:
    """Crop a rectangular region."""
    h_img, w_img = img.shape[:2]
    x1, y1 = max(0, x), max(0, y)
    x2, y2 = min(w_img, x + w), min(h_img, y + h)
    if x2 <= x1 or y2 <= y1:
        raise ValueError(f"Invalid crop: ({x},{y},{w},{h}) on {w_img}x{h_img}")
    return img[y1:y2, x1:x2].copy()


# ═══════════════════════════════════════════════════════════════════════
# Named filter dispatcher
# ═══════════════════════════════════════════════════════════════════════

FILTER_MAP = {
    "blur": lambda img, **kw: apply_gaussian_blur(img, kw.get("ksize", 5)),
    "sharpen": lambda img, **kw: apply_sharpen(img, kw.get("amount", 1.0)),
    "median_blur": lambda img, **kw: apply_median_blur(img, kw.get("ksize", 5)),
    "bilateral": lambda img, **kw: apply_bilateral_filter(
        img, kw.get("d", 9), kw.get("sigma_color", 75), kw.get("sigma_space", 75)
    ),
    "grayscale": lambda img, **kw: apply_grayscale(img),
    "sepia": lambda img, **kw: apply_sepia(img),
    "invert": lambda img, **kw: apply_invert(img),
    "emboss": lambda img, **kw: apply_emboss(img),
    "edge_detect": lambda img, **kw: apply_edge_detect(
        img, kw.get("threshold1", 50), kw.get("threshold2", 150)
    ),
    "posterize": lambda img, **kw: apply_posterize(img, kw.get("levels", 4)),
    "pixelate": lambda img, **kw: apply_pixelate(img, kw.get("block", 8)),
    "vignette": lambda img, **kw: apply_vignette(img, kw.get("strength", 0.5)),
    "sketch": lambda img, **kw: apply_sketch(img, kw.get("blur_size", 7)),
    "threshold": lambda img, **kw: apply_threshold(img, kw.get("method", "otsu"), kw.get("value", 128)),
    "morphology": lambda img, **kw: apply_morphology(img, kw.get("op", "dilate"), kw.get("ksize", 3)),
}


def apply_filter(img: np.ndarray, filter_name: str, **kw) -> np.ndarray:
    """Apply a named filter."""
    fn = FILTER_MAP.get(filter_name)
    if fn is None:
        raise ValueError(
            f"Unknown filter: {filter_name}. Available: {list(FILTER_MAP.keys())}"
        )
    return fn(img, **kw)
