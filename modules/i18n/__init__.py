"""Internationalization Module — PhantomVox AI system-level i18n infrastructure"""

from .i18n import I18nManager, _
from .locales import LOCALE_METADATA

__all__ = ["I18nManager", "_", "LOCALE_METADATA"]
