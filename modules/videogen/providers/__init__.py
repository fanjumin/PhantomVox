"""Video generation providers"""

from abc import ABC, abstractmethod
from typing import Any, Dict, List


class VideoGenProvider(ABC):
    """Abstract video generation provider"""

    name: str = ""
    description: str = ""

    @abstractmethod
    def generate(self, prompt: str, duration: int = 10,
                 style: str = "default", **kwargs) -> Dict[str, Any]:
        ...

    @abstractmethod
    def list_styles(self) -> List[Dict[str, str]]:
        ...
