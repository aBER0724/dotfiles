#!/usr/bin/env python3

from kittens.tui.handler import result_handler


def main(args: list[str]) -> None:
    return None


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss) -> None:
    """Move the active pane's nearest separator in an absolute direction."""
    tab = boss.active_tab
    if tab is None or len(args) < 2:
        return

    direction = args[1]
    if direction not in {"left", "down", "up", "right"}:
        return

    # Operate on the split pair itself. Kitty's normal resize command means
    # grow/shrink the active pane, whereas this kitten changes the pair bias so
    # the separator always follows the requested screen direction.
    active = tab.windows.active_group
    layout = tab.current_layout
    root = getattr(layout, "pairs_root", None)
    if active is None or root is None:
        return

    pair = root.pair_for_window(active.id)
    axis_is_horizontal = direction in { "left", "right" }
    while pair is not None and (pair.horizontal is not axis_is_horizontal or pair.is_redundant):
        pair = pair.parent(root)
    if pair is None:
        return

    cell_step = layout.bias_increment_for_cell(tab.windows, axis_is_horizontal) * 5
    delta = -cell_step if direction in { "left", "up" } else cell_step
    pair.bias = max(0.0, min(1.0, pair.bias + delta))
    tab.relayout()
