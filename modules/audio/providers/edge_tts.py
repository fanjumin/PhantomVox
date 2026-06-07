"""Edge-TTS provider — Microsoft free online TTS

Install: pip install edge-tts
Docs: https://github.com/rany2/edge-tts
"""

import asyncio
import os
import tempfile
from typing import Dict, List, Optional

import edge_tts

from . import TTSProvider


class EdgeTTSProvider(TTSProvider):
    name = "edge_tts"

    # Common voice list (primarily Chinese/English)
    DEFAULT_VOICES = [
        {"id": "zh-CN-XiaoxiaoNeural",  "name": "Xiaoxiao",  "gender": "Female", "locale": "zh-CN"},
        {"id": "zh-CN-YunxiNeural",     "name": "Yunxi",     "gender": "Male",   "locale": "zh-CN"},
        {"id": "zh-CN-YunjianNeural",   "name": "Yunjian",   "gender": "Male",   "locale": "zh-CN"},
        {"id": "zh-CN-XiaoyiNeural",    "name": "Xiaoyi",    "gender": "Female", "locale": "zh-CN"},
        {"id": "zh-TW-HsiaoChenNeural",  "name": "HsiaoChen", "gender": "Female", "locale": "zh-TW"},
        {"id": "zh-TW-YunJheNeural",    "name": "YunJhe",    "gender": "Male",   "locale": "zh-TW"},
        {"id": "en-US-AriaNeural",      "name": "Aria",      "gender": "Female", "locale": "en-US"},
        {"id": "en-US-GuyNeural",       "name": "Guy",       "gender": "Male",   "locale": "en-US"},
        {"id": "en-US-JennyNeural",     "name": "Jenny",     "gender": "Female", "locale": "en-US"},
        {"id": "en-GB-SoniaNeural",     "name": "Sonia",     "gender": "Female", "locale": "en-GB"},
        {"id": "ja-JP-NanamiNeural",    "name": "Nanami",    "gender": "Female", "locale": "ja-JP"},
        {"id": "ja-JP-KeitaNeural",     "name": "Keita",     "gender": "Male",   "locale": "ja-JP"},
        {"id": "ko-KR-SunHiNeural",     "name": "SunHi",     "gender": "Female", "locale": "ko-KR"},
        {"id": "fr-FR-DeniseNeural",    "name": "Denise",    "gender": "Female", "locale": "fr-FR"},
        {"id": "de-DE-KatjaNeural",     "name": "Katja",     "gender": "Female", "locale": "de-DE"},
        {"id": "es-ES-ElviraNeural",    "name": "Elvira",    "gender": "Female", "locale": "es-ES"},
        {"id": "ru-RU-SvetlanaNeural",  "name": "Svetlana",  "gender": "Female", "locale": "ru-RU"},
    ]

    # Voice alias mapping (short name → full ID)
    ALIASES = {
        "xiaoxiao":  "zh-CN-XiaoxiaoNeural",
        "yunxi":     "zh-CN-YunxiNeural",
        "yunjian":   "zh-CN-YunjianNeural",
        "aria":      "en-US-AriaNeural",
        "guy":       "en-US-GuyNeural",
        "jenny":     "en-US-JennyNeural",
        "sonia":     "en-GB-SoniaNeural",
        "nanami":    "ja-JP-NanamiNeural",
        "sunhi":     "ko-KR-SunHiNeural",
    }

    def _resolve_voice(self, voice: str) -> str:
        voice_lower = voice.strip().lower()
        if voice_lower in self.ALIASES:
            return self.ALIASES[voice_lower]
        # Pass full voice ID directly
        return voice

    def synthesize(self, text: str, voice: str = "default",
                   output_path: Optional[str] = None) -> Dict:
        """Synthesize speech

        Args:
            text: Text to synthesize
            voice: Voice ID or alias (default zh-CN-XiaoxiaoNeural)
            output_path: Output path, None saves to a temp file

        Returns:
            {"output_path": str, "voice": str, "duration_sec": float}
        """
        if voice == "default":
            voice_id = "zh-CN-XiaoxiaoNeural"
        else:
            voice_id = self._resolve_voice(voice)

        if output_path is None:
            fd, output_path = tempfile.mkstemp(suffix=".mp3")
            os.close(fd)

        # edge-tts is async, wrap with asyncio.run
        async def _run():
            communicate = edge_tts.Communicate(text=text, voice=voice_id)
            await communicate.save(output_path)

        asyncio.run(_run())

        # Rough duration estimate (~3.5 chars/sec for Chinese, ~4 chars/sec for English)
        char_count = len(text)
        estimated_sec = max(char_count / 3.5, 1.0)

        return {
            "output_path": output_path,
            "voice": voice_id,
            "text_length": char_count,
            "estimated_duration_sec": round(estimated_sec, 1),
        }

    def list_voices(self) -> List[Dict]:
        return [dict(v) for v in self.DEFAULT_VOICES]
