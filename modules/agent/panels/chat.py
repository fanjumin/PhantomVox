"""💬 Chat / 🧠 Think / 🖼 Image / 🎬 Video / 💻 Code panel implementations"""

import json
from typing import Any, Dict
from . import PanelProvider


class ChatPanel(PanelProvider):
    name = "chat"
    description = "AI natural language chat — uses configured LLM from Settings"

    def __init__(self, engine=None):
        self._engine = engine

    def execute(self, params: Dict[str, Any]) -> Dict[str, Any]:
        prompt = params.get("prompt", "")
        history = params.get("history", [])
        model_override = params.get("model", None)

        # Get config from engine
        cfg = None
        if self._engine:
            cfg = self._engine.get("config")

        if cfg:
            from ..llm_client import chat
            messages = []
            # Build full message history
            for msg in history:
                role = msg.get("role", "user")
                content = msg.get("content", "")
                messages.append({"role": role, "content": content})
            messages.append({"role": "user", "content": prompt})

            result = chat(
                config_manager=cfg,
                messages=messages,
                model_key=model_override,
            )
            if result["status"] == "ok":
                reply = result["reply"]
                return {
                    "status": "ok",
                    "result": reply,
                    "reply": reply,
                    "model": result.get("model", ""),
                    "usage": result.get("usage", {}),
                    "history": history + [
                        {"role": "user", "content": prompt},
                        {"role": "assistant", "content": reply},
                    ],
                }
            else:
                return {
                    "status": "error",
                    "error": result.get("error", "Unknown LLM error"),
                    "reply": f"[Error] {result.get('error', '')}",
                }

        # Fallback: no config manager available
        return {
            "status": "ok",
            "result": f"[ChatMock] Received: \"{prompt}\"",
            "reply": (
                "PhantomVox AI assistant ready. "
                "Configure an LLM in Settings → AI Models to enable real AI responses."
            ),
            "history": history + [{"role": "user", "content": prompt}],
        }


class ThinkPanel(PanelProvider):
    name = "think"
    description = "🧠 Deep thinking — reasoning chain using configured LLM"

    def __init__(self, engine=None):
        self._engine = engine

    def execute(self, params: Dict[str, Any]) -> Dict[str, Any]:
        task = params.get("task", "")
        model_override = params.get("model", None)

        cfg = None
        if self._engine:
            cfg = self._engine.get("config")

        if cfg:
            from ..llm_client import chat
            messages = [
                {"role": "system", "content": (
                    "You are a professional video/AI project planner. "
                    "Break down the user's task into concrete steps. "
                    "Respond in this format:\n"
                    "STEP 1: ...\n"
                    "STEP 2: ...\n"
                    "...\n"
                    "CONCLUSION: ..."
                )},
                {"role": "user", "content": f"Plan this video/AI task step by step:\n{task}"},
            ]
            result = chat(
                config_manager=cfg,
                messages=messages,
                model_key=model_override,
                temperature=0.3,
            )
            if result["status"] == "ok":
                reply = result["reply"]
                # Parse steps from reply
                steps = []
                for line in reply.strip().split("\n"):
                    line = line.strip()
                    if line.startswith("STEP"):
                        parts = line.split(":", 1)
                        steps.append({
                            "step": len(steps) + 1,
                            "action": parts[1].strip() if len(parts) > 1 else parts[0],
                        })
                conclusion = ""
                for line in reply.strip().split("\n"):
                    if line.startswith("CONCLUSION"):
                        conclusion = line.split(":", 1)[1].strip() if ":" in line else line
                return {
                    "status": "ok",
                    "task": task,
                    "reasoning_steps": steps or [{"step": 1, "action": reply[:100]}],
                    "conclusion": conclusion or "Ready to execute.",
                    "model": result.get("model", ""),
                }

            return {
                "status": "error",
                "error": result.get("error", "LLM error"),
                "task": task,
                "reasoning_steps": [],
                "conclusion": f"Error: {result.get('error', '')}",
            }

        # Fallback mock
        steps = [
            {"step": 1, "action": f"Analyze task: {task}"},
            {"step": 2, "action": "Break down into sub-tasks"},
            {"step": 3, "action": "Evaluate required modules and models"},
            {"step": 4, "action": "Generate execution plan"},
        ]
        return {
            "status": "ok",
            "task": task,
            "reasoning_steps": steps,
            "conclusion": f"Decomposed into {len(steps)} steps, ready to execute.",
        }


class ImageGenPanel(PanelProvider):
    name = "image_gen"
    description = "🖼 Image generation — text-to-image / image-to-image / restoration"

    def __init__(self, engine=None):
        self._engine = engine

    def execute(self, params: Dict[str, Any]) -> Dict[str, Any]:
        prompt = params.get("prompt", "")
        mode = params.get("mode", "text-to-image")

        cfg = None
        if self._engine:
            cfg = self._engine.get("config")

        if cfg:
            image_cfg = cfg.get("image") or {}
            model_key = image_cfg.get("model", "")
            provider = image_cfg.get("provider", "")
            api_key = cfg.get_api_key(provider) if hasattr(cfg, "get_api_key") else ""

            if model_key and api_key:
                # For now, try DALL-E 3 via OpenAI
                if "dall-e" in model_key or provider == "openai":
                    try:
                        import requests
                        headers = {
                            "Authorization": f"Bearer {api_key}",
                            "Content-Type": "application/json",
                        }
                        payload = {
                            "model": model_key or "dall-e-3",
                            "prompt": prompt,
                            "n": 1,
                            "size": "1024x1024",
                        }
                        resp = requests.post(
                            "https://api.openai.com/v1/images/generations",
                            headers=headers, json=payload, timeout=60
                        )
                        resp.raise_for_status()
                        data = resp.json()
                        image_url = data.get("data", [{}])[0].get("url", "")
                        return {
                            "status": "ok",
                            "result": f"Generated via {model_key}",
                            "image_url": image_url,
                            "prompt": prompt,
                        }
                    except Exception as e:
                        return {
                            "status": "error",
                            "error": f"Image gen failed: {e}",
                            "image_url": "",
                            "prompt": prompt,
                        }

        return {
            "status": "ok",
            "result": f"[ImageMock] mode={mode}, prompt=\"{prompt}\"",
            "image_url": "",
            "prompt": prompt,
        }


class VideoGenPanel(PanelProvider):
    name = "video_gen"
    description = "🎬 Video generation — text-to-video / image-to-video / edit"

    def execute(self, params: Dict[str, Any]) -> Dict[str, Any]:
        prompt = params.get("prompt", "")
        duration = params.get("duration", 5)
        return {
            "status": "ok",
            "result": f"[VideoMock] duration={duration}s, prompt=\"{prompt}\"",
            "video_url": "",
        }


class CodeGenPanel(PanelProvider):
    name = "code_gen"
    description = "💻 Code generation — natural language to FFmpeg filter graph"

    def execute(self, params: Dict[str, Any]) -> Dict[str, Any]:
        request = params.get("request", "")
        # Simple keyword mapping for demo
        mock_filters = {
            "fade": "xfade=transition=fade:duration=1:offset=5",
            "transition": "xfade=transition=fade:duration=1:offset=5",
            "speed": "setpts=0.5*PTS",
            "slow": "setpts=2.0*PTS",
            "vintage": "curves=vintage,noise=alls=30:allf=t+u",
            "circle": "xfade=transition=circleopen:duration=1:offset=5",
            "wipe": "xfade=transition=wipeleft:duration=1:offset=5",
        }
        filter_cmd = ""
        for key, val in mock_filters.items():
            if key in request.lower():
                filter_cmd = val
                break
        if not filter_cmd:
            filter_cmd = f"# FFmpeg equivalent for: {request} (pending implementation)"
        return {
            "status": "ok",
            "request": request,
            "ffmpeg_filter": filter_cmd,
            "code": f"ffmpeg -i input.mp4 -filter_complex \"{filter_cmd}\" output.mp4",
        }
