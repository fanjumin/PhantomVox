"""PhantomVox AI — Core Engine

Responsibilities:
  - Module registration and lifecycle management
  - Built-in infrastructure: i18n internationalization + hardware detection
  - Event dispatching (locale_changed)
  - Translation shortcut interface

Rules:
  - All top-level imports at the file header, inline imports strictly forbidden
  - New modules only need engine.register("name", instance)
  - No need to hardcode a module list in engine
"""

from typing import Any, Callable, Dict, Optional, List

from .project import Project
from modules.i18n import I18nManager
from modules.hardware import HardwareDetector


class Engine:
    """PhantomVox AI Core Engine"""

    def __init__(self, locale: Optional[str] = None):
        # Module container (open registration)
        self._modules: Dict[str, Any] = {}
        self._locale_listeners: List[Callable[[str, str], None]] = []

        # ── Infrastructure: i18n ─────────────────────────────
        self._i18n = I18nManager()
        if locale:
            self._i18n.set_locale(locale)
        self._i18n.on_locale_changed(self._on_locale_changed)
        self._modules["i18n"] = self._i18n

        # ── Infrastructure: hardware ──────────────────────────
        self._hardware = HardwareDetector()
        self._modules["hardware"] = self._hardware

        # ── Project state ────────────────────────────────────
        self._project: Optional[Project] = None

    # ── Properties ────────────────────────────────────────────

    @property
    def i18n(self) -> I18nManager:
        return self._i18n

    @property
    def hardware(self) -> HardwareDetector:
        return self._hardware

    @property
    def project(self) -> Optional[Project]:
        return self._project

    @project.setter
    def project(self, p: Project):
        self._project = p

    # ── Module registration ────────────────────────────────────────

    def register(self, name: str, instance: Any):
        """Register a module. Any unique name is fine."""
        self._modules[name] = instance

    def get(self, name: str) -> Any:
        """Get a registered module, return None if not found"""
        return self._modules.get(name)

    def has(self, name: str) -> bool:
        return name in self._modules

    @property
    def modules(self) -> Dict[str, Any]:
        return dict(self._modules)

    # ── Translation shortcut ────────────────────────────────────────

    def t(self, key: str, **kwargs) -> str:
        """engine.t('menu.file.new') — Global translation shortcut"""
        return self._i18n.t(key, **kwargs)

    # ── Events ────────────────────────────────────────────

    def _on_locale_changed(self, old: str, new: str):
        for cb in self._locale_listeners:
            try:
                cb(old, new)
            except Exception:
                pass

    def on_locale_changed(self, callback: Callable[[str, str], None]):
        """Register a locale change listener: callback(old, new)"""
        self._locale_listeners.append(callback)

    # ── Lifecycle ────────────────────────────────────────

    def __repr__(self) -> str:
        n = len(self._modules)
        return f"<Engine modules={n} locale={self._i18n.current} tier=T{self._hardware.detect().max_tier()}>"
