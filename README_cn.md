# PhantomVox AI v0.3.72

**AI 遇见创意** — 由多智能体 AI 驱动的智能音视频创作套件。

基于 **Flutter**（桌面 UI）+ **Python**（AI 服务器），支持 Linux/Windows/macOS。

## 工作区

| # | 工作区 | 状态 | 描述 |
|---|--------|------|------|
| 1 | **Flow Graph** | ✅ v0.3.72 | **基于树的创作流编辑器** — 聊天驱动生成（自然语言→完整树），可折叠树，节点详情面板，AI 扩展，版本管理（快照+恢复），导入/导出/保存/删除，四级树（主题→场景→节拍→子节拍） |
| 2 | **AI Agent** | ✅ v0.3.0 | 多智能体控制中心 — 聊天、思考、图像生成、视频生成、代码生成面板 + 8 智能体矩阵 |
| 3 | **StoryCut** | ✅ v0.3.0 | 故事驱动快速剪辑 — 媒体浏览器、视口、双层时间线、AI 快捷栏 |
| 4 | **ProEdit** | ✅ v0.3.0 | 精准编辑 — 媒体池+工具箱、6 标签检查器、5 轨时间线、调音台 |
| 5 | **Palette** | ✅ v0.3.0 | 调色 — 参考图库、15 节点图谱、4 标签调色工具（色轮/曲线/取色器/示波器） |
| 6 | **AudioForge** | ✅ v0.3.0 | 音频混音 — Fairlight 风格电平条、音轨列表、波形时间线、5 通道调音台、AI 工作室 |
| 7 | **EffectLab** | ✅ v0.3.0 | VFX 合成 — 双视口、Renderer3D1 检查器、帧时间线、节点画布 |
| 8 | **Dashboard** | ✅ v0.3.0 | 启动页 — 欢迎横幅、最近项目、硬件报告、AI 快捷卡片、快速聊天 |

### Flow Graph — 主要功能 (v0.3.72)

| 功能 | 描述 |
|------|------|
| **聊天驱动生成** | 在底部聊天标签输入提示词 → LLM 自动生成完整 2-3 级树（20-40 节点）并替换当前工作流 |
| **AI 扩展** | 选择任意节点 → 点击 AI → 通过 DeepSeek 生成 2-4 个子节点建议 |
| **可折叠树** | ▶/▼ 切换有子节点的节点，即使 40+ 节点也能保持清晰 |
| **版本快照** | 每次聊天生成自动保存上一状态 → 版本标签列出所有快照及时间戳 → 一键恢复 |
| **导入/导出** | 将当前工作流保存到任意 .json 路径，加载已有 .json 文件 |
| **删除** | 带确认对话框的清空当前树 |
| **持久化** | 自动保存到磁盘，应用重启后仍然保留 |
| **节点类型** | 主题 → 场景 → 节拍 → 缺失（AI 建议的缺失节点以橙色 [AI] 标记） |

## 架构

```
phantomvox_app/         — Flutter 桌面应用（Linux 构建）
  lib/
    pages/              — 8 个工作区页面
    services/           — API 服务（HTTP → localhost:8899）
    widgets/            — TimelineCanvas 等

modules/                — Python AI 服务器
  api_server/           — Flask HTTP API（8899，80+ 端点）
  agent/                — 智能体引擎，8 个智能体，工作流运行器
    mindmap.py          — FlowGraph 树 CRUD + 持久化
    llm_client.py       — 统一 LLM 客户端（15 个提供商）
    agents/director.py  — 导演智能体，含 AI 扩展功能
  audio/                — TTS（Edge-TTS），音乐（Suno/MusicGen 桩）
  codegen/              — NL→FFmpeg 代码生成（43 模板，7 类别）
  hardware/             — 硬件检测和模型等级映射（T1–T4）
  i18n/                 — 15 语言国际化系统，运行时热切换
  modelconfig/          — 配置管理器 + config.yaml 持久化
  timeline/             — 时间线引擎，滤镜图构建器
  videogen/             — 视频生成引擎（桩，提供商模式）
```

## 快速开始

```bash
# 1. 启动 AI 服务器
cd /path/to/project
python3 -m modules.api_server --host 0.0.0.0 --port 8899

# 2. 验证运行
curl http://127.0.0.1:8899/api/v1/health
# → {"service":"phantomvox-ai-server","status":"ok"}

# 3. 构建并运行 Flutter 应用
cd phantomvox_app
flutter build linux --release
./build/linux/x64/release/bundle/phantomvox_app
```

或使用预构建版本：
```bash
cd phantomvox_app/build/linux/x64/release/bundle
./phantomvox_app
```

## API 端点（50+ 总计）

| 区域 | 端点 | 状态 |
|------|------|------|
| 系统 | health, info, hardware | ✅ |
| 语言 | current, list, set, translate | ✅ |
| TTS | synthesize, voices, providers | ✅ 真实（Edge-TTS） |
| 音乐 | generate, styles, providers | ✅ 桩 |
| 智能体 | chat, think, image, video, code, matrix, workflow | ✅ |
| | **Flow Graph** | **root, node, reorder, save, import, export, delete, generate, expand, versions, versions/save, versions/restore** | **✅ v0.3.72** |
| | **Auth** | **/register, /login, /refresh, /users/me** | **✅ v0.3.72（JWT + 令牌轮换）** |
| | 代码生成 | generate, categories, templates | ✅ 43 模板 |
| | 视频生成 | generate, styles | ✅ 桩 |
| | 时间线 | CRUD, tracks, clips, effects, render | ✅ |
| | 模型 | list, config, api_keys | ✅ |

## CLI

```bash
python3 main.py --info                 # 显示系统信息
python3 main.py locale --list          # 列出可用语言
python3 main.py hardware               # 硬件报告和模型兼容性
python3 main.py hardware --check f5_tts # 检查模型是否可在本机运行
```

## i18n — 国际化

- 15 种语言：zh_CN, zh_TW, en, ja, ko, fr, de, it, es, pt_BR, ru, ar, vi, th, id
- 运行时热切换，无需重启
- 点键查找，支持插值和复数形式
- 添加语言 = 添加一个 JSON 文件，无需修改代码

## 硬件检测

- 启动时自动检测 CPU、RAM、GPU、磁盘、操作系统
- 将硬件映射到模型等级（T1–T4）
- 过滤不兼容的 AI 模型并建议升级

## AI 模型库

| 类别 | 模型 |
|------|------|
| TTS | Edge-TTS（在线）、MOSS-TTS、Bark、F5-TTS、GPT-SoVITS、CosyVoice、VoiceCraft |
| 音乐 | Suno（在线）、Udio、Riffusion、MusicGen（small/medium/large）、Stable Audio、AudioCraft |
| 聊天 | DeepSeek、Qwen、GLM、Yi、Baichuan、OpenAI、Anthropic、Gemini、Mistral、xAI |

## 技术栈

| 层 | 技术 | 状态 |
|----|------|------|
| UI | Flutter 3.44（Dart） | ✅ 已构建 Linux 桌面版 |
| AI 服务器 | Python 3.12 + Flask | ✅ 50+ API 端点 |
| LLM | DeepSeek（主要），15 提供商统一客户端 | ✅ |
| 构建 | cmake + g++ + ninja | ✅ 已验证 |

## 许可

MIT
