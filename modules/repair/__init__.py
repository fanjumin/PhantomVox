"""AI Image Repair Module — cloud-first, mask-based inpainting.

Usage:
    from modules.repair import RepairEngine
    engine = RepairEngine(config_dict)
    result = engine.repair(image, mask, prompt="fill naturally")
"""
from .engine import RepairEngine, RepairProvider

__all__ = ["RepairEngine", "RepairProvider"]
