"""Provider interface base class"""
from abc import ABC, abstractmethod
from typing import Dict, List


class TTSProvider(ABC):
    """TTS provider interface"""
    name: str = ""

    @abstractmethod
    def synthesize(self, text: str, voice: str = "default",
                   output_path: str = None) -> Dict:
        ...

    @abstractmethod
    def list_voices(self) -> List[Dict]:
        ...


class MusicProvider(ABC):
    """Music generation provider interface"""
    name: str = ""

    @abstractmethod
    def generate(self, prompt: str, style: str = "default",
                 duration: float = 30) -> Dict:
        ...

    @abstractmethod
    def list_styles(self) -> List[str]:
        ...
