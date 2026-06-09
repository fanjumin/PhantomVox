1|# PhantomVox AI v0.3.77
2|
3|**Where AI Meets Creativity** — an intelligent audio-video creation suite powered by multi-agent AI.
4|
5|Built with **Flutter** (desktop UI) + **Python** (AI server), targeting Linux/Windows/macOS.
6|
7|## Workspaces
8|
9|| # | Workspace | Status | Description |
10||---|-----------|--------|-------------|
11||| 1 | **Flow Graph** | ✅ v0.3.77 | **Tree-based creative flow editor** — Chat-driven generation (自然语言→完整树), collapsible tree, node detail panel, AI Expand, version management (snapshots + restore), Import/Export/Save/Delete, 4-level tree (topic→scene→beat→sub_beat) |
12||| 2 | **AI Agent** | ✅ v0.3.0 | Multi-agent control center — Chat, Think, Image Gen, Video Gen, Code Gen panels + 8-agent matrix |
13||| 3 | **StoryCut** | ✅ v0.3.0 | Story-driven quick cut — media browser, viewport, dual-layer timeline, AI QuickBar |
14||| 4 | **ProEdit** | ✅ v0.3.0 | Precision editing — media pool + toolbox, 6-tab inspector, 5-track timeline, mixer |
15||| 5 | **Palette** | ✅ v0.3.0 | Color grading — reference gallery, 15-node graph, 4-tab color tools (Wheels/Warper/Picker/Scopes) |
16||| 6 | **AudioForge** | ✅ v0.3.0 | Audio mixing — Fairlight-style meter bar, track list, wave timeline, 5-channel mixer, AI workshop |
17||| 7 | **EffectLab** | ✅ v0.3.0 | VFX compositing — dual viewport, Renderer3D1 inspector, frame timeline, node canvas |
18||| 8 | **Dashboard** | ✅ v0.3.0 | Launch page — welcome banner, recent projects, hardware report, AI quick cards, quick chat |
19|
20|### Flow Graph — Key Features (v0.3.77)
21|
22|| Feature | Description |
23||---------|-------------|
24|| **Chat-driven generation** | Type a prompt in the bottom Chat tab → LLM auto-generates a complete 2-3 level tree (20-40 nodes) and replaces the current workflow |
25|| **AI Expand** | Select any node → click AI → generates 2-4 child suggestions via DeepSeek |
26|| **Collapsible tree** | ▶/▼ toggle on nodes with children, tree stays manageable even with 40+ nodes |
27|| **Version snapshots** | Every Chat generation auto-saves the previous state → Versions tab lists all snapshots with timestamps → one-click Restore |
28|| **Import / Export** | Save current workflow to any .json path, load any existing .json file |
29|| **Delete** | Clear current tree with confirmation dialog |
30|| **Persistence** | Auto-saved to disk; survives app restart |
31|| **Node types** | topic → scene → beat → missing (AI-suggested gaps marked with orange [AI] tag) |
32|
33|## Architecture
34|
35|```
36|phantomvox_app/         — Flutter desktop app (Linux build)
37|  lib/
38|    pages/              — 8 workspace pages
39|    services/           — API service (HTTP → localhost:8899)
40|    widgets/            — TimelineCanvas, etc.
41|
42|modules/                — Python AI Server
43|  api_server/           — Flask HTTP API (8899, 80+ endpoints)
44|  agent/                — Agent engine, 8 agents, workflow runner
45|    mindmap.py          — FlowGraph tree CRUD + persistence
46|    llm_client.py       — Unified LLM client (15 providers)
47|    agents/director.py  — Director agent with AI Expand
48|  audio/                — TTS (Edge-TTS), Music (Suno/MusicGen stubs)
49|  codegen/              — NL→FFmpeg code generation (43 templates, 7 categories)
50|  hardware/             — Hardware detection & model tier mapping (T1–T4)
51|  i18n/                 — 15-language i18n system with runtime hot-switch
52|  modelconfig/          — Config manager + config.yaml persistence
53|  timeline/             — Timeline engine, filter graph builder
54|  videogen/             — Video generation engine (stub, providers pattern)
55|```
56|
57|## Quick Start
58|
59|```bash
60|# 1. Start the AI Server
61|cd /path/to/project
62|python3 -m modules.api_server --host 0.0.0.0 --port 8899
63|
64|# 2. Verify it's running
65|curl http://127.0.0.1:8899/api/v1/health
66|# → {"service":"phantomvox-ai-server","status":"ok"}
67|
68|# 3. Build & run the Flutter app
69|cd phantomvox_app
70|flutter build linux --release
71|./build/linux/x64/release/bundle/phantomvox_app
72|```
73|
74|Or use the pre-built release:
75|```bash
76|cd phantomvox_app/build/linux/x64/release/bundle
77|./phantomvox_app
78|```
79|
80|## API Endpoints (50+ total)
81|
82|| Area | Endpoints | Status |
83||------|-----------|--------|
84|| System | health, info, hardware | ✅ |
85|| Locale | current, list, set, translate | ✅ |
86|| TTS | synthesize, voices, providers | ✅ real (Edge-TTS) |
87|| Music | generate, styles, providers | ✅ stub |
88|| Agent | chat, think, image, video, code, matrix, workflow | ✅ |
89||| **Flow Graph** | **root, node, reorder, save, import, export, delete, generate, expand, versions, versions/save, versions/restore** | **✅ v0.3.77** |\r|| **Auth** | **/register, /login, /refresh, /users/me** | **✅ v0.3.77 (JWT + token rotation)** |
90||| CodeGen | generate, categories, templates | ✅ 43 templates |
91|| VideoGen | generate, styles | ✅ stub |
92|| Timeline | CRUD, tracks, clips, effects, render | ✅ |
93|| Models | list, config, api_keys | ✅ |
94|
95|## CLI
96|
97|```bash
98|python3 main.py --info                 # Show system info
99|python3 main.py locale --list          # List available languages
100|python3 main.py hardware               # Hardware report & model compatibility
101|python3 main.py hardware --check f5_tts # Check if model can run on this machine
102|```
103|
104|## i18n — Internationalization
105|
106|- 15 languages: zh_CN, zh_TW, en, ja, ko, fr, de, it, es, pt_BR, ru, ar, vi, th, id
107|- Runtime hot-switch without restart
108|- Dot-key lookup with interpolation & plural support
109|- Adding a language = adding one JSON file, no code changes
110|
111|## Hardware Detection
112|
113|- Auto-detects CPU, RAM, GPU, disk, OS at startup
114|- Maps hardware to model tiers (T1–T4)
115|- Filters incompatible AI models and suggests upgrades
116|
117|## AI Model Library
118|
119|| Category | Models |
120||----------|--------|
121|| TTS | Edge-TTS (online), MOSS-TTS, Bark, F5-TTS, GPT-SoVITS, CosyVoice, VoiceCraft |
122|| Music | Suno (online), Udio, Riffusion, MusicGen (small/medium/large), Stable Audio, AudioCraft |
123|| Chat | DeepSeek, Qwen, GLM, Yi, Baichuan, OpenAI, Anthropic, Gemini, Mistral, xAI |
124|
125|## Tech Stack
126|
127|| Layer | Technology | Status |
128||-------|-----------|--------|
129|| UI | Flutter 3.44 (Dart) | ✅ Linux desktop build |
130|| AI Server | Python 3.12 + Flask | ✅ 50+ API endpoints |
131|| LLM | DeepSeek (primary), 15-provider unified client | ✅ |
132|| Build | cmake + g++ + ninja | ✅ Verified |
133|
134|## License
135|
136|MIT
137|