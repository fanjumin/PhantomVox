"""Agent base class"""

from abc import ABC, abstractmethod
from typing import Any, Dict, Optional


class AgentBase(ABC):
    """Single AI Agent base"""

    name: str = ""
    role: str = ""
    description: str = ""
    # Module name to access via engine.get()
    target_module: str = ""
    active: bool = True

    @abstractmethod
    async def execute(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a task, return result"""
        ...

    def to_info(self) -> dict:
        return {
            "name": self.name, "role": self.role,
            "description": self.description,
            "target_module": self.target_module,
            "active": self.active,
        }
