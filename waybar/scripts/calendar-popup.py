#!/usr/bin/python3
"""Waybar 时钟的主题化下拉日历。"""
import atexit
import datetime as dt
import os
import re
import signal
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
PID_FILE = RUNTIME / "waybar-calendar-popup.pid"
THEME_FILE = Path.home() / ".config/omarchy/current/theme/waybar.css"
DEFAULTS = {
    "foreground": "#F0F8FF",
    "background": "#0A1428",
    "warning": "#FF40A3",
    "caution": "#BDBDBD",
    "date": "#00BFFF",
}


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
    window.calpop {{
      background: {c['background']};
      border: 1px solid alpha({c['date']}, 0.60);
      border-radius: 18px;
      color: {c['foreground']};
    }}
    box.panel {{ padding: 14px 16px 16px; }}
    box.heading {{ padding: 0 4px 10px; }}
    label.icon {{ color: {c['date']}; font-size: 18pt; padding-right: 10px; }}
    label.title {{ color: {c['foreground']}; font-size: 13pt; font-weight: bold; }}
    label.subtitle {{ color: alpha({c['foreground']}, 0.58); font-size: 9pt; }}
    calendar {{
      background: alpha({c['foreground']}, 0.045);
      color: {c['foreground']};
      border: 1px solid alpha({c['caution']}, 0.20);
      border-radius: 12px;
      padding: 9px;
      font-family: "JetBrainsMono Nerd Font";
      font-size: 10pt;
    }}
    calendar.header {{
      background: transparent;
      color: {c['date']};
      font-weight: bold;
      border: none;
    }}
    calendar.button {{ color: {c['date']}; background: transparent; }}
    calendar:selected {{
      background: {c['date']};
      color: {c['background']};
      border-radius: 7px;
    }}
    calendar:indeterminate {{ color: alpha({c['foreground']}, 0.28); }}
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

    win = Gtk.Window(title="Calendar")
    win.set_decorated(False)
    win.set_resizable(False)
    win.set_name("calpop")
    win.get_style_context().add_class("calpop")
    win.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)

    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_namespace(win, "waybar-calendar")
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, 54)
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

    heading = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
    heading.get_style_context().add_class("heading")
    icon = Gtk.Label(label="󰃭")
    icon.get_style_context().add_class("icon")
    heading.pack_start(icon, False, False, 0)

    titles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    title = Gtk.Label(label="日历")
    title.set_xalign(0)
    title.get_style_context().add_class("title")
    now = dt.datetime.now()
    subtitle = Gtk.Label(label=now.strftime("%Y 年 %m 月 · 第 %W 周"))
    subtitle.set_xalign(0)
    subtitle.get_style_context().add_class("subtitle")
    titles.pack_start(title, False, False, 0)
    titles.pack_start(subtitle, False, False, 0)
    heading.pack_start(titles, True, True, 0)
    panel.pack_start(heading, False, False, 0)

    calendar = Gtk.Calendar()
    calendar.set_size_request(310, 230)
    panel.pack_start(calendar, True, True, 0)

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

    win.show_all()
    win.present()
    calendar.grab_focus()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
