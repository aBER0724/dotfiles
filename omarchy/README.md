# omarchy

Stock [Omarchy](https://omarchy.org/) desktop (Hyprland + `omarchy-shell`, a Quickshell bar) —
only the bar is customized here; everything else stays Omarchy's own.

## Synced

- `shell.json` → `~/.config/omarchy/shell.json` — the bar layout
- `plugins/aber.tray/` → `~/.config/omarchy/plugins/aber.tray/` — a clone of the built-in
  `omarchy.tray` widget with the drawer opened by click instead of hover

## Bar layout

```
1 2 3 4   m - dotfiles                   wifi bt vol batt   Wed 18 Nov 09:33
workspaces  active window (file name)      tray status      clock       spacer
```

- `left` — workspaces, then the current window (the file name in an editor); the launcher moved
  into the tray drawer
- `center` — empty, and it is also the drawer's trigger: clicking the blank bar there opens the
  tray drawer, so there is no chevron button anywhere
- `right` — the tray (no icon of its own, it grows leftward out of the blank middle), then network,
  bluetooth, audio and power, then the clock, then an `omarchy.spacer` that ends the bar
- `tray` (the drawer) — menu, indicators, elsewhen, weather, system update, keyboard layout,
  agents, display, superwhisper

The window title sits on the left because of the camera notch: Omarchy raises a top bar to the notch
height and, since the cutout covers the middle, draws the `center` box beside the right section
instead of centering it (`BarModel.centerBesideRight`). A `center` widget is therefore not centered
at all on this display, so the title lives right after the workspaces and `center` stays empty. The
tray keeps the right section, where its drawer opens leftward over the empty middle of the bar —
which is exactly the empty middle the blank-click trigger covers, so the two fit together.

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

The clone in this repo keeps the upstream code and changes these things:

- both `HoverHandler`s that expanded the drawer on hover are gone
- `expandIcon` toggles the drawer on left click (right click is still the tray manager popup)
- the chevron is gone: the blank middle of the bar opens the drawer (below)
- the drawer opens in three tiers (below)

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

## Three tiers of tray icons

There is no expander button. The empty middle of the bar is the trigger, and how fast you click it
decides how deep the drawer opens:

The drawer reads **始终隐藏 | 隐藏 | 常驻** from the edge it opens away from: the always-hidden
icons sit leftmost, the hidden ones next to them, and the pinned ones against the bar's own edge, so
the three tiers are three blocks and never interleave. The panel lists them in the same order.

| Tier | What | How to reach it |
| --- | --- | --- |
| 常驻 (pinned) | On the bar itself, no click needed | Move the widget out of `tray`: `omarchy bar move <id> --section right --index N`. App tray icons can also be pinned in the right-click manager popup. |
| 隐藏 (hidden) | Shows on a single click of the blank bar | Keep it in the `tray` section with no tier — the default. |
| 始终隐藏 (always hidden) | Shows only on a fast second click | Keep it in `tray` and mark it: `omarchy bar set <id> tier alwaysHidden`. |

A click while the drawer is open closes it. **Five seconds after it opens, the drawer folds itself
shut again** (`autoHideTimer` in `Tray.qml`); a popup opened from the drawer holds it open instead
of yanking it away under the pointer, and the drawer closes once the popup does.

The double-click window is 400 ms (`lastChevronPress` in `Tray.qml`). `Tray.qml` implements the
tiers twice over: app tray icons (SystemTray items) go through `classifyItem` / `hiddenIds` — the
`hidden` array on the tray entry — while tray-section *widgets* are shown or hidden by
`applyWidgetTiers()`, which reads each widget's `tier` from its `shell.json` entry.

To undo the always-hidden marker: `omarchy bar set <id> tier "" --json` (or remove the `tier`
key by hand).

Each tier is one contiguous block of the `tray` section, and the fork keeps it that way: setting a
tier puts the widget at the front of the tray for 始终隐藏, or right after the last always-hidden one
for 隐藏, and `normalizeTrayTiers()` puts the list back in that order after the bar's drag engine has
dropped a widget somewhere else. The bar's own order is what the section lays its widgets out in, so
without that a hidden widget could be dropped between two always-hidden ones and would appear
between them in the double-clicked drawer.

## The indicators widget, forked to stop it flashing

`~/.config/omarchy/plugins/aber.indicators/` is a clone of `omarchy.indicators` that removes one
behaviour. Upstream shows only the indicators that are *active*, and reveals the inactive ones on
hover — from a zone that reaches past the widget on the side they grow toward
(`hiddenBlockZone`, `reach = inactiveLength`):

1. the pointer enters the zone, `hoverRevealHeld` turns on
2. the inactive icons appear, so the widget grows and the zone keeps only *half* its reach
3. the pointer that opened them can fall outside that smaller zone, so they hide again
4. the zone is full length again, and the pointer is inside it — so they come back

That loop is the flicker: approaching the center of the bar made the mute and screen-recording
icons appear and disappear. The clone drops `hoverRevealHeld` from the reveal condition, so on the
bar only active indicators ever show (`alwaysShow` in the widget's own settings still shows all of
them for good). In the tray's drawer the reveal stays, because the drawer already hides the widget
until it opens.

The clone also resolves the indicator components itself: upstream loads them with
`Qt.resolvedUrl("../indicators/<Id>.qml")`, which inside `~/.config/omarchy/plugins/` points at a
directory that does not exist there, so the fork reads them from
`$OMARCHY_PATH/shell/plugins/bar/indicators/` and keeps working when the shell updates those files.

### Setting a tier without dragging

The bar's drag and drop speaks sections only: `tray` and `right` are sections, so dragging a widget
out of the drawer into `right` pins it, and dragging it past the bar removes it. There is no drop
target for a *tier*, and none can be added from here: the drag engine lives in
`/usr/share/omarchy/shell/plugins/bar/Bar.qml`, which an update overwrites.

So the tiers have a control of their own: **right-click the blank middle of the bar**. The panel
lists every widget in the drawer or pinned on the bar, one row each, with three buttons —
常驻 / 隐藏 / 始终隐藏 — and the row's current tier raised. The panel writes through the same
`omarchy-bar move` and `omarchy-bar set <id> tier alwaysHidden` commands you would type, because a
`bar-widget` plugin is not allowed to write the layout itself: `bar.shell.mutateShellConfig` only
answers plugins whose kinds include `"bar"` (`shell.qml: pluginHasBarCapabilities`), so it returns
false here.

This is also the way back for a widget you can no longer grab. `Bar.qml` gates its drag pointer on
`slot.widgetWidth > 0 && slot.widgetHeight > 0`, and Omarchy's widgets collapse to zero width when
they have nothing to say — `omarchy.weather` until its forecast arrives, `omarchy.bluetooth` with
no adapter present. Such a widget is invisible *and* ungrabbable on the bar, while still sitting in
`shell.json`; the panel's 隐藏 / 始终隐藏 buttons put it back in the drawer without needing to grab it.
(For a widget dragged clean off the bar, `omarchy bar put <id>` is the way back.)

### Why the drawer animates even with animations off

This VM renders on the CPU, so Omarchy switches every animation off
(`~/.local/state/omarchy/toggles/hypr/no-animations.lua`, read by
`default/hypr/software-rendering.lua`) and `Style.duration(ms)` returns 0 for the whole shell. The
first version of the drawer bound its progress and slid nowhere: the value came straight from a
binding, and a `Behavior` does not animate a binding (the drawer snapped 319px in one frame).
Two fixes together:

- `revealProgress` is a plain property that `syncReveal()` *assigns*. The `Behavior` only eases
  values it sees written, so it now eases from wherever the drawer is.
- the slide uses a fixed `animationDuration` (300 ms) instead of `Style.duration()`, so it moves on
  a machine whose animations are off. A 40px-high slide costs nothing to draw; the rest of the
  shell stays still.

`drawerExtentSmooth` follows `drawerExtent` the same way (a 150 ms ease), so going from level 1 to
level 2 grows the drawer instead of widening it in one frame.

To get the whole shell animating as well: `omarchy-toggle-animations on` (this also brings back
blur and shadows, the expensive parts on llvmpipe).

### How the blank click is wired

`bar` inside a widget is Omarchy's plugin API object, **not** the bar item, so it has no children to
walk. The trigger therefore finds the bar layout from the other direction: up from the widget
(`root.parent` → `Loader` → `WidgetHost` → `ModuleSlot` → `RightModules`, the outermost ancestor
carrying `region === "right"`) and then sideways to its sibling with `region === "left"`. The
the clickable stretches span `left.x + left.width` to `right.x`, so they follow the layout and the
opening drawer automatically and never cover a widget. A right click there opens the tray manager
popup, which is where the old chevron's right click went.

The empty bar is covered by *two* stretches, not one, with a gap for the center box
(`CenterSections`, the only strip child carrying `besideRight`). A `center`/`centerBegin`/
`centerEnd` widget is laid out in the middle of the bar — exactly where a single stretch would sit
— and one covering `omarchy.agents` there made that icon impossible to drag or click, because the
press went to the invisible catcher instead of its slot. Either stretch may be empty: with nothing
centered, the center box is a point past the right section and only the left stretch exists.

## Caveat: `shell.json` is written by Omarchy

`~/.config/omarchy/shell.json` is a live config: dragging the bar, dropping a widget into another
section, and every `omarchy bar ...` command rewrite it. Most writes follow the symlink into this
repo — but **an atomic write replaces the symlink itself with a real file**. `omarchy bar set` was
caught doing exactly that: after it ran, `~/.config/omarchy/shell.json` was a plain file and edits
stopped reaching the repo. Check with `ls -l ~/.config/omarchy/shell.json` and re-link when needed:

```bash
cp ~/.config/omarchy/shell.json ~/dotfiles/omarchy/shell.json   # keep the latest live config first
rm ~/.config/omarchy/shell.json
ln -s ~/dotfiles/omarchy/shell.json ~/.config/omarchy/shell.json
```
