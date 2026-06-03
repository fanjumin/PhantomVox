"""ModelConfig — Model settings management

Responsibilities:
- Read/write ~/.phantomvox/config.yaml (YAML config)
- Manage model selection per module (LLM/Image/Video/Audio/Restore)
- API Key secure storage
- Hardware-aware: auto-filter unavailable local models
"""

from __future__ import annotations
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
                    "tier": entry.tier,
                    "local": entry.local,
                    "selected": entry.key == current,
                    "description": entry.description,
                })
        return results

    @staticmethod
    def _build_registry() -> List[ModelRegistryEntry]:
        return [
            # LLM
            ModelRegistryEntry("gpt-4o", "GPT-4o", "openai", "llm", 1, False, "OpenAI flagship model"),
            ModelRegistryEntry("claude-4-sonnet", "Claude 4 Sonnet", "anthropic", "llm", 1, False, "Anthropic flagship"),
            ModelRegistryEntry("deepseek-v3", "DeepSeek V3", "deepseek", "llm", 1, False, "High cost efficiency"),
            ModelRegistryEntry("llama-3.3-70b", "Llama 3.3 70B", "local", "llm", 2, True, "Local inference"),
            # Image
            ModelRegistryEntry("sdxl-turbo", "SDXL Turbo", "local", "image", 2, True, "Fast local generation"),
            ModelRegistryEntry("dall-e-3", "DALL-E 3", "openai", "image", 1, False, "OpenAI high quality"),
            ModelRegistryEntry("midjourney", "Midjourney", "midjourney", "image", 1, False, "Artistic style"),
            # Video
            ModelRegistryEntry("runway-gen4", "Runway Gen-4", "runway", "video", 1, False, "High quality text-to-video"),
            ModelRegistryEntry("pika", "Pika", "pika", "video", 1, False, "Video editing"),
            # TTS
            ModelRegistryEntry("edge-tts", "Edge-TTS", "edge", "tts", 1, False, "Microsoft online, 200+ voices"),
            ModelRegistryEntry("openai-tts", "OpenAI TTS", "openai", "tts", 1, False, "OpenAI high quality"),
            ModelRegistryEntry("cosyvoice", "CosyVoice 2", "local", "tts", 2, True, "Alibaba open-source, emotion control"),
            # Music
            ModelRegistryEntry("suno", "Suno AI", "suno", "music", 1, False, "Online music generation"),
            ModelRegistryEntry("udio", "Udio", "udio", "music", 1, False, "High quality online music"),
            ModelRegistryEntry("musicgen-small", "MusicGen Small", "local", "music", 1, True, "Meta open-source, CPU-capable"),
            ModelRegistryEntry("musicgen-medium", "MusicGen Medium", "local", "music", 2, True, "Requires 6GB VRAM"),
            # Restore
            ModelRegistryEntry("gfpgan", "GFPGAN", "local", "restore", 2, True, "Face restoration"),
            ModelRegistryEntry("realesrgan", "Real-ESRGAN", "local", "restore", 2, True, "General super-resolution"),
        ]

    def to_info(self) -> dict:
        return {
            "path": self._path,
            "exists": os.path.exists(self._path),
            "config": self.get_all(),
        }
