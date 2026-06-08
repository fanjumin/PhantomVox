# AI 图像修复模块设计方案（v2 — 云 API 优先）

## 1. 核心思路

**理解机器限制**：当前电脑（无 NVIDIA GPU）无法跑 LaMa / FLUX.1 dev / SDXL 等重型本地模型。

**策略**：以云端 API 为主要计算引擎（效果最好），OpenCV 传统算法为离线降级，本地模型接口为未来占位。

**核心工作流**（类似 Photoshop 的 Generative Fill）：

```
用户在画布上绘制选区 → 后端生成 mask PNG → 调用云 API (FLUX / SD / CogView)
  → 云模型根据 mask + prompt 生成修复内容 → 返回结果 → 更新预览
```

---

## 2. 架构总览

```
Flutter Image Studio
  │  选区绘制（brush / polygon / rect）
  │  POST /api/v1/editor/ai-repair
  ▼
API Server (modules/api_server)
  │
  ▼
RepairEngine (modules/repair/engine.py)
  │  provider = config.get("repair.provider") → "replicate_flux"
  │  根据 provider 选择 impl
  │
  ├── RepairProvider.REPLICATE_FLUX  (★★★★★ 推荐，效果最好)
  │   └── 调用 Replicate FLUX.1 Fill [pro] API
  │
  ├── RepairProvider.ZHIPU_COGVIEW  (★★★ 备选，已有 Key)
  │   └── 调用智谱 CogView-4 API
  │
  ├── RepairProvider.LOCAL_LAMA     (☆ 占位，未来升级后切换)
  │   └── stub → 抛出 NotImplementedError
  │
  └── RepairProvider.NONE           (离线降级)
      └── cv2.inpaint() Telea 传统修复
```

---

## 3. 目录结构

```
modules/repair/
├── __init__.py            # 导出 RepairEngine
├── engine.py              # 核心引擎 ~120 行
├── providers/
│   ├── __init__.py
│   ├── base.py            # 抽象基类 -> repair(image, mask, prompt) -> np.ndarray
│   ├── replicate.py       # Replicate FLUX Fill 客户端 ~100 行
│   ├── zhipu.py           # 智谱 CogView-4 客户端 ~80 行
│   └── opencv_fallback.py # cv2.inpaint() 传统修复 ~30 行
├── local/                 # 本地模型占位
│   ├── __init__.py
│   ├── lama.py            # LaMa inpaint (stub) — 未来实现
│   └── flux_dev.py        # FLUX.1 Fill dev (stub) — 未来实现
└── README.md
```

与现有 `modules/image_studio/ai_providers.py` 的关系：不冲突。现有的 `ai_enhance_image()` / `ai_restore_faces()` 继续保留（它们是本地 OpenCV 轻量增强），新的 RepairEngine 做**智能 mask 修复**。

---

## 4. 核心代码骨架

### 4.1 provider 枚举 + 配置

```python
# modules/repair/engine.py

from enum import Enum

class RepairProvider(str, Enum):
    REPLICATE_FLUX = "replicate_flux"       # ★ 推荐，效果最好
    ZHIPU_COGVIEW = "zhipu_cogview"         # 备选，已有 Key
    LOCAL_LAMA = "local_lama"               # 占位 — 未来升级
    NONE = "none"                           # 离线降级: OpenCV inpaint

class RepairEngine:
    """AI 修复引擎：根据配置选择 provider"""

    def __init__(self, config: dict):
        # config = engine.get("config") or 直接传 dict
        provider_name = config.get("repair", {}).get("provider", "replicate_flux")
        self.provider = RepairProvider(provider_name)
        self.api_keys = config.get("api_keys", {})
        self._impl = self._resolve()

    def _resolve(self) -> BaseRepairProvider:
        if self.provider == RepairProvider.REPLICATE_FLUX:
            from .providers.replicate import ReplicateRepair
            return ReplicateRepair(self.api_keys.get("replicate", ""))
        elif self.provider == RepairProvider.ZHIPU_COGVIEW:
            from .providers.zhipu import ZhipuRepair
            return ZhipuRepair(self.api_keys.get("zhipu", ""))
        elif self.provider == RepairProvider.LOCAL_LAMA:
            from .local.lama import LamaRepair
            return LamaRepair()     # stub — NotImplementedError
        else:
            from .providers.opencv_fallback import OpenCVFallback
            return OpenCVFallback()  # cv2.inpaint()

    def repair(self, image: np.ndarray, mask: np.ndarray,
               prompt: str = "", negative_prompt: str = "") -> np.ndarray:
        """
        主入口：AI 修复图像中 mask 白色区域
        
        Args:
            image: BGRA uint8 ndarray (H,W,4)
            mask:  单通道 uint8 (H,W), 白色=需要修复的区域
            prompt: 描述需要生成的内容 (e.g. "自然背景，无痕迹")
        
        Returns:
            BGRA uint8 ndarray 修复后的图像
        """
        return self._impl.repair(image, mask, prompt, negative_prompt)
```

### 4.2 抽象基类

```python
# modules/repair/providers/base.py

import numpy as np
from abc import ABC, abstractmethod

class BaseRepairProvider(ABC):
    """所有 provider 必须实现 repair()"""

    @abstractmethod
    def repair(self, image: np.ndarray, mask: np.ndarray,
               prompt: str = "", negative_prompt: str = "") -> np.ndarray:
        ...
```

### 4.3 OpenCV 降级（离线模式）

```python
# modules/repair/providers/opencv_fallback.py

import cv2
import numpy as np
from .base import BaseRepairProvider

class OpenCVFallback(BaseRepairProvider):
    """纯 CPU 传统修复 — 不需要 API Key，不需要 GPU"""

    def repair(self, image: np.ndarray, mask: np.ndarray,
               prompt: str = "", negative_prompt: str = "") -> np.ndarray:
        # cv2.inpaint 要求 mask 白色=修复区域
        gray_mask = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY) if mask.ndim == 3 else mask
        _, bin_mask = cv2.threshold(gray_mask, 127, 255, cv2.THRESH_BINARY)
        bgr = image[:, :, :3]
        alpha = image[:, :, 3] if image.shape[2] == 4 else np.full(image.shape[:2], 255, np.uint8)
        result_bgr = cv2.inpaint(bgr, bin_mask, inpaintRadius=3, flags=cv2.INPAINT_TELEA)
        return np.dstack([result_bgr, alpha])
```

### 4.4 Replicate FLUX Fill（首选云 API）

```python
# modules/repair/providers/replicate.py

import cv2, base64, io, time, requests
import numpy as np
from PIL import Image
from .base import BaseRepairProvider

class ReplicateRepair(BaseRepairProvider):
    """Replicate FLUX.1 Fill [pro] — 目前云端 inpainting 最强"""

    API_URL = "https://api.replicate.com/v1/predictions"

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.headers = {
            "Authorization": f"Token {api_key}",
            "Content-Type": "application/json"
        }

    def _pil_to_b64(self, pil_img: Image.Image) -> str:
        buf = io.BytesIO()
        pil_img.save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode()

    def repair(self, image: np.ndarray, mask: np.ndarray,
               prompt: str = "", negative_prompt: str = "") -> np.ndarray:
        # BGR(A) → PIL RGB
        img_rgb = cv2.cvtColor(image[:, :, :3], cv2.COLOR_BGR2RGB)
        img_pil = Image.fromarray(img_rgb)
        # mask → PIL (单通道)
        mask_gray = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY) if mask.ndim == 3 else mask
        mask_pil = Image.fromarray(mask_gray)

        img_b64 = self._pil_to_b64(img_pil)
        mask_b64 = self._pil_to_b64(mask_pil)

        # 调用 Replicate API（异步轮询模式）
        payload = {
            "version": "black-forest-labs/flux-fill-pro",
            "input": {
                "image": f"data:image/png;base64,{img_b64}",
                "mask": f"data:image/png;base64,{mask_b64}",
                "prompt": prompt or "fill naturally, seamless blend",
                "num_outputs": 1,
            }
        }
        # 创建 prediction
        resp = requests.post(self.API_URL, json=payload, headers=self.headers)
        data = resp.json()
        if "id" not in data:
            return image  # 失败返回原图

        # 轮询直到完成（Replicate 异步）
        poll_url = f"{self.API_URL}/{data['id']}"
        for _ in range(60):
            time.sleep(2)
            r = requests.get(poll_url, headers=self.headers)
            d = r.json()
            if d["status"] == "succeeded":
                result_url = d["output"][0]
                # 下载结果
                img_resp = requests.get(result_url)
                result_pil = Image.open(io.BytesIO(img_resp.content)).convert("RGBA")
                result_np = cv2.cvtColor(np.array(result_pil), cv2.COLOR_RGBA2BGRA)
                return result_np
            elif d["status"] == "failed":
                break

        return image  # 超时/失败返回原图
```

### 4.5 本地模型占位

```python
# modules/repair/local/lama.py

from ..providers.base import BaseRepairProvider

class LamaRepair(BaseRepairProvider):
    """LaMa 本地模型占位 — 将来安装 diffusers 后实现"""

    def repair(self, image, mask, prompt="", negative_prompt=""):
        raise NotImplementedError(
            "LaMa local model not installed. "
            "Run: pip install lama-cleaner\n"
            "Or switch to cloud provider by setting repair.provider in config."
        )
```

---

## 5. config.yaml 配置

```yaml
# ~/.phantomvox/config.yaml
restore:
  face: ""
  superres: ""
  strength: 0.8

# 新增
repair:
  provider: "replicate_flux"        # 默认云端
  prompt_default: "自然修复，无缝融合"

api_keys:
  replicate: "r8_xxxxxxxxxxxx"       # Replicate API Key
  zhipu: "zai_xxxxxxxxxxxx"          # 智谱 API Key（已有）
```

### Replicate API Key 获取

1. 打开 https://replicate.com/account/api-tokens
2. 注册 → 生成 token（通常有免费额度）
3. 写入 `config.yaml` 的 `api_keys.replicate`

### 智谱 CogView-4 作为国内备选

如果 Replicate 网络不通或没有 Key，你的 ZAI_API_KEY 可以直接调智谱：

```python
# modules/repair/providers/zhipu.py
# 调用 CogView-4 API：图片 + mask → 图生图生成修复区域
# 已有 ZAI_API_KEY = os.getenv("ZAI_API_KEY")
```

---

## 6. 用户交互流程（Flutter 端）

### 6.1 流程详解

```
1. 用户选择选区工具 (brush / rect / polygon)
   └→ 在画布上绘制需要修复的区域
   
2. 用户点击 "AI Repair" 按钮
   └→ 弹出 BottomSheet 选择：
      ├── 智能移除物体（自动填充）
      └── 自定义提示 → 输入框（可选）

3. 后端：接收当前图层 + mask + prompt
   ├── 根据 provider 配置调用云 API / OpenCV / 本地
   └── 返回修复后图像

4. Flutter 更新预览
```

### 6.2 与现有选区系统的集成

已有选区系统（brush/rect 工具）+ 蒙版 layer：

```python
# 后端侧：前端发送 mask 坐标/bitmap → _req_doc_snapshot() 含当前图层
# 后端从选区接口获取 mask np.ndarray

@app.route("/api/v1/editor/ai-repair", methods=["POST"])
def editor_ai_repair():
    data = request.get_json(silent=True) or {}
    doc = _req_doc_snapshot()
    prompt = data.get("prompt", "")
    
    repair_engine = RepairEngine(app.engine.get("config").get_all())
    
    # mask: 前端传选区坐标 → 后端 fillPoly 生成 mask
    # 如果前端传了 mask_b64 则直接用
    # 否则根据 points 生成
    mask = _build_mask(doc, data)
    
    for layer in doc.layers:
        if layer.visible and not layer.locked:
            layer.image = repair_engine.repair(layer.image, mask, prompt)
    
    return jsonify(_doc_response(doc))
```

---

## 7. Flutter 工具栏改动

已有选区绘制 + 一个独立修复按钮：

```dart
['ai-repair', Icons.auto_fix_high, 'AI Repair', true, 'ai-repair'],
```

点击逻辑：

```dart
case 'ai-repair':
  // 1. 获取当前选区
  //    - 如果有 brush 绘制的选区 → 后端自动生成 mask
  //    - 如果有矩形选区 → 后端截取 region
  //    - 如果无选区 → 弹窗提示"请先绘制要修复的区域"
  // 2. 可选：弹出 prompt 输入框（选填）
  // 3. 调用 _transformVoid('ai-repair', {'prompt': prompt})
  break;
```

**参数结构**：

```dart
POST /api/v1/editor/ai-repair
{
  "prompt": "自然背景，无缝融合",
  "mask_points": [[x1,y1], [x2,y2], ...],   // 可选：多边形选区坐标
  "mask_b64": "...",                          // 可选：直接传 mask PNG base64
  "provider": "replicate_flux"                // 可选：覆盖配置
}
```

---

## 8. 云 API 优先级

| 优先级 | 服务 | 模型 | 效果 | 备注 |
|--------|------|------|------|------|
| ★★★★★ | **Replicate** | FLUX.1 Fill [pro] | 最强 | 需要 Key（免费额度） |
| ★★★★ | **Black Forest Labs** | FLUX Fill 官方 API | 强 | 直接 API 调用 |
| ★★★ | **智谱 CogView-4** | 图生图 | 中 | 已有 Key，国内直达 |
| ★★ | **OpenCV Telea** | cv2.inpaint | 基础 | 离线降级，无 Key 可用 |

Fallback 链（按优先级）：

```
provider == "replicate_flux"
  → 有 Key 且网络可达 → Replicate API
  → 网络不通 → 自动降级到 OpenCV
  → 无 Key → 自动降级到 OpenCV

provider == "zhipu_cogview"
  → 有 Key → 智谱 API
  → 无 Key → OpenCV
```

---

## 9. 现有工具的整合

| 现有按钮 | 处理方式 |
|----------|----------|
| `ai-enhance` | 保留不变（本地 OpenCV 增强管线，实时轻量） |
| `ai-restore` | 保留不变（OpenCV 人脸修复） |
| `ai-repair` | **新增按钮**：选区 → 云 API 智能修复 |
| `upscale` / `denoise` / ... | 保留不变 |

**互不冲突**：原有按钮保留给用户"即时效 → 无需等待"的轻量操作；新 `ai-repair` 用于"选区 → AI 生成 → 等待返回"的智能修复。

---

## 10. 实施计划

| 步骤 | 内容 | 文件 | 预估行数 |
|------|------|------|---------|
| 1 | `modules/repair/engine.py` — 引擎 + provider 枚举 + config 读入 | 1 个文件 | ~80 行 |
| 2 | `modules/repair/providers/base.py` — 抽象基类 | 1 个文件 | ~20 行 |
| 3 | `modules/repair/providers/opencv_fallback.py` — CPU 降级 | 1 个文件 | ~30 行 |
| 4 | `modules/repair/providers/replicate.py` — Replicate FLUX 客户端 | 1 个文件 | ~120 行 |
| 5 | `modules/repair/providers/zhipu.py` — 智谱 CogView 客户端 | 1 个文件 | ~80 行 |
| 6 | `modules/repair/local/lama.py` — LaMa 占位 stub | 1 个文件 | ~15 行 |
| 7 | API 路由 `POST /api/v1/editor/ai-repair` | `api_server/__init__.py` 追加 | ~20 行 |
| 8 | 注册 `RepairEngine` 到 `create_app()` | `api_server/__init__.py` | ~3 行 |
| 9 | Flutter 按钮 + `_execActionTool()` case | `image_studio_page.dart` | ~30 行 |
| 10 | config.yaml 配置项 + 安装依赖 | `config_manager.py` + requirements | ~10 行 |
| 11 | 编译验证：flutter clean + build | — | — |

**总计约 410 行代码**，其中核心业务逻辑不到 200 行。

---

## 11. 与现有架构的关系图

```
config.yaml
  repair.provider = "replicate_flux"
  api_keys.replicate = "r8_xxx"
        │
        ▼
RepairEngine.__init__() → _resolve() → 实例化对应 provider
        │
        ▼
POST /api/v1/editor/ai-repair
  body: {prompt, mask_points, ...}
        │
        ▼
editor_ai_repair() in api_server/__init__.py
        │
        ▼
doc = _req_doc_snapshot()
mask = _build_mask(doc, data)   ← 选区转 mask
        │
        ▼
layer.image = engine.repair(layer.image, mask, prompt)
        │
        ▼
repair() dispatch:
  ├── ReplicateRepair.repair() → FLUX Fill API → 返回 BGR ndarray
  ├── ZhipuRepair.repair()     → CogView-4 API  → 返回 BGR ndarray
  ├── LamaRepair.repair()      → NotImplementedError (stub)
  └── OpenCVFallback.repair()  → cv2.inpaint()  → 返回 BGR ndarray
        │
        ▼
jsonify(_doc_response(doc)) → Flutter 更新预览
```

---

## 12. 后续扩展

- **更多本地模型**：升级 GPU 后，补全 `local/lama.py` 和 `local/flux_dev.py`，替换 stub 为真实 diffusers 代码，接口不变
- **更多云服务**：按需添加 Stability AI、ModelsLab、HuggingFace 等 provider
- **批量修复**：一次上传多张图片逐一修复
- **局部强度控制**：mask 灰度值 → 混合系数，实现半透明修复
- **修复历史**：存储修复前后对比，支持撤销/恢复
- **中文 UI**：所有按钮文字、prompt 默认值走 i18n
