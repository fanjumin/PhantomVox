"""Director Agent — Intent analysis → flow graph → agent dispatch

Responsibilities:
- Receive user intent
- Analyze keywords to decompose into sub-tasks
- Create flow graph nodes
- Dispatch to sub-agents
- Expand flow graph nodes with AI suggestions
"""

from typing import Any, Dict, List, Optional

from modules.agent.mindmap import FlowGraph, FlowNode, NodeType, NodeStatus
from . import AgentBase


class DirectorAgent(AgentBase):
    name = "director"
    role = "Director"
    description = "Intent parsing, task decomposition, scheduling — all creation starts here"
    target_module = "agent"

    def __init__(self, engine=None):
        self._engine = engine
        self._flowgraph: FlowGraph = FlowGraph()

    @property
    def flowgraph(self) -> FlowGraph:
        return self._flowgraph

    @flowgraph.setter
    def flowgraph(self, fg: FlowGraph):
        self._flowgraph = fg

    async def execute(self, task: Dict[str, Any]) -> Dict[str, Any]:
        action = task.get("action", "plan")
        if action == "plan":
            return self._plan(task.get("intent", ""))
        elif action == "flowgraph":
            return {"status": "ok", "flowgraph": self._flowgraph.to_dict()}
        elif action == "node_status":
            nid = task.get("node_id", "")
            status = task.get("status", "pending")
            self._flowgraph.update_node(nid, status=NodeStatus(status))
            return {"status": "ok"}
        elif action == "expand_flowgraph":
            return self._expand_node(task.get("node_id", "root"))
        return {"status": "error", "message": f"Unknown action: {action}"}

    def reset_flowgraph(self, label: str = ""):
        self._flowgraph = FlowGraph(root_label=label)

    def _plan(self, intent: str) -> Dict[str, Any]:
        """Parse intent and generate flow graph"""
        self.reset_flowgraph(intent)
        tasks = self._decompose_intent(intent)
        for t in tasks:
            self._flowgraph.add_node(
                "root", t["label"],
                node_type=NodeType.SCENE,
                description=t.get("desc", ""),
                agent=t.get("agent", ""),
            )
        return {
            "status": "ok",
            "intent": intent,
            "flowgraph": self._flowgraph.to_dict(),
            "tasks": tasks,
        }

    def _expand_node(self, node_id: str) -> Dict[str, Any]:
        """AI expand a flow graph node — generate child suggestions."""
        from modules.agent.llm_client import LLMClient

        node = self._flowgraph.nodes.get(node_id)
        if not node:
            return {"status": "error", "message": f"Node not found: {node_id}"}

        # Build context from existing flow graph
        fg = self._flowgraph
        existing_nodes = []
        for n in fg.nodes.values():
            existing_nodes.append(f"  [{n.node_type.value}] {n.label}")
        context = "\n".join(existing_nodes)

        if self._engine:
            try:
                cfg = self._engine.get("config")
                profile = cfg.get_profile() if cfg else {}
                provider = profile.get("provider", "deepseek")
                model = profile.get("model", "deepseek-v4")
            except Exception:
                provider = "deepseek"
                model = "deepseek-v4"
        else:
            provider = "deepseek"
            model = "deepseek-v4"

        prompt = f"""You are the Director Agent for a video creation tool. The user is building a creative flow graph.
Current flow graph:
{context}

The user wants to expand the node: "{node.label}" (type: {node.node_type.value})
Description: {node.description}

Generate 2-4 child nodes that would naturally expand this creative step.
Each child should have:
- label (short, 2-6 words)
- description (1 sentence)
- node_type: one of "scene", "beat", or "missing" (use "missing" for gaps that need attention)

Return ONLY a JSON array with no markdown:
[{{"label": "...", "description": "...", "node_type": "..."}}]
"""
        result = ""
        client = LLMClient(provider=provider, model=model)
        try:
            import asyncio
            response = asyncio.run(client.chat(prompt))
            result = response.get("content", "")
        except Exception as e:
            return {"status": "error", "message": f"LLM call failed: {e}"}

        # Parse the response
        import json
        import re
        try:
            # Try direct JSON parse first
            children = json.loads(result.strip())
        except json.JSONDecodeError:
            # Fallback: extract JSON array from text
            match = re.search(r'\[[\s\S]*?\]', result)
            if match:
                children = json.loads(match.group())
            else:
                return {"status": "error", "message": f"Could not parse LLM response: {result[:200]}"}

        # Add nodes to flow graph
        added = []
        for child in children:
            nt = NodeType(child.get("node_type", "scene"))
            nid = fg.add_node(
                node_id,
                child.get("label", "Untitled"),
                node_type=nt,
                description=child.get("description", ""),
                ai_generated=True,
            )
            added.append({"id": nid, "label": child.get("label", ""), "node_type": nt.value})

        return {
            "status": "ok",
            "node_id": node_id,
            "suggestions": added,
            "flowgraph": fg.to_dict(),
        }

    def _decompose_intent(self, intent: str) -> List[dict]:
        """Keyword matching → task list"""
        lower = intent.lower()
        tasks = []

        # Audio / voice
        if any(k in lower for k in ["voice", "tts", "narration", "dub", "voiceover"]):
            tasks.append({
                "label": "Voice Synthesis",
                "desc": "Generate voiceover / narration audio",
                "agent": "audio",
            })

        # Music
        if any(k in lower for k in ["music", "soundtrack", "background", "song"]):
            tasks.append({
                "label": "Music Generation",
                "desc": "Generate soundtrack or background music",
                "agent": "music",
            })

        # Video
        if any(k in lower for k in ["video", "clip", "footage", "promo"]):
            tasks.append({
                "label": "Video Asset Generation",
                "desc": "Text-to-video or video editing",
                "agent": "visual",
            })

        # Image
        if any(k in lower for k in ["image", "picture", "thumbnail", "cover"]):
            tasks.append({
                "label": "Image Asset Generation",
                "desc": "Text-to-image or image restoration",
                "agent": "visual",
            })

        # Color grading
        if any(k in lower for k in ["color", "grade", "lut"]):
            tasks.append({
                "label": "Color Grading",
                "desc": "Color correction, LUT application",
                "agent": "color",
            })

        # Effects / transitions
        if any(k in lower for k in ["effect", "transition", "vfx"]):
            tasks.append({
                "label": "Effect Generation",
                "desc": "Custom transition / effect code",
                "agent": "code",
            })

        # Editing
        if any(k in lower for k in ["edit", "cut", "trim"]):
            tasks.append({
                "label": "Timeline Editing",
                "desc": "Cut, trim, arrange assets on timeline",
                "agent": "editor",
            })

        # Default: generic workflow
        if not tasks:
            tasks = [
                {"label": "Requirements Analysis", "desc": "Understand creative goals", "agent": "director"},
                {"label": "Asset Preparation", "desc": "Collect and generate needed assets", "agent": "visual"},
                {"label": "Rough Cut", "desc": "Rough timeline assembly", "agent": "editor"},
                {"label": "Polish & Export", "desc": "Color, effects, export", "agent": "code"},
            ]

        return tasks
