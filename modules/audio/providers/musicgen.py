"""MusicGen — Meta local music generation (stub)

Requires PyTorch + audiocraft to actually run.
"""

from typing import Dict, List, Optional

from . import MusicProvider


STYLES = [
    "default", "melody", "chords",
    "ambient", "electronic", "classical",
]


class MusicGenProvider(MusicProvider):
    name = "musicgen_small"

    def __init__(self, model_size: str = "small"):
        self._model_size = model_size
        self._available = False  # Requires PyTorch installation

    def generate(self, prompt: str, style: str = "default",
                 duration: float = 30) -> Dict:
        return {
            "status": "unavailable",
            "message": f"MusicGen ({self._model_size}) requires PyTorch + audiocraft. "
                       "Install: pip install torch audiocraft",
            "prompt": prompt,
            "style": style,
            "duration": duration,
        }

    def list_styles(self) -> List[str]:
        return list(STYLES)
