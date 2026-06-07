"""
i18n.py - PhantomVox AI system-level i18n core

Architecture:
  I18nManager (singleton)
    ├── Load JSON locale files (lazy loading)
    ├── Key resolution: dot-path + flat key compatibility
    ├── Interpolation: {placeholder} template syntax
    ├── Pluralization: key.one / key.many + auto-select by count
    ├── Fallback chain: target language -> en (fallback) -> key name
    ├── Events: locale_changed listener pattern
    ├── Detection: locale.getdefaultlocale()
    └── Persistence: user preference JSON

Usage:
    _("menu.file.new")                     -> "New Project"
    _("welcome", name="PhantomVox")        -> "Welcome to PhantomVox"
    _("timeline.clips", count=5)           -> "5 clips"
"""

import json
import locale
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Callable, Any

_LOCALE_DIR = Path(__file__).parent / "locales"
_USER_PREF_PATH = Path.home() / ".phantomvox" / "locale.json"
_FALLBACK_LOCALE = "en"

# ── Singleton ─────────────────────────────────────────────────

_instance: Optional["I18nManager"] = None


def I18n() -> "I18nManager":
    """Get global singleton (lazy init)"""
    global _instance
    if _instance is None:
        _instance = I18nManager()
    return _instance


# ── Convenience functions ─────────────────────────────────────

def _(*args, **kwargs) -> str:
    """Global shortcut translation function.
    _(key)              → str
    _(key, count=N)     → auto-plural
    _(key, name="X")    → interpolation {name}
    """
    return I18n().t(*args, **kwargs)


# ── Main class ────────────────────────────────────────────────

class I18nManager:
    """Internationalization Manager (singleton)"""

    def __init__(self):
        self._cache: Dict[str, Dict[str, str]] = {}       # locale -> flat dict
        self._raw: Dict[str, Dict] = {}                   # locale -> raw JSON
        self._current: str = _FALLBACK_LOCALE
        self._listeners: List[Callable[[str, str], None]] = []   # (old, new)
        self._loaded: set = set()                         # already-loaded locales

        locale_id = self._detect_system_locale()
        self._load_user_preference()
        if not self._current:
            self._current = locale_id

    # ── Public API ──────────────────────────────────────────

    @property
    def current(self) -> str:
        return self._current

    @property
    def available(self) -> List[str]:
        """List all available locales (discovered from locales/*.json)"""
        files = sorted(_LOCALE_DIR.glob("*.json"))
        return [f.stem for f in files]

    def t(self, key: str, **kwargs) -> str:
        """Translate + interpolate + pluralize"""
        self._ensure_loaded(self._current)
        self._ensure_loaded(_FALLBACK_LOCALE)

        raw_key = key
        interp_params = dict(kwargs)  # copy for interpolation later
        # Plural detection: if count param exists, try key.one / key.many
        count = kwargs.pop("count", None)
        if count is not None:
            interp_params["count"] = count  # ensure count is available for interpolation
            plural_key = f"{key}.many" if count > 1 else f"{key}.one"
            raw_key = plural_key

        # Current language -> fallback (en) -> key name
        val = self._resolve(raw_key, self._current)
        if val is None:
            val = self._resolve(raw_key, _FALLBACK_LOCALE)
        if val is None:
            # Try stripping plural suffix and fallback to base key
            if count is not None:
                val = self._resolve(key, self._current)
                if val is None:
                    val = self._resolve(key, _FALLBACK_LOCALE)
            if val is None:
                val = raw_key

        # Interpolation
        if interp_params:
            val = self._interpolate(val, interp_params)

        return val

    def set_locale(self, locale_id: str, persist: bool = True):
        """Switch locale"""
        if locale_id not in self.available:
            available = ", ".join(self.available)
            raise ValueError(
                f"Unsupported locale: '{locale_id}'. Available: [{available}]"
            )
        old = self._current
        self._current = locale_id
        if persist:
            self._save_user_preference()
        for cb in self._listeners:
            cb(old, locale_id)

    def on_locale_changed(self, callback: Callable[[str, str], None]):
        """Register locale change listener: callback(old_locale, new_locale)"""
        self._listeners.append(callback)

    def reload(self):
        """Reload all locale files (hot reload)"""
        self._cache.clear()
        self._raw.clear()
        self._loaded.clear()
        self._ensure_loaded(self._current)

    # ── Internal ──────────────────────────────────────────────

    def _ensure_loaded(self, locale_id: str):
        if locale_id in self._loaded:
            return
        path = _LOCALE_DIR / f"{locale_id}.json"
        if not path.exists():
            return  # Silently ignore, fallback chain catches it
        with open(path, "r", encoding="utf-8") as f:
            raw = json.load(f)
        self._raw[locale_id] = raw
        self._cache[locale_id] = self._flatten(raw)
        self._loaded.add(locale_id)

    def _flatten(self, data: dict, prefix: str = "") -> Dict[str, str]:
        """Flatten nested dict recursively: {"menu": {"file": {"new": "..."}}} → "menu.file.new" """
        result = {}
        for key, val in data.items():
            full = f"{prefix}.{key}" if prefix else key
            if isinstance(val, dict):
                result.update(self._flatten(val, full))
            else:
                result[full] = str(val)
        return result

    def _resolve(self, key: str, locale_id: str) -> Optional[str]:
        cache = self._cache.get(locale_id, {})
        return cache.get(key, None)

    _INTERP_RE = re.compile(r"\{(\w+)\}")

    def _interpolate(self, template: str, params: dict) -> str:
        def _replacer(m):
            name = m.group(1)
            return str(params.get(name, f"{{{name}}}"))
        return self._INTERP_RE.sub(_replacer, template)

    def _detect_system_locale(self) -> str:
        """Detect system language (Linux locale)"""
        # Try environment variables
        lang = os.environ.get("LANG", "") or os.environ.get("LC_ALL", "")
        if lang:
            parts = lang.split(".")
            lang_id = parts[0].replace("-", "_")
            return self._best_match(lang_id)
        # Try Python locale
        try:
            code, _ = locale.getdefaultlocale()
            if code:
                return self._best_match(code.replace("-", "_"))
        except Exception:
            pass
        return "zh_CN" if self._is_chinese_env() else _FALLBACK_LOCALE

    def _is_chinese_env(self) -> bool:
        return any(k in os.environ.get("LANG", "")
                   for k in ["zh_CN", "zh_TW", "zh_HK", "zh_SG"])

    def _best_match(self, locale_id: str) -> str:
        available = set(self.available)
        # Exact match
        if locale_id in available:
            return locale_id
        # Language prefix match: zh_CN -> zh, en_US -> en
        lang_prefix = locale_id.split("_")[0]
        for avail in available:
            if avail.startswith(lang_prefix):
                return avail
        return _FALLBACK_LOCALE

    def _load_user_preference(self):
        if _USER_PREF_PATH.exists():
            try:
                with open(_USER_PREF_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self._current = data.get("locale", self._current)
            except Exception:
                pass

    def _save_user_preference(self):
        _USER_PREF_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(_USER_PREF_PATH, "w", encoding="utf-8") as f:
            json.dump({"locale": self._current}, f, ensure_ascii=False)

    def __repr__(self) -> str:
        return f"<I18nManager current='{self._current}' loaded={list(self._loaded)}>"
