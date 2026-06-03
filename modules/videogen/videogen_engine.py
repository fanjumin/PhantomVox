"""VideoGenEngine — Video generation orchestration engine

Follows the same provider pattern as AudioEngine.
Supports multiple providers (stub, RunwayML, Pika, etc.) registered dynamically.

Design:
- VideoGenEngine: orchestrates providers, provides unified API
- Each provider implements VideoGenProvider ABC
- StubProvider for development, real providers for production (GPU/API key needed)
"""

from __future__ import annotations
from typing import Any, Dict, List, Optional

from .providers import VideoGenProvider
from .providers.stub_provider import StubProvider


class VideoGenEngine:
    """Video generation engine with pluggable providers"""

    def __init__(self):
        self._providers: Dict[str, VideoGenProvider] = {}
        self._default = "stub"
        self.register_provider("stub", StubProvider())

    @property
    def providers(self) -> List[str]:
        return list(self._providers.keys())

    @property
    def active_provider(self) -> str:
        return self._default

    def register_provider(self, name: str, provider: VideoGenProvider):
        provider.name = name
        self._providers[name] = provider

    def generate(self, prompt: str, duration: int = 10,
                 style: str = "default", *,
                 provider: Optional[str] = None) -> Dict[str, Any]:
        p = self._providers.get(provider or self._default)
        if not p:
            return {"status": "error", "message": f"Provider '{provider}' not found"}
        return p.generate(prompt, duration=duration, style=style)

    def list_styles(self, provider: Optional[str] = None) -> List[Dict[str, str]]:
        p = self._providers.get(provider or self._default)
        if not p:
            return []
        return p.list_styles()

    def to_info(self) -> dict:
        return {
            "providers": self.providers,
            "active": self.active_provider,
            "styles": self.list_styles(),
        }
