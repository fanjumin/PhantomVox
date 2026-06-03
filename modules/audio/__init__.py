"""PhantomVox AI — 音频模型引擎 (TTS + Music)

通过 engine.register("audio", audio_engine) 注册到核心引擎。
"""

from .audio_engine import AudioEngine

__all__ = ["AudioEngine"]
