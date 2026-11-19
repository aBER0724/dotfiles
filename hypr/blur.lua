-- Frosted-glass blur for Omarchy's Hyprland desktops.
--
-- Kitty draws itself at background_opacity 0.85 (dotfiles/kitty/kitty.conf), so
-- the wallpaper shows through the terminal; this is what blurs it behind the
-- window instead of leaving a sharp picture under the text.
--
-- Load it from ~/.config/hypr/hyprland.lua *after* `require("default.hypr.toggles")`:
-- the "Animations off" flag (toggles/hypr/no-animations.lua) turns blur off and is
-- read later than looknfeel.lua, so the same override placed there would lose.
-- Animations and shadows are deliberately left alone; only blur is switched on.
--
-- Hyprland implements ext-background-effect, but a client asking for blur (kitty's
-- `background_blur`) does nothing while decoration:blur:enabled is off, so the
-- compositor side has to be turned on. macOS needs none of this: kitty blurs
-- natively through kitty/platform-macos.conf, and niri >= 26.04 takes the matching
-- window-rule in niri/config.kdl.
--
-- Starts from $OMARCHY_PATH/default/hypr/glass.lua, Omarchy's own glass recipe, but
-- with a wider radius and more passes (8/4 instead of 4/2): this display runs at
-- scale 2, so the stock radius is only ~2 logical pixels and reads as a slightly
-- soft picture rather than frosted glass. Both knobs are frame-time costs --
-- passes scale it linearly -- so tune them together, not one at a time.
hl.config({
  decoration = {
    blur = {
      enabled = true,
      size = 8,
      passes = 4,
      new_optimizations = true,
      xray = false,
      ignore_opacity = false,
      contrast = 1.0,
      brightness = 0.75,
      noise = 0.01,
      vibrancy = 0.35,
      vibrancy_darkness = 0.35,
      popups = true,
      special = true,
    },
  },
})
