"""Director Agent — Intent analysis → mind map → agent dispatch

Responsibilities:
- Receive user intent
- Analyze keywords to decompose into sub-tasks
- Create mind map nodes
- Dispatch to sub-agents
"""

from typing import Any, Dict, List

from modules.agent.mindmap import MindMap, NodeStatus
from . import AgentBase


class DirectorAgent(AgentBase):
    name = "director"
    role = "Director"
    description = "Intent parsing, task decomposition, scheduling — all creation starts here"
    target_module = "agent"

    def __init__(self, engine=None):
        self._engine = engine
        self._mindmap: MindMap = MindMap()

    @property
    def mindmap(self) -> MindMap:
        return self._mindmap

    async def execute(self, task: Dict[str, Any]) -> Dict[str, Any]:
        action = task.get("action", "plan")
        if action == "plan":
            return self._plan(task.get("intent", ""))
        elif action == "mindmap":
            return {"status": "ok", "mindmap": self._mindmap.to_dict()}
        elif action == "node_status":
            nid = task.get("node_id", "")
            status = task.get("status", "pending")
            self._mindmap.set_status(nid, NodeStatus(status))
            return {"status": "ok"}
        return {"status": "error", "message": f"Unknown action: {action}"}

    def reset_mindmap(self, label: str = ""):
        self._mindmap = MindMap(root_label=label)

    def _plan(self, intent: str) -> Dict[str, Any]:
        """Parse intent and generate mind map"""
        self.reset_mindmap(intent)
        tasks = self._decompose_intent(intent)
        for t in tasks:
            self._mindmap.add_child(
                "root", t["label"], description=t.get("desc", ""),
                agent=t.get("agent", ""),
            )
        return {
            "status": "ok",
            "intent": intent,
            "mindmap": self._mindmap.to_dict(),
            "tasks": tasks,
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
