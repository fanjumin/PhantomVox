"""PhantomVox Audio Engine — 音频模型编排层

职责：
  - 管理 TTS / 音乐生成提供者
  - 硬件感知：自动跳过当前机器不可运行的模型
  - 统一接口: tts(text, voice, ...) / music(prompt, style, ...)

用法：
  engine.register("audio", AudioEngine(hardware_detector))
  engine.get("audio").tts("你好", voice="edge_tts")
"""

from typing import Optional, Dict, List, Any


class AudioEngine:
    """音频模型编排引擎"""

    def __init__(self, hardware=None):
        self._hardware = hardware
        self._tts_providers: Dict[str, Any] = {}
        self._music_providers: Dict[str, Any] = {}
        self._default_tts = "edge_tts"
        self._default_music = "suno"

    # ── 注册 ──────────────────────────────────────────

    def register_tts(self, name: str, provider):
        """注册 TTS 提供者"""
        self._tts_providers[name] = provider

    def register_music(self, name: str, provider):
        """注册音乐生成提供者"""
        self._music_providers[name] = provider

    # ── TTS ───────────────────────────────────────────

    def tts(self, text: str, voice: str = None,
            provider: str = None, output_path: str = None) -> Dict:
        """文本转语音"""
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
        """获取可用的语音列表"""
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
        """音乐生成"""
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
        """获取可用风格列表"""
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
