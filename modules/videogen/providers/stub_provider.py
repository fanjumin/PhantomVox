"""Stub video generation provider — mock returns, no GPU needed"""

from typing import Any, Dict, List
from . import VideoGenProvider


class StubProvider(VideoGenProvider):
    name = "stub"
    description = "Stub provider for development (mock only)"

    def generate(self, prompt: str, duration: int = 10,
                 style: str = "default", **kwargs) -> Dict[str, Any]:
        return {
            "status": "mock",
            "provider": "stub",
            "result": f'[VideoGenStub] Generated {duration}s video: "{prompt}" ({style})',
            "duration_sec": duration,
            "style": style,
            "output_path": "/tmp/stub_video.mp4",
        }

    def list_styles(self) -> List[Dict[str, str]]:
        return [
            {"name": "default", "desc": "Default style"},
            {"name": "cinematic", "desc": "Cinematic / filmic look"},
            {"name": "anime", "desc": "Anime style animation"},
            {"name": "realistic", "desc": "Photorealistic output"},
            {"name": "3d_render", "desc": "3D rendered style"},
        ]
