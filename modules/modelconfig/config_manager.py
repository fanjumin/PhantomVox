"""ModelConfig — Model settings management

Responsibilities:
- Read/write ~/.phantomvox/config.yaml (YAML config)
- Manage model selection per module (LLM/Image/Video/Audio/Restore)
- API Key secure storage
- Hardware-aware: auto-filter unavailable local models
- Local user profile (~/.phantomvox/profile.json)
"""

from __future__ import annotations
import json
import os
from typing import Any, Dict, List, Optional
from dataclasses import dataclass, field, asdict

# ── Default config template ──────────────────────────────────

DEFAULT_CONFIG: dict = {
    "llm": {
        "provider": "",
        "model": "gpt-4o",
        "temperature": 0.7,
        "max_tokens": 4096,
        "system_prompt": "",
    },
    "image": {
        "engine": "stable-diffusion",
        "provider": "local",
        "model": "",
        "resolution": [1024, 1024],
    },
    "video": {
        "engine": "",
        "provider": "",
        "model": "",
        "max_duration": 10,
        "resolution": "1080p",
        "fps": 24,
    },
    "audio": {
        "tts": {"engine": "edge-tts", "voice": "zh-CN-Xiaoxiao"},
        "clone": {"engine": "", "model": ""},
        "music": {"engine": "suno"},
    },
    "restore": {
        "face": "",
        "superres": "",
        "strength": 0.8,
    },
    "api_keys": {},
    "proxy": {"type": "none", "host": "", "port": 0},
}

CONFIG_DIR = os.path.expanduser("~/.phantomvox")
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.yaml")
PROFILE_PATH = os.path.join(CONFIG_DIR, "profile.json")

DEFAULT_PROFILE: dict = {
    "display_name": "",
    "avatar": "",
    "theme": "dark",
    "created_at": "",
    "updated_at": "",
}


@dataclass
class ModelRegistryEntry:
    """Single model registry entry"""
    key: str
    name: str
    provider: str
    category: str  # llm / image / video / tts / music / restore
    tier: int      # 1~4
    local: bool
    description: str = ""


class ConfigManager:
    """Model config manager — read/write config.yaml"""

    def __init__(self, config_path: str = CONFIG_PATH):
        self._path = config_path
        self._config: dict = dict(DEFAULT_CONFIG)  # copy
        self._load()

    # ── File IO ─────────────────────────────────────

    def _load(self):
        if os.path.exists(self._path):
            try:
                import yaml
                with open(self._path) as f:
                    data = yaml.safe_load(f)
                if isinstance(data, dict):
                    self._deep_merge(self._config, data)
            except Exception:
                pass  # Fall back to defaults

    def save(self):
        os.makedirs(CONFIG_DIR, exist_ok=True)
        import yaml
        with open(self._path, "w") as f:
            yaml.dump(self._config, f, default_flow_style=False)

    @staticmethod
    def _deep_merge(base: dict, override: dict):
        for k, v in override.items():
            if k in base and isinstance(base[k], dict) and isinstance(v, dict):
                ConfigManager._deep_merge(base[k], v)
            else:
                base[k] = v

    # ── Read ──────────────────────────────────────────

    def get(self, *keys: str) -> Any:
        """Multi-level read: config.get('audio', 'tts', 'engine')"""
        val: Any = self._config
        for k in keys:
            if isinstance(val, dict):
                val = val.get(k)
            else:
                return None
        return val

    def get_all(self) -> dict:
        return dict(self._config)

    # ── Write ──────────────────────────────────────────

    def set(self, *keys_and_value) -> bool:
        """Multi-level write: config.set('audio', 'tts', 'engine', 'edge-tts')"""
        if len(keys_and_value) < 2:
            return False
        *keys, value = keys_and_value
        target = self._config
        for k in keys[:-1]:
            if k not in target or not isinstance(target[k], dict):
                target[k] = {}
            target = target[k]
        target[keys[-1]] = value
        self.save()
        return True

    # ── API Key ──────────────────────────────────────

    def set_api_key(self, provider: str, key: str):
        self._config.setdefault("api_keys", {})[provider] = key
        self.save()

    def get_api_key(self, provider: str) -> str:
        return self._config.get("api_keys", {}).get(provider, "")

    # ── Model registry ─────────────────────────────────────

    def get_available_models(self, category: str,
                             hardware_tier: int = 1) -> List[dict]:
        """Filter models by category and hardware tier, return available list"""
        if not hasattr(self, "_registry"):
            self._registry = self._build_registry()
        results = []
        for entry in self._registry:
            if entry.category == category and entry.tier <= hardware_tier:
                current = self.get(category.split("_")[0] if "_" in category else category, "model")
                results.append({
                    "key": entry.key,
                    "name": entry.name,
                    "provider": entry.provider,
                    "category": entry.category,
                    "tier": entry.tier,
                    "local": entry.local,
                    "selected": entry.key == current,
                    "description": entry.description,
                })
        return results

    @staticmethod
    def _build_registry() -> List[ModelRegistryEntry]:
        return [
            # ── LLM — International ───────────────────────────
            ModelRegistryEntry("gpt-4o", "GPT-4o", "openai", "llm", 1, False, "OpenAI flagship multimodal"),
            ModelRegistryEntry("gpt-4.1", "GPT-4.1", "openai", "llm", 1, False, "Latest GPT-4 class, improved coding"),
            ModelRegistryEntry("o1", "o1", "openai", "llm", 1, False, "OpenAI reasoning model (deep thinking)"),
            ModelRegistryEntry("o3-mini", "o3-mini", "openai", "llm", 1, False, "OpenAI fast reasoning"),
            ModelRegistryEntry("claude-4-sonnet", "Claude 4 Sonnet", "anthropic", "llm", 1, False, "Anthropic balanced flagship"),
            ModelRegistryEntry("claude-4-opus", "Claude 4 Opus", "anthropic", "llm", 1, False, "Anthropic maximum intelligence"),
            ModelRegistryEntry("claude-3.5-haiku", "Claude 3.5 Haiku", "anthropic", "llm", 1, False, "Anthropic fastest, cheapest"),
            ModelRegistryEntry("gemini-2.5-pro", "Gemini 2.5 Pro", "google", "llm", 1, False, "Google multimodal, 1M context"),
            ModelRegistryEntry("gemini-2.5-flash", "Gemini 2.5 Flash", "google", "llm", 1, False, "Google fast, cost-efficient"),
            ModelRegistryEntry("grok-3", "Grok 3", "xai", "llm", 1, False, "xAI flagship, real-time knowledge"),
            ModelRegistryEntry("llama-4-scout", "Llama 4 Scout", "meta", "llm", 3, True, "Meta open-source, 109B MoE"),
            ModelRegistryEntry("llama-4-maverick", "Llama 4 Maverick", "meta", "llm", 3, True, "Meta open-source, 400B MoE"),
            ModelRegistryEntry("mistral-large", "Mistral Large", "mistral", "llm", 1, False, "Mistral top-tier, multilingual"),
            ModelRegistryEntry("deepseek-v4", "DeepSeek V4", "deepseek", "llm", 1, False, "DeepSeek latest flagship"),
            ModelRegistryEntry("deepseek-r1", "DeepSeek R1", "deepseek", "llm", 1, False, "DeepSeek reasoning model"),
            # ── LLM — Chinese ───────────────────────────────
            ModelRegistryEntry("qwen2.5-72b", "Qwen2.5 72B", "alibaba", "llm", 1, False, "通义千问旗舰, strong Chinese"),
            ModelRegistryEntry("qwen2.5-32b", "Qwen2.5 32B", "alibaba", "llm", 1, False, "通义千问均衡版"),
            ModelRegistryEntry("qwen-vl-plus", "Qwen-VL-Plus", "alibaba", "llm", 1, False, "通义千问视觉版"),
            ModelRegistryEntry("glm-4-plus", "GLM-4-Plus", "zhipu", "llm", 1, False, "智谱旗舰, 工具调用强"),
            ModelRegistryEntry("glm-4-air", "GLM-4-Air", "zhipu", "llm", 1, False, "智谱轻量版, 高性价比"),
            ModelRegistryEntry("glm-4v-plus", "GLM-4V-Plus", "zhipu", "llm", 1, False, "智谱视觉版"),
            ModelRegistryEntry("ernie-4.5-turbo", "ERNIE 4.5 Turbo", "baidu", "llm", 1, False, "百度文心旗舰加速版"),
            ModelRegistryEntry("doubao-pro", "Doubao Pro", "bytedance", "llm", 1, False, "字节豆包旗舰"),
            ModelRegistryEntry("baichuan4", "Baichuan 4", "baichuan", "llm", 1, False, "百川智能旗舰"),
            ModelRegistryEntry("minimax-01", "MiniMax-01", "minimax", "llm", 1, False, "MiniMax旗舰, 长上下文"),
            ModelRegistryEntry("yi-lightning", "Yi-Lightning", "01ai", "llm", 1, False, "零一万物快速版"),
            ModelRegistryEntry("step-2", "Step-2", "stepfun", "llm", 1, False, "阶跃星辰旗舰"),
            ModelRegistryEntry("spark-4.0", "Spark 4.0", "iflytek", "llm", 1, False, "讯飞星火旗舰"),

            # ── Image — International ────────────────────────
            ModelRegistryEntry("dall-e-3", "DALL-E 3", "openai", "image", 1, False, "OpenAI high quality"),
            ModelRegistryEntry("midjourney-v7", "Midjourney V7", "midjourney", "image", 1, False, "Best artistic quality"),
            ModelRegistryEntry("sd3.5-large", "SD3.5 Large", "stability", "image", 3, True, "Stability AI flagship (12GB VRAM)"),
            ModelRegistryEntry("sdxl-turbo", "SDXL Turbo", "stability", "image", 2, True, "Fast local generation (6GB)"),
            ModelRegistryEntry("flux-1-pro", "FLUX.1 Pro", "blackforest", "image", 1, False, "Black Forest Lab professional"),
            ModelRegistryEntry("flux-1-schnell", "FLUX.1 Schnell", "blackforest", "image", 2, True, "Fast open-source, 4-step"),
            # ── Image — Chinese ─────────────────────────────
            ModelRegistryEntry("cogview-4", "CogView-4", "zhipu", "image", 1, False, "智谱图像生成"),
            ModelRegistryEntry("qwen-vl-max", "Qwen-VL-Max", "alibaba", "image", 1, False, "通义千问图生"),
            ModelRegistryEntry("step-1v", "Step-1V", "stepfun", "image", 1, False, "阶跃星辰图像"),
            ModelRegistryEntry("minimax-image", "MiniMax-Image", "minimax", "image", 1, False, "MiniMax图像生成"),

            # ── Video — International ────────────────────────
            ModelRegistryEntry("runway-gen4", "Runway Gen-4", "runway", "video", 1, False, "High quality text/video-to-video"),
            ModelRegistryEntry("sora", "Sora", "openai", "video", 1, False, "OpenAI video generation"),
            ModelRegistryEntry("pika-2.0", "Pika 2.0", "pika", "video", 1, False, "Video editing & generation"),
            ModelRegistryEntry("movie-gen", "Movie Gen", "meta", "video", 4, True, "Meta open-source (enterprise GPU)"),
            # ── Video — Chinese ──────────────────────────────
            ModelRegistryEntry("kling-2.0", "Kling 2.0", "kuaishou", "video", 1, False, "可灵AI旗舰视频"),
            ModelRegistryEntry("kling-1.6", "Kling 1.6", "kuaishou", "video", 1, False, "可灵AI经典版"),
            ModelRegistryEntry("vidu-2.0", "Vidu 2.0", "shengshu", "video", 1, False, "生数科技视频生成"),
            ModelRegistryEntry("cogvideox", "CogVideoX", "zhipu", "video", 3, True, "智谱开源视频 (16GB VRAM)"),
            ModelRegistryEntry("jimeng", "Jimeng", "bytedance", "video", 1, False, "字节即梦AI"),

            # ── TTS — International ───────────────────────────
            ModelRegistryEntry("edge-tts", "Edge-TTS", "microsoft", "tts", 1, False, "Microsoft online, 200+ voices, 15 languages"),
            ModelRegistryEntry("openai-tts", "OpenAI TTS", "openai", "tts", 1, False, "OpenAI high quality, multi-voice"),
            ModelRegistryEntry("openai-tts-hd", "OpenAI TTS HD", "openai", "tts", 1, False, "OpenAI premium quality"),
            ModelRegistryEntry("elevenlabs-turbo", "ElevenLabs Turbo", "elevenlabs", "tts", 1, False, "Fast, natural, 29 languages"),
            ModelRegistryEntry("elevenlabs-multi", "ElevenLabs Multilingual", "elevenlabs", "tts", 1, False, "Best multilingual quality"),
            ModelRegistryEntry("google-tts", "Google Cloud TTS", "google", "tts", 1, False, "Google WaveNet, 220+ voices"),
            # ── TTS — Chinese ────────────────────────────────
            ModelRegistryEntry("cosyvoice-2", "CosyVoice 2", "alibaba", "tts", 2, True, "阿里开源, 情感控制 (6GB VRAM)"),
            ModelRegistryEntry("fish-speech-1.5", "Fish-Speech 1.5", "fishaudio", "tts", 2, True, "Fish开源, 高自然度"),
            ModelRegistryEntry("gpt-sovits", "GPT-SoVITS", "local", "tts", 3, True, "语音克隆+TTS (12GB VRAM)"),
            ModelRegistryEntry("chattts", "ChatTTS", "local", "tts", 1, True, "对话式TTS, CPU可跑"),

            # ── Music — International ─────────────────────────
            ModelRegistryEntry("suno-v4", "Suno V4", "suno", "music", 1, False, "Best online music generation"),
            ModelRegistryEntry("udio", "Udio", "udio", "music", 1, False, "High quality music, genre rich"),
            ModelRegistryEntry("musicgen-small", "MusicGen Small", "meta", "music", 1, True, "Meta open-source, CPU-capable"),
            ModelRegistryEntry("musicgen-medium", "MusicGen Medium", "meta", "music", 2, True, "Requires 6GB VRAM"),
            ModelRegistryEntry("musicgen-large", "MusicGen Large", "meta", "music", 3, True, "Best quality local (12GB)"),
            ModelRegistryEntry("stable-audio-2", "Stable Audio 2.0", "stability", "music", 1, False, "Online audio generation"),
            # ── Music — Chinese ──────────────────────────────
            ModelRegistryEntry("seed-music", "Seed-Music", "bytedance", "music", 1, False, "字节音乐生成"),

            # ── Restore / Enhancement ─────────────────────────
            ModelRegistryEntry("gfpgan", "GFPGAN", "tencent", "restore", 2, True, "Face restoration (6GB VRAM)"),
            ModelRegistryEntry("realesrgan", "Real-ESRGAN", "xinntao", "restore", 2, True, "Super-resolution (6GB)"),
            ModelRegistryEntry("codeformer", "CodeFormer", "local", "restore", 2, True, "Face restoration alternative"),
        ]

    def to_info(self) -> dict:
        return {
            "path": self._path,
            "exists": os.path.exists(self._path),
            "config": self.get_all(),
        }

    # ── Local Profile ───────────────────────────────────

    def get_profile(self) -> dict:
        """Read local user profile from ~/.phantomvox/profile.json"""
        profile = dict(DEFAULT_PROFILE)
        if os.path.exists(PROFILE_PATH):
            try:
                with open(PROFILE_PATH) as f:
                    data = json.load(f)
                if isinstance(data, dict):
                    profile.update(data)
            except Exception:
                pass
        return profile

    def save_profile(self, data: dict) -> dict:
        """Save local user profile. Merges with existing data."""
        existing = self.get_profile()
        from datetime import datetime
        existing.update(data)
        existing["updated_at"] = datetime.now().isoformat()
        if not existing.get("created_at"):
            existing["created_at"] = existing["updated_at"]
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(PROFILE_PATH, "w") as f:
            json.dump(existing, f, indent=2, ensure_ascii=False)
        return existing
