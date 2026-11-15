# SPDX-License-Identifier: AGPL-3.0-only
"""UI-free homr state. No network, migrations, or access to the score library."""
import json
import os
from pathlib import Path
import sys

APP_PATH = str(Path(__file__).resolve().parent)
MODEL_STORAGE = os.environ.get("ARIA_OMR_MODELS", "")
platform = "android" if "ANDROID_ROOT" in os.environ else "win" if sys.platform == "win32" else "linux"
PHASES = {"Preparing": "正在准备识别", "Segmenting": "正在分析五线谱", "Extracting": "正在提取音符", "Transforming": "正在识别节奏与音高"}


def status(value):
    target = os.environ.get("ARIA_OMR_STATUS")
    if not target:
        return
    path = Path(target)
    temporary = path.with_suffix(".python.tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
    temporary.replace(path)


def check_cancelled():
    flag = os.environ.get("ARIA_OMR_CANCEL")
    if flag and Path(flag).exists():
        raise InterruptedError("识别已取消")


class State:
    homr_state = "Preparing"
    homr_progress = 0
    threads = min(4, os.cpu_count() or 1)

    def __setattr__(self, name, value):
        check_cancelled()
        object.__setattr__(self, name, value)
        if name in ("homr_state", "homr_progress"):
            page = int(os.environ.get("ARIA_OMR_PAGE", "1"))
            total = int(os.environ.get("ARIA_OMR_TOTAL", "1"))
            local = min(100, max(0, float(self.homr_progress))) / 100
            status({"state": "running", "message": f"第 {page}/{total} 页 · {PHASES.get(self.homr_state, '正在识别曲谱')}",
                    "progress": min(0.98, (page - 1 + local * 0.95) / total)})


appdata = State()
