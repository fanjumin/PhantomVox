"""Unified LLM client — routes to correct provider based on model config.

Supported providers:
- OpenAI-compatible (OpenAI, DeepSeek, Qwen, GLM, Yi, Baichuan, Minimax, StepFun, etc.)
- Anthropic (Claude)
- Google (Gemini) — via OpenAI-compatible wrapper
"""

from __future__ import annotations
import json
from typing import Any, Dict, List, Optional

import requests


# ── Provider config ──────────────────────────────────────

PROVIDER_ENDPOINTS: dict = {
    # International
    "openai": "https://api.openai.com/v1/chat/completions",
    "anthropic": "https://api.anthropic.com/v1/messages",
    "google": "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
    "deepseek": "https://api.deepseek.com/v1/chat/completions",
    "mistral": "https://api.mistral.ai/v1/chat/completions",
    "xai": "https://api.x.ai/v1/chat/completions",
    # Chinese (国内)
    "alibaba": "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
    "zhipu": "https://open.bigmodel.cn/api/paas/v4/chat/completions",
    "baidu": "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions",
    "bytedance": "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
    "baichuan": "https://api.baichuan-ai.com/v1/chat/completions",
    "minimax": "https://api.minimax.chat/v1/text/chatcompletion_v2",
    "01ai": "https://api.lingyiwanwu.com/v1/chat/completions",
    "stepfun": "https://api.stepfun.com/v1/chat/completions",
    "iflytek": "https://spark-api.xf-yun.com/v3.5/chat",
}

# Providers using OpenAI-compatible format (most of them)
OPENAI_COMPATIBLE = {
    "openai", "deepseek", "alibaba", "zhipu", "baichuan",
    "minimax", "01ai", "stepfun", "mistral", "xai",
    "bytedance",
}

# Provider API model name mapping (registry key → actual API model name)
MODEL_NAME_MAP: dict = {
    "gpt-4o": "gpt-4o",
    "gpt-4.1": "gpt-4.1",
    "o1": "o1",
    "o3-mini": "o3-mini",
    "claude-4-sonnet": "claude-sonnet-4-20250514",
    "claude-4-opus": "claude-opus-4-20250514",
    "claude-3.5-haiku": "claude-3-5-haiku-latest",
    "gemini-2.5-pro": "gemini-2.5-pro-exp-03-25",
    "gemini-2.5-flash": "gemini-2.5-flash-001",
    "deepseek-v4": "deepseek-chat",
    "deepseek-r1": "deepseek-reasoner",
    "qwen2.5-72b": "qwen2.5-72b-instruct",
    "qwen2.5-32b": "qwen2.5-32b-instruct",
    "qwen-vl-plus": "qwen-vl-plus",
    "glm-4-plus": "glm-4-plus",
    "glm-4-air": "glm-4-air",
    "glm-4v-plus": "glm-4v-plus",
    "doubao-pro": "doubao-pro-32k",
    "mistral-large": "mistral-large-latest",
}


def _resolve_model_name(model_key: str) -> str:
    """Map registry key to actual API model name."""
    return MODEL_NAME_MAP.get(model_key, model_key)


def chat(
    config_manager: Any,
    messages: List[Dict[str, str]],
    model_key: str | None = None,
    temperature: float | None = None,
    max_tokens: int | None = None,
    stream: bool = False,
) -> Dict[str, Any]:
    """Send a chat completion request using the configured model.

    Args:
        config_manager: ConfigManager instance (to read API keys & defaults)
        messages: List of {"role": "...", "content": "..."} dicts
        model_key: Override model key (default: from config)
        temperature: Override temperature (default: from config)
        max_tokens: Override max tokens (default: 4096)
        stream: Enable streaming (default: False)

    Returns:
        {"status": "ok", "reply": "...", "model": "...", "usage": {...}}
        or {"status": "error", "error": "..."}
    """
    # Read config
    llm_cfg = config_manager.get("llm") or {}
    model_key = model_key or llm_cfg.get("model", "")
    temperature = temperature if temperature is not None else llm_cfg.get("temperature", 0.7)
    max_tokens = max_tokens or llm_cfg.get("max_tokens", 4096)

    if not model_key:
        return {"status": "error", "error": "No LLM model configured. Go to Settings → AI Models to select one."}

    # Find the model in registry to get provider
    available = getattr(config_manager, "_registry", None)
    if available is None:
        available = config_manager._build_registry() if hasattr(config_manager, "_build_registry") else []
    
    entry = None
    for e in available:
        if e.key == model_key:
            entry = e
            break

    if not entry:
        return {"status": "error", "error": f"Model '{model_key}' not found in registry."}

    provider = entry.provider
    endpoint = PROVIDER_ENDPOINTS.get(provider)
    if not endpoint:
        return {"status": "error", "error": f"Unsupported provider '{provider}' for model '{model_key}'."}

    api_key = config_manager.get_api_key(provider) if hasattr(config_manager, "get_api_key") else ""

    if not api_key:
        return {"status": "error", "error": f"No API key configured for '{provider}'. Go to Settings → AI Models → API Keys."}

    # Resolve registry key to actual API model name
    api_model = _resolve_model_name(model_key)

    try:
        if provider == "anthropic":
            return _call_anthropic(endpoint, api_key, api_model, messages, temperature, max_tokens)
        elif provider in OPENAI_COMPATIBLE:
            return _call_openai_compat(endpoint, api_key, api_model, messages, temperature, max_tokens, stream)
        else:
            return {"status": "error", "error": f"Provider '{provider}' not implemented yet."}
    except Exception as e:
        return {"status": "error", "error": f"API call failed: {str(e)}"}


def _call_openai_compat(
    endpoint: str,
    api_key: str,
    model: str,
    messages: List[Dict[str, str]],
    temperature: float,
    max_tokens: int,
    stream: bool,
) -> Dict[str, Any]:
    """Call an OpenAI-compatible chat completion API."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    # Special handling for Zhipu (GLM) which uses a different auth header
    if "bigmodel.cn" in endpoint:
        headers["Authorization"] = api_key  # Zhipu uses raw API key without Bearer
        if not api_key.startswith("Bearer "):
            headers["Authorization"] = api_key
            # Actually Zhipu uses token-based auth, let's handle it
            # Zhipu API key format: xxxxx.yyyyy (JWT-like)
            if "." in api_key and not api_key.startswith("Bearer "):
                headers["Authorization"] = f"Bearer {api_key}"
    # DeepSeek
    if "deepseek.com" in endpoint and model.lower().startswith("deepseek-r1"):
        # R1 doesn't support system prompt, prepend to first user message instead
        system_msgs = [m for m in messages if m["role"] == "system"]
        user_msgs = [m for m in messages if m["role"] != "system"]
        if system_msgs and user_msgs:
            sys_text = system_msgs[-1]["content"]
            first_user = user_msgs[0]
            first_user["content"] = f"[System Instructions]\n{sys_text}\n\n[User Message]\n{first_user['content']}"
            messages = user_msgs

    payload = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": stream,
    }

    resp = requests.post(endpoint, headers=headers, json=payload, timeout=60)
    resp.raise_for_status()

    data = resp.json()
    choice = data.get("choices", [{}])[0]
    reply = choice.get("message", {}).get("content", "")
    usage = data.get("usage", {})

    return {
        "status": "ok",
        "reply": reply,
        "model": model,
        "usage": usage,
    }


def _call_anthropic(
    endpoint: str,
    api_key: str,
    model: str,
    messages: List[Dict[str, str]],
    temperature: float,
    max_tokens: int,
) -> Dict[str, Any]:
    """Call Anthropic Claude API."""
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json",
    }

    # Separate system message from conversation
    system = ""
    conv_messages = []
    for m in messages:
        if m["role"] == "system":
            system = (system + "\n" + m["content"]).strip()
        else:
            conv_messages.append({"role": m["role"], "content": m["content"]})

    payload = {
        "model": model,
        "messages": conv_messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
    }
    if system:
        payload["system"] = system

    resp = requests.post(endpoint, headers=headers, json=payload, timeout=60)
    resp.raise_for_status()

    data = resp.json()
    content_blocks = data.get("content", [])
    reply = " ".join(b.get("text", "") for b in content_blocks if b.get("type") == "text")
    usage = data.get("usage", {})

    return {
        "status": "ok",
        "reply": reply,
        "model": model,
        "usage": usage,
    }
