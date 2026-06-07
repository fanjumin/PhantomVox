"""PhantomVox AI — Core Data Models"""

from dataclasses import dataclass, field, asdict
from typing import Dict, List


@dataclass
class Asset:
    """Media asset"""
    id: str
    path: str
    type: str  # video, audio, image, music
    duration: float = 0.0


@dataclass
class TimelineClip:
    """Timeline clip"""
    asset_id: str
    start_time: float
    duration: float
    track: int = 0
    effects: Dict = field(default_factory=dict)


@dataclass
class Project:
    """Video project"""
    id: str
    name: str
    timeline: List[TimelineClip] = field(default_factory=list)
    assets: Dict[str, Asset] = field(default_factory=dict)
    metadata: Dict = field(default_factory=dict)

    def dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "timeline": [asdict(c) for c in self.timeline],
            "assets": {k: asdict(v) for k, v in self.assets.items()},
            "metadata": self.metadata,
        }
