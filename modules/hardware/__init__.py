"""Hardware Detection Module — PhantomVox AI hardware assessment and model tier mapping"""

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
