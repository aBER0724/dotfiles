#!/usr/bin/python3
"""Waybar 电源下拉菜单：注销、睡眠、重启、关机。"""
import atexit
import os
import signal
import subprocess
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, Gtk, GtkLayerShell

PID_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "waybar-power-menu.pid"

CSS = b"""
window.powermenu {
  background-color: alpha(@theme_bg_color, 0.97);
  border: 1px solid alpha(@theme_fg_color, 0.35);
  border-radius: 14px;
}
window.powermenu box.menu { padding: 10px; }
window.powermenu label.title {
  color: @theme_fg_color;
  font-weight: bold;
  padding: 4px 8px 10px;
}
window.powermenu button {
  background: transparent;
  color: @theme_fg_color;
  border: none;
  border-radius: 9px;
  padding: 10px 14px;
  margin: 2px;
  font-family: "JetBrainsMono Nerd Font";
  font-size: 11pt;
}
window.powermenu button:hover,
window.powermenu button:focus {
  background: alpha(@theme_selected_bg_color, 0.22);
}
window.powermenu button.danger { color: #f38ba8; }
window.powermenu button.confirm {
  background: #f38ba8;
  color: #1e1e2e;
  font-weight: bold;
}
window.powermenu button.cancel {
  background: alpha(@theme_fg_color, 0.10);
}
window.powermenu separator {
  background: alpha(@theme_fg_color, 0.18);
  margin: 7px 5px;
  min-height: 1px;
}
"""

ACTIONS = [
    ("󰍃  注销", ["niri", "msg", "action", "quit"], True),
    ("󰒲  睡眠", ["systemctl", "suspend"], False),
    ("󰜉  重启", ["systemctl", "reboot"], True),
    ("  关机", ["systemctl", "poweroff"], True),
]


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

    win = Gtk.Window(title="Power Menu")
    win.set_decorated(False)
    win.set_resizable(False)
    win.set_name("powermenu")
    win.get_style_context().add_class("powermenu")

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
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    root.get_style_context().add_class("menu")
    win.add(root)

    def close(*_) -> bool:
        win.close()
        return False

    def run(command: list[str]) -> None:
        close()
        subprocess.Popen(command, start_new_session=True)

    def show_actions() -> None:
        for child in root.get_children():
            root.remove(child)
        title = Gtk.Label(label="电源菜单")
        title.set_xalign(0)
        title.get_style_context().add_class("title")
        root.pack_start(title, False, False, 0)

        for index, (label, command, confirm) in enumerate(ACTIONS):
            if index == 2:
                root.pack_start(Gtk.Separator(), False, False, 0)
            button = Gtk.Button(label=label)
            button.set_relief(Gtk.ReliefStyle.NONE)
            button.get_child().set_xalign(0)
            if index >= 2:
                button.get_style_context().add_class("danger")
            if confirm:
                button.connect("clicked", lambda _, l=label, c=command: show_confirm(l, c))
            else:
                button.connect("clicked", lambda _, c=command: run(c))
            root.pack_start(button, False, False, 0)
        root.show_all()

    def show_confirm(label: str, command: list[str]) -> None:
        for child in root.get_children():
            root.remove(child)
        prompt = Gtk.Label(label=f"确定要{label.split()[-1]}吗？")
        prompt.get_style_context().add_class("title")
        root.pack_start(prompt, False, False, 4)

        confirm = Gtk.Button(label="确认")
        confirm.get_style_context().add_class("confirm")
        confirm.connect("clicked", lambda _: run(command))
        root.pack_start(confirm, False, False, 2)

        cancel = Gtk.Button(label="取消")
        cancel.get_style_context().add_class("cancel")
        cancel.connect("clicked", lambda _: show_actions())
        root.pack_start(cancel, False, False, 2)
        root.show_all()

    def on_key(_, event) -> bool:
        if event.keyval == Gdk.KEY_Escape:
            close()
            return True
        return False

    win.connect("key-press-event", on_key)
    win.connect("destroy", lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGTERM, lambda *_: win.close())

    show_actions()
    win.show_all()
    win.present()
    root.grab_focus()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
