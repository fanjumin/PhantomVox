"""硬件检测模块 — PhantomVox AI 硬件评估与模型等级映射"""

from .hardware import (
    HardwareDetector, HardwareSpec,
    detect, report,
    MODEL_TIER_MAP, TIER_LABELS,
)

__all__ = [
    "HardwareDetector", "HardwareSpec",
    "detect", "report",
    "MODEL_TIER_MAP", "TIER_LABELS",
]
