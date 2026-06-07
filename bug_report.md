# Image Studio 全工具 Bug 分析报告

## 架构根因：坐标转换全线崩溃

**核心函数 `_listenerLocalToImage()` (第536行)有一个致命错误：**
1. `getTransformTo(listenerRo)` 已经包含了 Transform/pan/zoom/Center/FittedBox 的完整变换链
2. 然后又手动算一遍 `scale = min(ds.width/imgW, ds.height/imgH)` 并除以它
3. 这两个计算不一致——getTransformTo 包含完整变换，但手动 scale 只计算了初始 BoxFit.contain 的缩放
4. 当 zoom≠1 或 pan≠(0,0) 时，额外除以 scale 会导致坐标偏移

**所有使用 `_listenerLocalToImage()` 的工具 = 坐标全错：**

---

## Bug 1. Crop — 裁剪框位置/大小全错

**函数链：**
- 进入Crop → `_fullImageRect()` → `_imageRectToListenerLocal()` → 用 render tree getTransformTo 把图像Rect转屏幕Rect → 初始定位正确(因为没缩放时数据一致)
- 拖动时 → `event.localPosition` 是屏幕坐标 → 与 `_cropRect`(屏幕坐标)比较 → 边缘检测工作
- 确认时 → `_applyCrop()` → `_listenerLocalToImage()` → getTransformTo + 手动除scale → 返回错误像素坐标

**表现：** 初始全图框是OK的，拖动时边缘跟随也OK(都在屏幕空间操作)，但双击确认时转换到图像像素的坐标是错的。裁剪的结果位置偏移、尺寸不对。

**次要bug：** 缩放后(zoom≠1)拖动裁剪框，因为`_cropRect`存储的是屏幕坐标但Transform改变了图像位置，框和图像错位。

---

## Bug 2. Text — 文本框完全错位

**函数链 (第396-446行)：**
- `_handleTextDown()` → `_listenerLocalToImage(pos)` → 存储图像坐标到 `_textBoxRect`
- `_handleTextMove()` → 同上，扩展 `_textBoxRect`
- 预览时 `_textBoxLayoutRect()` → `_imageRectToListenerLocal()` → render tree getTransformTo → 画在屏幕

**问题1（预览错位）：** `_imageRectToListenerLocal()` (第558-577行) 先把图像坐标乘以scale(手动BoxFit.contain计算)，然后用 getTransformTo 转换到屏幕坐标。但 render tree 里 FittedBox 的缩放已经包含了 BoxFit.contain，getTransformTo 返回的矩阵也包含了这个缩放。然后手动再乘一次 scale → 坐标双倍计算。

**问题2（文本不是内联编辑）：** 代码只在 overlay 上画了一个边框，没有真正的 TextField。用户要求的是 inline 编辑(在图像上直接打字)。完全不符合需求。

---

## Bug 3. Brush/Eraser — 笔刷预览坐标错位

**函数链 (第449-489行)：**
- `_handleBrushDown()` → `_listenerLocalToImage(pos)` → 图像坐标存 `_currentStroke`
- `_handleBrushMove()` → 图像坐标追加
- 预览：`_previewStroke = [pos]` (这里存的是**屏幕坐标**，因为 `pos = event.localPosition`)
- 预览：`_BrushPreviewPainter` (第1665行) 在屏幕空间画 `_previewStroke` 的屏幕坐标

**问题（笔刷大小不随zoom缩放）：**
- `_previewStroke` 存屏幕坐标 → 位置对齐 ✓
- 但 `size: _brushSize` (第1044行) 是图像像素值(如10px)
- 当 zoom=2 时，笔刷视觉预览是10px，但实际画在图像上是20px效果
- 反差：预览小，实际大，用户觉得笔刷不准

---

## Bug 4. Shape — 图形预览错位

**函数链 (第493-534行)：**
- `_handleShapeDown()` → `_listenerLocalToImage(pos)` → 图像坐标存 `_shapeStart`
- `_handleShapeMove()` → 图像坐标存 `_shapeEnd`
- 预览：`_shapeLayoutRect()` → `_imageRectToListenerLocal()` → 同 text 的 bug

**问题1（预览位置错）：** 同 text——`_imageRectToListenerLocal()` 手动 scale 计算和 getTransformTo 冲突，双倍缩放。
**问题2（线粗细不随zoom缩放）：** `strokeWidth` 是图像像素值，在屏幕空间预览时用图像像素大小画 → zoom=2时线显得太细。

---

## Bug 5. 所有 Overlay 不随 Transform 变换

**结构问题：** Overlay(裁剪框/文本框/笔刷预览/形状预览) 是用 `Positioned.fill()` 放在 Stack 里，在 Stack 的坐标系中绘制。
- 当用户 zoom/pan 时，图像通过 Transform 变换
- 但 overlay 没有跟随变换
- `_imageRectToListenerLocal()` 试图通过 getTransformTo 手动补偿，但补偿不准确

**正确做法应该是：** overlay 和图像一起缩放+平移，或者 overlay 基于 TransformationController.value 实时计算坐标。

---

## 总结：所有工具都依赖于有bug的坐标转换

| 工具 | 表现 | Bug类型 |
|------|------|---------|
| Crop | 框能拖动但确认后裁剪结果偏移 | `_listenerLocalToImage()` 的 scale×2 |
| Text | 框位置错、无内联编辑 | 坐标双倍计算 + 缺少TextField widget |
| Brush | 预览位置对但大小不对 | `_previewStroke`屏幕坐标对但`size`是图像像素 |
| Eraser | 同Brush | 同Brush |
| Shape | 预览位置错、线粗细不对 | `_imageRectToListenerLocal()` 坐标双倍 |
| Adjust | 无坐标问题(纯参数) | ✅ 没问题 |
| Filter | 无坐标问题(纯参数) | ✅ 没问题 |
| Rotate/Flip | 无坐标问题 | ✅ 没问题 |
| Resize | 无坐标问题 | ✅ 没问题 |

## 建议

**方案A — 最小修复：** 修 `_listenerLocalToImage()`——去掉手动 scale 计算，只用 `getTransformTo` 的逆矩阵。但 FittedBox+Center+Transform 的渲染树布局仍然复杂，getTransformTo 的可靠性存疑。

**方案B — 完整重写（基于Flutter官方方案）：** 用 `InteractiveViewer` + `TransformationController.toScene()` —— 这是 Flutter 团队为这个精确问题设计的官方方案。
