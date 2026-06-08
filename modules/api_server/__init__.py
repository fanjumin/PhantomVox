"""PhantomVox AI Server — HTTP API wrapper engine

Start:  python3 -m modules.api_server
Port:   8899 (default)
"""

import json
import sys
import os

from flask import Flask, jsonify, request

# ── Add project root to path ───────────────────────────────
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)


def create_app(engine=None):
    """Flask application factory"""
    if engine is None:
        from core.engine import Engine
        engine = Engine()

    # ── Audio engine ──────────────────────────────────────────
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

    # ── AI Repair engine ───────────────────────────────────
    from modules.repair import RepairEngine
    repair_engine = RepairEngine(config_mgr.get_all())
    engine.register("repair", repair_engine)

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

    # ── CORS — allow Flutter cross-origin requests ─────────────

    @app.after_request
    def add_cors(resp):
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Headers"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        return resp

    # ── Health check ───────────────────────────────────────────

    @app.route("/api/v1/health")
    def health():
        return jsonify({"status": "ok", "service": "phantomvox-ai-server"})

    # ── System info ────────────────────────────────────────────

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

    # ── Hardware detection ─────────────────────────────────────

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

    # ── Internationalization ───────────────────────────────────

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

    # ── Translation query ──────────────────────────────────────

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

    # ── Model config ───────────────────────────────────────────

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

    # ── Image Studio (Port 8899 unifié, remplace l'ancien FastAPI 8898) ──
    MAX_IMAGE_DIM = 8192
    MAX_IMAGE_PIXELS = 50_000_000
    MAX_BASE64_SIZE = 100_000_000

    import modules.image_studio as img_studio
    from modules.image_studio import Document, Layer, _encode_bgra, _pil_to_bgra, _bgra_to_pil
    from modules.image_studio.cv_tools import (
        apply_filter as _img_filter,
        adjust_brightness, adjust_contrast, adjust_saturation, adjust_hue,
        apply_clahe, auto_white_balance,
        crop_image as _crop, resize_image as _resize,
        rotate_image as _rotate, flip_image as _flip,
        smart_denoise, smart_sharpen, super_resolve, extract_lineart,
        hdr_tone, remove_background, inpaint_erase, blur_region,
    )
    from modules.image_studio.tools import draw_brush, draw_shape, add_text, fill_region
    from modules.image_studio.ai_providers import ai_enhance_image, ai_restore_faces

    import threading, math

    _editor_doc: Document | None = None
    _editor_lock = threading.Lock()
    _clipboard: dict | None = None  # for copy/cut/paste

    def _req_doc():
        with _editor_lock:
            global _editor_doc
            if _editor_doc is None:
                raise ValueError("No document open. Call /api/v1/editor/load first.")
            return _editor_doc

    def _req_doc_snapshot():
        """Get doc and save snapshot atomically under lock (TOCTOU prevention)."""
        with _editor_lock:
            global _editor_doc
            if _editor_doc is None:
                raise ValueError("No document open. Call /api/v1/editor/load first.")
            doc = _editor_doc
            doc._save_snapshot()
            return doc

    def _with_doc(fn):
        """Thread-safe doc operation: lock → check → snapshot → unlock → execute → relock → verify."""
        with _editor_lock:
            global _editor_doc
            if _editor_doc is None:
                raise ValueError("No document open.")
            doc = _editor_doc
            doc._save_snapshot()  # Snapshot taken atomically with doc check
        # Execute outside lock to avoid holding it during heavy CV operations
        result = fn(doc)
        with _editor_lock:
            # Verify doc wasn't replaced while we were working
            if _editor_doc is not doc:
                raise RuntimeError("Document was replaced during operation")
        return result

    def _build_repair_mask(doc, data: dict):
        """Build repair mask from request data — points or mask_b64.

        Priority:
          1. mask_b64 in request — use as-is
          2. mask_points in request — build polygon
          3. full white mask (repair entire image)
        """
        import cv2
        import numpy as np
        import base64
        from io import BytesIO
        from PIL import Image

        # 1. pre-built mask
        mask_b64 = data.get("mask_b64", "")
        if mask_b64:
            raw = base64.b64decode(mask_b64)
            pil = Image.open(BytesIO(raw)).convert("L")
            return np.array(pil, dtype=np.uint8)

        h, w = doc.height, doc.width

        # 2. polygon points
        points = data.get("mask_points", [])
        if isinstance(points, list) and len(points) >= 3:
            pts = np.array([(int(x), int(y)) for x, y in points], dtype=np.int32)
            mask = np.zeros((h, w), dtype=np.uint8)
            cv2.fillPoly(mask, [pts], 255)
            return mask

        # 3. fallback: full image mask
        return np.full((h, w), 255, dtype=np.uint8)

    def _validate_factor(val, default=1.0, lo=0.0, hi=100.0):
        """Validate numeric factor: finite, not NaN/Inf, within range."""
        import math
        try:
            v = float(val)
        except (TypeError, ValueError):
            return default
        if not math.isfinite(v):
            return default
        return max(lo, min(hi, v))

    def _validate_color(c):
        """Validate an RGB color list/tuple is 3 ints 0-255."""
        if not isinstance(c, (list, tuple)) or len(c) != 3:
            return (255, 255, 255)
        return (max(0, min(255, int(c[0]))),
                max(0, min(255, int(c[1]))),
                max(0, min(255, int(c[2]))))

    def _doc_response(doc: Document, extra: dict | None = None,
                      thumbnail_max: int | None = None) -> dict:
        if thumbnail_max and thumbnail_max > 0:
            b64 = doc.to_thumbnail_base64(max_size=thumbnail_max)
        else:
            b64 = doc.to_base64()
        r = {
            "status": "ok",
            "info": doc.info(),
            "base64": b64,
            "history": doc.get_history_state(),
        }
        if thumbnail_max:
            r["thumbnail"] = True
            r["full_size"] = {"width": doc.width, "height": doc.height}
        if extra:
            r.update(extra)
        return r

    def _op_current_layer(data: dict, fn):
        with _editor_lock:
            global _editor_doc
            doc = _editor_doc
            if doc is None:
                raise ValueError("No document open.")
            doc._save_snapshot()
            layer_idx = data.get("layer", -1)
            preview_only = data.pop("preview_only", False)
            op_kw = {k: v for k, v in data.items() if k != "layer"}
            if "color" in op_kw:
                op_kw["color"] = _validate_color(op_kw["color"])
            if "fill_color" in op_kw:
                op_kw["fill_color"] = _validate_color(op_kw["fill_color"])
            if "stroke_color" in op_kw:
                op_kw["stroke_color"] = _validate_color(op_kw["stroke_color"])
            if 0 <= layer_idx < len(doc.layers):
                doc.layers[layer_idx].image = fn(doc.layers[layer_idx].image, **op_kw)
            else:
                for layer in doc.layers:
                    layer.image = fn(layer.image, **op_kw)
            thumb_max = 320 if preview_only else None
            return _doc_response(doc, thumbnail_max=thumb_max)

    @app.route("/api/v1/editor/load", methods=["POST"])
    def editor_load():
        data = request.get_json(silent=True) or {}
        b64_data = data.get("image", "")
        if not b64_data:
            return jsonify({"error": "Provide 'image' (base64)"}), 400
        if len(b64_data) > MAX_BASE64_SIZE:
            return jsonify({"error": f"Image data too large ({len(b64_data)} bytes)"}), 400
        import base64, io
        from PIL import Image
        raw = base64.b64decode(b64_data)
        # Check dimensions BEFORE full decode (Image.open is lazy)
        try:
            pil_img = Image.open(io.BytesIO(raw))
            img_w, img_h = pil_img.size
        except Exception as e:
            return jsonify({"error": f"Cannot decode image: {e}"}), 400
        if img_w > MAX_IMAGE_DIM or img_h > MAX_IMAGE_DIM:
            return jsonify({"error": f"Image dimensions {img_w}x{img_h} exceed limit"}), 400
        if img_w * img_h > MAX_IMAGE_PIXELS:
            return jsonify({"error": f"Image too large: {img_w}x{img_h}"}), 400
        # Now fully decode
        pil_img = pil_img.convert("RGBA")
        arr = _pil_to_bgra(pil_img)
        with _editor_lock:
            global _editor_doc
            _editor_doc = Document(bg_image=arr)
            return jsonify(_doc_response(_editor_doc))

    @app.route("/api/v1/editor/crop", methods=["POST"])
    def editor_crop():
        data = request.get_json(silent=True) or {}
        try:
            w = int(data.get("w", 0))
            h = int(data.get("h", 0))
            if w <= 0 or h <= 0:
                return jsonify({"error": "Invalid crop dimensions"}), 400
            doc = _req_doc_snapshot()
            x, y = int(data["x"]), int(data["y"])
            for layer in doc.layers:
                layer.image = _crop(layer.image, x, y, w, h)
            if doc.layers:
                doc.width = doc.layers[0].width
                doc.height = doc.layers[0].height
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/resize", methods=["POST"])
    def editor_resize():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            w = max(1, int(data.get("width", doc.width)))
            h = max(1, int(data.get("height", doc.height)))
            keep = data.get("keep_aspect", False)
            for layer in doc.layers:
                layer.image = _resize(layer.image, w, h, keep)
            doc.width = doc.layers[0].width if doc.layers else w
            doc.height = doc.layers[0].height if doc.layers else h
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/rotate", methods=["POST"])
    def editor_rotate():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            angle = data.get("angle", 90)
            expand = data.get("expand", True)
            for layer in doc.layers:
                layer.image = _rotate(layer.image, angle, expand)
            if doc.layers:
                doc.width = doc.layers[0].width
                doc.height = doc.layers[0].height
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/flip", methods=["POST"])
    def editor_flip():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            direction = data.get("direction", "horizontal")
            for layer in doc.layers:
                layer.image = _flip(layer.image, direction)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/adjust", methods=["POST"])
    def editor_adjust():
        data = request.get_json(silent=True) or {}
        adj_type = data.get("type", "brightness")
        factor = _validate_factor(data.get("factor", 1.0))
        def _adj(img, **kw):
            if adj_type == "brightness":
                return adjust_brightness(img, factor)
            elif adj_type == "contrast":
                return adjust_contrast(img, factor)
            elif adj_type == "saturation":
                return adjust_saturation(img, factor)
            elif adj_type == "hue":
                return adjust_hue(img, _validate_factor(data.get("shift", 0), 0, -360, 360))
            elif adj_type == "clahe":
                return apply_clahe(img, _validate_factor(data.get("clip_limit", 2.0), 2.0, 0.1, 50.0))
            elif adj_type == "auto_wb":
                return auto_white_balance(img, _validate_factor(data.get("strength", 1.0), 1.0, 0.0, 5.0))
            return img
        return jsonify(_op_current_layer(data, _adj))

    @app.route("/api/v1/editor/filter", methods=["POST"])
    def editor_filter():
        data = request.get_json(silent=True) or {}
        name = data.get("name", "blur")
        kw = {k: v for k, v in data.items() if k != "name" and k != "layer"}
        def _flt(img, **kw2):
            return _img_filter(img, name, **{**kw, **kw2})
        return jsonify(_op_current_layer(data, _flt))

    @app.route("/api/v1/editor/text", methods=["POST"])
    def editor_text():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            txt = data.get("text", "")
            x, y = int(data.get("x", 10)), int(data.get("y", 10))
            fs = int(_validate_factor(data.get("font_size", 24), 24, 1, 500))
            color = _validate_color(data.get("color", [255, 255, 255]))
            opacity = _validate_factor(data.get("opacity", 1.0), 1.0, 0.0, 1.0)
            font_family = data.get("font_family", "sans-serif")
            sw = int(_validate_factor(data.get("stroke_width", 0), 0, 0, 100))
            sc_raw = data.get("stroke_color")
            sc = _validate_color(sc_raw) if sc_raw else None
            sb = int(_validate_factor(data.get("shadow_blur", 0), 0, 0, 100))
            shc_raw = data.get("shadow_color")
            shc = _validate_color(shc_raw) if shc_raw else (0, 0, 0)
            layer_idx = data.get("layer", 0)
            if 0 <= layer_idx < len(doc.layers):
                doc.layers[layer_idx].image = add_text(doc.layers[layer_idx].image, txt, x, y, font_size=fs, color=color, opacity=opacity, font_family=font_family, stroke_width=sw, stroke_color=sc, shadow_blur=sb, shadow_color=shc)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/draw", methods=["POST"])
    def editor_draw():
        data = request.get_json(silent=True) or {}
        mode = data.get("mode", "brush")
        # Filter out mode from op_kw so it doesn't reach draw_brush
        clean_data = {k: v for k, v in data.items() if k != "mode"}
        if mode == "eraser":
            # True eraser: set alpha=0 in circular regions
            try:
                import cv2
                import numpy as np
                doc = _req_doc_snapshot()
                points = data.get("points", [])
                layer_idx = data.get("layer", -1)
                size = data.get("size", 20)
                layers_to_mod = [doc.layers[layer_idx]] if 0 <= layer_idx < len(doc.layers) else doc.layers
                for layer in layers_to_mod:
                    for pt in points:
                        if len(pt) == 2:
                            cv2.circle(layer.image, (int(pt[0]), int(pt[1])), size // 2, (0, 0, 0, 0), -1)
                return jsonify(_doc_response(doc))
            except Exception as e:
                return jsonify({"error": str(e)}), 400
        return jsonify(_op_current_layer(clean_data, lambda img, **kw: draw_brush(img, **kw)))

    @app.route("/api/v1/editor/shape", methods=["POST"])
    def editor_shape():
        data = request.get_json(silent=True) or {}
        # Map 'type' from request to 'shape_type' for draw_shape()
        if "type" in data and "shape_type" not in data:
            data["shape_type"] = data.pop("type")
        return jsonify(_op_current_layer(data, lambda img, **kw: draw_shape(img, **kw)))

    @app.route("/api/v1/editor/gradient", methods=["POST"])
    def editor_gradient():
        """Draw a linear gradient across the entire layer."""
        data = request.get_json(silent=True) or {}
        try:
            import cv2, numpy as np
            doc = _req_doc_snapshot()
            color1 = _validate_color(data.get("color1", [255, 255, 255]))
            color2 = _validate_color(data.get("color2", [0, 0, 0]))
            direction = data.get("direction", "vertical")  # vertical | horizontal | diagonal
            opacity = _validate_factor(data.get("opacity", 1.0), 1.0, 0.0, 1.0)
            layer_idx = data.get("layer", -1)

            def _apply_gradient(layer_img):
                h, w = layer_img.shape[:2]
                c1 = np.array(color1, dtype=np.float32).reshape(1, 1, 3)
                c2 = np.array(color2, dtype=np.float32).reshape(1, 1, 3)
                if direction == "horizontal":
                    t = np.linspace(0, 1, w, dtype=np.float32).reshape(1, w, 1)
                    gradient = c1 * (1.0 - t) + c2 * t
                    gradient = np.broadcast_to(gradient, (h, w, 3))
                elif direction == "diagonal":
                    yy, xx = np.mgrid[0:h, 0:w]
                    max_d = max(w, h)
                    t = (xx + yy) / (max_d * 2.0)
                    t = np.clip(t, 0, 1)[..., np.newaxis]
                    gradient = c1 * (1.0 - t) + c2 * t
                else:  # vertical (default)
                    t = np.linspace(0, 1, h, dtype=np.float32).reshape(h, 1, 1)
                    gradient = c1 * (1.0 - t) + c2 * t
                    gradient = np.broadcast_to(gradient, (h, w, 3))
                a = int(255 * opacity)
                alpha = np.full((h, w, 1), a, dtype=np.uint8)
                return np.concatenate([gradient.astype(np.uint8), alpha], axis=2)

            if 0 <= layer_idx < len(doc.layers):
                doc.layers[layer_idx].image = _apply_gradient(doc.layers[layer_idx].image)
            else:
                for layer in doc.layers:
                    layer.image = _apply_gradient(layer.image)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/fill", methods=["POST"])
    def editor_fill():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            x, y = int(data.get("x", 0)), int(data.get("y", 0))
            color = _validate_color(data.get("color", [255, 255, 255]))
            for layer in doc.layers:
                layer.image = fill_region(layer.image, x, y, color)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/eyedropper", methods=["POST"])
    def editor_eyedropper():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc()
            x, y = int(data.get("x", 0)), int(data.get("y", 0))
            composite = doc.render()
            if 0 <= y < composite.shape[0] and 0 <= x < composite.shape[1]:
                b, g, r, a = composite[y, x]
                return jsonify({"status": "ok", "color": {"r": int(r), "g": int(g), "b": int(b), "a": int(a)}})
            return jsonify({"error": "Point out of bounds"}), 400
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/undo", methods=["POST"])
    def editor_undo():
        try:
            doc = _req_doc()
            with _editor_lock:
                doc.undo()
            return jsonify(_doc_response(doc))
        except ValueError as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/redo", methods=["POST"])
    def editor_redo():
        try:
            doc = _req_doc()
            with _editor_lock:
                doc.redo()
            return jsonify(_doc_response(doc))
        except ValueError as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/history")
    def editor_history():
        try:
            doc = _req_doc()
            return jsonify(doc.get_history_state())
        except ValueError as e:
            return jsonify({"can_undo": False, "can_redo": False})

    @app.route("/api/v1/editor/denoise", methods=["POST"])
    def editor_denoise():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            h = data.get("h", 10)
            for layer in doc.layers:
                layer.image = smart_denoise(layer.image, h=h)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/smart-sharpen", methods=["POST"])
    def editor_smart_sharpen():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            def _fn(img, **kw):
                from modules.image_studio.cv_tools import smart_sharpen
                return smart_sharpen(img, data.get("amount", 1.0))
            return jsonify(_op_current_layer(data, _fn))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/move", methods=["POST"])
    def editor_move():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            dx = int(data.get("dx", 0))
            dy = int(data.get("dy", 0))
            layer_idx = int(data.get("layer", -1))
            if 0 <= layer_idx < len(doc.layers):
                layer = doc.layers[layer_idx]
                h, w = layer.image.shape[:2]
                # Translate the image using affine transform
                import cv2
                import numpy as np
                matrix = np.array([[1.0, 0.0, float(dx)], [0.0, 1.0, float(dy)]], dtype=np.float64)
                layer.image = cv2.warpAffine(
                    layer.image, matrix, (w, h),
                    flags=cv2.INTER_LINEAR,
                    borderMode=cv2.BORDER_CONSTANT,
                    borderValue=(0, 0, 0, 0),
                )
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/clahe", methods=["POST"])
    def editor_clahe():
        data = request.get_json(silent=True) or {}
        return jsonify(_op_current_layer(data, lambda img, **kw: apply_clahe(img, data.get("clip_limit", 2.0))))

    @app.route("/api/v1/editor/auto-wb", methods=["POST"])
    def editor_auto_wb():
        data = request.get_json(silent=True) or {}
        return jsonify(_op_current_layer(data, lambda img, **kw: auto_white_balance(img, data.get("strength", 1.0))))

    @app.route("/api/v1/editor/info")
    def editor_info():
        try:
            doc = _req_doc()
            return jsonify(doc.info())
        except ValueError as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/new", methods=["POST"])
    def editor_new():
        data = request.get_json(silent=True) or {}
        w = max(1, min(int(data.get("width", 800)), MAX_IMAGE_DIM))
        h = max(1, min(int(data.get("height", 600)), MAX_IMAGE_DIM))
        if w * h > MAX_IMAGE_PIXELS:
            return jsonify({"error": f"Image too large: {w}x{h} exceeds {MAX_IMAGE_PIXELS} pixels"}), 400
        import numpy as np
        bg = np.zeros((h, w, 4), dtype=np.uint8)
        bg[:, :, 3] = 255  # fully opaque white
        bg[:, :, :3] = 255
        with _editor_lock:
            global _editor_doc
            _editor_doc = Document(bg_image=bg)
            return jsonify(_doc_response(_editor_doc))

    @app.route("/api/v1/editor/save", methods=["POST"])
    def editor_save():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc()
            path = data.get("path", "")
            fmt = data.get("fmt", "png")
            if fmt.lower() not in ("png", "jpg", "jpeg"):
                return jsonify({"error": f"Unsupported format: {fmt}"}), 400
            quality = max(1, min(int(data.get("quality", 95)), 100))
            # Prevent path traversal
            if path:
                real_path = os.path.realpath(path)
                cwd = os.path.realpath(os.getcwd())
                if not real_path.startswith(cwd):
                    return jsonify({"error": "Invalid save path"}), 400
            else:
                path = os.path.join(os.getcwd(), f"image_studio_output.{fmt}")
            path = doc.export(path, fmt=fmt, quality=quality)
            return jsonify({"status": "ok", "path": path})
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/add-layer", methods=["POST"])
    def editor_add_layer():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            import numpy as np
            empty = np.zeros((doc.height, doc.width, 4), dtype=np.uint8)
            with _editor_lock:
                layer = Layer(image=empty, name=data.get("name", f"Layer {len(doc.layers) + 1}"))
                doc.add_layer(layer)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/delete-layer", methods=["POST"])
    def editor_delete_layer():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            idx = data.get("layer", -1)
            with _editor_lock:
                doc.delete_layer(idx)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/layer-props", methods=["POST"])
    def editor_layer_props():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            idx = data.get("layer", -1)
            props = {}
            for k in ("opacity", "visible", "blend_mode", "name", "locked"):
                if k in data:
                    props[k] = data[k]
            with _editor_lock:
                doc.set_layer_properties(idx, **props)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/layer/info")
    def layer_info():
        try:
            doc = _req_doc()
            return jsonify({"status": "ok", "layers": [doc._layer_to_dict(l) for l in doc.layers]})
        except ValueError as e:
            return jsonify({"layers": []})

    # ── Advanced OpenCV tools ────────────────────────────

    @app.route("/api/v1/editor/upscale", methods=["POST"])
    def editor_upscale():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            scale = max(1, min(int(_validate_factor(data.get("scale", 2), 2, 1, 8)), 4))
            for layer in doc.layers:
                h, w = layer.image.shape[:2]
                new_w = min(w * scale, MAX_IMAGE_DIM)
                new_h = min(h * scale, MAX_IMAGE_DIM)
                if new_w * new_h > MAX_IMAGE_PIXELS:
                    return jsonify({"error": f"Upscaled too large: {new_w}x{new_h}"}), 400
                layer.image = super_resolve(layer.image, scale=scale)
            doc.width = doc.layers[0].width if doc.layers else doc.width * scale
            doc.height = doc.layers[0].height if doc.layers else doc.height * scale
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/lineart", methods=["POST"])
    def editor_lineart():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            method = data.get("method", "canny")
            for layer in doc.layers:
                layer.image = extract_lineart(layer.image, method=method)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/hdr", methods=["POST"])
    def editor_hdr():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            gamma = data.get("gamma", 1.5)
            contrast = data.get("contrast", 1.2)
            saturation = data.get("saturation", 1.3)
            for layer in doc.layers:
                layer.image = hdr_tone(layer.image, gamma=gamma, contrast=contrast, saturation=saturation)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/remove-bg", methods=["POST"])
    def editor_remove_bg():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            for layer in doc.layers:
                layer.image = remove_background(layer.image)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/ai-enhance", methods=["POST"])
    def editor_ai_enhance():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            for layer in doc.layers:
                layer.image = ai_enhance_image(layer.image)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/ai-restore", methods=["POST"])
    def editor_ai_restore():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            for layer in doc.layers:
                layer.image = ai_restore_faces(layer.image)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/ai-repair", methods=["POST"])
    def editor_ai_repair():
        """AI mask-based repair: receives image mask + prompt, returns repaired image."""
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            repair = app.engine.get("repair")
            if repair is None:
                return jsonify({"error": "Repair engine not initialized"}), 500

            # Build mask from points or use raw mask_b64
            mask = _build_repair_mask(doc, data)
            user_prompt = data.get("prompt", "").strip()
            task = data.get("task", "auto")

            # Auto-generate prompt based on task if user didn't provide one
            if not user_prompt:
                TASK_PROMPTS = {
                    "auto": "自然修复选中区域，无缝融合，保持整体风格和色调一致，无痕迹",
                    "watermark": "去除选中区域的水印/文字/Logo，用周围背景自然填充，无痕迹，保持纹理一致",
                    "face": "修复选中区域的人脸，保持五官自然，肤色均匀，表情真实",
                    "superres": "对选中区域进行超分辨率放大，增加细节清晰度，保持色彩自然",
                    "denoise": "去除选中区域的噪点，保留细节和边缘锐度，不过度平滑",
                    "colorize": "为选中区域的黑白/灰度部分自然上色，颜色真实合理",
                    "deblur": "修复选中区域的模糊，增强锐度和清晰度，恢复细节纹理",
                    "change_bg": "替换背景为干净自然的新背景，主体完整保留，边缘过渡平滑",
                }
                user_prompt = TASK_PROMPTS.get(task, TASK_PROMPTS["auto"])

            for layer in doc.layers:
                if layer.visible and not layer.locked:
                    layer.image = repair.repair(layer.image, mask, user_prompt)

            return jsonify(_doc_response(doc, extra={
                "repair_method": repair.provider.value,
                "repair_task": task,
            }))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/action", methods=["POST"])
    def editor_action():
        """Copy, cut, paste, delete, fill-selection."""
        data = request.get_json(silent=True) or {}
        action = data.get("action", "")
        try:
            doc = _req_doc_snapshot()
            import numpy as np
            import cv2
            h, w = doc.height, doc.width

            # Build selection mask from request
            sel_type = data.get("selection_type", "")  # rect / ellipse / lasso / poly
            mask = np.zeros((h, w), dtype=np.uint8)

            if sel_type == "rect":
                r = data.get("selection_rect", {})
                x1 = max(0, int(r.get("left", 0)))
                y1 = max(0, int(r.get("top", 0)))
                x2 = min(w, int(r.get("right", w)))
                y2 = min(h, int(r.get("bottom", h)))
                if x2 > x1 and y2 > y1:
                    mask[y1:y2, x1:x2] = 255
            elif sel_type == "ellipse":
                r = data.get("selection_rect", {})
                cx = (int(r.get("left", 0)) + int(r.get("right", w))) // 2
                cy = (int(r.get("top", 0)) + int(r.get("bottom", h))) // 2
                rx = max(1, (int(r.get("right", w)) - int(r.get("left", 0))) // 2)
                ry = max(1, (int(r.get("bottom", h)) - int(r.get("top", 0))) // 2)
                cv2.ellipse(mask, (cx, cy), (rx, ry), 0, 0, 360, 255, -1)
            elif sel_type in ("lasso", "poly"):
                pts = data.get("selection_points", [])
                if isinstance(pts, list) and len(pts) >= 3:
                    poly = np.array([(int(x), int(y)) for x, y in pts], dtype=np.int32)
                    cv2.fillPoly(mask, [poly], 255)

            has_mask = np.any(mask > 0)

            # Use clipboard from enclosing scope
            nonlocal _clipboard

            if action == "copy" and has_mask:
                # Extract selected pixels from active layer
                for layer in doc.layers:
                    if layer.visible and not layer.locked:
                        # Store full image + mask info
                        _clipboard = {
                            "image": layer.image.copy(),
                            "mask": mask.copy(),
                            "bounds": cv2.boundingRect(mask),  # x, y, w, h
                        }
                        break
                return jsonify(_doc_response(doc))

            elif action == "cut" and has_mask:
                for layer in doc.layers:
                    if layer.visible and not layer.locked:
                        # Store in clipboard first
                        _clipboard = {
                            "image": layer.image.copy(),
                            "mask": mask.copy(),
                            "bounds": cv2.boundingRect(mask),
                        }
                        # Set alpha to 0 in selected area
                        layer.image[mask > 0, 3] = 0
                        break
                return jsonify(_doc_response(doc))

            elif action == "paste" and _clipboard is not None:
                cb = _clipboard
                x, y, cw, ch = cb["bounds"]
                # Extract just the selected pixels
                cb_img = cb["image"].copy()
                cb_mask = cb["mask"]
                # Create transparent layer sized to the selection bounds
                pasted = np.zeros((h, w, 4), dtype=np.uint8)
                # Place the original pixels in the same position
                for c in range(4):
                    channel = cb_img[:, :, c]
                    pasted[:, :, c] = np.where(cb_mask > 0, channel, 0)
                # Add as new layer
                from modules.image_studio import Layer
                doc.add_layer(Layer(image=pasted, name="Pasted"))
                return jsonify(_doc_response(doc))

            elif action == "delete" and has_mask:
                for layer in doc.layers:
                    if layer.visible and not layer.locked:
                        layer.image[mask > 0, 3] = 0
                        break
                return jsonify(_doc_response(doc))

            elif action == "fill-selection":
                color = data.get("color", [128, 128, 128, 255])
                if isinstance(color, list):
                    if len(color) == 3:
                        color = [color[0], color[1], color[2], 255]
                    elif len(color) == 4:
                        pass
                    else:
                        color = [128, 128, 128, 255]
                if has_mask:
                    for layer in doc.layers:
                        if layer.visible and not layer.locked:
                            layer.image[mask > 0] = color
                else:
                    # No selection: fill entire layer
                    for layer in doc.layers:
                        if layer.visible and not layer.locked:
                            layer.image[:] = color
                return jsonify(_doc_response(doc))

            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/inpaint-erase", methods=["POST"])
    def editor_inpaint_erase():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            x = int(data.get("x", 0)); y = int(data.get("y", 0))
            w = int(data.get("w", 50)); h = int(data.get("h", 50))
            radius = data.get("radius", 3)
            for layer in doc.layers:
                layer.image = inpaint_erase(layer.image, x, y, w, h, radius=radius)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/blur-region", methods=["POST"])
    def editor_blur_region():
        data = request.get_json(silent=True) or {}
        try:
            doc = _req_doc_snapshot()
            x = int(data.get("x", 0)); y = int(data.get("y", 0))
            w = int(data.get("w", 50)); h = int(data.get("h", 50))
            ksize = data.get("ksize", 15)
            for layer in doc.layers:
                layer.image = blur_region(layer.image, x, y, w, h, ksize=ksize)
            return jsonify(_doc_response(doc))
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    @app.route("/api/v1/editor/fonts")
    def editor_fonts():
        from modules.image_studio.tools import get_system_fonts
        sf = get_system_fonts()
        fonts = []
        for name, path in sorted(sf.items()):
            ext = os.path.splitext(path)[1].lower()
            style = "regular"
            fn_lower = path.lower()
            if "bold" in fn_lower and "italic" in fn_lower:
                style = "bold_italic"
            elif "bold" in fn_lower:
                style = "bold"
            elif "italic" in fn_lower or "oblique" in fn_lower:
                style = "italic"
            elif "light" in fn_lower:
                style = "light"
            elif "medium" in fn_lower:
                style = "medium"
            fonts.append({
                "name": name,
                "family": name,
                "file": path,
                "style": style,
                "format": ext.lstrip("."),
                "has_cjk": "cjk" in path.lower() or "wenquan" in path.lower() or "arphic" in path.lower(),
            })
        return jsonify({"fonts": fonts})

    @app.route("/api/v1/editor/preview", methods=["POST"])
    def editor_preview():
        """Return a thumbnail preview (default 320px max side) of current state."""
        try:
            doc = _req_doc_snapshot()
            max_size = (request.get_json(silent=True) or {}).get("max_size", 320)
            b64 = doc.to_thumbnail_base64(max_size=int(max_size))
            return jsonify({
                "status": "ok",
                "info": doc.info(),
                "base64": b64,
                "history": doc.get_history_state(),
                "thumbnail": True,
            })
        except Exception as e:
            return jsonify({"error": str(e)}), 400

    return app

def main():
    """Start the AI Server"""
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
