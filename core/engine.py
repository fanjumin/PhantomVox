"""PhantomVox AI — 核心引擎

职责：
  - 模块注册与生命周期管理
  - 内置基础设施：i18n 国际化 + hardware 硬件检测
  - 事件分发 (locale_changed)
  - 翻译快捷接口

规则：
  - 所有顶层 import 在文件头，绝对禁止 inline import
  - 新增模块只需 engine.register("name", instance)
  - 无需在 engine 中硬编码模块列表
"""

from typing import Any, Callable, Dict, Optional, List

from .project import Project
from modules.i18n import I18nManager
from modules.hardware import HardwareDetector


class Engine:
    """PhantomVox AI 核心引擎"""

    def __init__(self, locale: Optional[str] = None):
        # 模块容器 (开放注册)
        self._modules: Dict[str, Any] = {}
        self._locale_listeners: List[Callable[[str, str], None]] = []

        # ── 基础设施: i18n ─────────────────────────────
        self._i18n = I18nManager()
        if locale:
            self._i18n.set_locale(locale)
        self._i18n.on_locale_changed(self._on_locale_changed)
        self._modules["i18n"] = self._i18n

        # ── 基础设施: hardware ──────────────────────────
        self._hardware = HardwareDetector()
        self._modules["hardware"] = self._hardware

        # ── 项目状态 ────────────────────────────────────
        self._project: Optional[Project] = None

    # ── 属性 ────────────────────────────────────────────

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

    # ── 模块注册 ────────────────────────────────────────

    def register(self, name: str, instance: Any):
        """注册一个模块。name 任意唯一标识即可。"""
        self._modules[name] = instance

    def get(self, name: str) -> Any:
        """获取已注册的模块，不存在返回 None"""
        return self._modules.get(name)

    def has(self, name: str) -> bool:
        return name in self._modules

    @property
    def modules(self) -> Dict[str, Any]:
        return dict(self._modules)

    # ── 翻译快捷 ────────────────────────────────────────

    def t(self, key: str, **kwargs) -> str:
        """engine.t('menu.file.new') — 全局翻译快捷"""
        return self._i18n.t(key, **kwargs)

    # ── 事件 ────────────────────────────────────────────

    def _on_locale_changed(self, old: str, new: str):
        for cb in self._locale_listeners:
            try:
                cb(old, new)
            except Exception:
                pass

    def on_locale_changed(self, callback: Callable[[str, str], None]):
        """注册语言切换监听器: callback(old, new)"""
        self._locale_listeners.append(callback)

    # ── 生命周期 ────────────────────────────────────────

    def __repr__(self) -> str:
        n = len(self._modules)
        return f"<Engine modules={n} locale={self._i18n.current} tier=T{self._hardware.detect().max_tier()}>"
