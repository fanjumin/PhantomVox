"""WorkflowRunner — Director Agent end-to-end orchestration

Pipeline:
  1. plan:  user intent → Director decomposes → mind map with sub-tasks
  2. dispatch:  for each sub-task → assign to matching agent
  3. collect:  gather results from all agents
  4. assemble:  combine results into timeline-compatible format
"""

from __future__ import annotations
import time
import uuid
from typing import Any, Dict, List, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from modules.agent.agent_engine import AgentEngine


class WorkflowRunner:
    """Orchestrate a full creative workflow from intent to timeline-ready assets"""

    def __init__(self, engine: AgentEngine):
        self._agent = engine
        self._workflows: Dict[str, Dict[str, Any]] = {}

    # ── Public API ──────────────────────────────────────────

    def start_workflow(self, intent: str) -> Dict[str, Any]:
        """Plan + dispatch + collect + assemble — full pipeline"""
        wid = _gen_id()

        # Phase 1: Plan (Director decomposes intent)
        plan_result = self._agent.plan(intent)
        tasks = plan_result.get("tasks", [])
        mindmap = plan_result.get("mindmap", {})

        workflow: Dict[str, Any] = {
            "id": wid,
            "intent": intent,
            "status": "running",
            "phase": "dispatch",
            "mindmap": mindmap,
            "tasks": tasks,
            "results": {},
            "timeline_assets": [],
            "errors": [],
            "started_at": time.time(),
            "completed_at": None,
        }
        self._workflows[wid] = workflow

        # Phase 2-3: Dispatch each task → collect results
        for task in tasks:
            agent_name = task.get("agent", "director")
            self._agent.update_node(
                task.get("label", ""),
                "running", progress=0.3,
            )

            result = self._agent.execute_agent(agent_name, task)

            node_id = task.get("label", "")
            if result.get("status") == "ok":
                self._agent.update_node(
                    node_id, "completed", progress=1.0,
                    result=result.get("result", ""),
                )
                workflow["results"][agent_name] = result
            else:
                self._agent.update_node(
                    node_id, "failed", error=result.get("message", "Unknown error"),
                )
                workflow["errors"].append(result.get("message", ""))

        # Phase 4: Assemble timeline assets
        workflow["timeline_assets"] = self._assemble(workflow["results"])
        workflow["status"] = "completed"
        workflow["phase"] = "done"
        workflow["completed_at"] = time.time()

        return self._summarize(wid)

    def get_workflow(self, wid: str) -> Optional[Dict[str, Any]]:
        wf = self._workflows.get(wid)
        if not wf:
            return None
        return self._summarize(wid)

    def list_workflows(self) -> List[Dict[str, Any]]:
        return [self._summarize(wid) for wid in self._workflows]

    # ── Assembly ────────────────────────────────────────────

    def _assemble(self, results: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Convert agent results into timeline-compatible asset list"""
        assets = []

        if "audio" in results:
            r = results["audio"]
            assets.append({
                "type": "audio",
                "label": "Voiceover",
                "source": r.get("result", ""),
                "engine": r.get("engine", "edge_tts"),
                "track": "A1",
            })

        if "music" in results:
            r = results["music"]
            assets.append({
                "type": "audio",
                "label": "Background Music",
                "source": r.get("result", ""),
                "style": r.get("style", "default"),
                "track": "A2",
            })

        if "visual" in results:
            r = results["visual"]
            assets.append({
                "type": "video" if r.get("result", "").startswith("video") else "image",
                "label": r.get("result", "Visual Asset"),
                "track": "V1",
            })

        if "code" in results:
            r = results["code"]
            assets.append({
                "type": "effect",
                "label": "Custom Effect",
                "code": r.get("code", ""),
                "track": "FX",
            })

        if "editor" in results:
            r = results["editor"]
            assets.append({
                "type": "timeline",
                "label": "Edited Sequence",
                "result": r.get("result", ""),
            })

        if not assets:
            assets.append({
                "type": "info",
                "label": "Workflow Completed",
                "detail": "All tasks processed. Check mind map for details.",
            })

        return assets

    def _summarize(self, wid: str) -> Dict[str, Any]:
        wf = self._workflows[wid]
        return {
            "id": wf["id"],
            "intent": wf["intent"],
            "status": wf["status"],
            "phase": wf["phase"],
            "task_count": len(wf["tasks"]),
            "completed_count": sum(
                1 for r in wf["results"].values()
                if r.get("status") == "ok"
            ),
            "error_count": len(wf["errors"]),
            "mindmap": wf["mindmap"],
            "timeline_assets": wf["timeline_assets"],
            "results": wf["results"],
            "errors": wf["errors"],
            "started_at": wf["started_at"],
            "completed_at": wf["completed_at"],
        }


def _gen_id() -> str:
    return f"wf_{uuid.uuid4().hex[:8]}"
