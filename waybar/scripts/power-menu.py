#!/usr/bin/python3
"""Waybar 的主题化电源下拉菜单。"""
import atexit
import os
import re
import signal
import subprocess
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
PID_FILE = RUNTIME / "waybar-power-menu.pid"
THEME_FILE = Path.home() / ".config/omarchy/current/theme/waybar.css"
DEFAULTS = {
    "foreground": "#F0F8FF",
    "background": "#0A1428",
    "warning": "#FF40A3",
    "caution": "#BDBDBD",
    "date": "#00BFFF",
    "misc": "#BDBDBD",
}
ACTIONS = [
    ("󰍃", "注销", "结束当前 niri 会话", ["niri", "msg", "action", "quit"], True, False),
    ("󰒲", "睡眠", "暂停并保留会话", ["systemctl", "suspend"], False, False),
    ("󰜉", "重启", "重新启动系统", ["systemctl", "reboot"], True, True),
    ("", "关机", "关闭计算机", ["systemctl", "poweroff"], True, True),
]


def theme_colors() -> dict[str, str]:
    colors = DEFAULTS.copy()
    try:
        text = THEME_FILE.read_text()
        for name, value in re.findall(r"@define-color\s+([\w-]+)\s+(#[0-9A-Fa-f]{6})\s*;", text):
            colors[name] = value
    except OSError:
        pass
    return colors


def popup_css(c: dict[str, str]) -> bytes:
    return f"""
    window.powermenu {{
      background: {c['background']};
      border: 1px solid alpha({c['warning']}, 0.62);
      border-radius: 18px;
      color: {c['foreground']};
    }}
    box.panel {{ padding: 14px; }}
    box.heading {{ padding: 1px 4px 12px; }}
    label.header-icon {{ color: {c['warning']}; font-size: 18pt; padding-right: 10px; }}
    label.title {{ color: {c['foreground']}; font-size: 13pt; font-weight: bold; }}
    label.subtitle {{ color: alpha({c['foreground']}, 0.55); font-size: 9pt; }}
    button.action {{
      background: alpha({c['foreground']}, 0.045);
      border: 1px solid alpha({c['caution']}, 0.18);
      border-radius: 12px;
      padding: 12px 14px;
      margin: 4px;
      min-width: 118px;
      min-height: 72px;
      box-shadow: none;
    }}
    button.action:hover,
    button.action:focus {{
      background: alpha({c['date']}, 0.14);
      border-color: alpha({c['date']}, 0.72);
    }}
    button.action.danger:hover,
    button.action.danger:focus {{
      background: alpha({c['warning']}, 0.15);
      border-color: alpha({c['warning']}, 0.78);
    }}
    label.action-icon {{ color: {c['date']}; font-size: 20pt; padding-bottom: 3px; }}
    button.danger label.action-icon {{ color: {c['warning']}; }}
    label.action-name {{ color: {c['foreground']}; font-size: 10pt; font-weight: bold; }}
    label.action-desc {{ color: alpha({c['foreground']}, 0.48); font-size: 8pt; }}
    box.confirm-view {{ padding: 10px 8px 6px; min-width: 270px; }}
    label.confirm-icon {{ color: {c['warning']}; font-size: 25pt; padding-bottom: 8px; }}
    label.confirm-title {{ color: {c['foreground']}; font-size: 13pt; font-weight: bold; }}
    label.confirm-text {{ color: alpha({c['foreground']}, 0.58); padding: 4px 0 12px; }}
    button.confirm,
    button.cancel {{
      border-radius: 10px;
      padding: 9px 18px;
      margin: 4px;
      box-shadow: none;
    }}
    button.confirm {{ background: {c['warning']}; color: {c['background']}; font-weight: bold; }}
    button.cancel {{
      background: alpha({c['foreground']}, 0.07);
      color: {c['foreground']};
      border: 1px solid alpha({c['caution']}, 0.22);
    }}
    button.cancel:hover {{ background: alpha({c['date']}, 0.13); }}
    """.encode()


def toggle_existing() -> bool:
    try:
        pid = int(PID_FILE.read_text().strip())
        if pid != os.getpid():
            os.kill(pid, signal.SIGTERM)
            return True
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        pass
    PID_FILE.write_text(str(os.getpid()))
    return False


def cleanup() -> None:
    try:
        if PID_FILE.read_text().strip() == str(os.getpid()):
            PID_FILE.unlink()
    except (FileNotFoundError, PermissionError):
        pass


def main() -> int:
    if toggle_existing():
        return 0
    atexit.register(cleanup)
    colors = theme_colors()

    win = Gtk.Window(title="Power Menu")
    win.set_decorated(False)
    win.set_resizable(False)
    win.set_name("powermenu")
    win.get_style_context().add_class("powermenu")
    win.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)

    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_namespace(win, "waybar-power-menu")
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.RIGHT, True)
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, 54)
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.RIGHT, 14)
    GtkLayerShell.set_exclusive_zone(win, 0)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.ON_DEMAND)

    provider = Gtk.CssProvider()
    provider.load_from_data(popup_css(colors))
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    panel.get_style_context().add_class("panel")
    win.add(panel)

    close_timer = 0
    has_entered = False

    def close(*_) -> bool:
        win.close()
        return False

    def cancel_close() -> None:
        nonlocal close_timer
        if close_timer:
            GLib.source_remove(close_timer)
            close_timer = 0

    def on_enter(_, event) -> bool:
        nonlocal has_entered
        if event.detail != Gdk.NotifyType.INFERIOR:
            has_entered = True
            cancel_close()
        return False

    def on_leave(_, event) -> bool:
        nonlocal close_timer
        if has_entered and event.detail != Gdk.NotifyType.INFERIOR:
            cancel_close()
            close_timer = GLib.timeout_add(450, close)
        return False

    def clear_panel() -> None:
        for child in panel.get_children():
            panel.remove(child)

    def run(command: list[str]) -> None:
        close()
        subprocess.Popen(command, start_new_session=True)

    def action_button(icon: str, name: str, desc: str, danger: bool) -> Gtk.Button:
        button = Gtk.Button()
        button.set_relief(Gtk.ReliefStyle.NONE)
        button.get_style_context().add_class("action")
        if danger:
            button.get_style_context().add_class("danger")
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        icon_label = Gtk.Label(label=icon)
        icon_label.get_style_context().add_class("action-icon")
        name_label = Gtk.Label(label=name)
        name_label.get_style_context().add_class("action-name")
        desc_label = Gtk.Label(label=desc)
        desc_label.get_style_context().add_class("action-desc")
        content.pack_start(icon_label, False, False, 0)
        content.pack_start(name_label, False, False, 0)
        content.pack_start(desc_label, False, False, 0)
        button.add(content)
        return button

    def show_actions() -> None:
        clear_panel()
        heading = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        heading.get_style_context().add_class("heading")
        icon = Gtk.Label(label="")
        icon.get_style_context().add_class("header-icon")
        heading.pack_start(icon, False, False, 0)
        titles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        title = Gtk.Label(label="电源菜单")
        title.set_xalign(0)
        title.get_style_context().add_class("title")
        subtitle = Gtk.Label(label="选择会话或系统操作")
        subtitle.set_xalign(0)
        subtitle.get_style_context().add_class("subtitle")
        titles.pack_start(title, False, False, 0)
        titles.pack_start(subtitle, False, False, 0)
        heading.pack_start(titles, True, True, 0)
        panel.pack_start(heading, False, False, 0)

        grid = Gtk.Grid(column_homogeneous=True, row_homogeneous=True)
        for index, (icon_text, name, desc, command, confirm, danger) in enumerate(ACTIONS):
            button = action_button(icon_text, name, desc, danger)
            if confirm:
                button.connect("clicked", lambda _, n=name, d=desc, c=command: show_confirm(n, d, c))
            else:
                button.connect("clicked", lambda _, c=command: run(c))
            grid.attach(button, index % 2, index // 2, 1, 1)
        panel.pack_start(grid, False, False, 0)
        panel.show_all()

    def show_confirm(name: str, desc: str, command: list[str]) -> None:
        clear_panel()
        view = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        view.get_style_context().add_class("confirm-view")
        icon = Gtk.Label(label="󰛌")
        icon.get_style_context().add_class("confirm-icon")
        title = Gtk.Label(label=f"确认{name}？")
        title.get_style_context().add_class("confirm-title")
        text = Gtk.Label(label=desc)
        text.get_style_context().add_class("confirm-text")
        view.pack_start(icon, False, False, 0)
        view.pack_start(title, False, False, 0)
        view.pack_start(text, False, False, 0)

        buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, homogeneous=True)
        cancel = Gtk.Button(label="取消")
        cancel.get_style_context().add_class("cancel")
        cancel.connect("clicked", lambda _: show_actions())
        confirm = Gtk.Button(label="确认")
        confirm.get_style_context().add_class("confirm")
        confirm.connect("clicked", lambda _: run(command))
        buttons.pack_start(cancel, True, True, 0)
        buttons.pack_start(confirm, True, True, 0)
        view.pack_start(buttons, False, False, 0)
        panel.pack_start(view, False, False, 0)
        panel.show_all()

    def on_key(_, event) -> bool:
        if event.keyval == Gdk.KEY_Escape:
            close()
            return True
        return False

    win.connect("enter-notify-event", on_enter)
    win.connect("leave-notify-event", on_leave)
    win.connect("key-press-event", on_key)
    win.connect("destroy", lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGTERM, lambda *_: win.close())

    show_actions()
    win.show_all()
    win.present()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
