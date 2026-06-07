"""Suno AI — Online music generation (API wrapper)

Note: Requires a Suno API key to actually call.
Currently a mock implementation returning simulated data.
"""

from typing import Dict, List, Optional

from . import MusicProvider

# Common music styles
STYLES = [
    "pop", "rock", "jazz", "classical", "electronic",
    "hiphop", "rnb", "folk", "ambient", "cinematic",
    "chinese_traditional", "lo-fi", "acoustic", "synthwave",
]


class SunoProvider(MusicProvider):
    name = "suno"

    def __init__(self, api_key: Optional[str] = None, api_url: Optional[str] = None):
        self._api_key = api_key
        self._api_url = api_url or "https://api.suno.ai/v1"
        self._mock = api_key is None

    def generate(self, prompt: str, style: str = "default",
                 duration: float = 30) -> Dict:
        """Generate music

        Returns mock data when no API key is configured.
        """
        if self._mock:
            style_name = style if style != "default" else "pop"
            return {
                "status": "mock",
                "message": "Suno API key not configured. Set SUNO_API_KEY env var.",
                "prompt": prompt,
                "style": style_name,
                "duration": duration,
                "mock_audio": True,
            }

        # TODO: Implement real Suno API call
        raise NotImplementedError("Real Suno API integration pending API key")

    def list_styles(self) -> List[str]:
        return list(STYLES)
