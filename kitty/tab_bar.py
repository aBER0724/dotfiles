# kitty custom tab bar
# Left: kitty's native powerline tabs. Right: reverse powerline system status.

from __future__ import annotations

import os
from datetime import datetime
from typing import TYPE_CHECKING

from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    draw_tab_with_powerline,
)

if TYPE_CHECKING:
    from kitty.fast_data_types import Screen


STATUS_CACHE_FILE = os.path.expanduser('~/.cache/kitty-status.txt')

# Kaku Dark palette
BAR_BG = 0x15141B
CPU_BG = 0x1F1D28
MEM_BG = 0x29263C
TIME_BG = 0x8E6AD9
TEXT_FG = 0xD5D4D6
TIME_FG = 0x15141B

REVERSE_SEPARATORS = {
    'angled': '',
    'round': '',
    'slanted': '',
}


def _read_metrics() -> tuple[str, str]:
    try:
        with open(STATUS_CACHE_FILE, 'r', encoding='utf-8') as f:
            cpu, mem = f.read().strip().split('|', 1)
            return cpu, mem
    except (OSError, ValueError):
        return '--', '--'


SHELL_NAMES = {'zsh', 'bash', 'fish', 'sh', 'dash', 'nu', 'xonsh'}
MAX_SIMPLE_TITLE_LENGTH = 18


def _shorten(text: str) -> str:
    text = text.strip() or '?'
    if len(text) <= MAX_SIMPLE_TITLE_LENGTH:
        return text
    return text[:MAX_SIMPLE_TITLE_LENGTH] + '…'


def draw_title(data: dict) -> str:
    """Show the cwd basename for shells, otherwise the foreground program."""
    tab = data['tab']
    # Login shells report names such as '-zsh'; normalize before matching.
    exe = (tab.active_exe or '').strip().lstrip('-')
    if exe in SHELL_NAMES or not exe:
        cwd = (tab.active_wd or '').rstrip(os.sep)
        home = os.path.expanduser('~').rstrip(os.sep)
        if cwd == home:
            title = '~'
        else:
            title = os.path.basename(cwd) or os.sep
    else:
        title = exe
    return _shorten(title)


def _draw_segment(
    screen: 'Screen',
    separator: str,
    previous_bg: int,
    segment_bg: int,
    foreground: int,
    text: str,
) -> None:
    # Reverse powerline separator points left into the preceding segment.
    screen.cursor.bg = as_rgb(previous_bg)
    screen.cursor.fg = as_rgb(segment_bg)
    screen.draw(separator)
    screen.cursor.bg = as_rgb(segment_bg)
    screen.cursor.fg = as_rgb(foreground)
    screen.draw(text)


def draw_tab(
    draw_data: DrawData,
    screen: 'Screen',
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    # Preserve kitty's native powerline appearance for tabs.
    end = draw_tab_with_powerline(
        draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data
    )

    if not is_last or extra_data.for_layout:
        return end

    cpu, mem = _read_metrics()
    # Read time directly on every redraw so it never inherits stale cache time.
    current_time = datetime.now().strftime('%H:%M')

    cpu_text = f' CPU {cpu}% '
    mem_text = f' MEM {mem}% '
    time_text = f' {current_time} '
    separator = REVERSE_SEPARATORS.get(draw_data.powerline_style, '')
    status_width = len(cpu_text) + len(mem_text) + len(time_text) + 3

    if end + status_width + 1 >= screen.columns:
        return end

    # Clear everything after the last tab before jumping to the right edge.
    # Without this, a previously longer title can remain visible between the
    # truncated tab and the status segments.
    screen.cursor.x = end
    screen.cursor.bg = as_rgb(BAR_BG)
    screen.cursor.fg = as_rgb(TEXT_FG)
    screen.erase_in_line(0, False)

    # The cursor inherits the last tab's font style; reset it for system data.
    screen.cursor.bold = False
    screen.cursor.italic = False
    screen.cursor.x = screen.columns - status_width
    _draw_segment(screen, separator, BAR_BG, CPU_BG, TEXT_FG, cpu_text)
    _draw_segment(screen, separator, CPU_BG, MEM_BG, TEXT_FG, mem_text)
    _draw_segment(screen, separator, MEM_BG, TIME_BG, TIME_FG, time_text)

    return end
