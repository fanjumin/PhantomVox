"""国际化模块 - PhantomVox AI 系统级 i18n 基础设施"""

from .i18n import I18nManager, _
from .locales import LOCALE_METADATA

__all__ = ["I18nManager", "_", "LOCALE_METADATA"]
