# omarchy

Stock [Omarchy](https://omarchy.org/) desktop (Hyprland + `omarchy-shell`, a Quickshell bar) —
only the bar is customized here; everything else stays Omarchy's own.

## Synced

- `shell.json` → `~/.config/omarchy/shell.json` — the bar layout
- `plugins/aber.tray/` → `~/.config/omarchy/plugins/aber.tray/` — a clone of the built-in
  `omarchy.tray` widget with the drawer opened by click instead of hover

## Bar layout

```
1 2 3 4          omarchy [window title]              ⌄ 周四 01:10
workspaces    active window (file name in an editor)   tray + clock
```

- `left` — workspaces only; the launcher moved into the tray drawer
- `center` — `omarchy.active-window`
- `right` — the tray chevron, then the clock at the far right
- `tray` (the drawer behind the chevron) — menu, indicators, elsewhen, weather, system update,
  keyboard layout, agents, bluetooth, network, audio, display, power, superwhisper

## Customizing the tray widget

Omarchy's rules: never edit `/usr/share/omarchy` (it is overwritten on update). Clone instead:

```bash
omarchy plugin clone omarchy.tray   # writes ~/.config/omarchy/plugins/<user>.tray/
```

The clone in this repo keeps the upstream code and changes two things:

- both `HoverHandler`s that expanded the drawer on hover are gone
- `expandIcon` toggles the drawer on left click (right click is still the tray manager popup)

```diff
-        HoverHandler {
-          onHoveredChanged: root.expanded = hovered
-        }
-
         BarIconButton {
           id: expandIcon
@@
           onPressed: function(button) {
             if (button === Qt.RightButton) root.managePopupOpen = !root.managePopupOpen
+            else if (button === Qt.LeftButton) root.expanded = !root.expanded
           }
         }
```

**Editing a plugin's QML is not hot-reloaded into a bar widget that is already on screen.** The
shell notices the file change and rebuilds the plugin registry, but the live widget instance keeps
running the code it was created with, so a change looks like a no-op. Restart the shell to load it:

```bash
omarchy restart shell
```

`shell.json` itself *does* hot-reload on save; only QML needs the restart. Refreshing or resetting
the bar goes through Omarchy: `omarchy bar ...`, `omarchy bar move <id> --section <section>`,
`omarchy refresh shell` (backs up first).

## Caveat: `shell.json` is written by Omarchy

`~/.config/omarchy/shell.json` is a live config: dragging the bar, dropping a widget into another
section, and every `omarchy bar ...` command rewrite it. Writes follow the symlink (verified with
`omarchy bar set`), so they land in this repo directly — that means `git status` will show bar
tweaks made in the shell, which is the point, but review them before committing rather than
expecting only hand-edited changes.
