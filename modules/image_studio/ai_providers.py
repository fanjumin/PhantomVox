"""AI enhancement providers — enhancement pipeline and face restoration.

References:
  - OpenCV face detection: https://docs.opencv.org/4.x/d2/d99/tutorial_js_face_detection.html
"""

from __future__ import annotations

import numpy as np
import cv2


def ai_enhance_image(img: np.ndarray) -> np.ndarray:
    """Multi-step enhancement pipeline: denoise → sharpen → CLAHE → auto WB.

    All operations work on 3-channel BGR; alpha channel is preserved.
    """
    result = img.copy()
    # 1. Denoise (3-channel only, per OpenCV docs requirement)
    result[:, :, :3] = cv2.fastNlMeansDenoisingColored(result[:, :, :3], None, 10, 10, 7, 21)
    # 2. Unsharp mask sharpen
    blurred = cv2.GaussianBlur(result[:, :, :3], (0, 0), 3)
    result[:, :, :3] = cv2.addWeighted(result[:, :, :3], 1.5, blurred, -0.5, 0)
    # 3. CLAHE on L channel
    lab = cv2.cvtColor(result[:, :, :3], cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    l = clahe.apply(l)
    result[:, :, :3] = cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)
    # 4. Grey-world auto white balance
    bgr = result[:, :, :3].astype(np.float32)
    mean_b, mean_g, mean_r = cv2.mean(bgr)[:3]
    gray_mean = (mean_b + mean_g + mean_r) / 3.0
    if mean_b > 0.01:
        bgr[:, :, 0] = np.clip(bgr[:, :, 0] * gray_mean / mean_b, 0, 255)
    if mean_g > 0.01:
        bgr[:, :, 1] = np.clip(bgr[:, :, 1] * gray_mean / mean_g, 0, 255)
    if mean_r > 0.01:
        bgr[:, :, 2] = np.clip(bgr[:, :, 2] * gray_mean / mean_r, 0, 255)
    result[:, :, :3] = bgr.astype(np.uint8)
    return result


def ai_restore_faces(img: np.ndarray) -> np.ndarray:
    """Face restoration: detect faces → CLAHE → bilateral filter smoothing.

    Uses OpenCV Haar cascade for detection; no GPU required.
    """
    result = img.copy()
    gray = cv2.cvtColor(result[:, :, :3], cv2.COLOR_BGR2GRAY)
    cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    faces = cascade.detectMultiScale(gray, 1.1, 4)
    for fx, fy, fw, fh in faces:
        face = result[fy : fy + fh, fx : fx + fw]
        # CLAHE on face
        lab = cv2.cvtColor(face[:, :, :3], cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
        l = clahe.apply(l)
        face[:, :, :3] = cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)
        # Bilateral filter for skin smoothing
        face[:, :, :3] = cv2.bilateralFilter(face[:, :, :3], 5, 50, 50)
        result[fy : fy + fh, fx : fx + fw] = face
    return result


def get_capabilities() -> dict:
    """Return dict of available AI features."""
    return {
        "enhance": True,
        "face_restore": True,
        "super_res": True,
        "lineart": True,
        "hdr": True,
        "remove_bg": True,
        "inpaint": True,
    }
