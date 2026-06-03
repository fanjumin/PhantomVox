# PhantomVox AI

**Where AI Meets Creativity** — an intelligent audio-video creation suite powered by multi-agent AI.

## Overview

PhantomVox AI is a next-generation creative workstation that combines professional-grade audio-video editing with an AI Agent ecosystem. Unlike traditional editors (Premiere, DaVinci Resolve), PhantomVox puts intelligence first — every creative action starts with an AI Agent conversation.

## Architecture

```
core/         — Engine, project models, interfaces
modules/
  i18n/       — 15-language i18n system with runtime hot-switch
  hardware/   — Hardware detection & model tier mapping (T1–T4)
main.py       — CLI entry point
docs/         — Architecture documentation
```

### Core Engine

A lightweight, extensible module registry. Infrastructure modules (i18n, hardware) are built-in. Feature modules register via `engine.register("name", instance)` — no hardcoded module lists.

### i18n — Internationalization

- 15 languages: zh_CN, zh_TW, en, ja, ko, fr, de, it, es, pt_BR, ru, ar, vi, th, id
- Runtime hot-switch without restart
- Dot-key lookup with interpolation & plural support
- Adding a language = adding one JSON file, no code changes

### Hardware Detection

- Auto-detects CPU, RAM, GPU, disk, OS at startup
- Maps hardware to model tiers (T1–T4)
- Filters incompatible AI models and suggests upgrades

### AI Model Library

| Category | Models | 
|----------|--------|
| TTS | Edge-TTS, MOSS-TTS, Bark, F5-TTS, GPT-SoVITS, CosyVoice, VoiceCraft |
| Music | Suno, Udio, Riffusion, MusicGen (small/medium/large), Stable Audio, AudioCraft |
| Singing | GPT-SoVITS Singing |

## Current Status

Early development. Infrastructure layer (engine, i18n, hardware detection) is complete. Agent framework and workspace modules are next.

## Quick Start

```bash
# Show system info
python3 main.py --info

# List available languages
python3 main.py locale --list

# Switch language at runtime
python3 main.py locale --set ja

# Hardware report & model compatibility
python3 main.py hardware

# Check if a specific model can run
python3 main.py hardware --check f5_tts
```

## License

MIT
