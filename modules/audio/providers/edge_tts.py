"""Edge-TTS 提供者 — Microsoft 免费在线 TTS

安装: pip install edge-tts
文档: https://github.com/rany2/edge-tts
"""

import asyncio
import os
import tempfile
from typing import Dict, List, Optional

import edge_tts

from . import TTSProvider


class EdgeTTSProvider(TTSProvider):
    name = "edge_tts"

    # 常用语音列表 (中英文为主)
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

    # 语音别名映射 (短名称 → 完整ID)
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
        # 直接传完整 ID
        return voice

    def synthesize(self, text: str, voice: str = "default",
                   output_path: Optional[str] = None) -> Dict:
        """合成语音

        Args:
            text: 要合成的文本
            voice: 语音 ID 或别名 (默认 zh-CN-XiaoxiaoNeural)
            output_path: 输出路径，None 则保存到临时文件

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

        # edge-tts 是异步的，用 asyncio.run 包装
        async def _run():
            communicate = edge_tts.Communicate(text=text, voice=voice_id)
            await communicate.save(output_path)

        asyncio.run(_run())

        # 粗略估计时长 (中文约 3.5字/秒，英文约 4字/秒)
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
