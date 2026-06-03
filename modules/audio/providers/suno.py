"""Suno AI — 在线音乐生成 (API 包装)

注意: 需要 Suno API Key 才能实际调用。
当前为 mock 实现，返回模拟数据。
"""

from typing import Dict, List, Optional

from . import MusicProvider

# 常用音乐风格
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
        """生成音乐

        无 API Key 时返回 mock 数据。
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

        # TODO: 实现真实 Suno API 调用
        raise NotImplementedError("Real Suno API integration pending API key")

    def list_styles(self) -> List[str]:
        return list(STYLES)
