"""Locale metadata configuration"""

LOCALE_METADATA = {
    "zh_CN": {
        "name": "简体中文",
        "native_name": "简体中文",
        "flag": "🇨🇳",
        "fallback": "en",
    },
    "zh_TW": {
        "name": "繁體中文",
        "native_name": "繁體中文",
        "flag": "🇭🇰",
        "fallback": "zh_CN",
    },
    "en": {
        "name": "English",
        "native_name": "English",
        "flag": "🇬🇧",
        "fallback": "",
    },
    "fr": {
        "name": "Français",
        "native_name": "Français",
        "flag": "🇫🇷",
        "fallback": "en",
    },
    "de": {
        "name": "Deutsch",
        "native_name": "Deutsch",
        "flag": "🇩🇪",
        "fallback": "en",
    },
    "it": {
        "name": "Italiano",
        "native_name": "Italiano",
        "flag": "🇮🇹",
        "fallback": "en",
    },
    "ja": {
        "name": "日本語",
        "native_name": "日本語",
        "flag": "🇯🇵",
        "fallback": "en",
    },
    "ko": {
        "name": "한국어",
        "native_name": "한국어",
        "flag": "🇰🇷",
        "fallback": "en",
    },
    "pt_BR": {
        "name": "Português (Brasil)",
        "native_name": "Português (Brasil)",
        "flag": "🇧🇷",
        "fallback": "en",
    },
    "es": {
        "name": "Español",
        "native_name": "Español",
        "flag": "🇪🇸",
        "fallback": "en",
    },
    "ru": {
        "name": "Русский",
        "native_name": "Русский",
        "flag": "🇷🇺",
        "fallback": "en",
    },
    "ar": {
        "name": "العربية",
        "native_name": "العربية",
        "flag": "🇸🇦",
        "fallback": "en",
    },
    "vi": {
        "name": "Tiếng Việt",
        "native_name": "Tiếng Việt",
        "flag": "🇻🇳",
        "fallback": "en",
    },
    "th": {
        "name": "ไทย",
        "native_name": "ไทย",
        "flag": "🇹🇭",
        "fallback": "en",
    },
    "id": {
        "name": "Bahasa Indonesia",
        "native_name": "Bahasa Indonesia",
        "flag": "🇮🇩",
        "fallback": "en",
    },
}


def list_locales():
    """Return available locale list (discovered from locales/*.json)"""
    from pathlib import Path
    files = sorted((Path(__file__).parent / "locales").glob("*.json"))
    result = []
    for f in files:
        lid = f.stem
        meta = LOCALE_METADATA.get(lid, {"name": lid, "native_name": lid, "flag": ""})
        result.append({
            "id": lid,
            "name": meta["name"],
            "native_name": meta["native_name"],
            "flag": meta["flag"],
        })
    return result
