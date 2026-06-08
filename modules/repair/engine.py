"""RepairEngine — hardware-aware AI image repair dispatcher.

Strategy: cloud-first, OpenCV fallback, local models as stubs for future.

Provider enum:
  REPLICATE_FLUX  — ★ Replicate FLUX.1 Fill [pro] (best quality, needs key)
  ZHIPU_COGVIEW   — Zhipu CogView-4 (good quality, you already have key)
  LOCAL_LAMA      — stub for future local LaMa
  NONE            — cv2.inpaint Telea (offline, zero dependencies)
"""

from __future__ import annotations

import logging
from enum import Enum
from typing import Any

import numpy as np

from .providers.base import BaseRepairProvider

logger = logging.getLogger(__name__)


class RepairProvider(str, Enum):
    SILICONFLOW = "siliconflow"  # Qwen-Image-Edit-2509 via SiliconFlow
    REPLICATE_FLUX = "replicate_flux"
    ZHIPU_COGVIEW = "zhipu_cogview"
    LOCAL_LAMA = "local_lama"
    NONE = "none"


_PROVIDER_MAP = {
    RepairProvider.SILICONFLOW: ("modules.repair.providers.siliconflow", "SiliconFlowRepair"),
    RepairProvider.REPLICATE_FLUX: ("modules.repair.providers.replicate", "ReplicateRepair"),
    RepairProvider.ZHIPU_COGVIEW: ("modules.repair.providers.zhipu", "ZhipuRepair"),
    RepairProvider.LOCAL_LAMA: ("modules.repair.local.lama", "LamaRepair"),
    RepairProvider.NONE: ("modules.repair.providers.opencv_fallback", "OpenCVFallback"),
}


class RepairEngine:
    """AI Repair Engine — resolve provider from config and dispatch."""

    def __init__(self, config: dict[str, Any] | None = None):
        self._config = config or {}
        repair_cfg = self._config.get("repair", {})
        provider_name = repair_cfg.get("provider", RepairProvider.SILICONFLOW.value)
        try:
            self.provider = RepairProvider(provider_name)
        except ValueError:
            logger.warning("Unknown repair provider %r, falling back to NONE", provider_name)
            self.provider = RepairProvider.NONE

        self.api_keys = self._config.get("api_keys", {})
        self._impl: BaseRepairProvider | None = None

    def _resolve(self) -> BaseRepairProvider:
        """Factory: instantiate the implementation matching current provider."""
        entry = _PROVIDER_MAP.get(self.provider)
        if entry is None:
            from .providers.opencv_fallback import OpenCVFallback
            return OpenCVFallback()

        mod_path, cls_name = entry
        try:
            import importlib
            mod = importlib.import_module(mod_path)
            cls = getattr(mod, cls_name)
            # Providers that need api_key or config
            if self.provider in (RepairProvider.REPLICATE_FLUX, RepairProvider.ZHIPU_COGVIEW, RepairProvider.SILICONFLOW):
                key = self.api_keys.get(self.provider.value.split("_")[0], "")
                return cls(api_key=key)
            else:
                return cls()
        except Exception as exc:
            logger.error("Failed to load %s.%s: %s", mod_path, cls_name, exc)
            from .providers.opencv_fallback import OpenCVFallback
            return OpenCVFallback()

    def repair(
        self,
        image: np.ndarray,
        mask: np.ndarray,
        prompt: str = "",
        negative_prompt: str = "",
    ) -> np.ndarray:
        """Repair the masked region using the configured provider.

        Args:
            image: BGRA uint8 ndarray (H, W, 4)
            mask:  single-channel uint8 ndarray (H, W), white = area to repair
            prompt:  what to generate (empty = auto-fill)
            negative_prompt: what to avoid

        Returns:
            BGRA uint8 ndarray (H, W, 4)
        """
        if self._impl is None:
            self._impl = self._resolve()

        logger.info("Repair using %s (prompt=%r)", self.provider.value, prompt[:60])
        try:
            return self._impl.repair(image, mask, prompt, negative_prompt)
        except NotImplementedError:
            logger.warning("%s not implemented, falling back to OpenCV", self.provider.value)
            from .providers.opencv_fallback import OpenCVFallback
            return OpenCVFallback().repair(image, mask, prompt, negative_prompt)
        except Exception as exc:
            logger.error("Repair failed: %s", exc, exc_info=True)
            return image  # safe fallback: original

    def set_provider(self, provider: RepairProvider | str):
        """Switch provider at runtime (invalidates cached impl)."""
        if isinstance(provider, str):
            provider = RepairProvider(provider)
        self.provider = provider
        self._impl = None

    def __repr__(self) -> str:
        return f"<RepairEngine provider={self.provider.value}>"
