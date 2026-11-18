# omarchy

Stock [Omarchy](https://omarchy.org/) desktop (Hyprland + `omarchy-shell`, a Quickshell bar) —
only the bar is customized here; everything else stays Omarchy's own.

## Synced

- `shell.json` → `~/.config/omarchy/shell.json` — the bar layout
- `plugins/aber.tray/` → `~/.config/omarchy/plugins/aber.tray/` — a clone of the built-in
  `omarchy.tray` widget with the drawer opened by click instead of hover

## Bar layout

```
1 2 3 4   m - dotfiles                            ‹  Wed 18 Nov 09:33
workspaces  active window (file name)     tray     clock       spacer
```

- `left` — workspaces, then the current window (the file name in an editor); the launcher moved
  into the tray drawer
- `center` — empty
- `right` — the tray chevron, then the clock, then an `omarchy.spacer` that ends the bar
- `tray` (the drawer behind the chevron) — menu, indicators, elsewhen, weather, system update,
  keyboard layout, agents, bluetooth, network, audio, display, power, superwhisper

The window title sits on the left because of the camera notch: Omarchy raises a top bar to the notch
height and, since the cutout covers the middle, draws the `center` box beside the right section
instead of centering it (`BarModel.centerBesideRight`). A `center` widget is therefore not centered
at all on this display, so the title lives right after the workspaces and `center` stays empty. The
tray keeps the right section, where its drawer opens leftward over the empty middle of the bar.

### The trailing spacer: macOS privacy dot

This Omarchy install runs in a VM on a Mac (try-omarchy), and macOS draws its privacy indicator — the
green/orange camera and microphone dot — in the top-right corner of the *host* screen. It floats over
the guest's bar, right where the clock ends, so the clock would sit under the dot and be unreadable
whenever an app grabs the camera or the mic.

The right section therefore ends with `omarchy.spacer` sized to two characters of the bar font
(`font.body` 12px monospace ≈ 7px per character, so 14px). Measured on the live bar, the clock's
right edge moves from 20px to 34px from the screen edge — the clock clears the dot.

```bash
omarchy plugin enable omarchy.spacer                  # the widget ships disabled
omarchy bar move omarchy.spacer --section right --index 2
omarchy bar set omarchy.spacer size 14 --json         # px; --json keeps it a number
```

`--json` matters: without it the size is stored as the string `"14"`. `Spacer.qml` reads it through
`Number()`, so both work, but the config stays consistent this way. The spacer only pads on a Mac
host; on a bare Omarchy machine it is 14px of extra breathing room at the end of the bar.

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
