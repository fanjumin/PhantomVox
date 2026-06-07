"""
hardware.py — PhantomVox AI Hardware Detection Module

Detects current machine hardware specifications and matches them against
model tiers (Tier 1~4) to help users understand which models can run
and what needs upgrading.

Detection items:
  - CPU cores / threads / model
  - Total / available RAM
  - GPU model / VRAM (nvidia-smi / AMD / Apple Silicon)
  - Available disk space
  - Operating system information

Model tiers:
  T1 — CPU-capable (>=8 cores, >=16GB RAM), no GPU required
  T2 — Entry GPU (>=6GB VRAM)
  T3 — Mid-range GPU (>=12GB VRAM)
  T4 — High-end GPU (>=24GB VRAM)
"""

import os
import sys
import json
import platform
import subprocess
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Dict, List, Optional, Tuple

# ── Model hardware tier definitions ──────────────────────────────────────

# Each model name -> (tier, type)
# tier: 1-4, type: "local" or "online"
MODEL_TIER_MAP: Dict[str, Tuple[int, str]] = {
    # ── TTS ──────────────────────────────────────────
    "edge_tts":       (1, "online"),   # Purely online, no hardware required
    "moss_tts":       (1, "local"),    # Lightweight, CPU-capable
    "bark":           (1, "local"),    # CPU-capable but slow, 16GB RAM
    "f5_tts":         (2, "local"),    # Requires GPU 6G+
    "gpt_sovits":     (2, "local"),    # Small model 6G, large model 12G
    "cosyvoice":      (2, "local"),    # 6G+
    "voicecraft":     (3, "local"),    # 12G+
    "amphion":        (2, "local"),    # 6G+

    # ── Music Gen ────────────────────────────────────
    "musicgen_small": (1, "local"),    # CPU barely capable
    "musicgen_medium":(2, "local"),    # 6G+
    "musicgen_large": (3, "local"),    # 12G+
    "audiocraft":     (2, "local"),    # 6G+
    "stable_audio":   (2, "local"),    # 6G+
    "riffusion":      (1, "local"),    # Lightweight, CPU-capable
    "suno":           (1, "online"),   # Online
    "udio":           (1, "online"),   # Online

    # ── Singing ──────────────────────────────────────
    "gpt_sovits_sing":(3, "local"),    # 12G+
}


# ── Tier thresholds ─────────────────────────────────────────────

TIER_THRESHOLDS = [
    # (tier_name, min_cores, min_ram_gb, min_vram_gb)
    ("tier_1",  4,  8,  0),    # Minimum runtime
    ("tier_1",  8, 16,  0),    # Recommended CPU
    ("tier_2",  8, 16,  6),    # Entry GPU
    ("tier_3",  8, 32, 12),    # Mid-range GPU
    ("tier_4", 16, 64, 24),    # High-end GPU
]

TIER_LABELS = ["", "T1 (CPU)", "T2 (Entry GPU)", "T3 (Mid GPU)", "T4 (High GPU)"]


# ── Data structures ────────────────────────────────────────────

@dataclass
class HardwareSpec:
    cpu_model: str = ""
    cpu_cores: int = 0
    cpu_threads: int = 0
    ram_total_gb: float = 0.0
    ram_available_gb: float = 0.0
    gpu_models: List[str] = field(default_factory=list)
    gpu_vram_gb: List[float] = field(default_factory=list)
    disk_free_gb: float = 0.0
    os_name: str = ""
    os_version: str = ""
    python_version: str = ""

    def to_dict(self) -> dict:
        return asdict(self)

    def max_tier(self) -> int:
        """Return the highest model tier (1-4) supported by this machine"""
        tier = 1
        for label, cores, ram, vram in TIER_THRESHOLDS:
            ok = True
            if self.cpu_cores < cores:
                ok = False
            if self.ram_total_gb < ram:
                ok = False
            if vram > 0:
                max_gpu_vram = max(self.gpu_vram_gb) if self.gpu_vram_gb else 0
                if max_gpu_vram < vram:
                    ok = False
            if ok:
                # find tier number from label
                t = int(label.split("_")[1])
                if t > tier:
                    tier = t
        return min(tier, 4)  # cap at 4

    def can_run_model(self, model_key: str) -> Tuple[bool, str]:
        """Check if a given model can run on this machine. Returns (can_run, explanation)"""
        info = MODEL_TIER_MAP.get(model_key)
        if info is None:
            return (False, f"Unknown model: {model_key}")
        required_tier, model_type = info
        if model_type == "online":
            return (True, "Online model, no local hardware required")
        current_tier = self.max_tier()
        if current_tier >= required_tier:
            return (True, f"Tier {current_tier} >= required T{required_tier}")
        else:
            # Hint what is missing
            needed = TIER_THRESHOLDS[required_tier]
            hints = []
            if self.cpu_cores < needed[1]:
                hints.append(f"CPU cores: {self.cpu_cores} < {needed[1]}")
            if self.ram_total_gb < needed[2]:
                hints.append(f"RAM: {self.ram_total_gb:.0f}GB < {needed[2]}GB")
            if needed[3] > 0:
                max_vram = max(self.gpu_vram_gb) if self.gpu_vram_gb else 0
                if max_vram < needed[3]:
                    hints.append(f"VRAM: {max_vram:.0f}GB < {needed[3]}GB")
            return (False, f"Needs T{required_tier}: " + "; ".join(hints))

    def upgrade_suggestions(self) -> List[str]:
        """Return upgrade suggestions to reach higher tiers"""
        current = self.max_tier()
        suggestions = []
        if current < 2:
            suggestions.append("Add NVIDIA GPU with 6GB+ VRAM (e.g. RTX 2060)")
        if current < 3:
            max_vram = max(self.gpu_vram_gb) if self.gpu_vram_gb else 0
            suggestions.append(f"Upgrade GPU to 12GB+ VRAM (e.g. RTX 3060/4060)")
            if self.ram_total_gb < 32:
                suggestions.append(f"Upgrade RAM to 32GB (current: {self.ram_total_gb:.0f}GB)")
        if current < 4:
            suggestions.append(f"Upgrade GPU to 24GB+ VRAM (e.g. RTX 4090)")
            if self.ram_total_gb < 64:
                suggestions.append(f"Upgrade RAM to 64GB (current: {self.ram_total_gb:.0f}GB)")
        return suggestions


# ── Detector ──────────────────────────────────────────────

class HardwareDetector:
    """Hardware detector — probes current machine configuration and matches model tiers"""

    def detect(self) -> HardwareSpec:
        """Execute full hardware detection"""
        spec = HardwareSpec()
        spec.python_version = sys.version
        self._detect_cpu(spec)
        self._detect_ram(spec)
        self._detect_gpu(spec)
        self._detect_disk(spec)
        self._detect_os(spec)
        return spec

    def report(self, spec: Optional[HardwareSpec] = None) -> dict:
        """Generate structured hardware report (includes tier assessment)"""
        if spec is None:
            spec = self.detect()
        tier = spec.max_tier()
        report = {
            "spec": spec.to_dict(),
            "max_tier": tier,
            "max_tier_label": TIER_LABELS[tier],
            "can_run_models": {},
            "upgrade_suggestions": [] if tier >= 4 else spec.upgrade_suggestions(),
        }
        for model_key in MODEL_TIER_MAP:
            ok, reason = spec.can_run_model(model_key)
            t, mtype = MODEL_TIER_MAP[model_key]
            report["can_run_models"][model_key] = {
                "can_run": ok,
                "reason": reason,
                "required_tier": t,
                "type": mtype,
            }
        return report

    # ── Individual checks ────────────────────────────

    def _detect_cpu(self, spec: HardwareSpec):
        try:
            import multiprocessing
            spec.cpu_cores = multiprocessing.cpu_count()
            # Linux /proc/cpuinfo
            if sys.platform == "linux":
                with open("/proc/cpuinfo") as f:
                    content = f.read()
                # count physical cores (cpu cores line)
                import re
                cores = re.findall(r"^cpu cores\s*:\s*(\d+)", content, re.MULTILINE)
                if cores:
                    spec.cpu_cores = int(cores[0])
                # model name
                models = re.findall(r"^model name\s*:\s*(.+)", content, re.MULTILINE)
                if models:
                    spec.cpu_model = models[0].strip()
                # threads
                processors = re.findall(r"^processor\s*:\s*\d+", content, re.MULTILINE)
                spec.cpu_threads = len(processors)
            elif sys.platform == "darwin":
                import subprocess
                r = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                                   capture_output=True, text=True, timeout=2)
                spec.cpu_model = r.stdout.strip()
                r2 = subprocess.run(["sysctl", "-n", "hw.logicalcpu"],
                                    capture_output=True, text=True, timeout=2)
                if r2.stdout.strip().isdigit():
                    spec.cpu_threads = int(r2.stdout.strip())
            else:
                spec.cpu_threads = spec.cpu_cores
        except Exception:
            spec.cpu_cores = 0
            spec.cpu_threads = 0

    def _detect_ram(self, spec: HardwareSpec):
        try:
            if sys.platform == "linux":
                with open("/proc/meminfo") as f:
                    content = f.read()
                import re
                total = re.search(r"MemTotal:\s+(\d+)", content)
                avail = re.search(r"MemAvailable:\s+(\d+)", content)
                if total:
                    spec.ram_total_gb = int(total.group(1)) / 1024 / 1024
                if avail:
                    spec.ram_available_gb = int(avail.group(1)) / 1024 / 1024
            elif sys.platform == "darwin":
                import subprocess
                r = subprocess.run(["sysctl", "-n", "hw.memsize"],
                                   capture_output=True, text=True, timeout=2)
                if r.stdout.strip().isdigit():
                    spec.ram_total_gb = int(r.stdout.strip()) / 1024**3
                # vm_stat for available
                r2 = subprocess.run(["vm_stat"], capture_output=True, text=True, timeout=2)
                # simple parse
                spec.ram_available_gb = spec.ram_total_gb * 0.5  # rough
            else:
                import psutil
                spec.ram_total_gb = psutil.virtual_memory().total / 1024**3
                spec.ram_available_gb = psutil.virtual_memory().available / 1024**3
        except Exception:
            pass

    def _detect_gpu(self, spec: HardwareSpec):
        """Detect NVIDIA GPU (nvidia-smi)"""
        try:
            r = subprocess.run(
                ["nvidia-smi", "--query-gpu=name,memory.total",
                 "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=5
            )
            if r.returncode == 0 and r.stdout.strip():
                for line in r.stdout.strip().split("\n"):
                    parts = [p.strip() for p in line.split(",")]
                    if len(parts) >= 2:
                        name = parts[0]
                        try:
                            vram = float(parts[1]) / 1024  # MiB -> GB
                        except ValueError:
                            vram = 0
                        spec.gpu_models.append(name)
                        spec.gpu_vram_gb.append(vram)
        except Exception:
            pass
        # Attempt AMD ROCm / Apple Metal detection
        if not spec.gpu_models:
            try:
                if sys.platform == "darwin":
                    r = subprocess.run(["system_profiler", "SPDisplaysDataType"],
                                       capture_output=True, text=True, timeout=5)
                    for line in r.stdout.split("\n"):
                        if "Chipset Model" in line:
                            spec.gpu_models.append(line.split(":")[-1].strip())
                            spec.gpu_vram_gb.append(0)  # unified memory
            except Exception:
                pass

    def _detect_disk(self, spec: HardwareSpec):
        try:
            stat = os.statvfs("/")
            free = stat.f_frsize * stat.f_bavail
            spec.disk_free_gb = free / 1024**3
        except Exception:
            # fake fallback
            spec.disk_free_gb = 10

    def _detect_os(self, spec: HardwareSpec):
        spec.os_name = platform.system()
        spec.os_version = platform.release()


# ── Convenience functions ────────────────────────────────

_detector_instance: Optional[HardwareDetector] = None


def detect() -> HardwareSpec:
    global _detector_instance
    if _detector_instance is None:
        _detector_instance = HardwareDetector()
    return _detector_instance.detect()


def report() -> dict:
    global _detector_instance
    if _detector_instance is None:
        _detector_instance = HardwareDetector()
    return _detector_instance.report()
