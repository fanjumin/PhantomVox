"""MindMap — Directed graph data model for creative workflow

Each node is a creative step:
- nodes: Dict[str, MindMapNode]
- root: str  root node ID
- edges: List[(from_id, to_id)]  directed edges

State machine: pending → running → completed | failed
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Optional, Dict
from enum import Enum


class NodeStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class MindMapNode:
    id: str
    label: str                       # Display label
    description: str = ""             # Detailed description
    status: NodeStatus = NodeStatus.PENDING
    progress: float = 0.0             # 0.0 ~ 1.0
    agent: str = ""                   # Responsible agent name
    parent_id: Optional[str] = None
    branch_id: Optional[str] = None   # Branch identifier under same parent
    result: Optional[str] = None      # Execution result summary
    error: Optional[str] = None


class MindMap:
    """Mind map — Directed acyclic graph"""

    def __init__(self, root_label: str = ""):
        self.nodes: Dict[str, MindMapNode] = {}
        self.edges: List[tuple[str, str]] = []
        self.root: str = ""
        if root_label:
            self.add_root(root_label)

    def add_root(self, label: str) -> str:
        nid = "root"
        self.nodes[nid] = MindMapNode(id=nid, label=label)
        self.root = nid
        return nid

    def add_child(self, parent_id: str, label: str, *,
                  description: str = "", agent: str = "",
                  branch_id: Optional[str] = None) -> str:
        nid = f"n{len(self.nodes)}"
        self.nodes[nid] = MindMapNode(
            id=nid, label=label, description=description,
            agent=agent, parent_id=parent_id, branch_id=branch_id,
        )
        self.edges.append((parent_id, nid))
        return nid

    def set_status(self, node_id: str, status: NodeStatus,
                   progress: Optional[float] = None,
                   result: Optional[str] = None,
                   error: Optional[str] = None):
        node = self.nodes.get(node_id)
        if not node:
            return
        node.status = status
        if progress is not None:
            node.progress = progress
        if result is not None:
            node.result = result
        if error is not None:
            node.error = error

    def to_dict(self) -> dict:
        return {
            "root": self.root,
            "nodes": {k: {
                "id": n.id, "label": n.label, "description": n.description,
                "status": n.status.value, "progress": n.progress,
                "agent": n.agent, "parent_id": n.parent_id,
                "branch_id": n.branch_id, "result": n.result, "error": n.error,
            } for k, n in self.nodes.items()},
            "edges": [[a, b] for a, b in self.edges],
        }
