"""AgentEngine — PhantomVox AI Agent Orchestrator

Responsibilities:
- Register AI panels (Chat/Think/ImageGen/VideoGen/CodeGen)
- Register sub-agents (Director/Editor/Audio/...)
- Director manages mind map lifecycle
- WorkflowRunner for end-to-end orchestration
- Access other modules via engine (audio/i18n/hardware)

Usage:
    engine = Engine()
    agent = AgentEngine(engine)
    agent.register_panel("chat", ChatPanel())
    agent.register_agent("director", DirectorAgent(engine))
    engine.register("agent", agent)
"""

from __future__ import annotations
from typing import Any, Dict, List, Optional, TYPE_CHECKING

from modules.agent.mindmap import FlowGraph, FlowNode, NodeType, NodeStatus
from modules.agent.panels import PanelProvider
from modules.agent.agents import AgentBase
from modules.agent.agents.director import DirectorAgent
from modules.agent.agents.stubs import (
    EditorAgent, AudioAgent, MusicAgent,
    VisualAgent, ColorAgent, RestoreAgent, CodeAgent,
)
from modules.agent.workflow import WorkflowRunner

if TYPE_CHECKING:
    from core.engine import Engine


class AgentEngine:
    """AI Agent Engine — panels + agents + mind map + workflow"""

    def __init__(self, engine: Optional[Engine] = None):
        self._engine = engine
        self._panels: Dict[str, PanelProvider] = {}
        self._agents: Dict[str, AgentBase] = {}

        # Director is a special agent that manages the mind map
        self._director = DirectorAgent(engine)
        self._agents["director"] = self._director

        # Register preset agents
        self.register_agent("editor", EditorAgent())
        self.register_agent("audio", AudioAgent())
        self.register_agent("music", MusicAgent())
        self.register_agent("visual", VisualAgent())
        self.register_agent("color", ColorAgent())
        self.register_agent("restore", RestoreAgent())
        self.register_agent("code", CodeAgent())

        # Workflow orchestrator (P7)
        self._workflow_runner = WorkflowRunner(self)

    # ── Panel management ────────────────────────────────────

    def register_panel(self, name: str, panel: PanelProvider):
        panel.name = name
        self._panels[name] = panel

    def get_panel(self, name: str) -> Optional[PanelProvider]:
        return self._panels.get(name)

    def list_panels(self) -> List[dict]:
        return [p.to_info() for p in self._panels.values()]

    # ── Agent management ────────────────────────────────────

    def register_agent(self, name: str, agent: AgentBase):
        agent.name = name
        self._agents[name] = agent

    def get_agent(self, name: str) -> Optional[AgentBase]:
        return self._agents.get(name)

    def list_agents(self) -> List[dict]:
        return [a.to_info() for a in self._agents.values()]

    def agent_matrix(self) -> dict:
        """Return multi-agent matrix status"""
        return {
            "agents": self.list_agents(),
            "active_count": sum(1 for a in self._agents.values() if a.active),
            "total": len(self._agents),
        }

    # ── Panel execution ────────────────────────────────────

    def execute_panel(self, panel_name: str, params: Dict[str, Any]) -> Dict[str, Any]:
        panel = self._panels.get(panel_name)
        if not panel:
            return {"status": "error", "message": f"Unknown panel: {panel_name}"}
        return panel.execute(params)

    # ── Director / Mind map ────────────────────────────────

    def plan(self, intent: str) -> Dict[str, Any]:
        """User intent -> Director decompose -> mind map"""
        import asyncio
        coro = self._director.execute({"action": "plan", "intent": intent})
        return asyncio.run(coro)

    def get_mindmap(self) -> Dict[str, Any]:
        return self._director.flowgraph.to_dict()

    def update_node(self, node_label: str, status: str, *,
                    progress: Optional[float] = None,
                    result: Optional[str] = None,
                    error: Optional[str] = None):
        """Update mind map node status by label (used by WorkflowRunner)"""
        for node in self._director.flowgraph.nodes.values():
            if node.label == node_label:
                self._director.flowgraph.update_node(
                    node.id, status=NodeStatus(status),
                )

    # ── Single agent execution ──────────────────────────────

    def execute_agent(self, agent_name: str, task: Dict[str, Any]) -> Dict[str, Any]:
        agent = self._agents.get(agent_name)
        if not agent:
            return {"status": "error", "message": f"Unknown agent: {agent_name}"}
        if not agent.active:
            return {"status": "error", "message": f"Agent {agent_name} is inactive"}
        import asyncio
        try:
            coro = agent.execute(task)
            result = asyncio.run(coro)
            return result
        except Exception as e:
            return {"status": "error", "message": str(e)}

    # ── Workflow orchestration (P7) ────────────────────────

    def start_workflow(self, intent: str) -> Dict[str, Any]:
        """End-to-end: plan -> dispatch -> collect -> assemble"""
        return self._workflow_runner.start_workflow(intent)

    def get_workflow(self, wid: str) -> Optional[Dict[str, Any]]:
        return self._workflow_runner.get_workflow(wid)

    def list_workflows(self) -> List[Dict[str, Any]]:
        return self._workflow_runner.list_workflows()

    # ── Info ──────────────────────────────────────────────

    def to_info(self) -> dict:
        return {
            "panels": self.list_panels(),
            "agents": self.list_agents(),
            "agent_matrix": self.agent_matrix(),
            "mindmap": self._director.mindmap.to_dict(),
        }
