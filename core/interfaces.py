"""PhantomVox AI — Core Interface Definitions

All module interfaces use Protocol (PEP 544) for duck typing.
When adding new feature modules, append Protocols here; do not modify existing interface signatures.
"""

from typing import Protocol, Dict, List, Optional


class Timeline(Protocol):
    """Timeline interface — track management for audio/video clips"""
    def add_clip(self, asset_path: str, start_time: float, duration: float, track: int = 0) -> str: ...
    def get_state(self) -> Dict: ...


class VideoProcessor(Protocol):
    """Video processing interface — cut/merge/transcode"""
    def cut(self, input_path: str, output_path: str, start: float, duration: float) -> bool: ...
    def merge(self, clips: List[str], output_path: str) -> bool: ...
    def transcode(self, input_path: str, output_path: str, preset: str = "default") -> bool: ...


class AudioProcessor(Protocol):
    """Audio processing interface — TTS/voice-clone/mix"""
    def text_to_speech(self, text: str, voice_id: str = "default", output_path: str = None) -> str: ...
    def voice_clone(self, reference_audio: str, text: str, output_path: str = None) -> str: ...
    def mix(self, tracks: List[str], output_path: str) -> bool: ...


class MusicGenerator(Protocol):
    """Music generation interface — AI composition"""
    def generate(self, prompt: str, duration: float, style: str = "default") -> str: ...


class AIChatAgent(Protocol):
    """AI Agent interface — intelligent conversation and instruction parsing"""
    def process(self, instruction: str, context: Dict) -> Dict: ...
    def suggest(self, context: Dict) -> str: ...


class ProjectManager(Protocol):
    """Project management interface — load/save/migrate"""
    def save(self, path: str) -> bool: ...
    def load(self, path: str) -> bool: ...
    def export(self, path: str, format: str = "json") -> bool: ...


class AgentPanel(Protocol):
    """AI Panel interface — common for all 5 sub-panels"""
    name: str
    description: str
    def execute(self, params: Dict) -> Dict: ...


class AgentProtocol(Protocol):
    """AI Agent interface — common for all 8 agents"""
    name: str
    role: str
    description: str
    active: bool
    def execute(self, task: Dict) -> Dict: ...


class ConfigManagerProtocol(Protocol):
    """Model config interface — read/write persisted configuration"""
    def get(self, *keys: str): ...
    def set(self, *keys_and_value) -> bool: ...
    def get_all(self) -> dict: ...
    def save(self): ...
