"""TimelineEngine — Timeline management and rendering

Responsibilities:
- Create/manage Timeline instances
- Serialize/deserialize .phantomvox project files
- Build FFmpeg commands via FilterGraphBuilder
- Register with Engine for API access
"""

from __future__ import annotations
import json
import os
import uuid
from typing import Any, Dict, List, Optional

from .models import Timeline, Track, Clip, Effect, EffectType, ClipType
from .filter_graph import FilterGraphBuilder


class ProjectSerializer:
    """Serialize/deserialize .phantomvox project files"""

    @staticmethod
    def save(timeline: Timeline, path: str):
        data = {
            "version": "1.0",
            "type": "phantomvox-project",
            "timeline": timeline.to_dict(),
        }
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    @staticmethod
    def load(path: str) -> Timeline:
        with open(path) as f:
            data = json.load(f)
        tl_data = data.get("timeline", data)
        return Timeline.from_dict(tl_data)


class TimelineEngine:
    """Timeline engine — manages timeline state, project files, rendering"""

    def __init__(self):
        self._timelines: Dict[str, Timeline] = {}

    # ── Timeline management ──────────────────────────────

    def create(self, name: str = "Untitled Project",
               fps: float = 24.0, width: int = 1920, height: int = 1080) -> Timeline:
        tl_id = str(uuid.uuid4())[:8]
        tl = Timeline(id=tl_id, name=name, fps=fps, width=width, height=height)
        # Default: one video track and one audio track
        tl.add_track(Track(id=f"{tl_id}_v1", type="video", name="Video 1", index=0))
        tl.add_track(Track(id=f"{tl_id}_a1", type="audio", name="Audio 1", index=1))
        self._timelines[tl_id] = tl
        return tl

    def get(self, tl_id: str) -> Optional[Timeline]:
        return self._timelines.get(tl_id)

    def list_timelines(self) -> List[dict]:
        return [{"id": k, "name": v.name, "duration": v.duration,
                 "tracks": len(v.tracks), "clips": sum(len(t.clips) for t in v.tracks)}
                for k, v in self._timelines.items()]

    def remove(self, tl_id: str) -> bool:
        return self._timelines.pop(tl_id, None) is not None

    # ── Track operations ────────────────────────────────

    def add_track(self, tl_id: str, track_type: str = "video",
                  name: str = "") -> Optional[Track]:
        tl = self._timelines.get(tl_id)
        if not tl:
            return None
        idx = max((t.index for t in tl.tracks), default=-1) + 1
        track = Track(
            id=f"{tl_id}_{track_type}_{idx}",
            type=track_type, name=name or f"{track_type.title()} {idx+1}",
            index=idx,
        )
        tl.add_track(track)
        return track

    def remove_track(self, tl_id: str, track_id: str) -> bool:
        tl = self._timelines.get(tl_id)
        if not tl:
            return False
        tl.tracks = [t for t in tl.tracks if t.id != track_id]
        return True

    # ── Clip operations ─────────────────────────────────

    def add_clip(self, tl_id: str, track_id: str, asset_path: str,
                 start: float = 0.0, duration: float = 10.0,
                 name: str = "", clip_type: str = "video") -> Optional[Clip]:
        tl = self._timelines.get(tl_id)
        if not tl:
            return None
        track = tl.get_track(track_id)
        if not track:
            return None
        clip = Clip(
            id=str(uuid.uuid4())[:8],
            asset_path=asset_path, name=name or os.path.basename(asset_path),
            track_id=track_id, start=start, duration=duration,
            clip_type=ClipType(clip_type),
        )
        track.add_clip(clip)
        return clip

    def update_clip(self, tl_id: str, clip_id: str,
                    updates: Dict[str, Any]) -> bool:
        tl = self._timelines.get(tl_id)
        if not tl:
            return False
        for track in tl.tracks:
            for clip in track.clips:
                if clip.id == clip_id:
                    for k, v in updates.items():
                        if hasattr(clip, k):
                            setattr(clip, k, v)
                    return True
        return False

    def remove_clip(self, tl_id: str, clip_id: str) -> bool:
        tl = self._timelines.get(tl_id)
        if not tl:
            return False
        for track in tl.tracks:
            track.clips = [c for c in track.clips if c.id != clip_id]
        return True

    # ── Effect operations ────────────────────────────────

    def add_effect(self, tl_id: str, clip_id: str, effect_type: str,
                   name: str = "", params: Optional[Dict[str, Any]] = None) -> Optional[Effect]:
        tl = self._timelines.get(tl_id)
        if not tl:
            return None
        for track in tl.tracks:
            for clip in track.clips:
                if clip.id == clip_id:
                    effect = Effect(
                        id=str(uuid.uuid4())[:8],
                        type=EffectType(effect_type),
                        name=name, params=params or {},
                    )
                    clip.effects.append(effect)
                    return effect
        return None

    def remove_effect(self, tl_id: str, effect_id: str) -> bool:
        tl = self._timelines.get(tl_id)
        if not tl:
            return False
        for track in tl.tracks:
            for clip in track.clips:
                clip.effects = [e for e in clip.effects if e.id != effect_id]
        return True

    # ── Project file operations ─────────────────────────

    def save_project(self, tl_id: str, path: str) -> bool:
        tl = self._timelines.get(tl_id)
        if not tl:
            return False
        ProjectSerializer.save(tl, path)
        return True

    def load_project(self, path: str) -> Optional[Timeline]:
        tl = ProjectSerializer.load(path)
        self._timelines[tl.id] = tl
        return tl

    # ── Rendering ─────────────────────────────────────────

    def build_render_command(self, tl_id: str, output_path: str = "output.mp4",
                             preset: str = "medium") -> List[str]:
        tl = self._timelines.get(tl_id)
        if not tl:
            return []
        builder = FilterGraphBuilder(tl)
        return builder.build(output_path, preset)

    def to_info(self) -> dict:
        return {
            "timelines": self.list_timelines(),
            "count": len(self._timelines),
        }
