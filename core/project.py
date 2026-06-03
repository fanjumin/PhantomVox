"""PhantomVox AI — 核心数据模型"""

from dataclasses import dataclass, field, asdict
from typing import Dict, List


@dataclass
class Asset:
    """媒体资源"""
    id: str
    path: str
    type: str  # video, audio, image, music
    duration: float = 0.0


@dataclass
class TimelineClip:
    """时间线片段"""
    asset_id: str
    start_time: float
    duration: float
    track: int = 0
    effects: Dict = field(default_factory=dict)


@dataclass
class Project:
    """视频项目"""
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
