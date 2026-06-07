# Image Studio 重写可行性方案与实施计划

> 基于 OpenCV 4.13.0 官方文档 + Flutter dart:ui API 官方文档 + 行业标准（Photopea/Photoshop）
> 参考来源：docs.opencv.org/4.x | api.flutter.dev | photopea.com

---

## 一、架构总览

参考 **Photopea** 的单页编辑器架构 + **Photoshop** 的 Tool → Options → Canvas 交互模型。

```
┌────────────────────────────────────────────────────┐
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ Toolbar  │  │ Options  │  │   Layer Panel    │  │
│  │ (左侧)    │  │ Bar (顶部)│  │   (右侧)         │  │
│  │          │  │          │  │                  │  │
│  │ 选择工具  │  │ 笔刷大小  │  │  图层列表        │  │
│  │ 画笔     │  │ 颜色     │  │  可见性切换       │  │
│  │ 橡皮     │  │ 不透明度  │  │  锁定            │  │
│  │ 形状     │  │ 混合模式  │  │  添加/删除        │  │
│  │ 文字     │  │          │  │  合并/分组        │  │
│  │ 填充     │  │          │  │                  │  │
│  │ 吸管     │  │          │  └──────────────────┘  │
│  │ 缩放     │  │          │                        │
│  │ 移动     │  │          │                        │
│  └──────────┘  └──────────┘                        │
│                                                    │
│  ┌────────────────────────────────────────────────┐│
│  │              Canvas (画布)                      ││
│  │  ┌──────────┐                                  ││
│  │  │  图层 n   │  ← CustomPainter 逐层渲染        ││
│  │  │  ...      │                                  ││
│  │  │  图层 0   │  ← 背景层                        ││
│  │  └──────────┘                                  ││
│  │                                                ││
│  │  Overlay: 当前工具交互指示器 (十字线/选框/路径)   ││
│  └────────────────────────────────────────────────┘│
│                                                    │
│  ┌─────────────────────────────────────────┐        │
│  │   状态栏: 缩放比例 | 坐标 | 图片尺寸     │        │
│  └─────────────────────────────────────────┘        │
└────────────────────────────────────────────────────┘
```

### 数据流

```
用户操作 (Gesture)
    ↓
Tool 子系统 (识别工具 → 生成命令)
    ↓
Canvas 渲染 (CustomPainter 重绘)
    ↓
后台同步 (FastAPI → OpenCV → 返回结果)
```

---

## 二、后端：FastAPI + OpenCV (权威依据)

### 2.1 核心数据模型 — Layer

参考 OpenCV Mat 文档：图像以 numpy.ndarray 表示，shape=(H,W,C)，dtype=uint8。

```python
class Layer:
    image: np.ndarray       # BGRA uint8, shape=(H,W,4)
    name: str
    opacity: float          # 0.0 ~ 1.0
    visible: bool = True
    blend_mode: str = "normal"  # normal/multiply/screen/overlay/...
    mask: np.ndarray | None # 单通道 uint8 mask
```

### 2.2 OpenCV 函数清单（来自官方文档）

#### 2.2.1 图像 I/O [docs.opencv.org: imread/imwrite]

```python
img = cv.imread(path, cv.IMREAD_UNCHANGED)  # 保留 alpha 通道
cv.imwrite(path, img, [cv.IMWRITE_PNG_COMPRESSION, 9])
```

#### 2.2.2 绘图函数 [docs.opencv.org: Drawing Functions tutorial]

```python
cv.line(img, pt1, pt2, color, thickness, lineType=cv.LINE_AA)
cv.circle(img, center, radius, color, thickness, lineType=cv.LINE_AA)
cv.rectangle(img, pt1, pt2, color, thickness, lineType=cv.LINE_AA)
cv.ellipse(img, center, axes, angle, startAngle, endAngle, color, thickness)
cv.polylines(img, [pts], isClosed, color, thickness)
cv.fillPoly(img, [pts], color)
cv.putText(img, text, org, fontFace, fontScale, color, thickness, cv.LINE_AA)
# thickness=-1 表示填充
# 颜色格式: BGR tuple 或 BGRA tuple
```

#### 2.2.3 图层合成 [docs.opencv.org: Arithmetic Operations]

**基础 alpha 混合公式**（标准 Porter-Duff src-over）:
```
output = src * src_alpha + dst * (1 - src_alpha)
```

```python
def composite(layers: list[Layer]) -> np.ndarray:
    """按从下到上顺序合成图层"""
    result = None
    for layer in layers:
        if not layer.visible:
            continue
        img = layer.image.copy()
        # 应用 opacity
        alpha = img[:,:,3] * layer.opacity
        img[:,:,3] = alpha
        # 应用 blend mode
        if layer.blend_mode == "normal":
            result = alpha_blend(img, result)
        elif layer.blend_mode == "multiply":
            result = multiply_blend(img, result)
        # ... 其他混合模式
    return result
```

#### 2.2.4 滤镜 [docs.opencv.org: Image Filtering]

```python
# 高斯模糊
cv.GaussianBlur(src, ksize, sigmaX)
# 中值模糊
cv.medianBlur(src, ksize)
# 双边滤波（保边去噪）
cv.bilateralFilter(src, d, sigmaColor, sigmaSpace)
# 自定义卷积核
kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]], np.float32)  # 锐化
cv.filter2D(src, -1, kernel)
```

#### 2.2.5 色彩调整 [docs.opencv.org]

```python
# 颜色空间转换
cv.cvtColor(img, cv.COLOR_BGR2GRAY)
cv.cvtColor(img, cv.COLOR_BGR2HSV)
# 阈值
cv.threshold(src, thresh, maxval, type)  # type=cv.THRESH_BINARY 等
# 直方图均衡
cv.equalizeHist(gray)
```

#### 2.2.6 几何变换 [docs.opencv.org]

```python
# 缩放
cv.resize(src, dsize, interpolation=cv.INTER_LINEAR)
# 仿射变换（旋转、平移、缩放）
M = cv.getRotationMatrix2D(center, angle, scale)
cv.warpAffine(src, M, dsize)
# 透视变换（裁剪）
M = cv.getPerspectiveTransform(src_pts, dst_pts)
cv.warpPerspective(src, M, dsize)
# 翻转
cv.flip(src, flipCode)  # 0=垂直, 1=水平, -1=两者
```

#### 2.2.7 选区/蒙版

```python
# 颜色范围选择
mask = cv.inRange(hsv, lower, upper)
# 边缘检测
edges = cv.Canny(gray, threshold1, threshold2)
# 轮廓检测
contours, _ = cv.findContours(binary, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE)
# 绘制轮廓
cv.drawContours(img, contours, -1, color, thickness=cv.FILLED)
```

### 2.3 API 端点设计

```
POST /api/image/new          → 创建新画布
POST /api/image/open         → 打开图片文件
POST /api/image/save         → 保存 PNG/JPEG

POST /api/layer/add          → 添加图层
POST /api/layer/delete       → 删除图层
POST /api/layer/reorder      → 调整图层顺序
POST /api/layer/merge        → 合并图层
POST /api/layer/properties   → 修改图层属性（不透明度/混合模式/可见性）

POST /api/tool/draw          → 画笔/橡皮画图
POST /api/tool/shape         → 形状（矩形/圆/椭圆/多边形）
POST /api/tool/text          → 文字
POST /api/tool/fill          → 填充（实色/渐变）
POST /api/tool/eyedropper    → 吸色

POST /api/filter/blur        → 模糊滤镜
POST /api/filter/sharpen     → 锐化
POST /api/adjust/brightness  → 亮度调整
POST /api/adjust/contrast    → 对比度
POST /api/adjust/hue_sat     → 色相饱和度

POST /api/transform/crop     → 裁剪
POST /api/transform/resize   → 缩放
POST /api/transform/rotate   → 旋转
POST /api/transform/flip     → 翻转

POST /api/history/undo       → 撤销
POST /api/history/redo       → 重做
```

---

## 三、前端：Flutter Web Canvas (权威依据)

### 3.1 核心渲染架构

Flutter 的 `dart:ui` 提供了完整的 Canvas 2D API [api.flutter.dev: Canvas-class]。

```dart
class EditorCanvas extends CustomPainter {
  final List<LayerData> layers;
  final ToolOverlay overlay;

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in layers.reversed) {
      if (!layer.visible) continue;

      canvas.save();
      canvas.clipRect(layer.bounds);  // 裁切到图层边界

      final paint = Paint()
        ..color = Color.fromARGB(
          (layer.opacity * 255).round(), 255, 255, 255
        )
        ..blendMode = _toBlendMode(layer.blendMode);

      canvas.drawImage(layer.image, Offset.zero, paint);
      canvas.restore();
    }
    // 绘制工具叠加层（十字线、选框等）
    overlay.paint(canvas, size);
  }
}
```

### 3.2 Canvas 可用绘图方法 [官方 API 参考]

| 方法 | 用途 |
|------|------|
| `drawImage(Image, Offset, Paint)` | 渲染图层图像 |
| `drawImageRect(Image, src, dst, Paint)` | 缩放渲染图像区域 |
| `drawCircle(Offset, double, Paint)` | 画圆（工具/形状预览） |
| `drawRect(Rect, Paint)` | 画矩形（选框/裁切区域） |
| `drawLine(Offset, Offset, Paint)` | 画线（画笔实时轨迹） |
| `drawPath(Path, Paint)` | 画任意路径（画笔/套索/形状） |
| `drawParagraph(Paragraph, Offset)` | 渲染文字图层 |
| `clipRect/clipPath/clipRRect` | 图层裁切 |
| `save/restore/saveLayer` | 状态栈管理 |

### 3.3 Paint 样式属性 [官方 API 参考]

```dart
Paint()
  ..color = Color(0xFFFF0000)       // 前景色
  ..strokeWidth = 3.0              // 线宽
  ..style = PaintingStyle.fill     // fill/stroke
  ..strokeCap = StrokeCap.round    // 圆头端点
  ..strokeJoin = StrokeJoin.round  // 圆角连接
  ..blendMode = BlendMode.srcOver // 混合模式
  ..isAntiAlias = true            // 抗锯齿
  ..filterQuality = FilterQuality.high
```

### 3.4 BlendMode 支持 [官方 API 参考]

Flutter 原生支持所有标准混合模式：
- `srcOver` — 正常（覆盖）
- `multiply` — 正片叠底
- `screen` — 滤色
- `overlay` — 叠加
- `darken` — 变暗
- `lighten` — 变亮
- `colorDodge` — 颜色减淡
- `colorBurn` — 颜色加深
- `hardLight` — 强光
- `softLight` — 柔光
- `difference` — 差值
- `exclusion` — 排除
- `hue/saturation/color/luminosity` — 颜色相关

### 3.5 交互处理

使用 `GestureDetector` + `Listener` 联合处理 [参考 Photopea 鼠标事件模型]：

```dart
Listener(
  onPointerDown: (event) => tool.onMouseDown(event.position),
  onPointerMove: (event) => tool.onMouseMove(event.position),
  onPointerUp: (event) => tool.onMouseUp(event.position),
  child: GestureDetector(
    onScaleStart: (details) => canvasController.onZoomStart(details),
    onScaleUpdate: (details) => canvasController.onZoomUpdate(details),
    child: CustomPaint(painter: EditorCanvas(...)),
  ),
)
```

---

## 四、行业标准参考：Photopea 架构

从 photopea.com 及 developer 资料分析，专业网页图片编辑器的通用架构：

### 4.1 数据模型

```
Document
 ├── width, height, resolution
 ├── layers: Layer[]       ← 有序列表，索引 0 = 最底层
 └── history: Command[]    ← 命令模式实现撤销/重做

Layer
 ├── name: string
 ├── image: pixels         ← RGBA 像素数据
 ├── opacity: 0.0-1.0
 ├── visible: bool
 ├── blendMode: enum
 ├── mask: Mask | null
 └── locked: bool

Command (Undo/Redo)
 ├── type: "paint" | "transform" | "filter" | ...
 ├── before: LayerState
 └── after: LayerState
```

### 4.2 工具交互模式

```
1. 从工具栏选择工具 → Options Bar 显示工具参数
2. 在画布上操作 (mousedown → mousemove → mouseup)
3. 实时预览（前端 Canvas 做临时渲染）
4. 操作完成 → 发送到后台 → 更新图层
```

### 4.3 撤销/重做 — 命令模式

```
class HistoryManager {
  Stack<Command> undoStack;
  Stack<Command> redoStack;

  execute(command) → 执行并压入 undoStack
  undo() → 弹出 undoStack，恢复 before 状态，压入 redoStack
  redo() → 弹出 redoStack，恢复 after 状态，压入 undoStack
}
```

---

## 五、实施计划

### Phase 1: 后端核心（2-3天）

```
Day 1: FastAPI 项目骨架 + 数据模型 (Layer/Document) + 图像 I/O
Day 2: 图层合成引擎（所有 BlendMode）+ 绘图 API（画笔/形状/文字）
Day 3: 滤镜 API（模糊/锐化/色彩调整）+ 几何变换（缩放/旋转/翻转/裁剪）
```

### Phase 2: 前端核心（2-3天）

```
Day 1: Canvas 渲染引擎（图层渲染 + 缩放/平移）
Day 2: 工具系统（画笔 + 形状 + 文字 + 填充 + 吸管）
Day 3: 图层面板 + 工具栏 + Options Bar + 交互集成
```

### Phase 3: 高级功能（1-2天）

```
Day 1: 撤销/重做 + 选区
Day 2: 性能优化 + 调试打磨
```

---

## 六、核心原则

1. **不闭门造车** — 每个 OpenCV 函数调用均参照 docs.opencv.org 签名
2. **不闭门造车** — 每个 Flutter API 使用均参照 api.flutter.dev 文档
3. **不闭门造车** — UI/UX 交互模式参照 Photopea + Photoshop 行业标准
4. **测试通过不等于合理** — 每步实现后对照官方文档验证
5. **先研究后动手** — 每个功能模块先看官方文档再实现

---

请审阅方案，确认后开始实施。
