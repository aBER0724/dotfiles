#!/usr/bin/python3
"""Waybar 时钟的轻量下拉日历。

使用 gtk-layer-shell 显示在屏幕顶部中央：不参与 niri 平铺、不占任务栏。
再次点击时钟、按 Esc 或点击窗外都会关闭。
"""
import atexit
import os
import signal
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, Gtk, GtkLayerShell

PID_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "waybar-calendar-popup.pid"

CSS = b"""
window.calpop {
  background-color: alpha(@theme_bg_color, 0.96);
  border: 1px solid alpha(@theme_fg_color, 0.35);
  border-radius: 14px;
}
window.calpop calendar {
  background: transparent;
  color: @theme_fg_color;
  border: none;
  padding: 10px;
}
window.calpop calendar.header {
  background: transparent;
  color: @theme_selected_bg_color;
  font-weight: bold;
}
window.calpop calendar:selected {
  background: @theme_selected_bg_color;
  color: @theme_selected_fg_color;
  border-radius: 6px;
}
"""


def toggle_existing() -> bool:
    """已有实例时关闭它并退出本次启动。"""
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

    win = Gtk.Window(title="Calendar")
    win.set_decorated(False)
    win.set_resizable(False)
    win.set_default_size(300, 250)
    win.set_name("calpop")
    win.get_style_context().add_class("calpop")

    # 真正的 Wayland 下拉面板：顶部居中，不参与 niri 平铺布局。
    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_namespace(win, "waybar-calendar")
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, 54)
    GtkLayerShell.set_exclusive_zone(win, 0)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.ON_DEMAND)

    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    calendar = Gtk.Calendar()
    calendar.set_hexpand(True)
    calendar.set_vexpand(True)
    win.add(calendar)

    def close(*_) -> bool:
        win.close()
        return False

    def on_key(_, event) -> bool:
        if event.keyval == Gdk.KEY_Escape:
            win.close()
            return True
        return False

    win.connect("key-press-event", on_key)
    win.connect("focus-out-event", close)
    win.connect("destroy", lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGTERM, lambda *_: win.close())

    win.show_all()
    win.present()
    calendar.grab_focus()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
