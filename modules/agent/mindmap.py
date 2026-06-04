"""FlowGraph — Creative flow tree for PhantomVox

Each node is a creative step in a tree structure:
- topic:   Root theme / project idea
- scene:   Major scene / story beat
- beat:    Specific shot or moment
- missing: AI-identified narrative gap

CRUD operations for frontend interaction.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Optional, Dict
from enum import Enum
import json


class NodeType(str, Enum):
    TOPIC = "topic"
    SCENE = "scene"
    BEAT = "beat"
    MISSING = "missing"


class NodeStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class FlowNode:
    id: str
    label: str                       # Display label
    node_type: NodeType = NodeType.TOPIC
    description: str = ""             # Detailed content
    status: NodeStatus = NodeStatus.PENDING
    progress: float = 0.0             # 0.0 ~ 1.0
    agent: str = ""                   # Responsible agent name
    parent_id: Optional[str] = None
    children: List[str] = field(default_factory=list)
    ai_generated: bool = False
    metadata: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "label": self.label,
            "node_type": self.node_type.value,
            "description": self.description,
            "status": self.status.value,
            "progress": self.progress,
            "agent": self.agent,
            "parent_id": self.parent_id,
            "children": self.children,
            "ai_generated": self.ai_generated,
            "metadata": self.metadata,
        }

    @classmethod
    def from_dict(cls, d: dict) -> FlowNode:
        return cls(
            id=d["id"],
            label=d.get("label", ""),
            node_type=NodeType(d.get("node_type", "topic")),
            description=d.get("description", ""),
            status=NodeStatus(d.get("status", "pending")),
            progress=d.get("progress", 0.0),
            agent=d.get("agent", ""),
            parent_id=d.get("parent_id"),
            children=d.get("children", []),
            ai_generated=d.get("ai_generated", False),
            metadata=d.get("metadata", {}),
        )


class FlowGraph:
    """Creative flow tree — hierarchical, not DAG (for Phase 1)."""

    def __init__(self, root_label: str = ""):
        self.nodes: Dict[str, FlowNode] = {}
        self.root: str = ""
        if root_label:
            self.add_root(root_label)

    # ── CRUD ────────────────────────────────────────────────

    def add_root(self, label: str, description: str = "") -> str:
        nid = "root"
        self.nodes[nid] = FlowNode(
            id=nid, label=label, node_type=NodeType.TOPIC,
            description=description,
        )
        self.root = nid
        return nid

    def add_node(self, parent_id: str, label: str, *,
                 node_type: NodeType = NodeType.SCENE,
                 description: str = "",
                 agent: str = "",
                 ai_generated: bool = False) -> str:
        """Add a child node under parent_id. Returns new node id."""
        if parent_id not in self.nodes:
            raise ValueError(f"Parent node not found: {parent_id}")
        nid = f"n{len(self.nodes)}"
        node = FlowNode(
            id=nid, label=label, node_type=node_type,
            description=description, agent=agent,
            parent_id=parent_id, ai_generated=ai_generated,
        )
        self.nodes[nid] = node
        self.nodes[parent_id].children.append(nid)
        return nid

    def update_node(self, node_id: str, **kwargs) -> bool:
        """Update fields on a node. Returns False if not found."""
        node = self.nodes.get(node_id)
        if not node:
            return False
        for key, value in kwargs.items():
            if hasattr(node, key):
                if key == "node_type" and isinstance(value, str):
                    value = NodeType(value)
                elif key == "status" and isinstance(value, str):
                    value = NodeStatus(value)
                setattr(node, key, value)
        return True

    def delete_node(self, node_id: str) -> bool:
        """Delete a node and all its descendants. Returns False if not found."""
        if node_id == self.root:
            return False  # Can't delete root
        node = self.nodes.get(node_id)
        if not node:
            return False

        # Recursively collect all descendant ids
        to_delete = self._collect_descendants(node_id)

        # Remove from parent's children list
        parent = self.nodes.get(node.parent_id) if node.parent_id else None
        if parent:
            parent.children = [c for c in parent.children if c not in to_delete]

        # Delete all nodes
        for nid in to_delete:
            self.nodes.pop(nid, None)
        return True

    def move_node(self, node_id: str, new_parent_id: str) -> bool:
        """Move a node under a new parent. Returns False if invalid."""
        if node_id == self.root:
            return False
        node = self.nodes.get(node_id)
        new_parent = self.nodes.get(new_parent_id)
        if not node or not new_parent:
            return False
        if node_id in self._collect_descendants(new_parent_id):
            return False  # Can't move to own child

        # Remove from old parent
        old_parent = self.nodes.get(node.parent_id) if node.parent_id else None
        if old_parent:
            old_parent.children = [c for c in old_parent.children if c != node_id]

        # Add to new parent
        node.parent_id = new_parent_id
        new_parent.children.append(node_id)
        return True

    def reorder_children(self, parent_id: str, child_ids: List[str]) -> bool:
        """Reorder children of a node. Returns False if parent not found."""
        parent = self.nodes.get(parent_id)
        if not parent:
            return False
        # Only keep valid children in the new order
        existing = set(parent.children)
        parent.children = [c for c in child_ids if c in existing]
        return True

    # ── Query ────────────────────────────────────────────────

    def get_children(self, node_id: str) -> List[FlowNode]:
        """Return child nodes of the given node."""
        node = self.nodes.get(node_id)
        if not node:
            return []
        return [self.nodes[cid] for cid in node.children if cid in self.nodes]

    def get_path(self, node_id: str) -> List[str]:
        """Return path from root to the given node (list of ids)."""
        path = []
        current = node_id
        while current and current in self.nodes:
            path.append(current)
            node = self.nodes[current]
            current = node.parent_id
        path.reverse()
        return path

    def has_ai_suggestions(self) -> bool:
        """Check if there are any AI-generated nodes that need review."""
        return any(n.ai_generated for n in self.nodes.values())

    def count_by_type(self) -> dict:
        """Return count of nodes by type."""
        counts = {}
        for n in self.nodes.values():
            t = n.node_type.value
            counts[t] = counts.get(t, 0) + 1
        return counts

    # ── Serialization ────────────────────────────────────────

    def to_dict(self) -> dict:
        return {
            "root": self.root,
            "nodes": {k: v.to_dict() for k, v in self.nodes.items()},
            "counts": self.count_by_type(),
            "has_ai_suggestions": self.has_ai_suggestions(),
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)

    @classmethod
    def from_dict(cls, d: dict) -> FlowGraph:
        fg = cls.__new__(cls)
        fg.root = d.get("root", "")
        fg.nodes = {}
        for nid, nd in d.get("nodes", {}).items():
            fg.nodes[nid] = FlowNode.from_dict(nd)
        return fg

    @classmethod
    def from_json(cls, s: str) -> FlowGraph:
        return cls.from_dict(json.loads(s))

    # ── Internals ────────────────────────────────────────────

    def _collect_descendants(self, node_id: str) -> List[str]:
        """Return node_id and all its descendants (DFS)."""
        result = [node_id]
        node = self.nodes.get(node_id)
        if node:
            for cid in node.children:
                result.extend(self._collect_descendants(cid))
        return result
