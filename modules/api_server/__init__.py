"""PhantomVox AI Server — HTTP API 包装引擎

启动:  python3 -m modules.api_server
端口:  8899 (默认)
"""

import json
import sys
import os

from flask import Flask, jsonify, request

# ── 将项目根目录加入 path ────────────────────────────
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)


def create_app(engine=None):
    """Flask 应用工厂"""
    if engine is None:
        from core.engine import Engine
        engine = Engine()

    # ── 音频引擎 ──────────────────────────────────────
    from modules.audio import AudioEngine
    from modules.audio.providers.edge_tts import EdgeTTSProvider
    from modules.audio.providers.suno import SunoProvider
    from modules.audio.providers.musicgen import MusicGenProvider

    audio = AudioEngine(hardware=engine.hardware)
    audio.register_tts("edge_tts", EdgeTTSProvider())
    audio.register_music("suno", SunoProvider())
    audio.register_music("musicgen_small", MusicGenProvider(model_size="small"))
    engine.register("audio", audio)

    # ── Agent engine ────────────────────────────────────
    from modules.agent import AgentEngine
    from modules.agent.panels.chat import ChatPanel, ThinkPanel, ImageGenPanel, VideoGenPanel, CodeGenPanel

    agent_engine = AgentEngine(engine=engine)
    agent_engine.register_panel("chat", ChatPanel(engine=engine))
    agent_engine.register_panel("think", ThinkPanel(engine=engine))
    agent_engine.register_panel("image_gen", ImageGenPanel(engine=engine))
    agent_engine.register_panel("video_gen", VideoGenPanel())
    agent_engine.register_panel("code_gen", CodeGenPanel())
    engine.register("agent", agent_engine)

    # ── Model config ────────────────────────────────────────
    from modules.modelconfig import ConfigManager
    config_mgr = ConfigManager()
    engine.register("config", config_mgr)

    # ── Timeline engine ──────────────────────────────────
    from modules.timeline import TimelineEngine
    timeline_engine = TimelineEngine()
    engine.register("timeline", timeline_engine)

    # ── CodeGen engine ──────────────────────────────────
    from modules.codegen import CodeGenEngine
    codegen_engine = CodeGenEngine()
    engine.register("codegen", codegen_engine)

    # ── VideoGen engine ──────────────────────────────────
    from modules.videogen import VideoGenEngine
    videogen_engine = VideoGenEngine()
    engine.register("videogen", videogen_engine)

    app = Flask(__name__)
    app.engine = engine

    # ── CORS 允许 Flutter 跨域请求 ──────────────────────

    @app.after_request
    def add_cors(resp):
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Headers"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        return resp

    # ── 健康检查 ──────────────────────────────────────

    @app.route("/api/v1/health")
    def health():
        return jsonify({"status": "ok", "service": "phantomvox-ai-server"})

    # ── 系统信息 ──────────────────────────────────────

    @app.route("/api/v1/info")
    def info():
        e = app.engine
        spec = e.hardware.detect()
        return jsonify({
            "name": e.t("app.name"),
            "tagline": e.t("app.tagline"),
            "locale": e.i18n.current,
            "tier": spec.max_tier(),
            "modules": len(e.modules),
            "hardware": {
                "cpu": spec.cpu_model,
                "cores": spec.cpu_cores,
                "threads": spec.cpu_threads,
                "ram_gb": round(spec.ram_total_gb, 1),
                "gpu": spec.gpu_models or [],
                "disk_free_gb": round(spec.disk_free_gb, 1),
                "os": f"{spec.os_name} {spec.os_version}",
            },
        })

    # ── 硬件检测 ──────────────────────────────────────

    @app.route("/api/v1/hardware")
    def hardware():
        e = app.engine
        r = e.hardware.report()
        return jsonify(r)

    @app.route("/api/v1/hardware/check/<model_key>")
    def hardware_check(model_key):
        e = app.engine
        spec = e.hardware.detect()
        ok, reason = spec.can_run_model(model_key)
        return jsonify({"model": model_key, "can_run": ok, "reason": reason})

    # ── 国际化 ────────────────────────────────────────

    @app.route("/api/v1/locale")
    def locale_current():
        e = app.engine
        return jsonify({"locale": e.i18n.current})

    @app.route("/api/v1/locales")
    def locales_list():
        e = app.engine
        items = []
        for loc in e.i18n.available:
            from modules.i18n.locales import LOCALE_METADATA
            meta = LOCALE_METADATA.get(loc, {})
            items.append({
                "code": loc,
                "name": meta.get("native_name", loc),
                "flag": meta.get("flag", ""),
                "current": loc == e.i18n.current,
            })
        return jsonify(items)

    @app.route("/api/v1/locale/set", methods=["POST"])
    def locale_set():
        e = app.engine
        data = request.get_json(silent=True) or {}
        loc = data.get("locale", "")
        if loc not in e.i18n.available:
            return jsonify({"error": f"Unsupported locale: {loc}"}), 400
        old = e.i18n.current
        e.i18n.set_locale(loc)
        return jsonify({"old": old, "new": loc})

    # ── 翻译查询 ──────────────────────────────────────

    @app.route("/api/v1/translate/<path:key>")
    def translate(key):
        e = app.engine
        params = request.args.to_dict()
        result = e.t(key, **params)
        return jsonify({"key": key, "value": result})

    # ── TTS ─────────────────────────────────────────────

    @app.route("/api/v1/tts", methods=["POST"])
    def tts_synthesize():
        data = request.get_json(silent=True) or {}
        text = data.get("text", "")
        if not text:
            return jsonify({"error": "Missing 'text' field"}), 400
        audio = app.engine.get("audio")
        if not audio:
            return jsonify({"error": "Audio engine not initialized"}), 500
        result = audio.tts(
            text=text,
            voice=data.get("voice"),
            provider=data.get("provider"),
        )
        status = 200 if result.get("status") == "ok" else 400
        return jsonify(result), status

    @app.route("/api/v1/tts/voices")
    def tts_voices():
        audio = app.engine.get("audio")
        provider = request.args.get("provider")
        voices = audio.tts_voices(provider=provider) if audio else []
        return jsonify(voices)

    @app.route("/api/v1/tts/providers")
    def tts_providers():
        audio = app.engine.get("audio")
        providers = audio.tts_providers if audio else []
        return jsonify(providers)

    # ── Music ──────────────────────────────────────────

    @app.route("/api/v1/music", methods=["POST"])
    def music_generate():
        data = request.get_json(silent=True) or {}
        prompt = data.get("prompt", "")
        if not prompt:
            return jsonify({"error": "Missing 'prompt' field"}), 400
        audio = app.engine.get("audio")
        if not audio:
            return jsonify({"error": "Audio engine not initialized"}), 500
        result = audio.music(
            prompt=prompt,
            style=data.get("style"),
            provider=data.get("provider"),
            duration=data.get("duration", 30),
        )
        status = 200 if result.get("status") in ("ok", "mock") else 400
        return jsonify(result), status

    @app.route("/api/v1/music/styles")
    def music_styles():
        audio = app.engine.get("audio")
        provider = request.args.get("provider")
        styles = audio.music_styles(provider=provider) if audio else []
        return jsonify(styles)

    @app.route("/api/v1/music/providers")
    def music_providers():
        audio = app.engine.get("audio")
        providers = audio.music_providers if audio else []
        return jsonify(providers)

    # ── Audio Info ─────────────────────────────────────

    @app.route("/api/v1/audio")
    def audio_info():
        audio = app.engine.get("audio")
        if not audio:
            return jsonify({"tts_providers": [], "music_providers": []})
        return jsonify({
            "tts_providers": audio.tts_providers,
            "music_providers": audio.music_providers,
        })

    # ── Agent panels ────────────────────────────────────

    @app.route("/api/v1/agent/chat", methods=["POST"])
    def agent_chat():
        agent = app.engine.get("agent")
        data = request.get_json(silent=True) or {}
        result = agent.execute_panel("chat", data)
        return jsonify(result)

    @app.route("/api/v1/agent/think", methods=["POST"])
    def agent_think():
        agent = app.engine.get("agent")
        data = request.get_json(silent=True) or {}
        result = agent.execute_panel("think", data)
        return jsonify(result)

    @app.route("/api/v1/agent/image", methods=["POST"])
    def agent_image():
        agent = app.engine.get("agent")
        data = request.get_json(silent=True) or {}
        result = agent.execute_panel("image_gen", data)
        return jsonify(result)

    @app.route("/api/v1/agent/video", methods=["POST"])
    def agent_video():
        agent = app.engine.get("agent")
        data = request.get_json(silent=True) or {}
        result = agent.execute_panel("video_gen", data)
        return jsonify(result)

    @app.route("/api/v1/agent/code", methods=["POST"])
    def agent_code():
        agent = app.engine.get("agent")
        data = request.get_json(silent=True) or {}
        result = agent.execute_panel("code_gen", data)
        return jsonify(result)

    # ── Agent mind map ─────────────────────────────────

    @app.route("/api/v1/agent/plan", methods=["POST"])
    def agent_plan():
        agent = app.engine.get("agent")
        data = request.get_json(silent=True) or {}
        intent = data.get("intent", "")
        result = agent.plan(intent)
        return jsonify(result)

    @app.route("/api/v1/agent/mindmap")
    def agent_mindmap():
        agent = app.engine.get("agent")
        return jsonify(agent.get_mindmap())

    @app.route("/api/v1/agent/mindmap/node", methods=["POST"])
    def agent_mindmap_node():
        agent = app.engine.get("agent")
        data = request.get_json(silent=True) or {}
        agent.update_node(
            data.get("node_id", ""),
            data.get("status", "pending"),
            progress=data.get("progress"),
            result=data.get("result"),
            error=data.get("error"),
        )
        return jsonify({"status": "ok"})

    # ── Agent matrix ───────────────────────────────────

    @app.route("/api/v1/agent/matrix")
    def agent_matrix():
        agent = app.engine.get("agent")
        return jsonify(agent.agent_matrix())

    @app.route("/api/v1/agent/panels")
    def agent_panels():
        agent = app.engine.get("agent")
        return jsonify({"panels": agent.list_panels()})

    # ── Agent workflow (P7) ─────────────────────────────

    @app.route("/api/v1/agent/workflow", methods=["POST"])
    def agent_workflow_start():
        agent = app.engine.get("agent")
        data = request.get_json(silent=True) or {}
        intent = data.get("intent", "")
        if not intent:
            return jsonify({"error": "Missing 'intent' field"}), 400
        result = agent.start_workflow(intent)
        return jsonify(result)

    @app.route("/api/v1/agent/workflow/<wid>")
    def agent_workflow_status(wid):
        agent = app.engine.get("agent")
        wf = agent.get_workflow(wid)
        if wf is None:
            return jsonify({"error": f"Workflow not found: {wid}"}), 404
        return jsonify(wf)

    @app.route("/api/v1/agent/workflows")
    def agent_workflows_list():
        agent = app.engine.get("agent")
        return jsonify({"workflows": agent.list_workflows()})

    # ── Image Editor ─────────────────────────────────────

    def _get_img_editor():
        """Get or create ImageEditorEngine instance."""
        if not hasattr(app, '_img_editor'):
            from modules.image_editor import ImageEditorEngine
            hw = app.engine.get("hardware") if hasattr(app.engine, 'get') else None
            app._img_editor = ImageEditorEngine(hardware=hw)
        return app._img_editor

    @app.route("/api/v1/editor/capabilities")
    def editor_capabilities():
        editor = _get_img_editor()
        return jsonify(editor.get_capabilities())

    @app.route("/api/v1/editor/load", methods=["POST"])
    def editor_load():
        """Load an image from file path. Returns base64 preview + info."""
        data = request.get_json(silent=True) or {}
        path = data.get("path", "")
        if not path or not os.path.exists(path):
            return jsonify({"error": "File not found"}), 404
        editor = _get_img_editor()
        try:
            info = editor.load(path)
            b64 = editor.to_base64()
            return jsonify({"status": "ok", "info": info, "base64": b64, "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/crop", methods=["POST"])
    def editor_crop():
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            info = editor.crop(data["x"], data["y"], data["w"], data["h"])
            return jsonify({"status": "ok", "info": info, "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/resize", methods=["POST"])
    def editor_resize():
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            info = editor.resize(data["width"], data["height"],
                                 data.get("keep_aspect", False))
            return jsonify({"status": "ok", "info": info, "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/rotate", methods=["POST"])
    def editor_rotate():
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            info = editor.rotate(data.get("angle", 90), data.get("expand", True))
            return jsonify({"status": "ok", "info": info, "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/flip", methods=["POST"])
    def editor_flip():
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            info = editor.flip(data.get("direction", "horizontal"))
            return jsonify({"status": "ok", "info": info, "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/adjust", methods=["POST"])
    def editor_adjust():
        """Adjust brightness/contrast/saturation/sharpness. All are optional factors (0-2)."""
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            if "brightness" in data:
                editor.adjust_brightness(data["brightness"])
            if "contrast" in data:
                editor.adjust_contrast(data["contrast"])
            if "saturation" in data:
                editor.adjust_saturation(data["saturation"])
            if "sharpness" in data:
                editor.adjust_sharpness(data["sharpness"])
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/filter", methods=["POST"])
    def editor_filter():
        """Apply preset filter: grayscale, sepia, blur, invert."""
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            editor.apply_filter(data.get("filter", "grayscale"))
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/text", methods=["POST"])
    def editor_text():
        """Add text overlay. Supports font_size, color, opacity, stroke, shadow."""
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            kwargs = dict(
                font_size=data.get("font_size", 24),
                color=tuple(data.get("color", [255, 255, 255])),
                opacity=data.get("opacity", 1.0),
                stroke_width=data.get("stroke_width", 0),
                shadow_blur=data.get("shadow_blur", 0),
            )
            if data.get("font_path"):
                kwargs["font_path"] = data["font_path"]
            if data.get("stroke_color"):
                kwargs["stroke_color"] = tuple(data["stroke_color"])
            if data.get("shadow_color"):
                kwargs["shadow_color"] = tuple(data["shadow_color"])
            if data.get("shadow_offset"):
                kwargs["shadow_offset"] = tuple(data["shadow_offset"])
            editor.add_text(
                data["text"],
                x=data.get("x", 10),
                y=data.get("y", 10),
                **kwargs,
            )
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/undo", methods=["POST"])
    def editor_undo():
        """Undo last editor operation."""
        editor = _get_img_editor()
        try:
            editor.undo()
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(),
                            "history": editor.get_history_state()})
        except ValueError as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/redo", methods=["POST"])
    def editor_redo():
        """Redo last undone operation."""
        editor = _get_img_editor()
        try:
            editor.redo()
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(),
                            "history": editor.get_history_state()})
        except ValueError as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/history", methods=["GET"])
    def editor_history():
        """Get undo/redo state."""
        editor = _get_img_editor()
        return jsonify(editor.get_history_state())

    @app.route("/api/v1/editor/fonts", methods=["GET"])
    def editor_fonts():
        """List available fonts (Chinese + English) for text tool."""
        import subprocess
        try:
            result = subprocess.run(
                ["fc-list", ":lang=zh", "-f", "%{file}|%{family[0]}\n"],
                capture_output=True, text=True, timeout=3
            )
            fonts = []
            seen = set()
            for line in result.stdout.strip().split("\n"):
                if not line.strip():
                    continue
                parts = line.split("|", 1)
                path = parts[0]
                name = parts[1] if len(parts) > 1 else path.split("/")[-1]
                if name not in seen and path.endswith((".ttf", ".ttc", ".otf")):
                    seen.add(name)
                    fonts.append({"name": name, "path": path})
            # Add common English fonts
            for extra_path in [
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
            ]:
                if os.path.exists(extra_path):
                    fname = os.path.basename(extra_path).replace(".ttf", "")
                    if fname not in seen:
                        fonts.append({"name": fname, "path": extra_path})
                        seen.add(fname)
            return jsonify(fonts[:30])
        except Exception as e:
            return jsonify({"error": str(e), "fonts": []}), 200

    @app.route("/api/v1/editor/watermark", methods=["POST"])
    def editor_watermark():
        """Add image watermark. watermark_path required. Optional: position, opacity, scale."""
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        wm_path = data.get("watermark_path", "")
        if not wm_path or not os.path.exists(wm_path):
            return jsonify({"error": "Watermark file not found"}), 404
        try:
            with open(wm_path, "rb") as f:
                editor.add_watermark(
                    f.read(),
                    position=data.get("position", "bottom_right"),
                    opacity=data.get("opacity", 0.5),
                    scale=data.get("scale", 0.2),
                )
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/blur-region", methods=["POST"])
    def editor_blur_region():
        """Blur a rectangular region. Required: x, y, w, h. Optional: radius."""
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            editor.blur_region(data["x"], data["y"], data["w"], data["h"],
                               data.get("radius", 20))
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/draw", methods=["POST"])
    def editor_draw():
        """Draw freehand brush stroke. Required: points [[x,y],...]. Optional: color, size, opacity."""
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        points = data.get("points", [])
        if not points or len(points) < 1:
            return jsonify({"error": "Need at least 1 point"}), 400
        try:
            pts = [(int(p[0]), int(p[1])) for p in points]
            editor.draw_brush(
                pts,
                color=tuple(data.get("color", [255, 255, 255])),
                size=data.get("size", 5),
                opacity=data.get("opacity", 1.0),
            )
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(),
                            "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/shape", methods=["POST"])
    def editor_shape():
        """Draw a shape. Required: type, x, y, w, h. Optional: fill_color, stroke_color, stroke_width."""
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            kwargs = {}
            if data.get("fill_color"):
                kwargs["fill_color"] = tuple(data["fill_color"])
            if data.get("stroke_color"):
                kwargs["stroke_color"] = tuple(data["stroke_color"])
            if data.get("stroke_width"):
                kwargs["stroke_width"] = data["stroke_width"]
            editor.draw_shape(
                data["type"], data["x"], data["y"], data["w"], data["h"],
                **kwargs,
            )
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(),
                            "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/denoise", methods=["POST"])
    def editor_denoise():
        """Denoise image. Optional: strength (1-5, default 3)."""
        data = request.get_json(silent=True) or {}
        editor = _get_img_editor()
        try:
            editor.denoise(data.get("strength", 3))
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64(), "history": editor.get_history_state()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/remove-bg", methods=["POST"])
    def editor_remove_bg():
        """Remove image background (local rembg)."""
        editor = _get_img_editor()
        try:
            editor.remove_background()
            return jsonify({"status": "ok", "info": editor.info(), "base64": editor.to_base64()})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/export", methods=["POST"])
    def editor_export():
        """Export current image to a file path."""
        data = request.get_json(silent=True) or {}
        path = data.get("path", "")
        if not path:
            return jsonify({"error": "No path provided"}), 400
        editor = _get_img_editor()
        try:
            abs_path = editor.export(path, fmt=data.get("fmt"), quality=data.get("quality", 95))
            return jsonify({"status": "ok", "path": abs_path})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    # ── Flow Graph (Creative Flow Tree) ────────────────

    @app.route("/api/v1/flowgraph")
    def flowgraph_get():
        """Get the full flow graph tree."""
        agent = app.engine.get("agent")
        return jsonify(agent.get_mindmap())

    @app.route("/api/v1/flowgraph/root", methods=["POST"])
    def flowgraph_set_root():
        """Create or update the root node."""
        data = request.get_json(silent=True) or {}
        label = data.get("label", "Untitled Project")
        description = data.get("description", "")
        agent = app.engine.get("agent")
        from modules.agent.mindmap import FlowGraph
        # If no root exists, create one; otherwise update label
        fg_data = agent.get_mindmap()
        if not fg_data.get("root"):
            agent._director.flowgraph = FlowGraph(label)
        else:
            agent._director.flowgraph.update_node("root", label=label, description=description)
        return jsonify(agent.get_mindmap())

    @app.route("/api/v1/flowgraph/node", methods=["POST"])
    def flowgraph_add_node():
        """Add a child node under a parent."""
        data = request.get_json(silent=True) or {}
        parent_id = data.get("parent_id", "root")
        label = data.get("label", "")
        node_type = data.get("node_type", "scene")
        description = data.get("description", "")
        ai_generated = data.get("ai_generated", False)
        if not label:
            return jsonify({"error": "Missing 'label' field"}), 400
        agent = app.engine.get("agent")
        from modules.agent.mindmap import NodeType as NT
        try:
            nid = agent._director.flowgraph.add_node(
                parent_id, label,
                node_type=NT(node_type),
                description=description,
                ai_generated=ai_generated,
            )
            agent._director._save()
            return jsonify({"status": "ok", "node_id": nid})
        except ValueError as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/flowgraph/node/<node_id>", methods=["PATCH"])
    def flowgraph_update_node(node_id):
        """Update a node's fields."""
        data = request.get_json(silent=True) or {}
        agent = app.engine.get("agent")
        ok = agent._director.flowgraph.update_node(node_id, **data)
        if not ok:
            return jsonify({"error": f"Node not found: {node_id}"}), 404
        agent._director._save()
        return jsonify({"status": "ok"})

    @app.route("/api/v1/flowgraph/node/<node_id>", methods=["DELETE"])
    def flowgraph_delete_node(node_id):
        """Delete a node and its descendants."""
        agent = app.engine.get("agent")
        ok = agent._director.flowgraph.delete_node(node_id)
        if not ok:
            return jsonify({"error": f"Cannot delete node: {node_id}"}), 400
        agent._director._save()
        return jsonify({"status": "ok"})

    @app.route("/api/v1/flowgraph/node/<node_id>/move", methods=["POST"])
    def flowgraph_move_node(node_id):
        """Move a node under a new parent."""
        data = request.get_json(silent=True) or {}
        new_parent_id = data.get("parent_id", "root")
        agent = app.engine.get("agent")
        ok = agent._director.flowgraph.move_node(node_id, new_parent_id)
        if not ok:
            return jsonify({"error": "Move failed: invalid parent or cycle"}), 400
        agent._director._save()
        return jsonify({"status": "ok"})

    @app.route("/api/v1/flowgraph/reorder", methods=["POST"])
    def flowgraph_reorder():
        """Reorder children of a parent node."""
        data = request.get_json(silent=True) or {}
        parent_id = data.get("parent_id", "root")
        child_ids = data.get("child_ids", [])
        agent = app.engine.get("agent")
        ok = agent._director.flowgraph.reorder_children(parent_id, child_ids)
        if not ok:
            return jsonify({"error": f"Parent not found: {parent_id}"}), 404
        agent._director._save()
        return jsonify({"status": "ok"})

    @app.route("/api/v1/flowgraph/save", methods=["POST"])
    def flowgraph_save():
        """Bulk save entire flow graph tree (replaces current)."""
        from modules.agent.mindmap import FlowGraph
        data = request.get_json(silent=True) or {}
        agent = app.engine.get("agent")
        try:
            fg = FlowGraph.from_dict(data)
            agent._director.flowgraph = fg
            agent._director._save()
            return jsonify({"status": "ok"})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/flowgraph/import", methods=["POST"])
    def flowgraph_import():
        """Import flow graph from a JSON file path."""
        data = request.get_json(silent=True) or {}
        path = data.get("path", "")
        if not path:
            return jsonify({"error": "No path provided"}), 400
        import os
        if not os.path.exists(path):
            return jsonify({"error": f"File not found: {path}"}), 404
        from modules.agent.mindmap import FlowGraph
        agent = app.engine.get("agent")
        try:
            fg = FlowGraph.load_from_file(path)
            if not fg.root:
                return jsonify({"error": "Invalid flow graph (no root)"}), 400
            agent._director.flowgraph = fg
            agent._director._save()
            return jsonify({"status": "ok"})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/flowgraph/export", methods=["POST"])
    def flowgraph_export():
        """Export current flow graph to a JSON file."""
        data = request.get_json(silent=True) or {}
        path = data.get("path", "")
        if not path:
            return jsonify({"error": "No path provided"}), 400
        agent = app.engine.get("agent")
        try:
            agent._director.flowgraph.save_to_file(path)
            return jsonify({"status": "ok"})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/flowgraph/delete", methods=["POST"])
    def flowgraph_delete():
        """Delete / reset current flow graph."""
        from modules.agent.mindmap import FlowGraph
        agent = app.engine.get("agent")
        fresh = FlowGraph()
        agent._director.flowgraph = fresh
        agent._director._save()
        return jsonify({"status": "ok"})

    # ── Version management ──────────────────────────────────

    VERSIONS_DIR = os.path.join(PROJECT_ROOT, "data", "versions")
    os.makedirs(VERSIONS_DIR, exist_ok=True)

    @app.route("/api/v1/flowgraph/versions", methods=["GET"])
    def flowgraph_versions():
        """List version snapshots (sorted newest first)."""
        versions = []
        if not os.path.isdir(VERSIONS_DIR):
            return jsonify({"versions": []})
        for fname in sorted(os.listdir(VERSIONS_DIR), reverse=True):
            if not fname.endswith(".json"):
                continue
            path = os.path.join(VERSIONS_DIR, fname)
            try:
                mtime = os.path.getmtime(path)
                size = os.path.getsize(path)
                # Read title from first few bytes
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                root_node = data.get("nodes", {}).get(data.get("root", ""), {})
                title = root_node.get("label", "Untitled")
                count = len(data.get("nodes", {}))
                versions.append({
                    "file": fname,
                    "title": title,
                    "node_count": count,
                    "time": mtime,
                    "size": size,
                })
            except Exception:
                continue
        return jsonify({"versions": versions})

    @app.route("/api/v1/flowgraph/versions/save", methods=["POST"])
    def flowgraph_version_save():
        """Save current flow graph as a version snapshot."""
        import re
        from datetime import datetime
        agent = app.engine.get("agent")
        fg = agent._director.flowgraph
        root_label = fg.nodes.get(fg.root, {}).label if fg.nodes.get(fg.root) else "Untitled"
        slug = re.sub(r"[^\w\u4e00-\u9fff]+", "_", root_label)[:30]
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        fname = f"{ts}_{slug}.json"
        path = os.path.join(VERSIONS_DIR, fname)
        fg.save_to_file(path)
        return jsonify({"status": "ok", "file": fname})

    @app.route("/api/v1/flowgraph/versions/restore", methods=["POST"])
    def flowgraph_version_restore():
        """Restore a version snapshot by filename."""
        data = request.get_json(silent=True) or {}
        fname = data.get("file", "")
        if not fname:
            return jsonify({"error": "No file specified"}), 400
        path = os.path.join(VERSIONS_DIR, fname)
        if not os.path.exists(path):
            return jsonify({"error": f"Version not found: {fname}"}), 404
        from modules.agent.mindmap import FlowGraph
        fg = FlowGraph.load_from_file(path)
        if not fg.root:
            return jsonify({"error": "Invalid version (no root)"}), 400
        agent = app.engine.get("agent")
        agent._director.flowgraph = fg
        agent._director._save()
        return jsonify({"status": "ok"})

    # ── AI Generate full tree ───────────────────────────────

    @app.route("/api/v1/flowgraph/generate", methods=["POST"])
    def flowgraph_generate():
        """Generate a complete flow graph from a natural language prompt."""
        from modules.agent.llm_client import chat as llm_chat

        data = request.get_json(silent=True) or {}
        prompt = data.get("prompt", "")
        if not prompt:
            return jsonify({"error": "No prompt provided"}), 400

        config_mgr = app.engine.get("config")
        if not config_mgr:
            return jsonify({"error": "Config manager not available"}), 500

        profile = config_mgr.get_profile() if hasattr(config_mgr, "get_profile") else {}
        model = profile.get("model", "deepseek-v4")

        system_msg = """You are a creative flow graph generator. Generate a complete tree structure for a creative project.

Node types:
- topic (root, one only)
- scene (major section / episode)
- beat (specific moment / shot / sub-scene)
- sub_beat (fine-grained action / camera direction)
- missing (gap that needs filling, mark with [AI])

Output ONLY a JSON object with this exact structure (no markdown, no explanation):
```json
{
  "root": "root",
  "nodes": {
    "root": {"id": "root", "label": "Project title", "node_type": "topic", "children": ["n1","n2"], "parent_id": null},
    "n1": {"id": "n1", "label": "Scene name", "node_type": "scene", "children": ["n1a","n1b"], "parent_id": "root"},
    "n1a": {"id": "n1a", "label": "Beat description", "node_type": "beat", "children": [], "parent_id": "n1"},
    "n1b": {"id": "n1b", "label": "Missing piece [AI]", "node_type": "missing", "children": [], "parent_id": "n1"},
    "n2": {"id": "n2", "label": "Scene name", "node_type": "scene", "children": [], "parent_id": "root"}
  }
}```

Rules:
- root must have parent_id: null
- Each node's id must be unique
- Every node referenced in "children" must exist
- Every node (except root) must have a valid parent_id
- parent_id must match the actual parent, root's children have parent_id "root"
- 3-4 levels of depth is ideal (topic → scene → beat → sub-beat)
- 15-40 nodes total is good
- Node IDs: "root", "n1", "n2", ... "n1a", "n1b", ...
- Labels in Chinese
- Use "missing" nodes for gaps, opportunities, or AI-suggested additions"""

        messages = [
            {"role": "system", "content": system_msg},
            {"role": "user", "content": f"Generate a complete creative flow graph for: {prompt}"},
        ]

        # Retry once on parse failure
        last_error = None
        for attempt in range(2):
            try:
                response = llm_chat(config_mgr, messages, model_key=model,
                                    temperature=0.7, max_tokens=4096)
                if response.get("status") != "ok":
                    last_error = response.get("error", "LLM call failed")
                    continue
                result = response.get("reply", "")

                # Strip markdown fences if present
                if "```json" in result:
                    result = result.split("```json")[1].split("```")[0].strip()
                elif "```" in result:
                    result = result.split("```")[1].split("```")[0].strip()

                tree = json.loads(result.strip())

                # Validate
                if "nodes" not in tree or "root" not in tree:
                    last_error = "Missing nodes or root in response"
                    continue

                root_id = tree["root"]
                if root_id not in tree["nodes"]:
                    last_error = f"Root '{root_id}' not in nodes"
                    continue

                # Build FlowGraph and replace current
                from modules.agent.mindmap import FlowGraph
                fg = FlowGraph.from_dict(tree)
                if not fg.root:
                    last_error = "Empty flow graph after parsing"
                    continue

                agent = app.engine.get("agent")
                agent._director.flowgraph = fg
                agent._director._save()

                # Return the new tree data for frontend
                return jsonify({"status": "ok", "flowgraph": fg.to_dict()})

            except json.JSONDecodeError as e:
                last_error = f"JSON parse error: {e}"
                continue
            except Exception as e:
                last_error = f"Error: {e}"
                continue

        return jsonify({"error": last_error or "Failed to generate flow graph"}), 500

    @app.route("/api/v1/flowgraph/expand", methods=["POST"])
    def flowgraph_expand():
        """AI expand a node — Director generates child suggestions."""
        data = request.get_json(silent=True) or {}
        node_id = data.get("node_id", "root")
        agent = app.engine.get("agent")
        result = agent.execute_agent("director", {
            "action": "expand_flowgraph",
            "node_id": node_id,
            "label": data.get("label", ""),
            "node_type": data.get("node_type", "topic"),
            "description": data.get("description", ""),
        })
        return jsonify(result)

    # ── 模型配置 ──────────────────────────────────────

    @app.route("/api/v1/models")
    def models_list():
        cfg = app.engine.get("config")
        category = request.args.get("category", "all")
        tier = request.args.get("tier", 1, type=int)
        if category == "all":
            results = []
            for cat in ("llm", "image", "video", "tts", "music", "restore"):
                results.extend(cfg.get_available_models(cat, tier))
            return jsonify({"models": results})
        return jsonify({"models": cfg.get_available_models(category, tier)})

    @app.route("/api/v1/models/config")
    def models_config():
        cfg = app.engine.get("config")
        return jsonify(cfg.get_all())

    # ── CodeGen (P6) ───────────────────────────────────

    @app.route("/api/v1/codegen/generate", methods=["POST"])
    def codegen_generate():
        data = request.get_json(silent=True) or {}
        query = data.get("query", "")
        if not query:
            return jsonify({"error": "Missing 'query' field"}), 400
        cg = app.engine.get("codegen")
        if not cg:
            return jsonify({"error": "CodeGen engine not initialized"}), 500
        result = cg.generate(
            query,
            category=data.get("category"),
            params=data.get("params"),
        )
        return jsonify(result)

    @app.route("/api/v1/codegen/templates")
    def codegen_templates():
        cg = app.engine.get("codegen")
        category = request.args.get("category")
        templates = cg.list_templates(category=category) if cg else []
        return jsonify({"templates": templates, "count": len(templates)})

    @app.route("/api/v1/codegen/categories")
    def codegen_categories():
        cg = app.engine.get("codegen")
        cats = cg.list_categories() if cg else []
        return jsonify({"categories": cats})

    # ── VideoGen (P6) ──────────────────────────────────

    @app.route("/api/v1/videogen/generate", methods=["POST"])
    def videogen_generate():
        data = request.get_json(silent=True) or {}
        prompt = data.get("prompt", "")
        if not prompt:
            return jsonify({"error": "Missing 'prompt' field"}), 400
        vg = app.engine.get("videogen")
        if not vg:
            return jsonify({"error": "VideoGen engine not initialized"}), 500
        result = vg.generate(
            prompt=prompt,
            duration=data.get("duration", 10),
            style=data.get("style", "default"),
        )
        return jsonify(result)

    @app.route("/api/v1/videogen/styles")
    def videogen_styles():
        vg = app.engine.get("videogen")
        styles = vg.list_styles() if vg else []
        return jsonify(styles)

    @app.route("/api/v1/videogen/info")
    def videogen_info():
        vg = app.engine.get("videogen")
        info = vg.to_info() if vg else {}
        return jsonify(info)

    @app.route("/api/v1/models/config", methods=["POST"])
    def models_config_set():
        cfg = app.engine.get("config")
        data = request.get_json(silent=True) or {}
        for section, values in data.items():
            if isinstance(values, dict):
                for k, v in values.items():
                    cfg.set(section, k, v)
        return jsonify({"status": "ok"})

    @app.route("/api/v1/models/api_keys", methods=["POST"])
    def models_api_keys():
        cfg = app.engine.get("config")
        data = request.get_json(silent=True) or {}
        for provider, key in data.items():
            cfg.set_api_key(provider, key)
        return jsonify({"status": "ok"})

    # ── Profile ─────────────────────────────────────────

    @app.route("/api/v1/profile")
    def profile_get():
        cfg = app.engine.get("config")
        return jsonify(cfg.get_profile())

    @app.route("/api/v1/profile", methods=["POST"])
    def profile_save():
        cfg = app.engine.get("config")
        data = request.get_json(silent=True) or {}
        return jsonify(cfg.save_profile(data))

    # ── Project (save/load .phantomvox) ─────────────────

    @app.route("/api/v1/project/new", methods=["POST"])
    def project_new():
        tl = app.engine.get("timeline")
        data = request.get_json(silent=True) or {}
        result = tl.create(data.get("name", "Untitled"))
        return jsonify(result)

    @app.route("/api/v1/project/save", methods=["POST"])
    def project_save():
        from modules.timeline.engine import ProjectSerializer
        data = request.get_json(silent=True) or {}
        path = data.get("path", "")
        timeline_data = data.get("timeline")
        if not path or not timeline_data:
            return jsonify({"error": "Missing 'path' or 'timeline' field"}), 400
        from modules.timeline.models import Timeline
        timeline = Timeline.from_dict(timeline_data)
        ProjectSerializer.save(timeline, path, data.get("metadata", {}))
        return jsonify({"status": "ok", "path": path})

    @app.route("/api/v1/project/load")
    def project_load():
        from modules.timeline.engine import ProjectSerializer
        path = request.args.get("path", "")
        if not path or not os.path.exists(path):
            return jsonify({"error": "File not found"}), 404
        try:
            with open(path) as f:
                data = json.load(f)
            return jsonify(data)
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    # ── Timeline endpoints ──────────────────────────────

    @app.route("/api/v1/timelines", methods=["POST"])
    def timeline_create():
        tl = app.engine.get("timeline")
        data = request.get_json(silent=True) or {}
        result = tl.create(
            name=data.get("name", "Untitled Project"),
            fps=data.get("fps", 24.0),
            width=data.get("width", 1920),
            height=data.get("height", 1080),
        )
        return jsonify({"status": "ok", "timeline": result.to_dict()})

    @app.route("/api/v1/timelines")
    def timeline_list():
        tl = app.engine.get("timeline")
        return jsonify({"timelines": tl.list_timelines()})

    @app.route("/api/v1/timelines/<tl_id>")
    def timeline_get(tl_id):
        tl = app.engine.get("timeline")
        result = tl.get(tl_id)
        if not result:
            return jsonify({"status": "error", "message": "Timeline not found"}), 404
        return jsonify({"status": "ok", "timeline": result.to_dict()})

    @app.route("/api/v1/timelines/<tl_id>/tracks", methods=["POST"])
    def timeline_add_track(tl_id):
        tl = app.engine.get("timeline")
        data = request.get_json(silent=True) or {}
        result = tl.add_track(
            tl_id, track_type=data.get("type", "video"),
            name=data.get("name", ""),
        )
        if not result:
            return jsonify({"status": "error", "message": "Timeline not found"}), 404
        return jsonify({"status": "ok", "track": result.to_dict()})

    @app.route("/api/v1/timelines/<tl_id>/tracks/<track_id>/clips", methods=["POST"])
    def timeline_add_clip(tl_id, track_id):
        tl = app.engine.get("timeline")
        data = request.get_json(silent=True) or {}
        result = tl.add_clip(
            tl_id, track_id,
            asset_path=data.get("asset_path", ""),
            start=data.get("start", 0.0),
            duration=data.get("duration", 10.0),
            name=data.get("name", ""),
            clip_type=data.get("clip_type", "video"),
        )
        if not result:
            return jsonify({"status": "error", "message": "Add clip failed"}), 400
        return jsonify({"status": "ok", "clip": result.to_dict()})

    @app.route("/api/v1/timelines/<tl_id>/clips/<clip_id>", methods=["PATCH"])
    def timeline_update_clip(tl_id, clip_id):
        tl = app.engine.get("timeline")
        data = request.get_json(silent=True) or {}
        ok = tl.update_clip(tl_id, clip_id, data)
        if not ok:
            return jsonify({"status": "error", "message": "Clip not found"}), 404
        return jsonify({"status": "ok"})

    @app.route("/api/v1/timelines/<tl_id>/clips/<clip_id>", methods=["DELETE"])
    def timeline_delete_clip(tl_id, clip_id):
        tl = app.engine.get("timeline")
        tl.remove_clip(tl_id, clip_id)
        return jsonify({"status": "ok"})

    @app.route("/api/v1/timelines/<tl_id>/clips/<clip_id>/effects", methods=["POST"])
    def timeline_add_effect(tl_id, clip_id):
        tl = app.engine.get("timeline")
        data = request.get_json(silent=True) or {}
        result = tl.add_effect(
            tl_id, clip_id,
            effect_type=data.get("type", "filter"),
            name=data.get("name", ""),
            params=data.get("params", {}),
        )
        if not result:
            return jsonify({"status": "error", "message": "Add effect failed"}), 400
        return jsonify({"status": "ok", "effect": result.to_dict()})

    @app.route("/api/v1/timelines/<tl_id>/render")
    def timeline_render(tl_id):
        tl = app.engine.get("timeline")
        cmd = tl.build_render_command(tl_id, output_path="render_output.mp4")
        return jsonify({
            "status": "ok",
            "ffmpeg_command": cmd,
            "command_str": " ".join(cmd) if cmd else "",
        })

    return app


# ── 独立启动入口 ─────────────────────────────────────

def main():
    """启动 AI Server"""
    import argparse

    parser = argparse.ArgumentParser(description="PhantomVox AI Server")
    parser.add_argument("--host", default="127.0.0.1", help="Bind address")
    parser.add_argument("--port", type=int, default=8899, help="Port")
    parser.add_argument("--debug", action="store_true", help="Debug mode")
    parser.add_argument("--locale", default=None, help="Startup language")
    args = parser.parse_args()

    from core.engine import Engine
    eng = Engine(locale=args.locale)
    app = create_app(eng)

    print(f"  PhantomVox AI Server → http://{args.host}:{args.port}")
    print(f"  Locale: {eng.i18n.current}")
    print(f"  Hardware Tier: T{eng.hardware.detect().max_tier()}")
    print()

    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == "__main__":
    main()
