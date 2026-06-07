"""PhantomVox Audio Engine — Audio model orchestration layer

Responsibilities:
  - Manage TTS / music generation providers
  - Hardware awareness: automatically skip models not runnable on current machine
  - Unified interface: tts(text, voice, ...) / music(prompt, style, ...)

Usage:
  engine.register("audio", AudioEngine(hardware_detector))
  engine.get("audio").tts("Hello", voice="edge_tts")
"""

from typing import Optional, Dict, List, Any


class AudioEngine:
    """Audio model orchestration engine"""

    def __init__(self, hardware=None):
        self._hardware = hardware
        self._tts_providers: Dict[str, Any] = {}
        self._music_providers: Dict[str, Any] = {}
        self._default_tts = "edge_tts"
        self._default_music = "suno"

    # ── Registration ─────────────────────────────────────

    def register_tts(self, name: str, provider):
        """Register a TTS provider"""
        self._tts_providers[name] = provider

    def register_music(self, name: str, provider):
        """Register a music generation provider"""
        self._music_providers[name] = provider

    # ── TTS ───────────────────────────────────────────

    def tts(self, text: str, voice: str = None,
            provider: str = None, output_path: str = None) -> Dict:
        """Text-to-speech"""
        name = provider or self._default_tts
        prov = self._tts_providers.get(name)
        if not prov:
            available = list(self._tts_providers.keys())
            return {"error": f"TTS provider '{name}' not found. Available: {available}"}

        if self._hardware:
            spec = self._hardware.detect()
            ok, reason = spec.can_run_model(name)
            if not ok:
                return {"error": f"'{name}' cannot run on this hardware: {reason}"}

        try:
            result = prov.synthesize(text=text, voice=voice or "default",
                                     output_path=output_path)
            return {"provider": name, "status": "ok", **result}
        except Exception as e:
            return {"provider": name, "status": "error", "error": str(e)}

    def tts_voices(self, provider: str = None) -> List[Dict]:
        """List available voices"""
        name = provider or self._default_tts
        prov = self._tts_providers.get(name)
        if not prov:
            return []
        try:
            return prov.list_voices()
        except Exception:
            return []

    @property
    def tts_providers(self) -> List[str]:
        return list(self._tts_providers.keys())

    # ── Music ─────────────────────────────────────────

    def music(self, prompt: str, style: str = None,
              provider: str = None, duration: float = 30) -> Dict:
        """Generate music"""
        name = provider or self._default_music
        prov = self._music_providers.get(name)
        if not prov:
            available = list(self._music_providers.keys())
            return {"error": f"Music provider '{name}' not found. Available: {available}"}

        if self._hardware:
            spec = self._hardware.detect()
            ok, reason = spec.can_run_model(name)
            if not ok:
                return {"error": f"'{name}' cannot run on this hardware: {reason}"}

        try:
            result = prov.generate(prompt=prompt, style=style or "default",
                                   duration=duration)
            return {"provider": name, "status": "ok", **result}
        except Exception as e:
            return {"provider": name, "status": "error", "error": str(e)}

    def music_styles(self, provider: str = None) -> List[str]:
        """List available style options"""
        name = provider or self._default_music
        prov = self._music_providers.get(name)
        if not prov:
            return []
        try:
            return prov.list_styles()
        except Exception:
            return []

    @property
    def music_providers(self) -> List[str]:
        return list(self._music_providers.keys())
