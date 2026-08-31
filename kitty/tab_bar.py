# kitty custom tab bar
# Left: kitty's native powerline tabs. Right: reverse powerline system status.

from __future__ import annotations

import os
from datetime import datetime
from typing import TYPE_CHECKING

from kitty.fast_data_types import get_options
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


# System status colors are derived from Kitty's live options. nbshell updates those
# options through load-config, so the custom status area follows every theme change.
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


def _theme_colors(draw_data: DrawData) -> tuple[int, int, int, int, int, int]:
    """Return status colors from the currently loaded Kitty/nbshell theme."""
    opts = get_options()
    bar_bg = int(draw_data.default_bg)
    cpu_bg = int(draw_data.inactive_bg)
    mem_bg = int(draw_data.active_bg)
    time_bg = int(opts.cursor or opts.active_border_color)
    text_fg = int(opts.foreground)
    time_fg = int(opts.cursor_text_color or opts.background)
    return bar_bg, cpu_bg, mem_bg, time_bg, text_fg, time_fg

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
    bar_bg, cpu_bg, mem_bg, time_bg, text_fg, time_fg = _theme_colors(draw_data)
    screen.cursor.x = end
    screen.cursor.bg = as_rgb(bar_bg)
    screen.cursor.fg = as_rgb(text_fg)
    screen.erase_in_line(0, False)

    # The cursor inherits the last tab's font style; reset it for system data.
    screen.cursor.bold = False
    screen.cursor.italic = False
    screen.cursor.x = screen.columns - status_width
    _draw_segment(screen, separator, bar_bg, cpu_bg, text_fg, cpu_text)
    _draw_segment(screen, separator, cpu_bg, mem_bg, text_fg, mem_text)
    _draw_segment(screen, separator, mem_bg, time_bg, time_fg, time_text)

    return end
