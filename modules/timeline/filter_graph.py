"""FFmpeg filter graph builder — Converts Timeline state to FFmpeg commands

Uses the FFmpeg mapping table from docs/detailed-architecture.md section 9.2.
"""

from __future__ import annotations
from typing import Dict, List, Optional, Tuple

from .models import Timeline, Track, Clip, Effect, EffectType, ClipType


class FilterGraphBuilder:
    """Build FFmpeg filter_complex strings from Timeline state"""

    def __init__(self, timeline: Timeline):
        self.timeline = timeline

    # ── Per-effect FFmpeg mapping ─────────────────────────

    @staticmethod
    def _effect_to_filter(effect: Effect) -> str:
        """Map a single Effect to its FFmpeg filter string"""
        params = effect.params
        etype = effect.type

        if etype == EffectType.TRANSFORM:
            zoom = params.get("zoom_x", 1.0)
            rot = params.get("rotation", 0)
            flip_h = params.get("flip_h", False)
            flip_v = params.get("flip_v", False)
            parts = []
            if zoom != 1.0:
                parts.append(f"zoompan=z={zoom}:d=1")
            if rot != 0:
                parts.append(f"rotate={rot}*PI/180")
            if flip_h:
                parts.append("hflip")
            if flip_v:
                parts.append("vflip")
            return ",".join(parts) if parts else "null"

        elif etype == EffectType.SPEED:
            speed = params.get("speed", 1.0)
            if speed != 1.0:
                return f"setpts={1.0/speed}*PTS"
            return "null"

        elif etype == EffectType.CROP:
            w = params.get("width", 0)
            h = params.get("height", 0)
            x = params.get("x", 0)
            y = params.get("y", 0)
            if w and h:
                return f"crop={w}:{h}:{x}:{y}"
            return "null"

        elif etype == EffectType.COLOR:
            # color balance / brightness / contrast / saturation
            parts = []
            brightness = params.get("brightness")
            contrast = params.get("contrast")
            saturation = params.get("saturation")
            if brightness is not None or contrast is not None or saturation is not None:
                b = brightness if brightness is not None else 0
                c = contrast if contrast is not None else 1.0
                s = saturation if saturation is not None else 1.0
                parts.append(f"eq=brightness={b}:contrast={c}:saturation={s}")
            # Color balance (shadows/midtones/highlights)
            cb = params.get("color_balance", {})
            if cb:
                parts.append(
                    f"colorbalance=rs={cb.get('shadows_r', 0)}:"
                    f"gs={cb.get('shadows_g', 0)}:bs={cb.get('shadows_b', 0)}:"
                    f"rm={cb.get('midtones_r', 0)}:gm={cb.get('midtones_g', 0)}:"
                    f"bm={cb.get('midtones_b', 0)}:"
                    f"rh={cb.get('highlights_r', 0)}:gh={cb.get('highlights_g', 0)}:"
                    f"bh={cb.get('highlights_b', 0)}"
                )
            # LUT
            lut = params.get("lut")
            if lut:
                parts.append(f"lut3d={lut}")
            return ",".join(parts) if parts else "null"

        elif etype == EffectType.TRANSITION:
            trans_type = params.get("type", "fade")
            duration = params.get("duration", 0.5)
            offset = params.get("offset", 1.0)
            return f"xfade=transition={trans_type}:duration={duration}:offset={offset}"

        elif etype == EffectType.FILTER:
            return params.get("filter_string", "null")

        elif etype == EffectType.STABILIZE:
            return "vidstabtransform"  # requires vidstabdetect pass first

        elif etype == EffectType.LENS_CORRECTION:
            cx = params.get("cx", 0.5)
            cy = params.get("cy", 0.5)
            k1 = params.get("k1", 0.0)
            k2 = params.get("k2", 0.0)
            return f"lenscorrection=cx={cx}:cy={cy}:k1={k1}:k2={k2}"

        elif etype == EffectType.AUDIO_FX:
            parts = []
            vol = params.get("volume")
            if vol is not None:
                parts.append(f"volume={vol}")
            eq = params.get("equalizer")
            if eq:
                parts.append(f"equalizer=f={eq.get('freq', 1000)}:t=q:w={eq.get('width', 1)}:g={eq.get('gain', 0)}")
            return ",".join(parts) if parts else "null"

        return "null"

    # ── Clip filter chain ────────────────────────────────

    @staticmethod
    def _build_clip_filter(asset_index: int, clip: Clip) -> Tuple[str, str]:
        """Build filter for a single clip.
        Returns (video_label, audio_label) e.g. ('[0:v]trim=...', '[0:a]atrim=...')
        """
        input_label_v = f"[{asset_index}:v]"
        input_label_a = f"[{asset_index}:a]"

        # Video chain
        video_filters = []
        if clip.source_start > 0 or clip.source_duration > 0:
            src_dur = clip.source_duration if clip.source_duration > 0 else ""
            video_filters.append(f"trim=start={clip.source_start}:duration={src_dur}")
        if clip.speed != 1.0:
            video_filters.append(f"setpts={1.0/clip.speed}*PTS")

        # Apply enabled effects (video)
        for effect in clip.effects:
            if not effect.enabled:
                continue
            f = FilterGraphBuilder._effect_to_filter(effect)
            if f and f != "null":
                video_filters.append(f)

        video_out = f"[v{clip.id}]"
        if video_filters:
            v_filter_str = ",".join(video_filters)
            v_result = f"{input_label_v}{v_filter_str}{video_out}"
        else:
            v_result = f"{input_label_v}null{video_out}"

        # Audio chain
        audio_filters = []
        if clip.source_start > 0 or clip.source_duration > 0:
            src_dur = clip.source_duration if clip.source_duration > 0 else ""
            audio_filters.append(f"atrim=start={clip.source_start}:duration={src_dur}")
        if clip.speed != 1.0:
            audio_filters.append(f"atempo={clip.speed}")
        if clip.volume != 1.0:
            audio_filters.append(f"volume={clip.volume}")

        audio_out = f"[a{clip.id}]"
        if audio_filters:
            a_filter_str = ",".join(audio_filters)
            a_result = f"{input_label_a}{a_filter_str}{audio_out}"
        else:
            a_result = f"{input_label_a}null{audio_out}"

        return v_result, a_result

    # ── Full timeline render command ─────────────────────

    def build(self, output_path: str = "output.mp4",
              preset: str = "medium") -> List[str]:
        """Build the complete FFmpeg command for rendering the timeline.
        Returns a list of command arguments (suitable for subprocess.run).
        """
        timeline = self.timeline
        clips: List[Clip] = []
        for track in timeline.tracks:
            clips.extend(track.clips)

        if not clips:
            return []

        # Collect unique asset paths
        asset_paths: List[str] = []
        path_map: Dict[str, int] = {}  # path → index
        for clip in clips:
            if clip.asset_path and clip.asset_path not in path_map:
                path_map[clip.asset_path] = len(asset_paths)
                asset_paths.append(clip.asset_path)

        # Build command
        cmd = ["ffmpeg"]

        # Input files
        for path in asset_paths:
            cmd.extend(["-i", path])

        # Filter complex
        filter_parts = []
        v_outputs = []
        a_outputs = []

        for clip in clips:
            if clip.asset_path not in path_map:
                continue
            idx = path_map[clip.asset_path]
            v_filter, a_filter = self._build_clip_filter(idx, clip)
            filter_parts.append(v_filter)
            filter_parts.append(a_filter)
            v_outputs.append(f"[v{clip.id}]")
            a_outputs.append(f"[a{clip.id}]")

        # Mix video tracks (overlay from bottom up)
        if len(v_outputs) > 1:
            # Concat or overlay depending on arrangement
            # For simplicity: overlay all video clips
            overlay_inputs = v_outputs
            base = overlay_inputs[0]
            for i, ov in enumerate(overlay_inputs[1:], 1):
                overlay_label = f"[v_mix_{i}]"
                filter_parts.append(f"{base}{ov}overlay{overlay_label}")
                base = overlay_label
            v_final = base
        elif v_outputs:
            v_final = v_outputs[0]
        else:
            v_final = ""

        # Mix audio tracks
        if len(a_outputs) > 1:
            mix_input = "".join(a_outputs)
            filter_parts.append(f"{mix_input}amix=inputs={len(a_outputs)}:duration=first[a_mix]")
            a_final = "[a_mix]"
        elif a_outputs:
            a_final = a_outputs[0]
        else:
            a_final = ""

        if filter_parts:
            filter_str = ";".join(filter_parts)
            cmd.extend(["-filter_complex", filter_str])

        # Map outputs
        if v_final:
            cmd.extend(["-map", v_final])
        if a_final:
            cmd.extend(["-map", a_final])

        # Encoding preset
        cmd.extend(["-preset", preset, "-y", output_path])
        return cmd

    def build_preview(self, time_sec: float = 0.0) -> List[str]:
        """Build a quick preview command for a single frame at given time"""
        timeline = self.timeline
        # Find clip at time
        target_clip = None
        for track in timeline.tracks:
            for clip in track.clips:
                if clip.start <= time_sec < clip.end:
                    target_clip = clip
                    break
            if target_clip:
                break

        if not target_clip:
            return []

        ts = time_sec - target_clip.start + target_clip.source_start
        cmd = [
            "ffmpeg", "-ss", str(ts),
            "-i", target_clip.asset_path,
            "-vframes", "1",
            "-f", "image2pipe",
            "-vcodec", "png",
            "-",
        ]
        return cmd

    def to_info(self) -> dict:
        return {
            "timeline": self.timeline.to_dict(),
            "clip_count": sum(len(t.clips) for t in self.timeline.tracks),
            "track_count": len(self.timeline.tracks),
            "duration_sec": self.timeline.duration,
        }
