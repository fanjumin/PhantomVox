# PhantomVox AI — 详细架构方案 v1.2

> 专业音视频创作 + AI Agent 深度集成
> 借鉴达芬奇核心理念，构建 PhantomVox 自有体系

---

## 一、整体应用布局

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [PhantomVox LOGO]  Flow Graph │ Image Studio │ AI Agent │ StoryCut │ ProEdit │ Palette │ AudioForge │ EffectLab │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  八个独立工作区 ─── 借鉴达芬奇核心理念，PhantomVox 自有命名体系                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

| 原达芬奇名 | PhantomVox 名 | 理念 |
|-----------|-------------|------|
| (无) | **Flow Graph** | 创作流图谱 — 工作流编排 |
| (无) | **Image Studio** | 图像处理工坊 — AI 图像编辑 |
| (无) | **AI Agent** | 智能体控制中心 |
| Cut | **StoryCut** | 故事剪辑，强调叙事 |
| Edit | **ProEdit** | 专业编辑，保持通用辨识度 |
| Color | **Palette** | 调色板，色彩工坊 |
| Fairlight | **AudioForge** | 音频锻造，声音工坊 |
| Fusion | **EffectLab** | 特效实验室 |

---

## 二、Flow Graph 页面 — 创作流图谱

> **已完成模块** — 将 AI Agent 中的思维导图功能独立为完整的创作流图谱页面，采用树形结构（非 DAG），支持聊天驱动生成、版本管理和 AI 扩展。

### 定位

Flow Graph（创作流图谱）是 PhantomVox 的**创作流编排中心**。用户通过自然语言聊天驱动生成完整创作树，手动调整节点结构，管理版本快照。与达芬奇不同，PhantomVox 的 Flow Graph 是**树形（Tree）而非 DAG** — 更适合创意分叉与方案对比。

### 页面结构

```
┌───────────────────────────────────────────────────────────────────────────┐
│  TOP_BAR: [Flow Graph]  [▼ 项目切换]  [+ Node]  [- 删除]  [AI ✧]  [导入] [导出] [版本v] │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  创作流图谱 — 核心树形区域                                                   │
│                                                                           │
│  + 制作产品宣传片 (topic)    ← 根节点, 紫色高亮                               │
│  │                                                                         │
│  ├── 📝 语音克隆 (scene)     — AI 生成 3个子节点                              │
│  │   ├── 🎤 旁白生成 (beat)                                                   │
│  │   └── 🗣 配音选择 (beat)                                                   │
│  │                                                                         │
│  ├── 🎵 音乐生成 (scene)                                                    │
│  │   ├── 🎼 爵士风格 (beat)                                                  │
│  │   │   └── 🎹 钢琴即兴前奏 (sub_beat)  ← 4级树深度                          │
│  │   └── 🎧 背景音乐 (beat)                                                  │
│  │                                                                         │
│  ├── 🎬 素材准备 (scene)                                                    │
│  │   └── 🖼 文生背景 (beat)                                                 │
│  │                                                                         │
│  ├── 🎥 视频生成 (scene)                                                    │
│  │   └── 🎞 AI 宣传片 (beat)                                                │
│  │                                                                         │
│  └── 💻 代码生成 (scene)                                                    │
│      └── 🔧 自定义转场 (beat)                                               │
│                                                                           │
│  ▶/▼ 折叠 | 点击节点展开详情 | 拖拽排序 | [AI] 标记为AI建议                     │
│  [橙色 AI 标签] = LLM 生成但未经验证的节点                                    │
├───────────────────────────────────────────────────────────────────────────┤
│  Chat / Versions 底部面板                                                    │
│  ┌─ 💬 Chat ────────────────────────────────────────────────────────────┐ │
│  │  用户: 制作一个产品宣传片，需要语音、音乐、视频三个部分                        │ │
│  │  AI: 已为您生成策划树，共3个场景8个子节点                                  │ │
│  │  [输入框...                                    ] [发送]                │ │
│  ├─ 📋 Versions ────────────────────────────────────────────────────────┤ │
│  │  v1 2026-06-04 14:30  "制作产品宣传片"                  [恢复] [删除]    │ │
│  │  v2 2026-06-04 14:35  "加入动画特效"                    [恢复] [删除]    │ │
│  │  v3 2026-06-04 14:40  "当前版本" ◄                     [恢复] [删除]    │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────┘
```

### 核心功能

| 功能 | 说明 |
|------|------|
| **聊天驱动生成** | 自然语言 → LLM 自动生成 3-4 层完整树（topic→scene→beat→sub_beat），替换当前工作流 |
| **AI 扩展** | 选中节点 → 点击 AI → LLM 生成 2-4 个子节点建议 |
| **折叠树** | ▶/▼ 切换子节点可见性，40+ 节点也轻松管理 |
| **版本快照** | 每次聊天生成自动保存上一个状态 → Versions 标签页列出所有快照 → 一键恢复 |
| **导入/导出** | 保存任意 .json，加载已有 .json 文件 |
| **删除** | 删除选中节点；工具栏 [-] 删除整棵树 |
| **持久化** | 自动保存至 `data/flowgraph.json`，重启不丢失 |
| **4 级节点类型** | topic → scene → beat → sub_beat（AI 建议缺失节点标记为橙色 [AI]） |
| **节点拖拽排序** | 长按节点拖拽调整兄弟节点顺序 |

### 已实现 API 端点

| 端点 | 说明 | 状态 |
|------|------|------|
| `POST /api/v1/flowgraph/root` | 获取根节点 | ✅ |
| `POST /api/v1/flowgraph/node` | CRUD 节点 | ✅ |
| `POST /api/v1/flowgraph/reorder` | 排序节点 | ✅ |
| `POST /api/v1/flowgraph/save` | 保存到文件 | ✅ |
| `POST /api/v1/flowgraph/import` | 导入 .json | ✅ |
| `POST /api/v1/flowgraph/export` | 导出 .json | ✅ |
| `POST /api/v1/flowgraph/delete` | 清空树 | ✅ |
| `POST /api/v1/flowgraph/generate` | LLM 生成完整树 | ✅ (DeepSeek) |
| `POST /api/v1/flowgraph/expand` | AI 扩展子节点 | ✅ (DeepSeek) |
| `POST /api/v1/flowgraph/versions` | 版本列表 | ✅ |
| `POST /api/v1/flowgraph/versions/save` | 保存版本快照 | ✅ |
| `POST /api/v1/flowgraph/versions/restore` | 恢复版本 | ✅ |
| `POST /api/v1/flowgraph/flow` | 获取完整流状态 | ✅ |

### 独创功能标识

- 整个页面都是独创（达芬奇没有创作流图谱）
- **树形结构**（Tree）而非 DAG — 更适合创意分叉与方案对比
- **自然语言→完整树** — 用户只需描述需求，AI 自动生成 3-4 层策划树
- **版本管理** — 对话驱动的版本快照系统，支持一键恢复
- **AI 扩展** — 选中节点 → AI 生成子节点建议（不同方案分支）

---

## 三、Image Studio 页面 — 图像处理工坊

> ✅ **v0.3.5 已完整实现** — 全功能图像编辑器，集成 OpenCV 图像处理套件和 AI 增强管线。对标主流 AI 图像编辑器（百度智能看图/Canva/Photopea）的核心功能。

### 定位

Image Studio（图像处理工坊）是 PhantomVox 的**图像编辑与修复中心**。用户在这里完成图像裁剪/缩放/旋转、滤镜、文本标注、画笔绘制、AI 修复增强等操作。区别于其他工作区，Image Studio 是独立于音视频编辑的纯图像处理模块。

### 设计参照：行业标准架构

Image Studio 的交互模式参照 **Photopea** 的单页编辑器架构 + **Photoshop** 的 Tool → Options → Canvas 模型（来源：photopea.com 及 developer 资料分析）：

```
用户操作 (Gesture)
    ↓
Tool 子系统 (识别工具 → 生成命令)
    ↓
Canvas 渲染 (CustomPainter 重绘)
    ↓
后台同步 (Flask → OpenCV → 返回结果)
```

**工具交互模式：**
1. 从工具栏选择工具 → 属性面板显示工具参数
2. 在画布上操作 (mousedown → mousemove → mouseup)
3. 实时预览（前端 Canvas 做临时渲染）
4. 操作完成 → 发送到后台 → 更新图层

### 页面布局

```
┌───────────────────────────────────┬──────────────────────────────┬──────────────────────────┐
│  左侧工具栏 (98px, 2列)          │  中央画布                   │  右侧属性面板 (240px)     │
│                                  │                              │                          │
│  ┌────┐ ┌────┐                  │  ┌────────────────────────┐  │  ┌─ 工具属性 ──────────┐ │
│  │Crop│ │Text│                  │  │                        │  │  │                     │ │
│  └────┘ └────┘                  │  │   图像 (可缩放/平移)    │  │  │  [当前工具参数]       │ │
│  ┌────┐ ┌────┐                  │  │                        │  │  │                     │ │
│  │Brush│ │Eraser│               │  │   ┌────────────────┐    │  │  │ 颜色选择器           │ │
│  └────┘ └────┘                  │  │   │ 裁剪选框/选区   │    │  │  │ 尺寸滑块             │ │
│  ┌────┐ ┌────┐                  │  │   └────────────────┘    │  │  │ 不透明度              │ │
│  │Shape│ │Resize│               │  │                        │  │  │                     │ │
│  └────┘ └────┘                  │  │  鼠标滚轮=缩放         │  │  └─────────────────────┘ │
│  ┌────┐ ┌────┐                  │  │  无工具时拖动=平移     │  │                          │
│  │Rotate││Flip │                │  │  工具激活时拖动=操作    │  │  ┌─ AI 工具 ────────────┐ │
│  └────┘ └────┘                  │  │                        │  │  │ [AI Enhance]         │ │
│  ┌────┐ ┌────┐                  │  │  ClipRect 防溢出        │  │  │ [Face Restore]        │ │
│  │Adjust││Filter│               │  │                        │  │  │ [Upscale 2x/4x]      │ │
│  └────┘ └────┘                  │  │                        │  │  │ [Lineart] [HDR]      │ │
│  ┌────┐ ┌────┐                  │  │                        │  │  └─────────────────────┘ │
│  │Denoise││RmBG │               │  └────────────────────────┘  │                          │
│  └────┘ └────┘                  │                              │  ┌─ 历史操作 ────────────┐ │
│  ┌────┐ ┌────┐                  │                              │  │  ↩ Undo  (30步)       │ │
│  │AI✧│ │Upscale│               │                              │  │  ↪ Redo               │ │
│  └────┘ └────┘                  │                              │  └─────────────────────┘ │
├───────────────────────────────────┴──────────────────────────────┴──────────────────────────┤
│  状态栏: 缩放: 150%  |  图像: 1920×1080  |  工具: Crop  |  内存: 45MB                        │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 核心功能

| 功能类别 | 工具 | 说明 |
|---------|------|------|
| **基础变换** | Crop, Resize, Rotate, Flip | 图像裁剪(交互选框)、缩放(精确像素)、旋转(90°/自定义)、翻转(水平/垂直) |
| **绘制标注** | Text, Brush, Eraser, Shapes | 文字(拖拽生成文本框)、画笔(自由绘制)、擦除、形状(矩形/圆/线/箭头) |
| **色彩调整** | Adjust (Brightness/Contrast/Saturation/Blur) | 实时滑杆调节，即时预览 |
| **滤镜** | Blur, Emboss, Edge, Sharpen, Sepia | 常见图像滤镜一键应用 |
| **OpenCV 套件** | Smart Denoise, CLAHE, Auto White Balance, Super Resolve, Inpaint Erase, Lineart, HDR Tone | 基于 OpenCV (v4.13) 的图像处理管线 |
| **AI 增强** | AI Enhance, AI Face Restore | 多步降噪→锐化→CLAHE→自动白平衡管线；人脸修复(GFPGAN/OpenCV fallback) |
| **撤销/重做** | Undo/Redo | 30 步历史快照栈，所有操作可回退 |
| **视图控制** | Zoom (滚轮), Pan (拖拽) | ClipRect 防溢出，状态栏显示缩放比 |

### 后端核心数据模型

参考 OpenCV Mat 文档：图像以 numpy.ndarray 表示，shape=(H,W,C)，dtype=uint8。采用 Photopea 标准的 Document → Layer → Command 模型：

```python
# 文档
class Document:
    width: int
    height: int
    layers: list[Layer]       # 有序列表，索引 0 = 最底层
    history: list[Command]    # 命令模式实现撤销/重做

# 图层
class Layer:
    image: np.ndarray         # BGRA uint8, shape=(H,W,4)
    name: str
    opacity: float            # 0.0 ~ 1.0
    visible: bool = True
    blend_mode: str = "normal"  # normal/multiply/screen/overlay/...
    mask: np.ndarray | None   # 单通道 uint8 mask

# 命令模式（Undo/Redo）
class Command:
    type: str                 # "paint" | "transform" | "filter" | ...
    before: LayerState
    after: LayerState
```

**基础 alpha 混合公式**（标准 Porter-Duff src-over）：
```
output = src * src_alpha + dst * (1 - src_alpha)
```

### 后端模块架构

```python
modules/image_studio/           # 图像处理引擎模块
├── __init__.py                 # 数据模型 (Layer, Document, _Snapshot) + 合成引擎
│   ├── Layer class             # 单图层 (BGRA uint8, 混合模式, 蒙版, 锁定)
│   ├── Document class          # 文档 (多图层管理, 撤销/重做栈, 50步+256MB内存保护)
│   ├── composite_layers()      # Porter-Duff src-over 合成 (10种混合模式)
│   └── Alpha blend helpers     # normal/multiply/screen/overlay/darken/lighten/difference/exclusion/hard_light/soft_light
├── tools.py                    # 像素级绘制工具
│   ├── add_text()              # 支持 stroke/shadow 的文本渲染
│   ├── draw_brush()            # 自由画笔 (线条+端点圆)
│   ├── draw_shape()            # 矩形/椭圆/圆/线/箭头
│   ├── flood_fill()            # 泛洪填充 (alpha 保护, 自动 copy)
│   └── eyedropper()            # 取色 (R,G,B)
├── cv_tools.py                 # OpenCV 工具集 (~28 函数)
│   ├── 滤镜 (gaussian/median/bilateral/sharpen/emboss/edge/grayscale/sepia/invert)
│   ├── 色彩调整 (brightness/contrast/saturation/hue/CLAHE/auto_wb)
│   ├── 几何变换 (resize/rotate/flip)
│   ├── 高级工具 (smart_denoise/smart_sharpen/super_resolve/extract_lineart/hdr_tone)
│   ├── 背景/修复 (remove_background/inpaint_erase/blur_region/crop_image)
│   └── FILTER_MAP 分发器 (9 种命名滤镜)
└── ai_providers.py             # AI 增强管线
    ├── ai_enhance_image()      # 管线: 降噪→锐化→CLAHE→自动白平衡
    ├── ai_restore_faces()      # Haar Cascade 人脸检测 + CLAHE + 双边滤波
    └── get_capabilities()      # 返回可用 AI 功能列表
```
**更新说明 (2026-06-07):** 模块路径已从 `image_editor/` 迁移为 `image_studio/`。`__init__.py` 不再包含编排逻辑（移至 `api_server/__init__.py` 路由层），专注数据模型与合成引擎。`tools.py` 新增 `flood_fill` 和 `eyedropper`。`cv_tools.py` 扩展至 ~28 个函数，覆盖所有 OpenCV 管线操作。

### OpenCV 函数参考（官方 API 签名）

以下 OpenCV 函数均参照 `docs.opencv.org/4.x` 实现，逐条对照官方签名：

#### 图像 I/O
```python
img = cv.imread(path, cv.IMREAD_UNCHANGED)  # 保留 alpha 通道
cv.imwrite(path, img, [cv.IMWRITE_PNG_COMPRESSION, 9])
```

#### 绘图函数
```python
cv.line(img, pt1, pt2, color, thickness, lineType=cv.LINE_AA)
cv.circle(img, center, radius, color, thickness, lineType=cv.LINE_AA)
cv.rectangle(img, pt1, pt2, color, thickness, lineType=cv.LINE_AA)
cv.ellipse(img, center, axes, angle, startAngle, endAngle, color, thickness)
cv.polylines(img, [pts], isClosed, color, thickness)
cv.fillPoly(img, [pts], color)
cv.putText(img, text, org, fontFace, fontScale, color, thickness, cv.LINE_AA)
# thickness=-1 表示填充；颜色格式: BGR tuple 或 BGRA tuple
```

#### 图层合成
```python
def composite(layers: list[Layer]) -> np.ndarray:
    """按从下到上顺序合成图层"""
    result = None
    for layer in layers:
        if not layer.visible:
            continue
        img = layer.image.copy()
        alpha = img[:,:,3] * layer.opacity
        img[:,:,3] = alpha
        if layer.blend_mode == "normal":
            result = alpha_blend(img, result)
        elif layer.blend_mode == "multiply":
            result = multiply_blend(img, result)
        # ... 其他混合模式
    return result
```

#### 滤镜
```python
cv.GaussianBlur(src, ksize, sigmaX)                     # 高斯模糊
cv.medianBlur(src, ksize)                                # 中值模糊
cv.bilateralFilter(src, d, sigmaColor, sigmaSpace)       # 保边去噪
kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]], np.float32)
cv.filter2D(src, -1, kernel)                             # 锐化
```

#### 色彩调整
```python
cv.cvtColor(img, cv.COLOR_BGR2GRAY)                     # 灰度
cv.cvtColor(img, cv.COLOR_BGR2HSV)                      # HSV
cv.threshold(src, thresh, maxval, type)                  # 二值化
cv.equalizeHist(gray)                                    # 直方图均衡
```

#### 几何变换
```python
cv.resize(src, dsize, interpolation=cv.INTER_LINEAR)     # 缩放
M = cv.getRotationMatrix2D(center, angle, scale)
cv.warpAffine(src, M, dsize)                             # 旋转/平移/缩放
M = cv.getPerspectiveTransform(src_pts, dst_pts)
cv.warpPerspective(src, M, dsize)                        # 透视裁剪
cv.flip(src, flipCode)                                   # 翻转 (0=垂直, 1=水平, -1=两者)
```

#### 选区/蒙版
```python
mask = cv.inRange(hsv, lower, upper)                     # 颜色范围选择
edges = cv.Canny(gray, threshold1, threshold2)           # 边缘检测
contours, _ = cv.findContours(binary, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE)
cv.drawContours(img, contours, -1, color, thickness=cv.FILLED)
```

### 后端合规性确认（2026-06-06 审计）

经逐函数对照 OpenCV 官方文档 `docs.opencv.org/4.13.0`，后端实现合规性如下：

| 操作 | 签名 | 结论 |
|------|------|------|
| smart_denoise | `cv.fastNlMeansDenoisingColored(arr, None, h, h, template_size, search_size)` | ✅ 符合官方 |
| smart_sharpen | 高斯模糊 + `addWeighted` unsharp mask | ✅ 标准做法 |
| clahe_enhance | `createCLAHE(clipLimit, tileGridSize)` → LAB 通道应用 | ✅ 符合官方 |
| auto_white_balance | `cv.xphoto.createSimpleWB()` — OpenCV contrib xphoto Gray World | ✅ 已改用官方实现 |
| inpaint_erase | `cv.inpaint(arr, mask, radius, INPAINT_TELEA/NS)` | ✅ 符合官方 |
| extract_lineart | Canny / Sobel / Laplacian | ✅ 符合官方 |
| hdr_tone | Reinhard 色调映射 → 已修复 log(0) 和 MinFilter 问题 | ✅ 已修复 |
| super_resolve | Lanczos resize + sharpen | ✅ 标准实现（非 AI SR，已加文档说明） |

### API 端点

| 端点 | 说明 | 状态 |
|------|------|------|
| `POST /api/v1/editor/load` | 加载图像 | ✅ |
| `POST /api/v1/editor/crop` | 裁剪 | ✅ |
| `POST /api/v1/editor/resize` | 缩放 | ✅ |
| `POST /api/v1/editor/rotate` | 旋转 | ✅ |
| `POST /api/v1/editor/flip` | 翻转 | ✅ |
| `POST /api/v1/editor/adjust` | 色彩调整 (亮度/对比度/饱和度/模糊) | ✅ |
| `POST /api/v1/editor/filter` | 滤镜 (blur/emboss/edge/sharpen/sepia) | ✅ |
| `POST /api/v1/editor/text` | 添加文本 (font/size/color/stroke/shadow) | ✅ |
| `POST /api/v1/editor/blur-region` | 区域模糊 | ✅ |
| `POST /api/v1/editor/denoise` | 降噪 | ✅ |
| `POST /api/v1/editor/draw` | 画笔绘制 (freehand) | ✅ |
| `POST /api/v1/editor/shape` | 形状绘制 (rect/circle/line/arrow) | ✅ |
| `POST /api/v1/editor/remove-bg` | 移除背景 | ✅ |
| `POST /api/v1/editor/smart-sharpen` | OpenCV 智能锐化 | ✅ |
| `POST /api/v1/editor/clahe` | OpenCV CLAHE | ✅ |
| `POST /api/v1/editor/auto-wb` | OpenCV 自动白平衡 | ✅ |
| `POST /api/v1/editor/upscale` | OpenCV 超分辨率 2x/4x | ✅ |
| `POST /api/v1/editor/inpaint-erase` | OpenCV 修复擦除 | ✅ |
| `POST /api/v1/editor/lineart` | OpenCV 线稿提取 | ✅ |
| `POST /api/v1/editor/hdr` | OpenCV HDR 色调 | ✅ |
| `POST /api/v1/editor/ai-enhance` | AI 增强管线 | ✅ |
| `POST /api/v1/editor/ai-restore` | AI 人脸修复 | ✅ |
| `POST /api/v1/editor/undo` | 撤销 | ✅ |
| `POST /api/v1/editor/redo` | 重做 | ✅ |
| `GET /api/v1/editor/fonts` | 字体列表 (30 种) | ✅ |
|| `GET /api/v1/editor/history` | 历史状态 (can_undo/can_redo) | ✅ |
| `POST /api/v1/editor/gradient` | 渐变填充 (linear/radial) | ✅ | v0.3.5 新增 |
| `POST /api/v1/editor/fill` | 泛洪填充 (from tools.flood_fill) | ✅ | v0.3.5 新增 |
| `POST /api/v1/editor/eyedropper` | 取色 (返回 RGB) | ✅ | v0.3.5 新增 |
| `GET /api/v1/editor/info` | 文档信息 (宽/高/图层数) | ✅ | v0.3.5 新增 |
| `POST /api/v1/editor/new` | 创建新文档 | ✅ | v0.3.5 新增 |
| `POST /api/v1/editor/save` | 保存文档到文件 | ✅ | v0.3.5 新增 |
| `POST /api/v1/editor/add-layer` | 添加空白图层 | ✅ | v0.3.5 新增 |
| `POST /api/v1/editor/delete-layer` | 删除指定图层 | ✅ | v0.3.5 新增 |
| `POST /api/v1/editor/layer-props` | 设置图层属性 (opacity/visible/blend_mode/locked) | ✅ | v0.3.5 新增 |

| **总计** | **35 个端点** (文档 26 + 新增 9) | ✅ |

### 已知问题与待修复项

#### 🔴 P0 — 坐标转换架构问题（必须修复）→ ✅ **已修复 (v0.3.5)**

~~**根因：** 前端画布使用手工 `Transform + _zoomLevel + _panOffset` 实现缩放/平移，但坐标转换函数 `_screenToImage()` 仅计算了初始 `FittedBox(fit:BoxFit.contain)` 的缩放，忽略了 Transform 设置的 `_panOffset` 和 `_zoomLevel`。根据 Flutter 官方 API（`TransformationController.toScene()`），应改用 `InteractiveViewer` + `TransformationController` 替代手工 Transform。~~

**修复状态：** 已改用 `InteractiveViewer` + `TransformationController`。所有指针事件通过 `Matrix4.inverted(_tc.value)` 正确转换为图像像素坐标。~~旧的手工 `Transform + _zoomLevel + _panOffset` 代码已完全移除。~~

~~**影响范围：所有基于 `_listenerLocalToImage()` 的工具在缩放/平移后坐标全部计算错误。**~~

~~| 工具 | 具体表现 | 根因 |~~
~~|------|---------|------|~~
~~| Crop | 框能拖动但确认后裁剪结果偏移 | `_listenerLocalToImage()` 的 scale×2 计算 |~~
~~| Text | 框位置错、无内联编辑 | 坐标双倍计算 + 缺少 TextField widget |~~
~~| Brush/Eraser | 预览位置对但大小不对 | `_previewStroke` 屏幕坐标对但尺寸是图像像素 |~~
~~| Shape | 预览位置错、线粗细不对 | `_imageRectToListenerLocal()` 坐标双倍 |~~

~~**修复方案：** 用 `InteractiveViewer` + `TransformationController.toScene()` 替换手工 `Transform`。这是 Flutter 团队为此类问题设计的官方方案（参考: api.flutter.dev, InteractiveViewer-class）。~~

#### 🟡 P1 — 短期修复项

| # | 问题 | 建议 |
|---|------|------|
| 1 | Adjust 滑块每 tick 触发 HTTP POST（拖动 40 格 = 40 次请求） | 改用 `onChangeEnd`，拖动结束时只发一次 |
| 2 | `_hitTestHandle` 用图像像素距离（12px）检测手柄，缩放后手感不一致 | 改为固定屏幕像素距离 |
| 3 | Text 框拖动无图像边界钳制 | 添加 clamp 逻辑 |
| 4 | ~~`auto_white_balance` 手写 gray-world 实现~~ | ✅ **已修复 (2026-06-07):** 改用 `cv.xphoto.createSimpleWB()` — OpenCV contrib xphoto 官方 Gray World |

#### 🟢 P2 — 长期优化

| # | 问题 | 建议 |
|---|------|------|
| 1 | ~~`image_studio_page.dart` 单文件 ~1742 行~~ | ✅ **已拆分 (2026-06-07):** API 客户端 → `image_studio_api.dart` (83行)，覆盖渲染器 → `image_studio_painter.dart` (115行)，主文件 1818 行 |
| 2 | ~~图像传输用完整 base64 太重~~ | ✅ **已优化 (2026-06-07):** 后端支持 `preview_only` 参数返回 320px 缩略图（~80% 传输量减少），`/api/v1/editor/preview` 独立端点，Flutter 前端所有工具操作默认使用预览模式 |

### 与竞品对比

| 功能 | **PhantomVox Image Studio** | 百度智能看图 | Canva | Photopea |
|------|---------------------------|------------|-------|---------|
| 裁剪 | ✅ 交互选框 | ✅ | ✅ | ✅ |
| 文字 | ✅ 拖拽生成文本框 | ✅ | ✅ | ✅ |
| 画笔 | ✅ 自由绘制 | ✅ | ✅ | ✅ |
| OpenCV 管线 | ✅ 12种处理函数 | ❌ | ❌ | ⚪ 部分 |
| AI 增强 | ✅ (CPU可用) | ✅ 云端 | ✅ 云端 | ❌ |
| 超分辨率 | ✅ 2x/4x | ✅ | ❌ | ❌ |
| 线稿 | ✅ Canny/Sobel/Laplacian | ❌ | ✅ | ❌ |
| HDR 色调 | ✅ | ⚪ | ✅ | ❌ |
| 30步撤销 | ✅ (所有操作) | ❌ | ✅ | ✅ |
| 离线可用 | ✅ (纯本地) | ❌ 纯云端 | ❌ 部分 | ✅ |
| 免费 | ✅ (MIT) | ✅ 基础 | ⚪ 付费墙 | ⚪ 广告 |

---

## 四、AI Agent 页面 — 智能体控制中心

这是 PhantomVox 的**核心差异化**，一个独立的完整工作区。

> ✅ **P1 已完成代码实现：** `modules/agent/` — AgentEngine + 5 面板 + 8 Agent。
> ✅ **模型配置：** `modules/modelconfig/` — ConfigManager + 模型注册表 + config.yaml 持久化。
> 两类模块均已注册到 Engine，可通过 `GET /api/v1/agent/plan` 等 14 个新端点调用。

### 整体布局

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  [AI Agent]  |  [💬聊天]  [🧠思考]  [🖼生图]  [🎬生视频]  [💻代码]  [🔧矩阵]  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                                                                              │
├──────────────────────────────┬───────────────────────────────────────────────┤
│  左侧: 当前激活子面板          │  右侧: 多智能体矩阵                              │
│                              │                                               │
│  [💬 AI聊天] - 对话窗口       │  ┌──────────┬──────────┬──────────┬──────────┐ │
│  ┌──────────────────────┐    │  │ Director │  Editor  │  Audio   │  Music   │ │
│  │ 用户: 做产品宣传片      │    │  │ 🟢活跃   │  🟢活跃   │  🟢活跃   │  🟢活跃   │ │
│  │ 助手: 分解为以下步骤    │    │  ├──────────┼──────────┼──────────┼──────────┤ │
│  │                      │    │  │ Visual   │  Color   │  Restore │   Code   │ │
│  │ [输入框...] [发送]     │    │  │ 🟢活跃   │  ⚪闲置   │  🟢活跃   │  🟢活跃   │ │
│  └──────────────────────┘    │  └──────────┴──────────┴──────────┴──────────┘ │
│                              │                                               │
│  [🧠 深度思考]               │  [Agent详情 - 选中展开]                          │
│  推理链路 步骤1→2→3...      │  Director: 任务分解中, 子任务4个, 进度50%         │
│                              │  [暂停] [调整] [手动干预]                        │
│  [🖼 图像生成]               │                                               │
│  prompt输入 / 上传修复       │                                               │
│                              │                                               │
│  [🎬 视频生成]               │                                               │
│  文生视频 / 图生视频 / 编辑   │                                               │
│                              │                                               │
│  [💻 代码生成]               │                                               │
│  自然语言→特效/转场/参数      │                                               │
│                              │                                               │
└──────────────────────────────┴───────────────────────────────────────────────┘
```

### 3.1 五大子面板

| 面板 | 交互 | 案例 |
|------|------|------|
| **💬 AI 聊天** | 自然语言对话 | "给这段视频加复古胶片效果" |
| **🧠 深度思考** | 推理链路可视化 | 查看 AI 如何分步推理 |
| **🖼 图像生成** | 文生图/图生图/修复 | 输入 prompt 生成 / 上传老照片修复 |
| **🎬 视频生成** | 文生视频/图生视频/编辑 | "生成一段产品展示动画, 10秒" |
| **💻 代码生成** | 会话式编程 | "创建圆形展开转场, 1秒" |

### 3.2 视频生成

视频生成面板集成主流视频生成能力：

| 能力 | 说明 |
|------|------|
| **文生视频** | 文字描述直接生成视频片段 |
| **图生视频** | 上传图片 → 动效动画 |
| **视频扩展** | 延长已有视频片段 |
| **视频风格化** | 转换视频为特定风格（动画/油画/像素） |
| **帧插值** | 慢动作补帧、帧率提升 |
| **生成结果** | 直接入轨时间线或导出 |

### 3.3 多智能体矩阵

| Agent | 角色 | 对接模块 | 默认 |
|-------|------|---------|------|
| **Director** | 导演 — 意图解析、任务分解、调度 | 全局 | 🟢 |
| **Editor** | 剪辑师 — 时间线操作 | StoryCut / ProEdit | 🟢 |
| **Audio** | 音频师 — 克隆/TTS/混音 | AudioForge | 🟢 |
| **Music** | 作曲家 — 音乐生成 | AudioForge | 🟢 |
| **Visual** | 视觉师 — 文生图/视频/特效 | EffectLab | 🟢 |
| **Color** | 调色师 — 色彩分级 | Palette | ⚪ |
| **Restore** | 修复师 — 旧照/视频帧修复 | Palette | 🟢 |
| **Code** | 程序员 — 会话式编程 | 全模块 | 🟢 |

---

## 五、StoryCut 页面 — 故事剪辑

### 定位
快速粗剪、素材浏览、故事板式操作。对标达芬奇 Cut 页面的效率理念，但交互更轻量、AI 更强。

### 布局结构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Media Pool │ Sync Bin │ Keyframes │ Transitions │ Titles │ Effects │ 项目名 │ Quick Export │ Full Screen │ Mixer │ Inspector │
│ 片段: 3 Minute Edit 1  |  源素材 TC: 00:04:18:12  |  VU电平柱                  │
├──────────────┬──────────────────────────────────┬───────────────────────────┤
│  素材浏览面板  │  监看窗口 VIEWPORT               │  电平指示面板               │
│  5列缩略图阵  │  实拍画面(满画幅)                  │  竖向电平条 -5~-50dB       │
│  [搜索]      │  [◀◀][▶][■][▶▶][🔁]              │   绿/黄/红分段             │
├──────────────┼──────────────────────────────────┼───────────────────────────┤
│ 轨道控制栏   │  故事时间线                                                 │
│ 添加/锁定/   │  总时标: 01:00:00.00 → 01:03:45.00                          │
│ 显示按钮     │  播放头: 01:02:58:07 (红色)                                 │
│              │  缩略轨道层 / 主编辑轨道层                                   │
└──────────────┴─────────────────────────────────────────────────────────────┘
```

### AI 增强
- **AI QuickCut** — 输入指令自动完成故事粗剪
- **语音转文字索引** — 自动转录，点击文字跳转
- **AI 场景标记** — 自动识别场景切换

---

## 六、ProEdit 页面 — 专业编辑

### 布局结构

```
┌──────────────────────────┬──────────────────────────────┬────────────────────┐
│ 左侧资源面板              │  中央监看窗口 VIEWPORT       │  右侧属性面板         │
│                          │                              │                     │
│ Media Pool 素材树         │  画面 + 下方关键帧控制栏       │  Tab: Video/Audio   │
│ ├─ FOLEY                 │  [◀][▶][■][🔁]              │  │ Effects/Trans    │
│ ├─ GFX                   │                              │  │ Image/File       │
│ ├─ 项目素材               │                              │                     │
│ │  └─ 选中素材 (高亮)     │                              │  Transform          │
│ └─ Smart Bins            │                              │  ├─ Zoom X/Y 1.000  │
│                          │                              │  ├─ Position X/Y    │
│ 特效工具箱               │                              │  ├─ Rotation        │
│ ├─ 视频转场              │                              │  ├─ Anchor Point    │
│ ├─ 音频转场              │                              │  ├─ Pitch/Yaw       │
│ ├─ 字幕/发生器           │                              │  └─ Flip            │
│ ├─ Open FX / 滤镜       │                              │                     │
│ ├─ 音频效果器            │                              │  Smart Reframe      │
│ └─ 收藏                  │                              │  Cropping           │
│                          │                              │  Dynamic Zoom       │
│                          │                              │  Composite          │
│                          │                              │  Speed Change       │
│                          │                              │  Stabilization      │
├──────────────────────────┴──────────────────────────────┼────────────────────┤
│  编辑时间线                                              │  右下混音面板         │
│  标尺: 01:02:16:00 → 01:02:48:00                       │                     │
│  V2 B ROLL  │  素材A002/A003                            │  A1 DYLAN  电平     │
│  V1 DYLAN   │  素材A001/A003/A005                       │  A2 SOUNDTRACK1     │
│  A1 VO      │  ▓▓▓▓▓▓▓▓▓▓ (音频波形)                    │  Bus1               │
│  A2 SOUND1  │  ▓▓▓▓▓▓▓▓ (绿色音频)                      │  [FX][EQ] [推子]     │
│  A3 SOUND2  │  ▓▓▓▓▓▓▓▓▓▓ (蓝色音频)                    │                     │
└──────────────────────────────────────────────────────────┴────────────────────┘
```

### AI 增强
- **AI 属性面板** — 自然语言调参（"让画面更暖"→自动)
- **AI 素材标记** — 自动识别内容打标签
- **AI 粗编** — 输入脚本自动匹配素材

---

## 七、Palette 页面 — 色彩工坊

### 布局结构

```
┌──────────────┬──────────────────────────────────┬─────────────────────────┐
│  参考画廊      │  监看窗口 VIEWPORT               │  节点工作台               │
│              │                                  │                         │
│ 静帧参考库    │  画面 + 下方播放控制              │  多级串并行节点网络        │
│ 风格预设      │  [◀][▶][■][🔁]                  │                         │
│ PowerGrade   │  TC: 01:14:56:13                │  预处理组: IDT/NR/美化   │
│ 项目时间线    │                                  │  调色组: 曝光/对比/白平衡 │
│              │                                  │  区域组: 分区遮罩         │
│ [缩略图网格]  │                                  │  输出→ Final Out (红色)  │
│              │                                  │                         │
├──────────────┴──────────────────────────────────┴─────────────────────────┤
│  素材条 (时间线片段快速切换)                                                │
├───────────────────────────────────────────────────────────────────────────┤
│  底部调色工具组:                                                            │
│  [色轮] 暗部/中间/亮部/全局  │  [色域映射] 色相-饱和度  │  [取色工具]  │  [波形示波器]  │
│  曝光/饱和度/色温/色调        │  六边形网格              │  曲线/吸管   │  RGB Parade    │
└───────────────────────────────────────────────────────────────────────────┘
```

### AI 增强
- **AI 色彩匹配** — 选中参考图，自动匹配色调
- **AI 风格推荐** — 电影感/日系/复古/赛博朋克
- **AI 节点生成** — 描述需求自动生成节点链路

---

## 八、AudioForge 页面 — 音频工坊

### 布局结构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Media Pool │ Effects │ Index │ Groups │ Sound Library │ ADR │ 项目名 │ Mixer │ Meters │ Inspector │
│ 多轨电平阵列  │  Bus主控  │  监听室  │  响度读数: TP/Short/Integrated/Range  │ 小预览窗 │
│ [DIM] [Pause/Reset响度]  路由: Bus→Main                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  TC: 01:01:57:00  │  音频预设  │  [◀][▶][■][🔁][●录音][⚙]                      │
│  时间轴标尺  │  播放头(红色)                                                   │
├──────────────┬──────────────────────────────────────┬───────────────────────┤
│ 轨道信息栏    │  音频波形时间线                       │  混音面板               │
│              │                                      │                       │
│ A1 Audio1   │  A1波形 ▓▓▓▓▓▓▓▓▓▓                   │  A1 [FX][DY][EQ]      │
│  A1 R/S/M   │  A3波形 ▓▓▓▓▓▓ [选中]                 │    ████ RGB电平        │
│ A2 Audio2   │  A4波形 ▓▓▓▓▓▓▓                       │    ───推子───           │
│  A2 R/S/M   │  A5波形 ▓▓▓▓▓                         │                       │
│              │                                      │  A2/A3/A4/Bus 同理     │
│              │  [悬浮插件窗]                          │                       │
│              │  空间/扩散/亮度旋钮  │  相位图谱        │                       │
│              │                                      │                       │
├──────────────┴──────────────────────────────────────┴───────────────────────┤
│  AI 音频工坊 (底部可展开面板)                                                 │
│  [语音克隆]  │  [TTS]  │  [音乐生成]  │  [降噪]  │  [混音]                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### AI 增强
- **AI 音频工坊面板** — 内嵌在底部可展开，含语音克隆/TTS/音乐生成/降噪/自动混音
- **AI 配乐推荐** — 根据画面情绪自动推荐

### 实现现状

以下模块已在 P0 阶段完成代码实现，非纯方案：

| 模块 | 路径 | 状态 | 说明 |
|------|------|------|------|
| **AudioEngine 编排层** | `modules/audio/audio_engine.py` | ✅ 完成 | 统一 TTS/Music 提供者注册、发现、调用 |
| **Edge-TTS 集成** | `modules/audio/providers/edge_tts.py` | ✅ 真实 | 17 种语音，`list_voices()` / `synthesize()` 真实合成 MP3 |
| **Suno 桩** | `modules/audio/providers/suno.py` | ✅ 桩 | mock 返回，待 API Key 后可激活 |
| **MusicGen 桩** | `modules/audio/providers/musicgen.py` | ✅ 桩 | stub 返回，需 PyTorch |
| **API Server** | `modules/api_server/` | ✅ 完成 | Flask HTTP, 22 端点, 端口 8899 |
| | | | 端点：`/api/v1/tts`, `/api/v1/tts/voices`, `/api/v1/tts/providers`, `/api/v1/music`, `/api/v1/music/styles`, `/api/v1/music/providers`, `/api/v1/audio/info`, `/api/v1/health`, `/api/v1/info`, `/api/v1/hardware`, `/api/v1/locale`, `/api/v1/locale/set`, `/api/v1/translate` 等 |

---

## 九、EffectLab 页面 — 特效工坊

### 布局结构

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Media Pool │ Effects │ Clips │ Nodes │ 项目名 │ Spline │ Keyframes │ Inspector │
│ 缩放  │  预览视口名  │  输出视口  │  预设  │  分辨率                                      │
├──────────────┬──────────────────────────────┬─────────────────────────────────┤
│ 左预览视口    │  中央输出视口                 │  右侧检查器                      │
│ 孤立特效元素  │  合成成片画面                │  Tools / Modifiers              │
│              │  画面+坐标标识                │  Global In/Out / 当前帧          │
│              │                              │  [Controls][Image][Settings]    │
│              │                              │  Camera:Default│Eye:Mono       │
│              │                              │  Renderer 参数                  │
├──────────────┴──────────────────────────────┴─────────────────────────────────┤
│  帧时间轴: 32~78帧 │ 入点13.0│出点58.0│当前43.0│ [◀◀][▶][■][🔁]                    │
├──────────────────────────────────────────────────────────────────────────────┤
│  节点工作台 (核心区域)                                                         │
│                                                                              │
│  ┌──┐    ┌──┐    ┌──┐    ┌──┐                                                │
│  │M1│───→│N2│───→│M3│───→│M4│───→ MediaOut                                    │
│  └──┘    └──┘    └──┘    └──┘                                                │
│            ↑                                                                  │
│          ┌──┐  多色节点 + 连线锚点                                              │
│          │N1│  (分支并行链路)                                                   │
│          └──┘                                                                 │
│                                                                              │
│  右击节点 → [AI 生成] [编辑参数] [替换节点]                                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

### AI 增强
- **AI 节点生成** — "给车尾加火焰爆炸"→自动生成节点链路
- **AI 特效推荐** — 根据画面内容推荐
- **代码生成集成** — 会话式编程生成自定义特效

---

## 十、模型设置（Model Config）

> 🚧 本模块目前为框架设计阶段。模型设置是全局配置中心，让用户选择、切换、管理所有 AI 模块的后端模型和 API 提供商。

### 设计理念

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  模型设置  [← 全局可用，可从顶栏齿轮图标或 AI Agent 页进入]                    │
├───────────────────────


│                     ┌────────────────────────────────────────────────────┐  │
│                     │  ┌─ AI 聊天 ───────────────────────────────────┐ │  │
│                     │  │  [▼ 选择模型]  ┌────────────────────────┐  │ │  │
│                     │  │              │ GPT-4o ● (当前)          │  │ │  │
│                     │  │              │ Claude 4 Sonnet          │  │ │  │
│                     │  │              │ DeepSeek V3              │  │ │  │
│                     │  │              │ Llama 3.3 70B (本地)     │  │ │  │
│                     │  │              │ 自定义...                │  │ │  │
│                     │  │              └────────────────────────┘  │ │  │
│                     │  │  上下文窗口: 128K │ 温度: 0.7 [━━━━●━━━━]│  │ │  │
│                     │  │  系统提示词模板: [编辑] [恢复默认]        │  │ │  │
│                     │  ├─────────────────────────────────────────┤ │  │
│                     │  ├─ 图像生成 ──────────────────────────┐   │ │  │
│                     │  │  [▼ 选择引擎]  Stable Diffusion XL   │   │ │  │
│                     │  │  默认分辨率: 1024×1024              │   │ │  │
│                     │  ├──────────────────────────────────────┤   │ │  │
│                     │  ├─ 视频生成 ──────────────────────────┐   │ │  │
│                     │  │  [▼ 选择引擎]  Runway Gen-4         │   │ │  │
│                     │  │  最大时长: 10s                      │   │ │  │
│                     │  ├──────────────────────────────────────┤   │ │  │
│                     │  ├─ 音频生成 ──────────────────────────┐   │ │  │
│                     │  │  TTS: [Edge TTS / OpenAI TTS]       │   │ │  │
│                     │  │  音乐生成: [Suno / MusicGen]        │   │ │  │
│                     │  ├──────────────────────────────────────┤   │ │  │
│                     │  ├─ 图像修复 ──────────────────────────┐   │ │  │
│                     │  │  [▼ 选择引擎]  GFPGAN / Real-ESRGAN │   │ │  │
│                     │  │  修复强度: [━━━●━━━]                │   │ │  │
│                     │  ├──────────────────────────────────────┤   │ │  │
│                     │  └─ API 配置 ─────────────────────────┐ │   │ │
│                     │     ┌────────────────────────────────┐ │   │ │
│                     │     │ OpenAI Key:  ***************   │ │   │ │
│                     │     │ Anthropic Key: ************    │ │   │ │
│                     │     │ 本地模型路径: /models/... [浏览]│ │   │ │
│                     │     │ 代理设置: [不使用 / HTTP / SOCKS5]│  │   │ │
│                     │     └────────────────────────────────┘ │   │ │
│                     │                                        │   │ │
│                     │  [应用] [恢复默认]                      │   │ │
│                     └────────────────────────────────────────┘   │ │
│                                                                   │ │
└───────────────────────────────────────────────────────────────────────┘

### 配置文件结构

```yaml
# ~/.phantomvox/config.yaml (示例)
llm:
  provider: openai
  model: gpt-4o
  temperature: 0.7
  max_tokens: 4096

image:
  engine: stable-diffusion
  provider: local
  model: sdxl-turbo
  resolution: [1024, 1024]

video:
  engine: runway
  api_key: "sk-xxx"
  max_duration: 10

audio:
  tts:
    engine: edge-tts
    voice: zh-CN-Xiaoxiao
  clone:
    engine: cosyvoice
  music:
    engine: musicgen
    model: musicgen-medium

restore:
  face: gfpgan
  superres: realsrgan
  strength: 0.8
```

---

## 十一、FFmpeg 引擎层 — 音视频处理核心

> 所有 5 个页面的音视频操作，底层均由 FFmpeg 引擎驱动。FFmpeg 不是"一个页面"，而是**整个应用的音视频骨骼**。

### 9.1 FFmpeg 引擎架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PhantomVox FFmpeg Engine                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─ Demuxer (解封装) ───────────────────────────────────────────────────┐  │
│  │  输入源: MP4/MOV/MKV/AVI/MTS/BRAW/WAV/MP3/FLAC/OGG                  │  │
│  │  自动检测: 编码格式/分辨率/帧率/码率/声道/采样率                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│  ┌─ Decoder (解码) ─────────────────────────────────────────────────────┐  │
│  │  视频: H.264/H.265/VP9/AV1/ProRes/DNxHD                              │  │
│  音频: AAC/MP3/PCM/FLAC/Opus/Vorbis                                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│  ┌─ Filter Graph (滤镜图) ───────────────────────────────────────────────┐ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐              │ │
│  │  │视频滤镜链 │→ │音频滤镜链 │→ │叠加合成   │→ │编码输出   │              │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘              │ │
│  │                                                                       │ │
│  │  视频滤镜: scale/crop/rotate/overlay/drawtext/fade/colorbalance/...   │ │
│  │  音频滤镜: volume/equalizer/pan/adelay/amix/afftdn/loudnorm/...      │ │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│  ┌─ Muxer (封装输出) ───────────────────────────────────────────────────┐  │
│  │  导出: MP4(H.264/H.265) / MOV(ProRes) / GIF / WebM / WAV / MP3      │  │
│  │  参数: 分辨率/码率/帧率/质量预设/像素格式                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 五个模块的 FFmpeg 映射

对照 CSV 数据中每个模块的核心控件，映射到 FFmpeg 实现：

#### StoryCut / ProEdit — 时间线编辑

| 控件 (来自CSV) | FFmpeg 实现 |
|---------------|------------|
| 轨道 V1/V2/V3/V4 视频轨道 | `overlay` 滤镜叠层 + `concat` 拼接 |
| 轨道 A1/A2/A3 音频轨道 | `amix` 多路混音 + `volume` 音量控制 |
| 播放头/时间标尺 | `-ss` seek + `-t` duration 精确截取 |
| 切割/裁剪 | `trim` 滤镜（视频）+ `atrim`（音频） |
| 变速 Speed Change | `setpts`（视频速度）+ `atempo`（音频速度） |
| 转场 Transitions (Dissolve/Iris) | `xfade` 过渡滤镜（dissolve/fade/slide/wipes） |
| 关键帧 Keyframes | `select` 滤镜提取关键帧 + 参数插值 |
| Zoom X/Y / Position X/Y | `zoompan` 动效缩放 + `crop` 裁剪 |
| Rotation / Pitch / Yaw | `rotate` + `perspective` 透视变换 |
| Flip 翻转 | `hflip` / `vflip` |
| Opacity 透明度 | `format=rgba` + `colorchannelmixer` |
| Cropping | `crop` 滤镜（精确像素/百分比） |
| Stabilization | `vidstabdetect` + `vidstabtransform` |
| Lens Correction | `lenscorrection` 镜头畸变校正 |

#### Palette — 色彩工坊

| 控件 (来自CSV) | FFmpeg 实现 |
|---------------|------------|
| 色轮: Black/Dark/Shadow/Global | `colorbalance` 暗部/中间/亮部色彩调整 |
| 色温/色调 Temp/Tint | `colorchannelmixer` 通道混合 |
| 曝光 Exposure | `exposure` 或 `eq` 滤镜的 brightness/contrast |
| 饱和度 Saturation | `eq` 滤镜 saturation 参数，或 `hue` 滤镜 |
| Color Warper 色相六边形 | `hue` H 偏移 + `colorchannelmixer` |
| LUT 应用 | `lut3d` 直接加载 .cube/.3dl 文件 |
| RGB Parade 示波器 | `waveform` 滤镜 + `vectorscope` |
| 节点串并行链路 | 多个 filter 链用 `;` 分隔并行，`,` 串联 |

#### AudioForge — 音频工坊

| 控件 (来自CSV) | FFmpeg 实现 |
|---------------|------------|
| VU 电平表 (1~27轨) | `volumedetect` 分析 + `ebur128` 响度分析 |
| Bus1 路由 → Main | `amix` 混音路由矩阵 |
| DIM 衰减开关 | `volume=volume=-20dB` |
| 响度读数 TP/Short/Integrated | `loudnorm=I=-23:LRA=7:TP=-2` |
| FX/Dynamics/EQ 通道 | 多滤镜串联: `afftdn`(降噪) → `compand`(压缩) → `equalizer`(均衡) |
| Width 立体声宽度 | `stereotools=mcl=0:mode=ms` 或 `extrastereo` |
| Diffusion/Sparkle | `aphaser` + `equalizer` 高频提升 |
| 相位图谱 Scope | `aphasemeter` 生成相位数据 →UI 渲染扇形图 |
| 录音功能 | `-f alsa` 或 `-f avfoundation` 采集 |
| ADR 配音录制 | `ffmpeg -f pulse -i default -acodec pcm_s16le` |

#### EffectLab — 特效合成

| 控件 (来自CSV) | FFmpeg 实现 |
|---------------|------------|
| 节点树 Node Canvas | **复杂 filter graph** - 每个节点=一个滤镜/一组滤镜 |
| uMerge1 合并视口 | `overlay` 叠加 |
| MediaOut 输出 | 最终 filter chain 输出 |
| Renderer3D1 3D渲染 | 3D→2D 投影 + `perspective` 或调用 OpenGL |
| Global In/Out | `trim=start:end` |
| Camera / Eye | 坐标变换矩阵 + `perspective` |
| Anti-Aliasing | `pp=al` 后处理抗锯齿 |
| Lighting | `colorbalance` + `eq` 亮度模拟 |
| Wireframe | `edgedetect` 边缘检测 + `overlay` |
| Shading Model | `hue` + `colorbalance` 材质质感模拟 |
| RGBA / Z / Vector 通道 | 多 filter 分支并行，`split` 分离通道 |

### 9.3 FFmpeg 时间线渲染管线

这是整个应用最核心的渲染流程：

```
用户操作 (拖拽/切割/特效)
       │
       ▼
时间线状态 →  Clip列表 (每段clip有时基+入出点+特效链)
       │
       ▼
Filter Graph 构建器 → 生成 FFmpeg 命令行
       │
       ▼
    ┌─────────────────────────────────────────────┐
    │  示例: 两个视频片段+转场+音频混音             │
    │                                             │
    │  ffmpeg                                      │
    │    -i clip1.mp4 -i clip2.mp4                  │
    │    -filter_complex "                          │
    │      [0:v]trim=0:5,setpts=PTS[cl1v];          │
    │      [0:a]atrim=0:5,asetpts=PTS[cl1a];        │
    │      [1:v]trim=0:3,setpts=PTS[cl2v];          │
    │      [1:a]atrim=0:3,asetpts=PTS[cl2a];        │
    │      [cl1v][cl2v]xfade=d=1:offset=4[vout];    │
    │      [cl1a][cl2a]acrossfade=d=1[audio_out]"   │
    │    -map "[vout]" -map "[audio_out]" output.mp4 │
    └─────────────────────────────────────────────┘
       │
       ▼
    ┌──────────────┐    ┌──────────────┐
    │  实时预览     │    │  后台渲染导出  │
    │  (pipe帧→UI)  │    │  (完整精度)   │
    └──────────────┘    └──────────────┘
```

### 9.4 代码生成 ↔ FFmpeg 映射

AI Agent 的代码生成模块，本质上是将自然语言翻译为 FFmpeg filter graph：

```
用户说: "加一个圆形展开转场"
  → Code Agent 生成:
    xfade=transition=circleopen:duration=1:offset=4

用户说: "低音降3dB高音提2dB"
  → Code Agent 生成:
    equalizer=f=250:t=q:w=1:g=-3,equalizer=f=8000:t=q:w=1:g=2

用户说: "给视频叠加VHS复古效果"
  → Code Agent 生成复合滤镜链:
    curves=vintage,noise=alls=30:allf=t+u,hue=h=20:s=-30,
    drawbox=x=6:y=4:w=iw-12:h=ih-8:color=black@0.1
```

### 9.5 预渲染缓存策略

| 场景 | 策略 |
|------|------|
| 实时预览（拖动播放头） | 关键帧缓存 + 低分辨率代理渲染 |
| 特效调整（参数变化） | 只重新渲染受影响的 clip 片段 |
| 最终导出 | 全分辨率完整渲染 |
| AI 生成预览 | 先低质量快速出片，确认后高质量重渲染 |

---

## 十二、全局菜单栏（Global Menu）

> 所有七个工作区共享的全局菜单栏，位于窗口最顶部。PhantomVox 遵循专业软件惯例，但菜单项针对 AI 音视频创作做了定制。

### 10.1 菜单栏布局

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ PhantomVox  │  智体(A)  │  文件(F)  │  编辑(E)  │  视图(V)  │  素材(M)  │  工具(T)  │  窗口(W)  │  帮助(H)  │
│   [● ● ●]   │           │          │          │           │           │          │           │           │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 各菜单详细

#### 智体 (AI — PhantomVox 核心入口)

> 所有创作从这里开始。用户在智体菜单中启动 AI 对话、生成素材、编排流程，再进入具体编辑页面精调。

```
智体(A)
├── AI 智能体面板       Ctrl+Shift+Space → 打开 AI Agent 页面
├── ────────────
├── 智能场景检测                     → AI 自动分析素材并标记场景
├── 智能素材标记                     → AI 自动识别素材内容类型
├── 智能颜色匹配                     → AI 匹配参考画面色调
├── ────────────
├── 一键成片            ▸
│   ├── 根据脚本创建                  → 输入脚本文字，AI 自动匹配素材
│   ├── 根据语音创建                  → 导入语音，AI 自动对口型
│   └── 根据图片创建                  → 导入图片集，AI 自动编排
├── ────────────
├── AI 模型设置                      → 跳转到模型设置页
└── 禁用所有 AI                      → 一键切换为纯手动模式
```

#### 文件 (File)

```
文件(F)
├── 新建项目           Ctrl+N        → 弹出项目设置对话框（名称/分辨率/帧率/时长）
├── 打开项目           Ctrl+O        → 浏览 .phantomvox 项目文件
├── 最近项目           ▸
│   ├── project_001.phantomvox
│   ├── my_film_edit.phantomvox
│   └── 清除列表
├── ────────────
├── 保存               Ctrl+S        → 保存当前项目
├── 另存为...          Ctrl+Shift+S   → 另存为新项目文件
├── 保存为模板         ▸             → 将当前时间线保存为可复用的模板
├── ────────────
├── 导入               ▸
│   ├── 媒体文件...     Ctrl+I       → 浏览导入音视频/图片文件
│   ├── 素材文件夹...                 → 导入整个素材文件夹
│   ├── 项目文件...                   → 导入其他 .phantomvox 项目
│   ├── LUT/色彩预设                 → 导入 .cube/.3dl 调色文件
│   ├── 字幕文件...                   → 导入 .srt/.ass 字幕
│   └── XML/EDL 时间线               → 从达芬奇/Premiere 导入工程
├── 导出               ▸
│   ├── 视频...          Ctrl+E      → 导出设置对话框（格式/分辨率/码率）
│   ├── 音频...                      → 仅导出音频轨道
│   ├── 当前帧截图                   → 导出当前帧为 PNG/JPEG
│   ├── 字幕文件...                  → 导出时间线字幕
│   └── 项目归档...                  → 打包所有素材+项目为 ZIP
├── ────────────
├── 项目设置                        → 分辨率/帧率/音频采样率/渲染格式
├── 模型设置                        → AI 模型引擎配置（跳转到全局设置）
└── 退出               Alt+F4
```

#### 编辑 (Edit)

```
编辑(E)
├── 撤销               Ctrl+Z        → 多级撤销（支持50步）
├── 重做               Ctrl+Y        → 重新执行撤销的操作
├── ────────────
├── 剪切               Ctrl+X
├── 复制               Ctrl+C
├── 粘贴               Ctrl+V
├── 删除               Delete
├── 全选               Ctrl+A
├── ────────────
├── 分割片段           Ctrl+B        → 在播放头位置分割当前选中 clip
├── 波纹删除           Shift+Del     → 删除并合并空隙
├── 修剪开头           Q             → 将播放头位置设为片段新起点
├── 修剪结尾           W             → 将播放头位置设为片段新终点
├── ────────────
├── 素材属性                        → 打开选中素材的属性面板
└── 快捷键参考          Ctrl+/       → 弹出快捷键速查表
```

#### 视图 (View)

```
视图(V)
├── 工作区布局          ▸
│   ├── 默认布局                     → 恢复出厂布局
│   ├── 紧凑模式                     → 隐藏侧边栏，最大化时间线
│   ├── 双屏模式                     → 监看窗口投射到第二显示器
│   └── 保存当前布局                  → 保存自定义布局
├── ────────────
├── 显示               ▸
│   ├── 工具栏           ✓           → 顶部工具栏显示/隐藏
│   ├── 状态栏           ✓           → 底部状态栏显示/隐藏
│   ├── 标尺             ✓           → 时间线标尺显示/隐藏
│   ├── 波形图           ✓           → 音频轨道波形显示/隐藏
│   ├── 缩略图           ✓           → 视频轨道缩略图显示/隐藏
│   └── 特效控制栏                    → 底部特效参数栏显示/隐藏
├── ────────────
├── 时间线缩放          ▸
│   ├── 放大             Ctrl+=      → 时间线缩放 +1 级
│   ├── 缩小             Ctrl+-      → 时间线缩放 -1 级
│   ├── 适配窗口         Shift+Z     → 整条时间线适配窗口宽度
│   └── 适配片段         Z           → 选中片段适配窗口宽度
├── ────────────
├── 全屏               F11           → 全屏监看窗口
└── 暗色主题/亮色主题                  → 界面主题切换
```

#### 素材 (Media)

```
素材(M)
├── 分析素材                        → 扫描选中素材（时长/编码/场景标记）
├── 转码为代理                       → 创建低分辨率代理文件加速编辑
├── 替换素材                         → 用新文件替换时间线中的素材
├── 创建            ▸
│   ├── 新复合片段                   → 将多段选中clip合并为一个复合片段
│   ├── 新调整图层                   → 创建跨轨道的特效调整层
│   └── 新颜色 Matte                → 创建纯色/渐变背景层
├── ────────────
├── 标记             ▸
│   ├── 添加标记         M           → 在当前时间位置添加标记点
│   ├── 标记为入点        I           → 设置选中片段入点
│   ├── 标记为出点        O           → 设置选中片段出点
│   └── 清除标记                     → 清除所有标记
├── ────────────
└── 素材信息                         → 查看选中素材的详细元数据
```

#### 工具 (Tools)

```
工具(T)
├── 创作流图谱            Ctrl+Shift+F  → 打开 Flow Graph 创作流面板
├── 音频工坊             Ctrl+Shift+A  → 打开 AudioForge 音频工坊面板
├── 图像修复             Ctrl+Shift+R  → 打开 AI 图像修复面板
├── 批量处理                         → 批量转码/修复/导出
├── ────────────
├── 旁白录制                         → 启动录音面板（对接 AudioForge）
├── 屏幕录制                         → 录制屏幕作为素材
├── ────────────
├── 时间线统计                       → 统计当前时间线的 clip/特效/时长
├── 媒体管理                         → 管理所有素材（移动/删除/重链）
└── 检查更新                         → 检查 PhantomVox 新版本
```

#### 窗口 (Window)

```
窗口(W)
├── 工作区切换          ▸
│   ├── Flow Graph      Ctrl+7      → 创作流图谱
│   ├── AI Agent        Ctrl+6      → 智能体页面
│   ├── StoryCut        Ctrl+1      → 故事剪辑页面
│   ├── ProEdit         Ctrl+2      → 专业编辑页面
│   ├── Palette         Ctrl+3      → 色彩工坊页面
│   ├── AudioForge      Ctrl+4      → 音频工坊页面
│   └── EffectLab       Ctrl+5      → 特效工坊页面
├── ────────────
├── 面板管理            ▸
│   ├── 资源库           ✓
│   ├── 属性面板          ✓
│   ├── 混音面板          ✓
│   ├── 创作流图谱       ✓
│   └── 重置所有面板位置
├── ────────────
└── 切换到此工作区                    → 最近使用的页面列表
```

#### 帮助 (Help)

```
帮助(H)
├── 用户手册            F1            → 打开在线文档
├── 视频教程                         → 跳转到教程列表
├── ────────────
├── 快捷键参考                       → 快捷键速查表
├── 反馈问题                         → 提交 Bug/建议
├── ────────────
├── 关于 PhantomVox                   → 版本号/许可证/致谢
├── 检查更新                         → 自动更新检测
└── 系统信息                         → 硬件/GPU/内存/FFmpeg 版本
```

### 10.3 快捷键体系

```
常用编辑:  Ctrl+Z/Y/X/C/V   撤销/重做/剪切/复制/粘贴
项目操作:  Ctrl+N/O/S       新建/打开/保存
时间线:    Ctrl+B           分割
           Q / W            修剪开头/结尾
           I / O            入点/出点
           M                标记
           空格              播放/暂停
           ← →              前一帧/后一帧
           ↑ ↓              上一轨道/下一轨道
缩放:      Ctrl+= / Ctrl+-  放大/缩小
           Z                适配片段
           Shift+Z          适配全部
页面切换:  Ctrl+1~7          切换7个工作区
智体:      Ctrl+Shift+Space  打开 AI Agent
           Ctrl+Shift+F      打开 Flow Graph
           Ctrl+Shift+A      打开音频工坊
           Ctrl+Shift+R      打开图像修复
导出:      Ctrl+E            导出视频
帮助:      F1 / Ctrl+/      帮助/快捷键
```

### 10.4 右键上下文菜单

每个核心区域有独立的右键菜单：

| 区域 | 右键菜单项 |
|------|-----------|
| **时间线轨道** | 添加轨道/删除轨道/重命名/轨道颜色/锁定轨道/静音轨道/Solo |
| **时间线 Clip** | 剪切/复制/删除/分割/替换素材/变速/冻结帧/添加特效 |
| **素材库项目** | 导入/预览/添加到时间线/替换/删除/属性 |
| **调色节点** | 添加串行节点/添加并行节点/删除节点/禁用节点/重置/保存为预设 |
| **混合推子** | 添加 FX/添加 EQ/重置推子/复制通道/Solo |
| **Flow Graph 节点** | 执行/暂停/取消/编辑参数/回溯/展开分支/保存为模板 |
| **Agent 列表** | 激活/禁用/查看详情/分配任务/查看日志 |

---

## 十七、PhantomVox 模块命名对照

| 达芬奇名称 | PhantomVox 名称 | 说明 |
|-----------|----------------|------|
| Cut | **StoryCut** | 故事剪辑 |
| Edit | **ProEdit** | 专业编辑 |
| Color | **Palette** | 调色板 |
| Fairlight | **AudioForge** | 音频锻造 |
| Fusion | **EffectLab** | 特效实验室 |
| (无) | **Flow Graph** | 创作流图谱 — 工作流编排 |
| (无) | **AI Agent** | 智能体中心 |
| Media Pool | **资源库** | 素材管理 |
| Viewer | **视窗/Viewport** | 监看窗口 |
| Inspector | **属性面板** | 参数检查器 |
| Timeline | **时间线** | 保持原名（通用） |
| Mixer | **混音面板** | 调音台 |
| Node | **节点工作台** | 节点编辑区 |

---

## 十三、账户与订阅系统

### 11.1 登录/注册入口

#### 入口位置

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PhantomVox  │  文件  │  编辑  │  ...  │  帮助  │  [未登录 ● 登录/注册]  │
│   LOGO      │        │       │       │        │                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

右上角头像区域：

| 状态 | 显示 | 点击行为 |
|------|------|---------|
| **未登录** | [头像占位图标] 登录/注册 | 弹出登录对话框 |
| **已登录（免费版）** | 用户头像 + 小字 "Free" | 弹出用户菜单 |
| **已登录（订阅版）** | 用户头像 + 小字 "Pro" | 弹出用户菜单 |
| **已登录（试用中）** | 用户头像 + 小字 "Trial X天" | 弹出用户菜单 |

#### 登录对话框

```
┌──────────────────────────────────────┐
│           登录 PhantomVox              │
│                                      │
│  ┌──────────────────────────────────┐│
│  │ 邮箱 / 用户名                     ││
│  └──────────────────────────────────┘│
│  ┌──────────────────────────────────┐│
│  │ 密码                              ││
│  └──────────────────────────────────┘│
│                                      │
│  [✓] 记住我                           │
│                                      │
│  [          登录          ]           │
│                                      │
│  ─────── 或使用以下方式登录 ────────   │
│                                      │
│  [微信登录] [Github登录] [Google登录]   │
│                                      │
│  还没有账号？[注册]  │  [忘记密码]      │
└──────────────────────────────────────┘
```

#### 用户菜单（点击头像）

```
┌──────────────────────┐
│  user@email.com      │
│  ── Free Plan ──     │
│                      │
│  [升级到 Pro]  ← 订阅入口  │
│  ────────────          │
│  账户设置              │
│  订阅管理              │
│  我的云素材              │
│  ────────────          │
│  偏好设置              │
│  ────────────          │
│  退出登录              │
└──────────────────────┘
```

### 11.2 订阅模式设计

```
方案: Freemium + 分层订阅
├── Free（免费版）
│   ├── 基础剪辑功能（StoryCut / ProEdit 基础）
│   ├── 2 条视频轨道 / 2 条音频轨道
│   ├── AI 聊天 50 次/月
│   ├── 导出 1080p (带水印)
│   └── 无云存储
│
├── Pro（专业版） — ¥XX/月 或 ¥XXX/年
│   ├── 不限轨道数
│   ├── AI 聊天不限次
│   ├── 图像生成/修复（含云端算力 1000点/月）
│   ├── 视频生成（含云端算力 500点/月）
│   ├── 音频工坊全套（克隆/TTS/音乐生成）
│   ├── 导出 4K 无 watermark
│   ├── 50GB 云存储
│   └── 优先技术支持
│
watermark
│   ├── 50GB 云存储
│   └── 优先技术支持
│
├── Studio（工作室版） — ¥XXX/月
│   ├── Pro 全部功能
│   ├── AI 云端算力不限量
│   ├── 8K 导出
│   ├── 500GB 云存储
│   ├── 团队协作（多用户时间线）
│   ├── 批量处理
│   └── 专属客户经理
│
└── 一次性买断（Perpetual） — ¥XXXX
    ├── 当前版本永久使用
    ├── 不含云端 AI 算力
    ├── 不含云存储
    ├── 不含升级
    └── 可加购年度 AI 算力包
```

#### 功能与订阅映射表

| 功能模块 | Free | Pro | Studio | 买断 |
|---------|------|-----|--------|------|
| 基础编辑（StoryCut/ProEdit） | ✅ 2轨 | ✅ 不限 | ✅ 不限 | ✅ 不限 |
| Palette 色彩工坊 | ❌ | ✅ | ✅ | ✅ |
| AudioForge 基础 | ✅ 2轨 | ✅ 不限 | ✅ 不限 | ✅ 不限 |
| AI 音频工坊（克隆/TTS/音乐） | ❌ | ✅ | ✅ | ⚪ 需加购算力包 |
| AI 聊天 | 50次/月 | 不限 | 不限 | ❌ |
| 图像生成/修复 | ❌ | 1000点/月 | 不限 | ⚪ 需加购 |
| 视频生成 | ❌ | 500点/月 | 不限 | ❌ |
| EffectLab 特效 | ❌ | ✅ | ✅ | ✅ |
| Flow Graph 创作流 | ✅ 基础 | ✅ 完整 | ✅ 完整 | ✅ 本地 |
| 代码生成 | ❌ | ✅ | ✅ | ✅ |
| 模型设置自定义 | ❌ | ✅ 云端API | ✅ 不限 | ✅ 仅本地 |
| 导出分辨率 | 1080p(水印) | 4K | 8K | 4K |
| 云存储 | 0 | 50GB | 500GB | 0 |
| 团队协作 | ❌ | ❌ | ✅ | ❌ |
| 批量处理 | ❌ | ❌ | ✅ | ❌ |
| 技术支持 | 社区 | 邮件 | 专属 | 社区 |

### 11.3 订阅管理页面

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  订阅管理                                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  当前方案: Free Plan                                                         │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  您当前使用的是免费版                                                  │  │
│  │  AI 聊天剩余: 32/50 次 (本月)                                        │  │
│  │  导出无水印: ❌                                                       │  │
│  │  4K 导出: ❌                                                          │  │
│  │                                                                       │  │
│  │  [升级到 Pro - ¥XX/月]   [升级到 Studio - ¥XXX/月]                     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  历史账单                                                                   │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ 无历史记录                                                             │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  兑换激活码 [输入框] [兑换]                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.4 离线/本地模式

PhantomVox 支持**完全离线使用**：
- 无需登录即可使用基础编辑功能
- AI 功能降级为纯本地模型（需用户在模型设置中配置）
- 订阅检查仅在使用云端算力时触发
- 买断版永久离线可用

---

## 十四、版本与升级系统

### 12.1 版本号规范

```
PhantomVox v1.2.3 (Build 20260603)
          │  │  │       └── 构建日期 YYYYMMDD
          │  │  └──────── 补丁号（Bug 修复/小优化）
          │  └─────────── 次版本号（功能增量更新）
          └────────────── 主版本号（架构级更新）
```

| 版本级别 | 变更范围 | 升级方式 | 收费 |
|---------|---------|---------|------|
| **主版本** 1→2 | 架构重写/重大 UI 重构 | 手动下载 | 可能收费升级 |
| **次版本** 1.2→1.3 | 新功能/新模块 | 自动检测 | 订阅期内免费 |
| **补丁** 1.2.3→1.2.4 | Bug 修复/性能优化 | 静默自动 | 免费 |
| **每日构建** | 内测功能 | 手动切换通道 | 仅内部/内测用户 |

### 12.2 更新机制

#### 自动更新检测

```
应用启动 → 后台检查更新
              │
       ┌──────┴──────┐
       │              │
    有更新          无更新
       │              │
       ▼              ▼
┌─────────────────┐  ┌──────────┐
│ 发现新版本 v1.3.0 │  │ 已是最新  │
│                  │  └──────────┘
│ 当前: v1.2.0     │
│ 更新内容:         │
│ • 新增 AI 音频工坊 │
│ • 优化渲染速度30%  │
│ • 修复 12 个 Bug  │
│                  │
│ [立即更新] [稍后]   │
│ [忽略此版本]       │
└─────────────────┘
```

#### 更新渠道

| 渠道 | 说明 | 推送频率 | 稳定性 |
|------|------|---------|--------|
| **Stable** | 稳定版，公众使用 | 每月 | ★★★★★ |
| **Beta** | 新功能预览，有 Bug 风险 | 每周 | ★★★ |
| **Alpha** | 每日构建，仅供测试 | 每日 | ★ |
| **LTS** | 长期支持版，企业/买断用户 | 季度安全更新 | ★★★★★ |

#### 设置页面 — 更新配置

```
┌─ 更新设置 ─────────────────────────────────────┐
│ 更新渠道: [Stable ▼]                            │
│ 自动检查更新: [✓]                               │
│ 自动下载更新: [✓] (仅非高峰期)                   │
│ 自动安装:     [ ] (推荐手动确认后安装)             │
│                                                │
│ [立即检查更新]  [查看更新历史]                    │
│                                                │
│ 上次检查: 2026-06-03 14:30                      │
│ 当前版本: PhantomVox v0.6.0 (Build 20260603)    │
│ 许可证: Free Plan / 到期: 无                    │
└────────────────────────────────────────────────┘
```

### 12.3 关于对话框

```
┌────────────────────────────────────────────┐
│             关于 PhantomVox                  │
│                                            │
│           [PhantomVox LOGO]                 │
│                                            │
│   PhantomVox AI v0.6.0                     │
│   Build 20260603                           │
│                                            │
│   魅影音画 — AI 智能创作平台                 │
│                                            │
│   License: Free Plan                       │
│   (订阅用户: Pro / Studio / 买断)           │
│                                            │
│   FFmpeg 版本: 7.1                         │
│   Python 版本: 3.12                        │
│   系统: Windows 11 / macOS 15 / Linux 6.17  │
│   GPU: NVIDIA RTX 4090 (CUDA 12.4)         │
│                                            │
│   ──────────────────────────────────────    │
│                                            │
│   开发团队: PhantomVox Studio               │
│   许可证: MIT (核心) / 商业 (Premium 模块)   │
│   特别感谢: FFmpeg / PyTorch / ...          │
│                                            │
│   [检查更新]  [许可证]  [致谢]  [关闭]       │
└────────────────────────────────────────────┘
```

### 12.4 激活码与离线激活

| 场景 | 方式 |
|------|------|
| **在线激活** | 登录账户后自动验证订阅状态 |
| **离线激活** | 生成机器码 → 在另一台设备获取激活码 → 输入激活 |
| **企业批量** | 企业管理员后台批量生成激活码 |
| **试用激活** | 注册即获得 14 天 Pro 试用（不限支付方式） |
| **教育优惠** | 教育邮箱(.edu)验证后获得教育版折扣 |

## 十五、国际化系统 (i18n)

### 13.1 系统架构

> PhantomVox AI 内置系统级国际化基础设施，所有 UI 字符串通过键值查找，支持运行时热切换。**这不是方案，是实际代码基础设施。**

```
Locale 检测:
  ├── 环境变量 LANG / LC_ALL
  ├── Python locale.getdefaultlocale()
  └── 用户偏好 ~/.phantomvox/locale.json (持久化)

I18nManager (模块 / 单例)
  ├── 加载 JSON 词库 (懒加载, 支持热重载)
  ├── 键解析: dot 路径递归拍平
  ├── 插值: {placeholder} 模板语法
  ├── 复数: key.one / key.many + count 自动选择
  ├── 回退链: 目标语言 → en (fallback) → 键名
  └── 事件: locale_changed 监听器模式
```

### 13.2 已安装语言包

目前内置 **15 种语言**，覆盖全球主要视频创作市场：

| 语言 | 代码 | 旗标 | 区域 |
|------|------|------|------|
| **简体中文** | zh_CN | 🇨🇳 | 中国大陆 |
| **繁體中文** | zh_TW | 🇭🇰 | 港澳台/海外华人 |
| **English** | en | 🇬🇧 | 全球 (base fallback) |
| **Español** | es | 🇪🇸 | 西班牙/拉丁美洲 |
| **Português (Brasil)** | pt_BR | 🇧🇷 | 巴西 |
| **Français** | fr | 🇫🇷 | 法国/欧洲 |
| **Deutsch** | de | 🇩🇪 | 德国/奥地利/瑞士 |
| **Italiano** | it | 🇮🇹 | 意大利 |
| **日本語** | ja | 🇯🇵 | 日本 |
| **한국어** | ko | 🇰🇷 | 韩国 |
| **Русский** | ru | 🇷🇺 | 俄罗斯/独联体 |
| **العربية** | ar | 🇸🇦 | 中东/北非 |
| **Tiếng Việt** | vi | 🇻🇳 | 越南 |
| **ไทย** | th | 🇹🇭 | 泰国 |
| **Bahasa Indonesia** | id | 🇮🇩 | 印度尼西亚 |

> 扩展新语言：在 `modules/i18n/locales/` 下新建 `{locale_id}.json` 即可，无需改代码。

### 13.3 词库结构

词库按功能域分层，覆盖：

- **menu** — 全局菜单 (智体/文件/编辑/视图/素材/工具/窗口/帮助)
- **workspace** — 7 个工作区名+描述+工具
- **audio** — 音频模型 (TTS + 音乐创作)
- **hardware** — 硬件检测与等级
- **model** — AI 模型设置
- **timeline** — 时间线操作
- **account** — 账户/订阅
- **common** — 通用 UI (确定/取消/保存/删除...)
- **error** — 错误信息 (支持 {message} 插值)
- **dialog** — 对话框
- **shortcut** — 快捷键说明
- **system** — 系统消息

### 13.4 开发者 API

```python
# 全局快捷函数
from modules.i18n import _

_("menu.file.new")                     # "新建项目" (当前语言)
_("menu.ai.panel_shortcut")            # "Ctrl+Shift+Space"
_("error.generic", message="文件损坏")  # "发生错误：文件损坏"
_("timeline.clips", count=3)           # "3 个片段" (复数)

# 引擎集成
from core.engine import VideoAIEngine
engine = VideoAIEngine(locale="zh_CN")
engine.translate("menu.ai.panel")      # "AI 智能体面板"

# 运行时切换
engine.i18n.set_locale("en")           # 所有 UI 立即切换
engine.i18n.available                  # ["de","en","fr","it","zh_CN","zh_TW"]

# 监听切换事件
engine.i18n.on_locale_changed(lambda old, new: print(f"{old}→{new}"))
```

### 13.5 代码位置

```
modules/i18n/
├── __init__.py     — 导出 I18nManager, _, LOCALE_METADATA
├── i18n.py         — 核心 I18nManager (单例, 懒加载, 拍平, 插值, 复数, 回退)
├── locales.py      — 语言元数据 (名称/旗标/回退顺序)
└── locales/
    ├── zh_CN.json  — 简体中文
    ├── zh_TW.json  — 繁體中文
    ├── en.json     — English (base fallback)
    ├── es.json     — Español
    ├── pt_BR.json  — Português
    ├── fr.json     — Français
    ├── de.json     — Deutsch
    ├── it.json     — Italiano
    ├── ja.json     — 日本語
    ├── ko.json     — 한국어
    ├── ru.json     — Русский
    ├── ar.json     — العربية
    ├── vi.json     — Tiếng Việt
    ├── th.json     — ไทย
    ├── id.json     — Bahasa Indonesia
    └── ...扩展: 新建 {locale}.json 即可
```

---

## 十六、硬件检测与模型等级

### 14.1 概述

> 系统内置硬件检测模块，启动时自动探测 CPU/内存/GPU/磁盘/OS，对照模型等级数据库评估哪些 AI 模型可在本机运行，不足时给出具体升级建议。

### 14.2 模型等级体系 (Tier 1~4)

| 等级 | 硬件要求 | 适用场景 | 示例模型 |
|------|---------|---------|---------|
| **T1 CPU** | >=8核CPU, >=16GB RAM, 无GPU | 在线API、轻量本地模型 | Edge-TTS, MOSS-TTS, Suno, Riffusion, Bark |
| **T2 入门GPU** | + NVIDIA GPU >=6GB VRAM | 中等本地TTS/音乐 | F5-TTS, GPT-SoVITS(small), MusicGen Medium, AudioCraft |
| **T3 中端GPU** | + GPU >=12GB VRAM, 32GB RAM | 高质量音频合成 | GPT-SoVITS(full), VoiceCraft, MusicGen Large, 歌声合成 |
| **T4 高端GPU** | + GPU >=24GB VRAM, 64GB RAM | 全部模型全量 | 所有模型最高配置 |

### 14.3 语音合成 (TTS) 模型

| 模型 | 类型 | T级 | 说明 |
|------|------|-----|------|
| **Edge-TTS** | 在线 | T1 | 微软在线，200+音色，多语言免费 |
| **MOSS-TTS-nano** | 本地 | T1 | 轻量，CPU可跑，低配机器 |
| **Bark (Suno)** | 本地 | T1 | 文本转音频，含音乐/笑声/情感 |
| **F5-TTS** | 本地 | T2 | 开源，零样本声音克隆，中文优秀 |
| **GPT-SoVITS-v2pro** | 本地 | T2~T3 | 高音质克隆，5秒样本，需GPU |
| **CosyVoice 2** | 本地 | T2 | 多语言，情感可控 |
| **VoiceCraft** | 本地 | T3 | 高精度零样本克隆 |

### 14.4 音乐创作模型

| 模型 | 类型 | T级 | 说明 |
|------|------|-----|------|
| **Suno AI** | 在线 | T1 | 在线音乐生成，歌词+风格，支持中文/英文 |
| **Udio** | 在线 | T1 | 在线音乐生成，音质出色，风格丰富 |
| **Riffusion** | 本地 | T1 | 开源，频谱图驱动，轻量可本地 |
| **MusicGen Small** | 本地 | T1 | Meta开源，CPU勉强可跑 |
| **MusicGen Medium** | 本地 | T2 | 6G显存，文本/旋律条件生成 |
| **Stable Audio Open** | 本地 | T2 | Stability AI开源，文本转音频/音效 |
| **AudioCraft** | 本地 | T2 | Meta工具包，MusicGen+AudioGen一体 |
| **MusicGen Large** | 本地 | T3 | 12G显存，最高质量 |
| **GPT-SoVITS 歌声** | 本地 | T3 | 歌词+旋律生成歌声 |

### 14.5 代码位置

```
modules/hardware/
├── __init__.py     — 导出 HardwareDetector, HardwareSpec, detect(), report()
└── hardware.py     — 核心检测 (CPU/RAM/GPU/磁盘/OS) + 模型等级数据库
```

### 14.6 API

```python
from modules.hardware import detect, report

spec = detect()                              # 一键检测
print(spec.cpu_model)                        # CPU 型号
print(spec.max_tier())                       # 最高等级 (1~4)
spec.can_run_model("f5_tts")                 # (True/False, 原因)
spec.upgrade_suggestions()                   # 升级建议列表

report()                                     # 完整报告 (含所有模型兼容性)
```

---

## 附录、完整文档结构总览

| 章 | 标题 | 说明 |
|----|------|------|
| 一 | 整体应用布局 | 8 个工作区标签 |
| **二** | **Flow Graph** | **创作流图谱 — 树形策划编辑器** |
| **三** | **Image Studio** | **图像处理工坊 — AI 图像编辑** |
| 四 | AI Agent 页面 | 智能体控制中心 |
| 五 | StoryCut 页面 | 故事剪辑布局+AI |
| 六 | ProEdit 页面 | 专业编辑布局+AI |
| 七 | Palette 页面 | 色彩工坊布局+AI |
| 八 | AudioForge 页面 | 音频工坊布局+AI |
| 九 | EffectLab 页面 | 特效工坊布局+AI |
| 十 | 模型设置 | 全局 AI 模型配置 |
| 十一 | FFmpeg 引擎层 | 音视频处理核心 |
| 十二 | 全局菜单栏 | 8 个菜单+快捷键 |
| **十三** | **账户与订阅** | **登录/注册/订阅体系** |
| **十四** | **版本与升级** | **版本号/更新/关于** |
| **十五** | **国际化 (i18n)** | **15 语言/系统词库/运行时切换** |
| **十六** | **硬件检测与模型等级** | **T1~T4/音频模型兼容/升级建议** |
| 十七 | 模块命名对照 | 达芬奇↔PhantomVox |
| 十八 | 页面↔AI 映射 | 能力对应表 |
| **十九** | **实施路线** | **P0~P8 分阶段** |
| ★ **二十** | **跨平台架构** | **Flutter + Rust + Python | 移动+桌面** |
---

## 十八、页面↔AI 映射

| 页面 | AI 增强功能 | 实现状态 |
|------|-----------|---------|
| **StoryCut** 故事剪辑 | AI QuickCut、语音转文字索引、AI 场景标记 | ✅ **Flutter UI 完成** — 素材浏览/视口/电平指示/故事时间线 |
| **ProEdit** 专业编辑 | AI 属性面板、AI 素材标记、AI 粗编 | ✅ **Flutter UI 完成** — 媒体池/工具箱/6标签检查器/5轨时间线/混音面板 |
| **Palette** 色彩工坊 | AI 色彩匹配、AI 风格推荐、AI 节点生成 | ✅ **Flutter UI 完成** — 参考画廊/色轮/曲线/示波器/节点工作台 |
| **AudioForge** 音频工坊 | AI 音频工坊面板（语音克隆/TTS/音乐生成/降噪/混音）、AI 配乐推荐 | ✅ **Flutter UI 完成** — TTS 面板 + 音乐面板 + 语音克隆占位, 后端 API 已打通 |
| **EffectLab** 特效工坊 | AI 节点生成、AI 特效推荐、代码生成集成 | ✅ **Flutter UI 完成** — 预览/输出视口/节点图/检查器/帧时间线 |
| **Flow Graph** 创作流图谱 | AI 树形策划编辑、聊天驱动生成、版本管理 | ✅ **v0.3.5** — 4 级树 (topic→scene→beat→sub_beat), LLM 生成完整树, AI 扩展, 版本快照/恢复, 导入/导出 |
| **Image Studio** 图像处理工坊 | AI 图像编辑、OpenCV 增强、AI 修复 | ✅ **v0.3.5** — 24 个 API 端点, Crop/Text/Brush/Shapes/滤镜/调整, OpenCV 12 函数, AI Enhance, AI Face Restore, 30 步撤销 |
| **StoryCut** 故事剪辑 | AI QuickCut、语音转文字索引、AI 场景标记 | ✅ **Flutter UI 完成** — 素材浏览/视口/电平指示/故事时间线 |
| **AI Agent** 智能体中心 | 多智能体矩阵 (Director/Editor/Audio/Music/Visual/Color/Restore/Code) | ✅ **Flutter UI 完成** — 5 子面板 + Agent 矩阵网格 + **P7 端到端编排** |

---

## 十九、分阶段实施路线

| 阶段 | 内容 | 前置 | 备注 |
|------|------|------|------|
| **P0** | 系统基础设施 + 早期模块 | — | **已就绪** |
| | ├── i18n 国际化 (15语言, 热切换, 词库) | — | ✅ 已完成 |
| | ├── 硬件检测模块 (CPU/RAM/GPU/Tier评估) | — | ✅ 已完成 |
| | ├── 音频模型数据库 (TTS+Music, T1~T4) | — | ✅ 已完成 |
| | ├── 引擎模块注册机制 (core/engine.py) | — | ✅ 已完成 |
| | ├── AudioEngine 编排层 + 3 个音频提供者 | — | ✅ 已完成 (Edge-TTS 真实, Suno/MusicGen 桩) |
| | ├── API Server (Flask, 80+ 端点, 端口 8899) | — | ✅ 已完成 |
| | └── Flutter 桌面应用骨架 | — | ✅ 已完成 (Linux 编译通过) |
| **P1** | Agent 框架 + 模型配置 | P0 | ✅ **已完成** |
| | ├── AgentEngine 编排 (5 面板 + 8 Agent) | | ✅ 已完成 |
| | ├── Director 意图分解 + 思维导图数据模型 | | ✅ 已完成 |
| | ├── 模型配置 (ConfigManager + 注册表 + config.yaml) | | ✅ 已完成 |
| | └── 14 个 REST 端点 (/api/v1/agent/*, /api/v1/models/*) | | ✅ 已完成 |
| **P2** | ProEdit 页面 (时间线+属性面板+AI助手) | P1 | **P2 Flutter UI 完成** |
| | ├── Timeline 数据模型 (Track/Clip/Effect) | | ✅ 已完成 |
| | ├── FFmpeg filter graph 构建器 (9种效果类型) | | ✅ 已完成 |
| | ├── 项目文件序列化 (.phantomvox) | | ✅ 已完成 |
| | ├── TimelineEngine 编排 + 11 个 REST 端点 | | ✅ 已完成 |
| | └── ProEdit Flutter UI | | ✅ 已完成 (P2 Flutter UI 完成) |
| **P3** | AudioForge 音频工坊 (完整 UI + 更多模型) | P1 | **P3 Flutter UI 完成** |
| | ├── TTS 面板 (语音选择/文本输入/生成) | | ✅ 已完成 (Edge-TTS API 打通) |
| | ├── 音乐生成面板 (风格/时长/prompt) | | ✅ 已完成 (Suno/MusicGen 桩) |
| | ├── 语音克隆面板 (占位) | | ✅ 已完成 (待 T2 GPU) |
| | └── AudioForge 页面集成到导航栏 | | ✅ 已完成 |
| **P4** | Palette + EffectLab | P3 | **P4 Flutter UI 完成** |
| | ├── Palette 色彩工坊 (参考画廊/视窗/色轮/节点) | | ✅ 已完成 |
| | ├── EffectLab 特效工坊 (预览/输出/节点/检查器) | | ✅ 已完成 |
| | └── Palette + EffectLab 页面集成到导航栏 | | ✅ 已完成 |
| **P5** | StoryCut + AI Agent + Flow Graph | P4 | **P5 Flutter UI 完成** |
| | ├── StoryCut 故事剪辑 (素材浏览/视口/故事时间线) | | ✅ 已完成 |
| | ├── AI Agent 页面 (聊天/思考/生图/生视频/代码面板) | | ✅ 已完成 |
| | ├── 多智能体矩阵 (8 Agent 状态网格) | | ✅ 已完成 |
| | ├── Flow Graph 创作流图谱 (树形策划编辑/聊天驱动/版本管理) | | ✅ 已完成 (v0.3.5 树形重写) |
| | └── StoryCut + Agent + Flow Graph 集成到滚动导航栏 | | ✅ 已完成 |
| **P6** | 代码生成引擎 + 视频生成 | P5 | **P6 完成** — 43 模板, 7 类别, 真实 FFmpeg filter 生成 |
| | ├── modules/codegen/ — NL→FFmpeg 引擎 (43 模板, 7 类别) | | ✅ 已完成 |
| | ├── modules/videogen/ — 视频生成引擎 (桩, 可扩展提供者模式) | | ✅ 已完成 |
| | ├── 6 个新 API 端点 (codegen×3 + videogen×3) → 当时的端点总数 47 | | ✅ 已完成 |
| | ├── CodeAgent 使用真实 codegen 引擎替代 stub | | ✅ 已完成 |
| | └── Flutter Code 面板调用 /api/v1/codegen/generate | | ✅ 已完成 |
| **P8** | Image Studio 图像处理工坊 | P7 | **P8 完成** — 全功能图像编辑器 + OpenCV + AI |
| | ├── modules/image_editor/ — ImageEditor (crop/text/brush/shapes) | | ✅ 已完成 |
| | ├── cv_tools.py — OpenCV 12 函数 (denoise/sharpen/inpaint/upscale/lineart/HDR) | | ✅ 已完成 |
| | ├── ai_providers.py — AI Enhance + Face Restore 管线 | | ✅ 已完成 |
| | ├── 24 个 /api/v1/editor/* 端点 | | ✅ 已完成 |
| | └── Flutter Image Studio 页面 (2列工具栏/画布/属性面板/30步撤销) | | ✅ 已完成 |
| **P7** | Director Agent 端到端编排 | P6 | **P7 完成** — 用户意图→分解→派发→Agent执行→时间线素材 |
| | ├── WorkflowRunner 编排引擎 (plan/dispatch/collect/assemble) | | ✅ 已完成 |
| | ├── 3 个 workflow API 端点 (start/status/list) | | ✅ 已完成 |
| | ├── Agent 页面调用 workflow API (替代旧 plan API) | | ✅ 已完成 |
| | ├── 时间线资产列表 + Apply to Timeline 按钮 | | ✅ 已完成 |
| | └── API 端点总数: 80+ | | ✅ 已完成 |

### P3 音频工坊 — 模型接入计划

```
AudioForge
├── TTS 面板
│   ├── 在线: Edge-TTS  (T1, 立即可用)
│   ├── 本地: MOSS-TTS  (T1, 你的机器可跑)
│   ├── 本地: F5-TTS    (T2, 需 GPU 6G+)
│   └── 本地: GPT-SoVITS (T2~T3, 需 GPU 12G+)
│
├── 声音克隆面板
│   ├── 快速克隆 (5秒样本 → F5-TTS / GPT-SoVITS)
│   └── 音色管理库
│
├── 音乐生成面板
│   ├── 在线: Suno AI  (T1, 歌词+风格)
│   ├── 在线: Udio     (T1, 高品质)
│   ├── 本地: Riffusion (T1, 你的机器可跑)
│   ├── 本地: MusicGen  (T1~T3, 分模型)
│   └── 本地: Stable Audio (T2, 音效)
│
└── 硬件感知层
    ├── 启动时: engine.hardware.detect()
    ├── 模型列表: 自动隐藏不可运行的本地模型
    └── 提示: "此模型需要 T2 GPU (≥6G显存)，是否跳过？"
```

### 硬件检测在启动流程中的位置

```
PhantomVox 启动
  ├── 1. 加载引擎 (VideoAIEngine)
  ├── 2. 初始化 i18n (检测系统语言)
  ├── 3. 硬件检测 (HardwareDetector.detect())
  │      └── 结果存入 engine.hardware_spec
  ├── 4. 根据 Tier 过滤可用模型列表
  ├── 5. 加载 UI (透传语言设置)
  └── 6. 就绪，显示硬件报告 (可选弹窗)
```

---

## 二十、跨平台架构与开发技术栈

### 18.1 平台目标

| 平台 | 类型 | 优先级 | 部署方式 |
|------|------|--------|----------|
| Windows 10/11 | 桌面 | P0 | 原生安装包 (MSI/EXE) |
| macOS 13+ (Intel + Apple Silicon) | 桌面 | P0 | DMG / App Store |
| iOS 16+ (iPhone + iPad) | 移动 | P1 | App Store |
| Android 10+ (手机 + 平板) | 移动 | P1 | APK / Play Store |
| Linux (Ubuntu/Debian) | 桌面 | P2 | AppImage / Flatpak |

### 18.2 三层技术栈

```
┌──────────────────────────────────────────────────────────────┐
│                     Flutter UI Layer (Dart)                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │   iOS    │ │ Android  │ │ Windows  │ │  macOS   │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
│  单一代码库 · Skia/Impeller 渲染 · Canvas 时间线 · Material 3│
│  dart:ffi → Rust  │  http/ws → Python AI Server            │
├──────────────────────────────────────────────────────────────┤
│                   Rust Media Engine (crate)                   │
│  phantomvox-media-core                                       │
│  ├── ffmpeg-sys       — FFmpeg 安全 FFI 绑定                  │
│  ├── timeline-render  — Canvas 时间线数据模型 + 渲染指令      │
│  ├── audio-dsp        — 音频处理 (EQ/压缩/变调/频谱)          │
│  ├── color-math       — 色彩空间转换/LUT/Lift-Gamma-Gain     │
│  └── codec-bridge     — 编解码器统一接口                      │
│  编译目标: x86_64-pc-windows-msvc / aarch64-apple-darwin /    │
│            aarch64-linux-android / aarch64-apple-ios 等       │
│  调用方: Flutter (dart:ffi) + Python (PyO3)                  │
├──────────────────────────────────────────────────────────────┤
│               Python AI Agent Server (现状)                    │
│  core/engine.py | modules/i18n/ | modules/hardware/           │
│  桌面端: 本地进程 (localhost:8899) HTTP/WebSocket             │
│  移动端: 云端部署 (Docker + k8s, 可选 on-device 降级)          │
│  API: /api/v1/agent, /api/v1/tts, /api/v1/music, /api/v1/proj│
└──────────────────────────────────────────────────────────────┘
```

### 18.3 Flutter — UI 层 (核心技术选型)

**为什么选择 Flutter 而非其他框架：**

| 方案 | 跨平台覆盖 | Canvas 性能 | 原生集成 | 生态成熟度 | 包体积 |
|------|-----------|------------|---------|-----------|-------|
| **Flutter** | ✅ iOS/Android/Win/macOS | ★★★★★ Skia/Impeller | ★★★★★ Method Channel | ★★★★★ | ~15MB |
| Tauri v2 | ✅ 全平台(WebView) | ★★★ 受限于 Web | ★★★★ Rust sidecar | ★★★ | ~5MB |
| React Native | ❌ 桌面弱 | ★★★ JavaScript Bridge | ★★★★ | ★★★★★ | ~30MB |
| .NET MAUI | ❌ macOS/iOS弱 | ★★★ 系统原生 | ★★★★ | ★★★ | ~50MB |
| Python Kivy | ❌ 移动体验差 | ★★ 软件渲染 | ★★ | ★★ | ~40MB |

**关键决策理由：**
1. **Canvas 渲染能力**：专业视频编辑器需要高性能 Canvas 绘制（时间线轨道、调色轮、波形图）。Flutter 的 Skia/Impeller 引擎是目前跨平台框架中最强的 2D 渲染方案。
2. **单一代码库**：一套 Dart 代码编译到 4 个平台，维护成本远低于多套原生代码（Swift + Kotlin + C#）。
3. **Hot Reload**：视频编辑 UI 极其复杂，hot reload 迭代效率远超编译型方案。
4. **FFI 支持**：`dart:ffi` 可以直接调用 Rust 编译的原生库，延迟低于 1μs。

**已在 Linux 开发机上成功编译** — phantomvox_app (68KB ELF, build/linux/x64/debug/bundle/)。

**Flutter SDK 版本：** 3.44.1 stable (手动解压至 ~/flutter/flutter/，避免 snap 版本触发 1.5GB 下载)。
**编译工具链：** cmake 3.28 + g++ 13.3.0 + ninja 1.11.1，需 `-DCMAKE_CXX_COMPILER=/usr/bin/g++` 绕过 snap clang 兼容性问题。

**核心 Flutter package 选型：**

| 用途 | Package | 理由 |
|------|---------|------|
| 时间线 Canvas | `custom_paint` + `gesture_detector` | 自绘，完全控制像素 |
| 状态管理 | `riverpod` | 编译安全、可测试、无 boilerplate |
| 本地 HTTP 通信 | `dio` + `web_socket_channel` | 与 Python AI Server 通信 |
| Rust FFI | `dart:ffi` + `ffigen` | 零开销原生调用 |
| 文件选择 | `file_picker` | 系统原生文件对话框 |
| 平台窗口 | `window_manager` (桌面) | 窗口缩放/标题栏/系统托盘 |
| 本地数据库 | `drift` (SQLite) | 项目元数据/用户偏好 |
| 国际化 | Flutter `l10n` + 现有 Python i18n | 运行时语言切换同步 |

### 18.4 Rust — 媒体引擎层

**为什么选择 Rust 而非 C/C++：**

- **内存安全**：媒体处理中 70% 的 CVE 来自内存安全问题（缓冲区溢出、use-after-free）。Rust 在编译期杜绝此类问题。
- **零开销抽象**：性能等价手写 C，但安全性和开发效率高一个量级。
- **跨平台编译**：`rustup target add` 一键添加编译目标，`cargo-lipo` 生成 iOS fat binary，`cargo-ndk` 生成 Android .so。
- **PyO3 双向调用**：桌面端 Python 可以通过 `pip install phantomvox-media-core` 直接 import Rust 模块。

**媒体引擎 crate 设计：**

```rust
// phantomvox-media-core 伪架构
mod ffmpeg_sys {      // 安全封装 FFmpeg API
    fn transcode(in: &str, out: &str, opts: TranscoderOpts) -> Result<()>;
    fn probe(path: &str) -> Result<MediaInfo>;
    fn extract_frame(path: &str, time: f64) -> Result<Vec<u8>>;
}
mod timeline_render {  // Canvas 时间线数据模型
    struct Track { clips: Vec<Clip>, muted: bool }
    struct Clip { start: f64, duration: f64, effects: Vec<Effect> }
    fn render_frame(timeline: &Timeline, time: f64) -> RasterFrame;
}
mod audio_dsp {       // 音频 DSP
    fn eq(input: &[f32], freq: f32, gain: f32) -> Vec<f32>;
    fn time_stretch(input: &[f32], ratio: f64) -> Vec<f32>;
    fn pitch_shift(input: &[f32], semitones: i32) -> Vec<f32>;
}
```

### 18.5 Python — AI Agent 层 (就是我们现在的项目)

**现状：已实现为完整 Flask API 服务，端口 8899：**

```
Python AI Server  ←→ Flutter UI
(localhost:8899)     (REST)
     │
     ├── GET  /api/v1/health           # 健康检查 ✅
     ├── GET  /api/v1/info             # 系统信息 ✅
     ├── GET  /api/v1/hardware         # 硬件检测报告 ✅
     ├── GET  /api/v1/hardware/check/<model> # 模型兼容检查 ✅
     ├── GET  /api/v1/locale           # 当前语言 ✅
     ├── GET  /api/v1/locales          # 可用语言列表 ✅
     ├── POST /api/v1/locale/set       # 切换语言 ✅
     ├── GET  /api/v1/translate/<key>  # 翻译查询 ✅
     ├── POST /api/v1/tts              # 文字转语音 ✅ (Edge-TTS)
     ├── GET  /api/v1/tts/voices       # TTS 语音列表 ✅
     ├── GET  /api/v1/tts/providers    # TTS 提供者列表 ✅
     ├── POST /api/v1/music            # 音乐生成 ✅ (mock)
     ├── GET  /api/v1/music/styles     # 音乐风格列表 ✅
     ├── GET  /api/v1/music/providers  # 音乐提供者列表 ✅
     ├── GET  /api/v1/audio            # 音频引擎状态 ✅
     ├── POST /api/v1/agent/chat      # 💬 AI 聊天 ✅
     ├── POST /api/v1/agent/think     # 🧠 深度思考 ✅
     ├── POST /api/v1/agent/image     # 🖼 图像生成 ✅
     ├── POST /api/v1/agent/video     # 🎬 视频生成 ✅
     ├── POST /api/v1/agent/code      # 💻 代码生成 ✅
     ├── POST /api/v1/agent/plan      # 📋 意图→创作流 ✅
     ├── GET  /api/v1/agent/mindmap   # 创作流状态 ✅
     ├── POST /api/v1/agent/mindmap/node # 更新节点 ✅
     ├── GET  /api/v1/agent/matrix    # 多智能体矩阵 ✅
     ├── GET  /api/v1/agent/panels    # 面板列表 ✅
     ├── GET  /api/v1/models          # 可用模型(硬件过滤) ✅
     ├── GET  /api/v1/models/config   # 当前模型配置 ✅
     ├── POST /api/v1/models/config   # 更新模型配置 ✅
     ├── POST /api/v1/models/api_keys # 设置 API Key ✅
     ├── POST /api/v1/codegen/generate  # 💻 NL→FFmpeg 代码生成 ✅
     ├── GET  /api/v1/codegen/categories # 代码模板类别 ✅
     ├── GET  /api/v1/codegen/templates  # 代码模板列表 ✅
     ├── POST /api/v1/videogen/generate  # 🎬 视频生成 ✅ (mock)
     ├── GET  /api/v1/videogen/styles    # 视频风格列表 ✅
     ├── GET  /api/v1/videogen/providers # 视频提供者列表 ✅
     ├── POST /api/v1/timeline          # 创建时间线 ✅
     ├── GET  /api/v1/timeline/<id>     # 获取时间线 ✅
     ├── PUT  /api/v1/timeline/<id>     # 更新时间线 ✅
     ├── DELETE /api/v1/timeline/<id>   # 删除时间线 ✅
     ├── GET  /api/v1/timeline/list     # 时间线列表 ✅
     ├── POST /api/v1/timeline/<id>/track   # 添加轨道 ✅
     ├── GET  /api/v1/timeline/<id>/tracks  # 轨道列表 ✅
     ├── POST /api/v1/timeline/<id>/clip    # 添加片段 ✅
     ├── POST /api/v1/timeline/<id>/effect  # 添加特效 ✅
     ├── POST /api/v1/timeline/<id>/render  # 渲染时间线 ✅
     ├── POST /api/v1/editor/load         # Image Studio 加载图像 ✅
     ├── POST /api/v1/editor/crop         # 裁剪 ✅
     ├── POST /api/v1/editor/resize       # 缩放 ✅
     ├── POST /api/v1/editor/rotate       # 旋转 ✅
     ├── POST /api/v1/editor/flip         # 翻转 ✅
     ├── POST /api/v1/editor/adjust       # 色彩调整 ✅
     ├── POST /api/v1/editor/filter       # 滤镜 ✅
     ├── POST /api/v1/editor/text         # 添加文本 ✅
     ├── POST /api/v1/editor/blur-region  # 区域模糊 ✅
     ├── POST /api/v1/editor/denoise      # 降噪 ✅
     ├── POST /api/v1/editor/draw         # 画笔 ✅
     ├── POST /api/v1/editor/shape        # 形状 ✅
     ├── POST /api/v1/editor/remove-bg    # 移除背景 ✅
     ├── POST /api/v1/editor/smart-sharpen # OpenCV 锐化 ✅
     ├── POST /api/v1/editor/clahe        # OpenCV CLAHE ✅
     ├── POST /api/v1/editor/auto-wb      # 自动白平衡 ✅
     ├── POST /api/v1/editor/upscale      # 超分辨率 2x/4x ✅
     ├── POST /api/v1/editor/inpaint-erase # 修复擦除 ✅
     ├── POST /api/v1/editor/lineart      # 线稿提取 ✅
     ├── POST /api/v1/editor/hdr          # HDR 色调 ✅
     ├── POST /api/v1/editor/ai-enhance   # AI 增强管线 ✅
     ├── POST /api/v1/editor/ai-restore   # AI 人脸修复 ✅
     ├── POST /api/v1/editor/undo         # 撤销 ✅
     ├── POST /api/v1/editor/redo         # 重做 ✅
     ├── GET  /api/v1/editor/fonts        # 字体列表 (30种) ✅
     ├── GET  /api/v1/editor/history      # 历史状态 ✅
     ├── POST /api/v1/workflow/start     # 启动工作流 ✅
     ├── GET  /api/v1/workflow/<id>/status # 工作流状态 ✅
     └── GET  /api/v1/workflow/list      # 工作流列表 ✅
```

**Flutter 端调用示意 (Dart)：**

```dart
final response = await dio.post(
  'http://localhost:8899/api/v1/tts',
  data: {'text': '你好', 'voice': 'edge-tts'},
);
```

### 18.6 移动端特殊情况

| 维度 | iOS | Android |
|------|-----|---------|
| Rust 编译 | `cargo-lipo` → .xcframework | `cargo-ndk` → .so (arm64-v8a, armeabi-v7a) |
| Python AI | 云端 API (iOS 禁止动态加载解释器) | 可选 Chaquopy 嵌入式 Python (本地推理) |
| 离线 TTS | 系统 AVSpeechSynthesizer (降级) | 系统 TTS Engine (降级) |
| 本地模型 | CoreML 转换 (轻量分类器) | NNAPI / TFLite (轻量模型) |
| 重型推理 | 必须走云端 | 必须走云端 |
| 文件访问 | 沙箱 + 系统文件浏览器 | SAF + 存储权限 |

### 18.7 开发工具链总览

| 工具 | 用途 | 安装方式 |
|------|------|----------|
| **Flutter SDK** 3.29+ | UI 开发 | `fvm` (Flutter Version Manager) |
| **Rust** 1.85+ | 媒体引擎 | `rustup` |
| **Python** 3.11+ | AI Server | system / pyenv |
| **VS Code** + 插件 | 主力 IDE | Flutter / Rust-analyzer / Python |
| **Docker** | 移动端 AI 后端 | system |
| **GitHub Actions** | CI/CD | 在线配置 |
| **Fastlane** | App Store / Play 发布 | Ruby gem |
| **CodeMagic** | Flutter + Rust 联合构建 | 在线 CI (支持 iOS 签名) |

### 18.8 开发阶段与平台对应

| 阶段 | 开发目标 | 使用工具 | 平台 |
|------|---------|---------|------|
|| P0 | ✅ Python AI Server 完整 (80+端点) + Audio 引擎 + i18n + 硬件检测 | VS Code + Python | ✅ 调试用 CLI |
|| P1 | ✅ Agent 框架 + 思维导图 + 模型配置 (14 新端点) | Python | 调试用 CLI |
|| P2 | ✅ ProEdit 完整 UI (时间线/素材/检查器/混音器) | Flutter Canvas | ✅ Linux 桌面端完成 |
|| P3 | ✅ AudioForge 音频工坊 UI + 更多 TTS/Music 模型集成 | Flutter + Python AI Server | ✅ 桌面端完成 |
|| P4 | Palette + EffectLab | Flutter Canvas + Shaders | ✅ 桌面端完成 |
|| P5 | StoryCut + AI Agent UI + Flow Graph 树形版 | Flutter + WebSocket | ✅ 桌面端完成 |
|| P6 | 代码生成引擎 + 视频生成 | CodeGenEngine + VideoGenEngine | ✅ 完成 (43 模板, 80+ 端点) |
|| P7 | Director Agent 端到端编排 | WorkflowRunner + Agent API | ✅ 完成 (用户意图→时间线资产) |
|| P8 | Image Studio 图像处理工坊 | OpenCV + AI Enhance | ✅ 完成 (24 editor 端点) |

### 18.9 关键结论

1. **Python AI Server 已实现** — 80+ 个 REST 端点覆盖 Agent 智能体、Image Studio、TTS、音乐生成、代码生成、视频生成、时间线管理、硬件检测、国际化、工作流编排、模型配置，直接对接 Flutter 前端。
2. **Image Studio (图像处理工坊) 已实现** — 24 个 /api/v1/editor/* 端点，Flutter 全功能页面（2列工具栏/画布/属性面板/30步撤销），OpenCV 12 函数套件，CPU AI 增强管线。
3. **Rust 媒体引擎从 P2 开始介入**——P1 的 Flutter UI 骨架已编译通过，可直接通过 HTTP 与 Python AI Server 通信。
4. **Flutter 是所有 UI 的唯一选择**——不要 Web 前端、不要原生 Swift/Kotlin，维护三套 UI 成本不可接受。
5. **移动端 P6 才做**——前期集中桌面端验证产品价值，移动端作为扩展而非核心。

*文档版本：v1.4 — 2026-06-07*

*当前应用版本：PhantomVox AI v0.3.5*

### 文档参考

本章第三章 (Image Studio) 融合了以下源文档的内容：

| 源文档 | 位置 | 合并内容 |
|--------|------|---------|
| **IMAGE_STUDIO_FEASIBILITY.md** | 项目根目录 | 行业标准架构参考、Photopea 交互模型、Layer/Document 数据模型、OpenCV 函数签名参考表、图层合成算法 |
| **image_studio_doc_audit_2026-06-06.md** | `docs/` | Flutter 坐标架构 P0 Bug 根因分析、各工具影响矩阵、P1/P2 修复清单、OpenCV 后端合规性逐函数确认表 |
