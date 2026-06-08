# AI 修复右侧面板设计方案

## 1. 定位

这是一个 **独立的、专用的** 右侧功能面板，与 TOOLS（OpenCV 工具）平级，但视觉上更突出。**不是工具栏按钮**，不是 TOOLS 里的一行小按钮。

## 2. 面板布局

```
┌─────────────────────┐
│  AI 修复            │ ← 标题行，与 LAYERS、TOOLS、HISTORY 平级
├─────────────────────┤
│                     │
│  ☐ 选中区域自动检测  │ ← 显示当前是否有选区
│  ┌───────────────┐  │
│  │ 在画布上绘制选区 │  │ ← 状态提示区
│  │ 或选择自动检测   │  │
│  └───────────────┘  │
│                     │
│  修复类型            │ ← 分组标题
│  ┌──┬──┬──┬──┐     │
│  │综│去│人│超│     │ ← 2×4 网格，单选（激活态高亮）
│  │合│水│脸│分│     │
│  │  │印│  │  │     │
│  ├──┼──┼──┼──┤     │
│  │去│上│去│换│     │
│  │噪│色│模│背│     │
│  │  │  │糊│景│     │
│  └──┴──┴──┴──┘     │
│                     │
│  提示词（选填）      │ ← 分组标题
│  ┌───────────────┐  │
│  │ 例如：自然无痕…  │  │ ← 文本输入框，placehoder 按类型变
│  └───────────────┘  │
│                     │
│  ┌───────────────┐  │
│  │  ▶ 执行修复     │  │ ← 主按钮，无选区时置灰
│  └───────────────┘  │
│                     │
│  状态                │ ← 进度/结果区域
│  ◌ 等待选区…         │
│  ─── 或 ───          │
│  ✓ 修复完成          │
│  ✗ 失败：{原因}      │
├─────────────────────┤
│  TOOLS              │ ← 下方 OpenCV 工具区（不改变）
│  ...                │
└─────────────────────┘
```

## 3. 用户流程

```
1. 用户打开图片 → 进入 Image Studio
2. 用户在画布上用选区工具（brush/rect/polygon）绘制要修复的区域
   ↓
3. 切换到右侧 "AI 修复" 面板
   ↓
4. 选择修复类型（综合/去水印/人脸/超分/去噪/上色/去模糊/换背景）
   ↓
5. (可选) 输入提示词
   ↓
6. 点击 "执行修复"
   ↓
7. 面板显示进度状态
   ↓
8. 后端：获取当前图层 + 选区 mask + prompt
   → 根据 provider 配置调用云端 API 或 OpenCV 降级
   ↓
9. 修复完成 → 更新画布预览 → 面板显示 "✓ 修复完成"
```

**关键**：

- **选区是核心**：去水印/去模糊/去噪 必须选区 → AI 只修选区内。无选区时执行按钮置灰。
- **换背景**特殊：选择"换背景"后，AI **自动检测主体**（不需要用户画选区），用 prompt 生成新背景。如画了选区则用选区指定主体范围。
- **去水印**典型流程：brush 工具涂盖水印区 → 选"去水印" → 执行 → AI inpaint 填充。

## 4. 状态区域

面板底部有一个状态显示区，展示当前修复进度：

| 状态 | 显示 | 含义 |
|------|------|------|
| idle | 空 | 等待用户操作 |
| waiting | 旋转圈 + "等待选区…" | 无选区 |
| ready | "就绪" | 有选区，可执行 |
| running | 进度条 + "修复中…" | 正在调用 API |
| success | "✓ 修复完成" | 成功 |
| error | "✗ 修复失败: {msg}" | 失败 + 原因 |
| fallback | "⚠ 云端不可用，已降级为传统修复" | 自动降级提示 |

## 5. 与选区的集成

现有选区来源：
- **Brush 工具**：用户在画布上刷出区域
- **Rect 工具**：矩形选区
- **Polygon**：多边形选区（如有）

后端接收：
```python
POST /api/v1/editor/ai-repair
{
  "task": "auto" | "watermark" | "face" | "superres" | "denoise" | "colorize" | "deblur" | "change_bg",
  "prompt": "自然修复背景，无痕迹",
  "mask_points": [[x1,y1], [x2,y2], ...],   # 当前选区多边形
  # 或
  "mask_b64": "base64..."                    # 直接传 mask PNG
}
```

| task | 中文名 | 选区要求 | 备注 |
|------|--------|----------|------|
| auto | 综合 | 必须 | 通用 inpainting，无特定优化 |
| watermark | 去水印 | 必须 | 选区套住水印，AI 填充 |
| face | 人脸修复 | 必须 | 选区框住脸部，AI 补全细节 |
| superres | 超分 | 可选（选区内超分） | 整体或局部提升分辨率 |
| denoise | 去噪 | 必须 | 选区去噪点 |
| colorize | 上色 | 必须 | 选区黑白→彩色 |
| deblur | 去模糊 | 必须 | 选区去模糊 |
| change_bg | 换背景 | 不需（自动检测主体） | 保持主体变背景 |

如果没有选区（mask_points 为空）：
- `change_bg` → 自动检测主体
- 其他类型 → 全图修复

## 6. Flutter 实现要点

### 6.1 状态变量

```dart
// AI Repair panel state
String _repairTask = 'auto';
String _repairPrompt = '';
String _repairStatus = 'idle';  // idle | waiting | ready | running | success | error
String? _repairStatusMsg;        // 状态详情
```

### 6.2 面板位置

```dart
// 在 _rightPanel() 中，放在 TOOLS 和 HISTORY 之间：
// ── AI Repair Panel ──
_sectionTitle('AI 修复', accent: true),  // 特殊颜色 accent
...  // 内容
const Divider(...)

// ── TOOLS ──
_sectionTitle('TOOLS'),
...

// ── HISTORY ──
```

### 6.3 选区检测

通过现有 `_currentTool` 和选区状态判断是否有选区：
```dart
bool get _hasSelection =>
    _cropRect != null ||          // rect selection
    (_brushPoints?.length ?? 0) > 2 ||  // brush selection
    (_polygonPoints?.length ?? 0) > 2;  // polygon selection
```

## 7. 后续扩展可能性

- 修复强度滑块
- 对比视图（before/after 切换）
- 修复历史（多次修复可回退）
- 批量修复
- 本地模型状态显示（检测 GPU 后提示"本地模型可用"）

## 8. 实施步骤

1. 在 `_rightPanel()` 中插入 AI 修复面板 UI
2. 添加 `_repairStatus` 状态变量和状态管理
3. 实现选区检测逻辑
4. 实现状态驱动的按钮交互（无选区时置灰）
5. 后端已就绪（`modules/repair/` + API 路由已有）
6. 编译验证
