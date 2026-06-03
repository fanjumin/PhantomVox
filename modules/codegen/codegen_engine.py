"""CodeGenEngine — NL to FFmpeg filter graph using template matching

Design:
- EffectTemplate catalog: maps keywords/regex to FFmpeg filter strings
- CodeGenEngine.match(): brute-force keyword matching over templates
- CodeGenEngine.generate(): returns filter string + parameter suggestions
- Tightly coupled with timeline EffectType enum for direct injection

This is a no-dependency engine (no LLM, no API). It uses regex+templates
to cover the most common use cases. Replace with an LLM-powered engine
for unlimited coverage.
"""

from __future__ import annotations
import re
import json
from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass
class EffectTemplate:
    """A single code generation template"""
    name: str
    category: str  # transition / color / transform / audio / special / text / composite
    keywords: List[str]  # Matching keywords in the natural language query
    description: str
    filter_template: str  # FFmpeg filter string with {param} placeholders
    params: Dict[str, object] = field(default_factory=dict)  # Default parameter values
    param_descriptions: Dict[str, str] = field(default_factory=dict)


# ── Template catalog ──────────────────────────────────────

TRANSITION_TEMPLATES = [
    EffectTemplate(
        name="Crossfade", category="transition",
        keywords=["crossfade", "cross fade", "dissolve", "smooth transition"],
        description="Standard crossfade / dissolve transition",
        filter_template="xfade=transition=fade:duration={duration}:offset={offset}",
        params={"duration": 0.5, "offset": 1.0},
        param_descriptions={"duration": "Transition length in seconds", "offset": "Overlap offset in seconds"},
    ),
    EffectTemplate(
        name="Fade to Black", category="transition",
        keywords=["fade to black", "fadeout", "fade out"],
        description="Fade out to black",
        filter_template="fade=type=out:duration={duration}:start_time={start}",
        params={"duration": 1.0, "start": 0.0},
        param_descriptions={"duration": "Fade duration in seconds"},
    ),
    EffectTemplate(
        name="Fade from Black", category="transition",
        keywords=["fade from black", "fadein", "fade in"],
        description="Fade in from black",
        filter_template="fade=type=in:duration={duration}",
        params={"duration": 1.0},
        param_descriptions={"duration": "Fade duration in seconds"},
    ),
    EffectTemplate(
        name="Slide Left", category="transition",
        keywords=["slide left", "push left"],
        description="Slide transition from right to left",
        filter_template="xfade=transition=slideright:duration={duration}:offset={offset}",
        params={"duration": 0.5, "offset": 1.0},
        param_descriptions={"duration": "Transition length in seconds"},
    ),
    EffectTemplate(
        name="Slide Right", category="transition",
        keywords=["slide right", "push right"],
        description="Slide transition from left to right",
        filter_template="xfade=transition=slideleft:duration={duration}:offset={offset}",
        params={"duration": 0.5, "offset": 1.0},
        param_descriptions={"duration": "Transition length in seconds"},
    ),
    EffectTemplate(
        name="Wipe", category="transition",
        keywords=["wipe", "wipe transition"],
        description="Wipe transition (directional)",
        filter_template="xfade=transition=wipedown:duration={duration}:offset={offset}",
        params={"duration": 0.5, "offset": 1.0},
        param_descriptions={"duration": "Transition length in seconds"},
    ),
    EffectTemplate(
        name="Zoom Transition", category="transition",
        keywords=["zoom transition", "zoom in transition"],
        description="Zoom in transition effect",
        filter_template="xfade=transition=zoom_in:duration={duration}:offset={offset}",
        params={"duration": 0.5, "offset": 1.0},
        param_descriptions={"duration": "Transition length in seconds"},
    ),
]

COLOR_TEMPLATES = [
    EffectTemplate(
        name="Sepia Tone", category="color",
        keywords=["sepia", "old photo", "vintage photo", "brown"],
        description="Sepia tone color grade",
        filter_template="colorchannelmixer=.3:.4:.3:0:.3:.4:.3:0:.3:.4:.3",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Grayscale", category="color",
        keywords=["grayscale", "black and white", "b&w", "bw", "monochrome", "noir"],
        description="Black and white / grayscale",
        filter_template="hue=s=0",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Warm Tone", category="color",
        keywords=["warm", "warm tone", "sunset", "golden"],
        description="Warm color temperature (+orange/yellow)",
        filter_template="colorbalance=rh=0.2:gh=0.1:bh=-0.2:rm=0.1:gm=0.05:bm=-0.1",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Cool Tone", category="color",
        keywords=["cool", "cool tone", "cold", "blue", "icy"],
        description="Cool color temperature (+blue)",
        filter_template="colorbalance=rh=-0.1:gh=-0.05:bh=0.2:rm=-0.05:gm=0:bm=0.15",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Vintage", category="color",
        keywords=["vintage", "retro", "old film", "classic film"],
        description="Vintage film look (faded + warm)",
        filter_template="curves=vintage,colorbalance=rh=0.15:gh=0.05:bh=-0.15",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Dramatic", category="color",
        keywords=["dramatic", "cinematic", "film look", "movie look", "teal"],
        description="Cinematic teal/orange look (high contrast, teal shadows, warm highlights)",
        filter_template="eq=contrast=1.3:saturation=1.1:brightness=-0.05,colorbalance=rs=-0.15:gs=0:bs=0.2:rh=0.15:gh=0:bh=-0.1",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Brightness", category="color",
        keywords=["brightness", "brighter", "darker", "brighten"],
        description="Adjust brightness level",
        filter_template="eq=brightness={value}",
        params={"value": 0.1},
        param_descriptions={"value": "Brightness adjustment (-1.0 to 1.0)"},
    ),
    EffectTemplate(
        name="Contrast", category="color",
        keywords=["contrast", "more contrast", "less contrast"],
        description="Adjust contrast level",
        filter_template="eq=contrast={value}",
        params={"value": 1.2},
        param_descriptions={"value": "Contrast multiplier (0.0 to 3.0)"},
    ),
    EffectTemplate(
        name="Saturation", category="color",
        keywords=["saturation", "vibrant", "colorful", "desaturate"],
        description="Adjust saturation level",
        filter_template="eq=saturation={value}",
        params={"value": 1.5},
        param_descriptions={"value": "Saturation multiplier (0.0 = B&W, 1.0 = normal)"},
    ),
]

TRANSFORM_TEMPLATES = [
    EffectTemplate(
        name="Zoom In", category="transform",
        keywords=["zoom in", "close up", "magnify", "enlarge"],
        description="Digital zoom in effect",
        filter_template="zoompan=z={zoom}:d=1:s={width}x{height}",
        params={"zoom": 1.5, "width": 1920, "height": 1080},
        param_descriptions={"zoom": "Zoom factor (1.0 = 100%)"},
    ),
    EffectTemplate(
        name="Zoom Out", category="transform",
        keywords=["zoom out", "wide shot", "pull back"],
        description="Digital zoom out effect",
        filter_template="zoompan=z={zoom}:d=1:s={width}x{height}",
        params={"zoom": 0.7, "width": 1920, "height": 1080},
        param_descriptions={"zoom": "Zoom factor (<1.0 = zoom out)"},
    ),
    EffectTemplate(
        name="Rotate", category="transform",
        keywords=["rotate", "rotation", "spin", "turn"],
        description="Rotate video by degrees",
        filter_template="rotate={angle}*PI/180:fill={fill}",
        params={"angle": 90, "fill": "black"},
        param_descriptions={"angle": "Rotation angle in degrees", "fill": "Background fill color"},
    ),
    EffectTemplate(
        name="Flip Horizontal", category="transform",
        keywords=["flip horizontal", "mirror", "flip x", "hflip"],
        description="Mirror horizontally",
        filter_template="hflip",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Flip Vertical", category="transform",
        keywords=["flip vertical", "flip y", "vflip", "upside down"],
        description="Mirror vertically",
        filter_template="vflip",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Crop", category="transform",
        keywords=["crop", "cut out", "trim edges"],
        description="Crop video to specified dimensions",
        filter_template="crop={width}:{height}:{x}:{y}",
        params={"width": 1280, "height": 720, "x": 0, "y": 0},
        param_descriptions={"width": "Output width", "height": "Output height", "x": "Crop offset X", "y": "Crop offset Y"},
    ),
]

SPEED_TEMPLATES = [
    EffectTemplate(
        name="Speed Up", category="speed",
        keywords=["speed up", "fast forward", "accelerate", "time lapse", "timelapse", "hyperlapse"],
        description="Increase playback speed",
        filter_template="setpts={factor}*PTS",
        params={"factor": 0.5},
        param_descriptions={"factor": "Time scaling factor. <1.0 = faster (0.5 = 2x speed)"},
    ),
    EffectTemplate(
        name="Slow Motion", category="speed",
        keywords=["slow motion", "slow down", "decelerate", "slo mo", "slo-mo"],
        description="Decrease playback speed (slow motion)",
        filter_template="setpts={factor}*PTS,minterpolate=fps=60:mi_mode=mci",
        params={"factor": 2.0},
        param_descriptions={"factor": "Time scaling factor. >1.0 = slower (2.0 = 0.5x speed). Uses motion interpolation."},
    ),
    EffectTemplate(
        name="Reverse", category="speed",
        keywords=["reverse", "rewind", "play backwards", "time reverse"],
        description="Play video in reverse",
        filter_template="reverse",
        params={},
        param_descriptions={},
    ),
]

AUDIO_TEMPLATES = [
    EffectTemplate(
        name="Volume Up", category="audio",
        keywords=["volume up", "louder", "increase volume", "amplify"],
        description="Increase audio volume",
        filter_template="volume={value}",
        params={"value": 1.5},
        param_descriptions={"value": "Volume multiplier (1.0 = normal, 2.0 = 2x loudness)"},
    ),
    EffectTemplate(
        name="Volume Down", category="audio",
        keywords=["volume down", "quieter", "decrease volume", "lower volume", "mute", "silence"],
        description="Decrease audio volume or mute",
        filter_template="volume={value}",
        params={"value": 0.3},
        param_descriptions={"value": "Volume multiplier (0.0 = mute, 0.5 = half)"},
    ),
    EffectTemplate(
        name="Echo", category="audio",
        keywords=["echo", "reverberation", "reverb", "delay"],
        description="Add echo/reverb effect",
        filter_template="aecho={in_gain}:{out_gain}:{delay}:{decay}",
        params={"in_gain": 0.8, "out_gain": 0.9, "delay": 500, "decay": 0.4},
        param_descriptions={"delay": "Echo delay in milliseconds", "decay": "Echo decay factor (0.0-1.0)"},
    ),
    EffectTemplate(
        name="Pitch Shift", category="audio",
        keywords=["pitch", "pitch shift", "higher pitch", "lower pitch", "chipmunk", "deep voice"],
        description="Shift audio pitch up or down",
        filter_template="asetrate={sample_rate}*{ratio},aresample={sample_rate}",
        params={"ratio": 1.2, "sample_rate": 44100},
        param_descriptions={"ratio": "Pitch ratio (>1.0 = higher, <1.0 = lower)"},
    ),
    EffectTemplate(
        name="Bass Boost", category="audio",
        keywords=["bass", "bass boost", "low end", "subwoofer", "deep bass"],
        description="Boost low frequencies",
        filter_template="equalizer=f=60:t=q:w=1:g={gain}",
        params={"gain": 6},
        param_descriptions={"gain": "Bass boost in dB (0-20)"},
    ),
    EffectTemplate(
        name="Noise Reduction", category="audio",
        keywords=["noise reduction", "denoise", "remove noise", "clean audio", "hiss"],
        description="Reduce background noise",
        filter_template="anlmdn=s={strength}:p={patch}",
        params={"strength": 1.0, "patch": 3.0},
        param_descriptions={"strength": "Noise reduction strength", "patch": "Patch size"},
    ),
]

SPECIAL_TEMPLATES = [
    EffectTemplate(
        name="Glitch Effect", category="special",
        keywords=["glitch", "glitch effect", "digital distortion", "error", "corrupt"],
        description="Digital glitch/distortion effect",
        filter_template="crop=iw:{slice_h}:0:{offset}[g];[0:v][g]overlay={x}:{y}",
        params={"slice_h": 10, "offset": 150, "x": 5, "y": 100},
        param_descriptions={"slice_h": "Glitch slice height in pixels"},
    ),
    EffectTemplate(
        name="VHS Effect", category="special",
        keywords=["vhs", "vhs effect", "retro video", "tape", "analog"],
        description="Retro VHS tape aesthetic",
        filter_template="curves=vintage,hue=s=0.8,noise=alls=10:allf=t+u,colorbalance=rs=0.1:gs=-0.05:bs=0.05",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Film Grain", category="special",
        keywords=["film grain", "grain", "noise", "film texture"],
        description="Add film grain / noise texture",
        filter_template="noise=alls={strength}:allf=t+u",
        params={"strength": 10},
        param_descriptions={"strength": "Grain intensity (1-100)"},
    ),
    EffectTemplate(
        name="Blur", category="special",
        keywords=["blur", "gaussian blur", "soften", "defocus", "out of focus"],
        description="Apply gaussian blur",
        filter_template="gblur=sigma={sigma}",
        params={"sigma": 3.0},
        param_descriptions={"sigma": "Blur strength (higher = more blur)"},
    ),
    EffectTemplate(
        name="Pixelate", category="special",
        keywords=["pixelate", "pixel", "mosaic", "censor", "blur face"],
        description="Pixelation / mosaic effect",
        filter_template="pixelize=width={w}:height={h}:x={x}:y={y}",
        params={"w": 50, "h": 50, "x": 0, "y": 0},
        param_descriptions={"w": "Pixel block width", "h": "Pixel block height"},
    ),
    EffectTemplate(
        name="Edge Detection", category="special",
        keywords=["edge detection", "edges", "outline", "sketch", "line art"],
        description="Edge detection / outline effect",
        filter_template="edgedetect=mode=colormix:high={threshold}",
        params={"threshold": 0.2},
        param_descriptions={"threshold": "Edge detection threshold (0.0-1.0)"},
    ),
    EffectTemplate(
        name="Stabilize", category="special",
        keywords=["stabilize", "steady", "smooth footage", "anti-shake", "deshake"],
        description="Video stabilization",
        filter_template="vidstabtransform=smoothing={smooth}:optzoom=0",
        params={"smooth": 30},
        param_descriptions={"smooth": "Stabilization smoothing factor (higher = smoother)"},
    ),
]

COMPOSITE_TEMPLATES = [
    EffectTemplate(
        name="Picture-in-Picture", category="composite",
        keywords=["picture in picture", "pip", "overlay", "inset"],
        description="Picture-in-picture overlay",
        filter_template="[1:v]scale={w}:{h}[pip];[0:v][pip]overlay={x}:{y}",
        params={"w": 320, "h": 240, "x": 20, "y": 20},
        param_descriptions={"w": "PIP width", "h": "PIP height", "x": "X position", "y": "Y position"},
    ),
    EffectTemplate(
        name="Split Screen", category="composite",
        keywords=["split screen", "side by side", "dual screen", "comparison"],
        description="Side-by-side split screen",
        filter_template="[0:v]scale=iw/2:ih[left];[1:v]scale=iw/2:ih[right];[left][right]hstack",
        params={},
        param_descriptions={},
    ),
    EffectTemplate(
        name="Green Screen", category="composite",
        keywords=["green screen", "chroma key", "chromakey", "background removal"],
        description="Chroma key / green screen removal",
        filter_template="chromakey={color}:similarity={sim}:blend={blend}",
        params={"color": "0x00FF00", "sim": 0.1, "blend": 0.1},
        param_descriptions={"color": "Key color in hex", "sim": "Color similarity threshold"},
    ),
    EffectTemplate(
        name="Text Overlay", category="composite",
        keywords=["text", "title", "caption", "subtitle", "overlay text", "watermark"],
        description="Text overlay on video",
        filter_template="drawtext=text='{text}':fontcolor={color}:fontsize={size}:x={x}:y={y}",
        params={"text": "Sample Text", "color": "white", "size": 24, "x": 10, "y": 10},
        param_descriptions={"text": "Text to display", "color": "Font color", "size": "Font size"},
    ),
    EffectTemplate(
        name="Ken Burns", category="composite",
        keywords=["ken burns", "pan and zoom", "slow zoom", "photo animation"],
        description="Ken Burns pan-and-zoom effect for still images",
        filter_template="zoompan=z={zoom}:d={duration}:fps=24:s={width}x{height}",
        params={"zoom": 1.3, "duration": 60, "width": 1920, "height": 1080},
        param_descriptions={"zoom": "End zoom level", "duration": "Effect duration in frames"},
    ),
]

# Combine all templates
ALL_TEMPLATES = (
    TRANSITION_TEMPLATES + COLOR_TEMPLATES + TRANSFORM_TEMPLATES +
    SPEED_TEMPLATES + AUDIO_TEMPLATES + SPECIAL_TEMPLATES +
    COMPOSITE_TEMPLATES
)

CATEGORY_MAP: Dict[str, List[EffectTemplate]] = {
    "transition": TRANSITION_TEMPLATES,
    "color": COLOR_TEMPLATES,
    "transform": TRANSFORM_TEMPLATES,
    "speed": SPEED_TEMPLATES,
    "audio": AUDIO_TEMPLATES,
    "special": SPECIAL_TEMPLATES,
    "composite": COMPOSITE_TEMPLATES,
}


class CodeGenEngine:
    """NL to FFmpeg code generation engine"""

    def __init__(self):
        self.templates = ALL_TEMPLATES
        self.categories = CATEGORY_MAP

    def generate(self, query: str, category: Optional[str] = None,
                 params: Optional[Dict[str, object]] = None) -> Dict:
        """Generate FFmpeg filter code from natural language query

        Args:
            query: Natural language description (e.g. "add a fade transition")
            category: Optional category filter
            params: Optional parameter overrides

        Returns:
            Dict with name, category, filter_code, params, description
        """
        query_lower = query.lower().strip()
        candidates = self._match(query_lower, category)

        if not candidates:
            return {
                "status": "error",
                "message": f"No matching template for: {query}",
                "suggestions": [t.name for t in ALL_TEMPLATES[:10]],
            }

        best = candidates[0]
        filter_code = best.filter_template

        # Merge default params with user overrides
        merged_params = dict(best.params)
        if params:
            merged_params.update(params)

        # Apply params to template
        try:
            filter_code = filter_code.format(**merged_params)
        except KeyError as e:
            return {
                "status": "error",
                "message": f"Missing parameter: {e}",
                "template": best.filter_template,
                "expected_params": list(best.params.keys()),
                "provided_params": list(merged_params.keys()),
            }

        return {
            "status": "ok",
            "name": best.name,
            "category": best.category,
            "filter_code": filter_code,
            "description": best.description,
            "params": merged_params,
            "param_descriptions": best.param_descriptions,
        }

    def list_templates(self, category: Optional[str] = None) -> List[Dict]:
        """List available templates, optionally filtered by category"""
        templates = self.categories.get(category, ALL_TEMPLATES) if category else ALL_TEMPLATES
        return [
            {
                "name": t.name,
                "category": t.category,
                "description": t.description,
                "keywords": t.keywords[:5],
                "default_params": t.params,
            }
            for t in templates
        ]

    def list_categories(self) -> List[str]:
        return list(self.categories.keys())

    def _match(self, query: str, category: Optional[str] = None) -> List[EffectTemplate]:
        """Match query against templates by keyword scoring"""
        candidates = self.categories.get(category, ALL_TEMPLATES) if category else ALL_TEMPLATES
        scored = []

        for template in candidates:
            score = 0
            matched = []
            for kw in template.keywords:
                if kw in query:
                    score += 1
                    matched.append(kw)
            if score > 0:
                # Bonus for matching more keywords
                scored.append((score, len(matched), template))

        scored.sort(key=lambda x: (-x[0], -x[1]))
        return [t for _, _, t in scored]

    def to_info(self) -> dict:
        return {
            "total_templates": len(self.templates),
            "categories": list(self.categories.keys()),
            "templates_by_category": {k: len(v) for k, v in self.categories.items()},
        }
