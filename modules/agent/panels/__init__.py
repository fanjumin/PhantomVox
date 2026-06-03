"""Panel provider abstract base class"""

from abc import ABC, abstractmethod
from typing import Any, Dict


class PanelProvider(ABC):
    """AI panel provider base"""

    name: str = ""
    description: str = ""

    @abstractmethod
    def execute(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Execute panel operation, returns {"result": ..., "status": "ok"|"error"}"""
        ...

    def to_info(self) -> dict:
        return {"name": self.name, "description": self.description}
