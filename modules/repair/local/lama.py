"""LaMa local model stub — placeholder for future GPU upgrade.

When you upgrade to a machine with NVIDIA GPU (6GB+ VRAM),
install lama-cleaner and implement this properly.

Reference:
  https://github.com/Sanster/lama-cleaner
"""

from ..providers.base import BaseRepairProvider


class LamaRepair(BaseRepairProvider):
    """LaMa inpainting — stub. Throws NotImplementedError.

    To enable:
      pip install lama-cleaner
      # Then implement _real_call() with the lama-cleaner API
    """

    def repair(self, image, mask, prompt="", negative_prompt=""):
        raise NotImplementedError(
            "LaMa local model is not installed. "
            "Run: pip install lama-cleaner\n"
            "Or switch to a cloud provider by setting repair.provider in config.yaml."
        )
