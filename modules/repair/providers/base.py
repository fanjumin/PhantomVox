"""Abstract base class for all repair providers."""

from abc import ABC, abstractmethod

import numpy as np


class BaseRepairProvider(ABC):
    """All repair providers must implement repair()."""

    @abstractmethod
    def repair(
        self,
        image: np.ndarray,
        mask: np.ndarray,
        prompt: str = "",
        negative_prompt: str = "",
    ) -> np.ndarray:
        """
        Repair the masked area of an image.

        Args:
            image: BGRA uint8 ndarray, shape=(H, W, 4)
            mask:  single-channel uint8 ndarray, shape=(H, W), white=area to repair
            prompt: text description of desired content
            negative_prompt: what to avoid

        Returns:
            BGRA uint8 ndarray, same shape as input
        """
        ...
