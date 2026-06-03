"""Timeline data models — Track, Clip, Effect, Timeline"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple
from enum import Enum


class ClipType(str, Enum):
    VIDEO = "video"
    AUDIO = "audio"
    GENERATOR = "generator"  # color matte, text, etc.


class EffectType(str, Enum):
    TRANSFORM = "transform"      # zoom/position/rotation/flip
    COLOR = "color"              # color balance, LUT
    SPEED = "speed"              # speed change
    CROP = "crop"                # cropping
    TRANSITION = "transition"    # crossfade, wipe, etc.
    AUDIO_FX = "audio_fx"        # EQ, compressor, reverb
    FILTER = "filter"            # generic FFmpeg filter
    STABILIZE = "stabilize"      # video stabilization
    LENS_CORRECTION = "lens"     # lens distortion correction


@dataclass
class Effect:
    """Single effect applied to a clip"""
    id: str
    type: EffectType
    name: str = ""
    params: Dict[str, Any] = field(default_factory=dict)
    enabled: bool = True

    def to_dict(self) -> dict:
        return {
            "id": self.id, "type": self.type.value,
            "name": self.name, "params": dict(self.params),
            "enabled": self.enabled,
        }

    @staticmethod
    def from_dict(d: dict) -> Effect:
        return Effect(
            id=d["id"], type=EffectType(d["type"]),
            name=d.get("name", ""), params=d.get("params", {}),
            enabled=d.get("enabled", True),
        )


@dataclass
class Clip:
    """A single clip on a track"""
    id: str
    asset_path: str              # Source file path
    name: str = "Untitled Clip"
    track_id: str = ""

    # Timeline position
    start: float = 0.0           # In-point on timeline (seconds)
    duration: float = 10.0       # Duration on timeline

    # Source range
    source_start: float = 0.0    # In-point in source file
    source_duration: float = 0.0  # Duration from source (0 = use full)

    clip_type: ClipType = ClipType.VIDEO
    speed: float = 1.0
    volume: float = 1.0
    effects: List[Effect] = field(default_factory=list)

    @property
    def end(self) -> float:
        return self.start + self.duration

    def to_dict(self) -> dict:
        return {
            "id": self.id, "asset_path": self.asset_path,
            "name": self.name, "track_id": self.track_id,
            "start": self.start, "duration": self.duration,
            "source_start": self.source_start,
            "source_duration": self.source_duration,
            "clip_type": self.clip_type.value,
            "speed": self.speed, "volume": self.volume,
            "effects": [e.to_dict() for e in self.effects],
        }

    @staticmethod
    def from_dict(d: dict) -> Clip:
        return Clip(
            id=d["id"], asset_path=d["asset_path"],
            name=d.get("name", "Untitled Clip"),
            track_id=d.get("track_id", ""),
            start=d.get("start", 0.0), duration=d.get("duration", 10.0),
            source_start=d.get("source_start", 0.0),
            source_duration=d.get("source_duration", 0.0),
            clip_type=ClipType(d.get("clip_type", "video")),
            speed=d.get("speed", 1.0), volume=d.get("volume", 1.0),
            effects=[Effect.from_dict(e) for e in d.get("effects", [])],
        )


@dataclass
class Track:
    """A single track (video or audio)"""
    id: str
    type: str = "video"          # "video" or "audio"
    name: str = ""
    index: int = 0
    clips: List[Clip] = field(default_factory=list)
    muted: bool = False
    locked: bool = False
    solo: bool = False

    @property
    def duration(self) -> float:
        if not self.clips:
            return 0.0
        return max(c.end for c in self.clips)

    def add_clip(self, clip: Clip):
        clip.track_id = self.id
        self.clips.append(clip)
        self.clips.sort(key=lambda c: c.start)

    def to_dict(self) -> dict:
        return {
            "id": self.id, "type": self.type, "name": self.name,
            "index": self.index,
            "clips": [c.to_dict() for c in self.clips],
            "muted": self.muted, "locked": self.locked, "solo": self.solo,
        }

    @staticmethod
    def from_dict(d: dict) -> Track:
        return Track(
            id=d["id"], type=d.get("type", "video"),
            name=d.get("name", ""), index=d.get("index", 0),
            clips=[Clip.from_dict(c) for c in d.get("clips", [])],
            muted=d.get("muted", False), locked=d.get("locked", False),
            solo=d.get("solo", False),
        )


@dataclass
class Timeline:
    """Complete timeline — the core editing document"""
    id: str = ""
    name: str = "Untitled Project"
    fps: float = 24.0
    width: int = 1920
    height: int = 1080
    audio_sample_rate: int = 48000
    tracks: List[Track] = field(default_factory=list)

    @property
    def duration(self) -> float:
        if not self.tracks:
            return 0.0
        return max(t.duration for t in self.tracks)

    @property
    def video_tracks(self) -> List[Track]:
        return [t for t in self.tracks if t.type == "video"]

    @property
    def audio_tracks(self) -> List[Track]:
        return [t for t in self.tracks if t.type == "audio"]

    def add_track(self, track: Track):
        self.tracks.append(track)
        self.tracks.sort(key=lambda t: t.index)

    def get_track(self, track_id: str) -> Optional[Track]:
        for t in self.tracks:
            if t.id == track_id:
                return t
        return None

    def to_dict(self) -> dict:
        return {
            "id": self.id, "name": self.name,
            "fps": self.fps, "width": self.width, "height": self.height,
            "audio_sample_rate": self.audio_sample_rate,
            "duration": self.duration,
            "tracks": [t.to_dict() for t in self.tracks],
        }

    @staticmethod
    def from_dict(d: dict) -> Timeline:
        return Timeline(
            id=d.get("id", ""), name=d.get("name", "Untitled Project"),
            fps=d.get("fps", 24.0), width=d.get("width", 1920),
            height=d.get("height", 1080),
            audio_sample_rate=d.get("audio_sample_rate", 48000),
            tracks=[Track.from_dict(t) for t in d.get("tracks", [])],
        )
