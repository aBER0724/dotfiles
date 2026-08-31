# kitty watcher — 后台线程刷新系统状态缓存, 主线程定时器触发 tab bar 重绘.
#
# 配合 tab_bar_style custom + ~/dotfiles/kitty/tab_bar.py 使用.
# 在 kitty.conf 里启用:  watcher watcher.py
#
# 工作流程:
#   1. on_load 时启动一个 daemon 线程, 每 REFRESH_INTERVAL 秒执行
#      ~/dotfiles/kitty/status.sh, 把输出写到 STATUS_CACHE_FILE.
#      (status.sh 自身 ~1-2s, 必须放后台线程避免卡 UI)
#   2. 同时在 kitty 主循环注册 add_timer 定时器, 周期性调
#      boss.refresh_active_tab_bar() 触发 tab bar 重绘.
#      tab_bar.py 的 draw_tab 会读取 STATUS_CACHE_FILE 渲染到右侧.

from __future__ import annotations

import os
import subprocess
import threading
import time

STATUS_CACHE_FILE = os.path.expanduser('~/.cache/kitty-status.txt')
STATUS_SCRIPT = os.path.expanduser('~/dotfiles/kitty/status.sh')

METRICS_REFRESH_INTERVAL = 30
CLOCK_REDRAW_INTERVAL = 10

_started = False
_start_lock = threading.Lock()


def _write_status(text: str) -> None:
    cache_dir = os.path.dirname(STATUS_CACHE_FILE)
    os.makedirs(cache_dir, exist_ok=True)
    tmp = STATUS_CACHE_FILE + '.tmp'
    try:
        with open(tmp, 'w', encoding='utf-8') as f:
            f.write(text)
        os.replace(tmp, STATUS_CACHE_FILE)
    except OSError:
        pass


def _refresh_status() -> None:
    try:
        result = subprocess.run(
            ['/bin/bash', STATUS_SCRIPT],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            _write_status(result.stdout.strip())
    except (OSError, subprocess.TimeoutExpired):
        pass


def _status_loop() -> None:
    while True:
        _refresh_status()
        time.sleep(METRICS_REFRESH_INTERVAL)


def _setup_redraw_timer(boss) -> None:
    from kitty.fast_data_types import add_timer

    def _redraw(timer_id) -> None:
        try:
            boss.refresh_active_tab_bar()
        except Exception:
            pass

    # Redraw often enough to keep the clock current; metrics refresh independently.
    add_timer(_redraw, float(CLOCK_REDRAW_INTERVAL), True)

def on_load(boss, data) -> None:
    global _started
    with _start_lock:
        if _started:
            return
        _started = True

    # 主线程定时器: 周期性触发 tab bar 重绘
    _setup_redraw_timer(boss)

    # 后台线程: 跑 status.sh 写缓存
    t = threading.Thread(target=_status_loop, name='kitty-status-refresh', daemon=True)
    t.start()
