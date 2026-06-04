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
