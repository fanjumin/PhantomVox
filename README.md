# PhantomVox AI v0.3.76

**Where AI Meets Creativity** — an intelligent audio-video creation suite powered by multi-agent AI.

Built with **Flutter** (desktop UI) + **Python** (AI server), targeting Linux/Windows/macOS.

## Workspaces

| # | Workspace | Status | Description |
|---|-----------|--------|-------------|
|| 1 | **Flow Graph** | ✅ v0.3.76 | **Tree-based creative flow editor** — Chat-driven generation (自然语言→完整树), collapsible tree, node detail panel, AI Expand, version management (snapshots + restore), Import/Export/Save/Delete, 4-level tree (topic→scene→beat→sub_beat) |
|| 2 | **AI Agent** | ✅ v0.3.0 | Multi-agent control center — Chat, Think, Image Gen, Video Gen, Code Gen panels + 8-agent matrix |
|| 3 | **StoryCut** | ✅ v0.3.0 | Story-driven quick cut — media browser, viewport, dual-layer timeline, AI QuickBar |
|| 4 | **ProEdit** | ✅ v0.3.0 | Precision editing — media pool + toolbox, 6-tab inspector, 5-track timeline, mixer |
|| 5 | **Palette** | ✅ v0.3.0 | Color grading — reference gallery, 15-node graph, 4-tab color tools (Wheels/Warper/Picker/Scopes) |
|| 6 | **AudioForge** | ✅ v0.3.0 | Audio mixing — Fairlight-style meter bar, track list, wave timeline, 5-channel mixer, AI workshop |
|| 7 | **EffectLab** | ✅ v0.3.0 | VFX compositing — dual viewport, Renderer3D1 inspector, frame timeline, node canvas |
|| 8 | **Dashboard** | ✅ v0.3.0 | Launch page — welcome banner, recent projects, hardware report, AI quick cards, quick chat |

### Flow Graph — Key Features (v0.3.76)

| Feature | Description |
|---------|-------------|
| **Chat-driven generation** | Type a prompt in the bottom Chat tab → LLM auto-generates a complete 2-3 level tree (20-40 nodes) and replaces the current workflow |
| **AI Expand** | Select any node → click AI → generates 2-4 child suggestions via DeepSeek |
| **Collapsible tree** | ▶/▼ toggle on nodes with children, tree stays manageable even with 40+ nodes |
| **Version snapshots** | Every Chat generation auto-saves the previous state → Versions tab lists all snapshots with timestamps → one-click Restore |
| **Import / Export** | Save current workflow to any .json path, load any existing .json file |
| **Delete** | Clear current tree with confirmation dialog |
| **Persistence** | Auto-saved to disk; survives app restart |
| **Node types** | topic → scene → beat → missing (AI-suggested gaps marked with orange [AI] tag) |

## Architecture

```
phantomvox_app/         — Flutter desktop app (Linux build)
  lib/
    pages/              — 8 workspace pages
    services/           — API service (HTTP → localhost:8899)
    widgets/            — TimelineCanvas, etc.

modules/                — Python AI Server
  api_server/           — Flask HTTP API (8899, 80+ endpoints)
  agent/                — Agent engine, 8 agents, workflow runner
    mindmap.py          — FlowGraph tree CRUD + persistence
    llm_client.py       — Unified LLM client (15 providers)
    agents/director.py  — Director agent with AI Expand
  audio/                — TTS (Edge-TTS), Music (Suno/MusicGen stubs)
  codegen/              — NL→FFmpeg code generation (43 templates, 7 categories)
  hardware/             — Hardware detection & model tier mapping (T1–T4)
  i18n/                 — 15-language i18n system with runtime hot-switch
  modelconfig/          — Config manager + config.yaml persistence
  timeline/             — Timeline engine, filter graph builder
  videogen/             — Video generation engine (stub, providers pattern)
```

## Quick Start

```bash
# 1. Start the AI Server
cd /path/to/project
python3 -m modules.api_server --host 0.0.0.0 --port 8899

# 2. Verify it's running
curl http://127.0.0.1:8899/api/v1/health
# → {"service":"phantomvox-ai-server","status":"ok"}

# 3. Build & run the Flutter app
cd phantomvox_app
flutter build linux --release
./build/linux/x64/release/bundle/phantomvox_app
```

Or use the pre-built release:
```bash
cd phantomvox_app/build/linux/x64/release/bundle
./phantomvox_app
```

## API Endpoints (50+ total)

| Area | Endpoints | Status |
|------|-----------|--------|
| System | health, info, hardware | ✅ |
| Locale | current, list, set, translate | ✅ |
| TTS | synthesize, voices, providers | ✅ real (Edge-TTS) |
| Music | generate, styles, providers | ✅ stub |
| Agent | chat, think, image, video, code, matrix, workflow | ✅ |
|| **Flow Graph** | **root, node, reorder, save, import, export, delete, generate, expand, versions, versions/save, versions/restore** | **✅ v0.3.76** |\r|| **Auth** | **/register, /login, /refresh, /users/me** | **✅ v0.3.76 (JWT + token rotation)** |
|| CodeGen | generate, categories, templates | ✅ 43 templates |
| VideoGen | generate, styles | ✅ stub |
| Timeline | CRUD, tracks, clips, effects, render | ✅ |
| Models | list, config, api_keys | ✅ |

## CLI

```bash
python3 main.py --info                 # Show system info
python3 main.py locale --list          # List available languages
python3 main.py hardware               # Hardware report & model compatibility
python3 main.py hardware --check f5_tts # Check if model can run on this machine
```

## i18n — Internationalization

- 15 languages: zh_CN, zh_TW, en, ja, ko, fr, de, it, es, pt_BR, ru, ar, vi, th, id
- Runtime hot-switch without restart
- Dot-key lookup with interpolation & plural support
- Adding a language = adding one JSON file, no code changes

## Hardware Detection

- Auto-detects CPU, RAM, GPU, disk, OS at startup
- Maps hardware to model tiers (T1–T4)
- Filters incompatible AI models and suggests upgrades

## AI Model Library

| Category | Models |
|----------|--------|
| TTS | Edge-TTS (online), MOSS-TTS, Bark, F5-TTS, GPT-SoVITS, CosyVoice, VoiceCraft |
| Music | Suno (online), Udio, Riffusion, MusicGen (small/medium/large), Stable Audio, AudioCraft |
| Chat | DeepSeek, Qwen, GLM, Yi, Baichuan, OpenAI, Anthropic, Gemini, Mistral, xAI |

## Tech Stack

| Layer | Technology | Status |
|-------|-----------|--------|
| UI | Flutter 3.44 (Dart) | ✅ Linux desktop build |
| AI Server | Python 3.12 + Flask | ✅ 50+ API endpoints |
| LLM | DeepSeek (primary), 15-provider unified client | ✅ |
| Build | cmake + g++ + ninja | ✅ Verified |

## License

MIT
