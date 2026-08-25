-- Kaku Configuration

local wezterm = require 'wezterm'

local function resolve_bundled_config()
  local resource_dir = wezterm.executable_dir:gsub('MacOS/?$', 'Resources')
  local bundled = resource_dir .. '/kaku.lua'
  local f = io.open(bundled, 'r')
  if f then
    f:close()
    return bundled
  end
  return '/Applications/Kaku.app/Contents/Resources/kaku.lua'
end

local config = {}
local bundled = resolve_bundled_config()
if bundled then
  -- The bundled Kaku handler clears right status whenever the window is not
  -- fullscreen. Registering our system monitor after it would make every pulse
  -- alternate between empty and populated text. Suppress only that one bundled
  -- registration while preserving all other Kaku event handlers.
  local original_on = wezterm.on
  wezterm.on = function(event_name, callback)
    if event_name == 'update-right-status' then
      return
    end
    return original_on(event_name, callback)
  end

  local ok, loaded = pcall(dofile, bundled)
  wezterm.on = original_on
  if ok and type(loaded) == 'table' then
    config = loaded
  elseif not ok then
    wezterm.log_error('failed to load bundled Kaku config: ' .. tostring(loaded))
  end
end



local function basename(path)
  return path:match('([^/]+)$')
end

local function equal_padding(all)
  return {
    left = all,
    right = all,
    top = '40px',
    bottom = '30px',
  }
end

local function padding_matches(current, expected)
  return current
    and current.left == expected.left
    and current.right == expected.right
    and current.top == expected.top
    and current.bottom == expected.bottom
end

local fullscreen_uniform_padding = {
  left = '40px',
  right = '0px',
  top = '40px',
  bottom = '30px',
}

local function update_window_config(window, is_full_screen)
  local overrides = window:get_config_overrides() or {}
  if is_full_screen then
    if not padding_matches(overrides.window_padding, fullscreen_uniform_padding) or overrides.hide_tab_bar_if_only_one_tab ~= false then
      overrides.window_padding = fullscreen_uniform_padding
      overrides.hide_tab_bar_if_only_one_tab = false
      window:set_config_overrides(overrides)
    end
    return
  end

  if overrides.window_padding ~= nil or overrides.hide_tab_bar_if_only_one_tab ~= nil then
    overrides.window_padding = nil
    overrides.hide_tab_bar_if_only_one_tab = nil
    window:set_config_overrides(overrides)
  end
end

local function extract_path_from_cwd(cwd)
  if not cwd then
    return ''
  end

  local path = ''
  if type(cwd) == 'table' then
    path = cwd.file_path or cwd.path or tostring(cwd)
  else
    path = tostring(cwd)
  end

  path = path:gsub('^file://[^/]*', ''):gsub('/$', '')
  return path
end

local function tab_path_parts(pane)
  local cwd = pane.current_working_dir
  if not cwd then
    local ok, runtime_cwd = pcall(function()
      return pane:get_current_working_dir()
    end)
    if ok then
      cwd = runtime_cwd
    end
  end

  local path = extract_path_from_cwd(cwd)
  if path == '' then
    return '', ''
  end

  local current = basename(path) or path
  local parent_path = path:match('(.+)/[^/]+$') or ''
  local parent = basename(parent_path) or parent_path
  return parent, current
end

wezterm.on('format-tab-title', function(tab, tabs, hover, max_width, _, _)
  local parent, current = tab_path_parts(tab.active_pane)
  local text = current
  if parent ~= '' and current ~= '' then
    text = parent .. '/' .. current
  end
  if text == '' then
    text = tab.active_pane.title
  end
  if tab.active_pane.is_zoomed then
    text = text .. ' 󰁌'
  end

  local tab_idx = tab.tab_index + 1

  return ' ' .. tostring(tab_idx) .. ' ' .. text .. ' '
end)

-- Kaku 0.19 repaints the tab bar whenever this callback runs. Keep the
-- callback interval aligned with the stats producer and avoid resetting
-- identical content, so CPU/memory/time remain visible without 1 Hz churn.
local last_status_by_window = {}
local last_stats_fetch = 0
local cached_cpu_pct = '?'
local cached_mem_pct = '?'


wezterm.on('update-right-status', function(window)
  local dims = window:get_dimensions()
  update_window_config(window, dims.is_full_screen)

  local now = os.time()
  if now - last_stats_fetch >= 4 then
    local f = io.open('/tmp/kaku-stats', 'r')
    if f then
      local data = f:read('*a')
      f:close()
      local cpu, mem = data:match('(%d+)%s+(%d+)')
      if cpu then cached_cpu_pct = cpu end
      if mem then cached_mem_pct = mem end
    end
    last_stats_fetch = now
  end

  local cpu_icon = wezterm.nerdfonts.md_cpu_64_bit or ''
  local mem_icon = wezterm.nerdfonts.md_memory or ''
  local clock_icon = wezterm.nerdfonts.md_clock_time_four_outline
    or wezterm.nerdfonts.md_clock_outline
    or ''
  local time_text = wezterm.strftime('%H:%M')
  local status = ' ' .. cpu_icon .. ' ' .. cached_cpu_pct .. '% '
      .. '│'
      .. ' ' .. mem_icon .. ' ' .. cached_mem_pct .. '% '
      .. '│'
      .. ' ' .. clock_icon .. ' ' .. time_text .. ' '

  if status ~= last_status_by_window[window] then
    window:set_right_status(status)
    last_status_by_window[window] = status
  end
end)

-- ===== Font =====
config.font = wezterm.font('IoskeleyMonoTerm Nerd Font')

config.font_rules = {
  {
    intensity = 'Normal',
    italic = true,
    font = wezterm.font_with_fallback({
      { family = 'JetBrainsMono Nerd Font', weight = 'Regular', italic = true },
      { family = 'PingFang SC', weight = 'Regular' },
    }),
  },
}

config.bold_brightens_ansi_colors = false
config.font_size = 15
config.cell_width = 1.0
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }
config.use_cap_height_to_scale_fallback_fonts = false

config.freetype_load_target = 'Normal'
-- config.freetype_render_target = 'HorizontalLcd'

config.allow_square_glyphs_to_overflow_width = 'WhenFollowedBySpace'
config.custom_block_glyphs = true

-- config.freetype_load_target = 'Normal'
-- config.freetype_render_target = 'HorizontalLcd'

-- ===== Cursor =====
config.default_cursor_style = 'BlinkingBar'
config.cursor_thickness = '2px'
config.cursor_blink_rate = 0

-- ===== Scrollback =====
config.scrollback_lines = 10000

-- ===== Mouse =====
config.selection_word_boundary = ' \t\n{}[]()"\'-'  -- Smart selection boundaries

-- ===== Window =====
config.window_padding = {
  left = '40px',
  right = '0px',
  top = '70px',
  bottom = '30px',
}

config.initial_cols = 110
config.initial_rows = 22

config.window_close_confirmation = 'NeverPrompt'

-- ===== Tab Bar =====
config.enable_tab_bar = true
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.tab_max_width = 32
config.hide_tab_bar_if_only_one_tab = false
config.show_tab_index_in_tab_bar = true
config.show_new_tab_button_in_tab_bar = false

-- ===== Shell =====
config.default_prog = { '/bin/zsh', '-l' }

-- ===== macOS Specific =====
config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true
config.native_macos_fullscreen_mode = true
config.quit_when_all_windows_are_closed = false

-- ===== Key Bindings =====
config.keys = {
  -- Cmd+R: clear screen + scrollback
  {
    key = 'r',
    mods = 'CMD',
    action = wezterm.action.Multiple({
      wezterm.action.SendKey({ key = 'l', mods = 'CTRL' }),
      wezterm.action.ClearScrollback('ScrollbackAndViewport'),
    }),
  },

  -- Cmd+Q: quit
  {
    key = 'q',
    mods = 'CMD',
    action = wezterm.action.QuitApplication,
  },

  -- Cmd+N: new window
  {
    key = 'n',
    mods = 'CMD',
    action = wezterm.action.SpawnWindow,
  },

  -- Cmd+W: close current pane (smart)
  {
    key = 'w',
    mods = 'CMD',
    action = wezterm.action_callback(function(win, pane)
      local tab = win:active_tab()
      if #tab:panes() > 1 then
        win:perform_action(wezterm.action.CloseCurrentPane { confirm = false }, pane)
      else
        win:perform_action(wezterm.action.CloseCurrentTab { confirm = false }, pane)
      end
    end),
  },

  -- Cmd+Shift+W: close current tab
  {
    key = 'W',
    mods = 'CMD|SHIFT',
    action = wezterm.action.CloseCurrentTab({ confirm = false }),
  },

  -- Cmd+T: new tab
  {
    key = 't',
    mods = 'CMD',
    action = wezterm.action.SpawnTab('CurrentPaneDomain'),
  },

  -- Cmd+Ctrl+F: toggle fullscreen
  {
    key = 'f',
    mods = 'CMD|CTRL',
    action = wezterm.action.ToggleFullScreen,
  },

  -- Cmd+M: minimize window
  {
    key = 'm',
    mods = 'CMD',
    action = wezterm.action.Hide,
  },

  -- Cmd+H: hide application
  {
    key = 'h',
    mods = 'CMD',
    action = wezterm.action.HideApplication,
  },

  -- Cmd+Shift+R: reload configuration
  {
    key = 'R',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ReloadConfiguration,
  },
  {
    key = '.',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ReloadConfiguration,
  },

  -- Cmd+Equal/Minus/0: adjust font size
  {
    key = '=',
    mods = 'CMD',
    action = wezterm.action.IncreaseFontSize,
  },
  {
    key = '-',
    mods = 'CMD',
    action = wezterm.action.DecreaseFontSize,
  },
  {
    key = '0',
    mods = 'CMD',
    action = wezterm.action.ResetFontSize,
  },

  -- Alt+Left / Alt+Right: word jump
  {
    key = 'LeftArrow',
    mods = 'OPT',
    action = wezterm.action.SendKey({ key = 'b', mods = 'ALT' }),
  },
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = wezterm.action.SendKey({ key = 'f', mods = 'ALT' }),
  },

  -- Cmd+Left / Cmd+Right: line start/end
  {
    key = 'LeftArrow',
    mods = 'CMD',
    action = wezterm.action.SendKey({ key = 'a', mods = 'CTRL' }),
  },
  {
    key = 'RightArrow',
    mods = 'CMD',
    action = wezterm.action.SendKey({ key = 'e', mods = 'CTRL' }),
  },

  -- Cmd+Backspace: delete to line start
  {
    key = 'Backspace',
    mods = 'CMD',
    action = wezterm.action.SendKey({ key = 'u', mods = 'CTRL' }),
  },

  -- Alt+Backspace: delete word
  {
    key = 'Backspace',
    mods = 'OPT',
    action = wezterm.action.SendKey({ key = 'w', mods = 'CTRL' }),
  },

  -- Cmd+S: save (forward to neovim as Ctrl+S)
  {
    key = 's',
    mods = 'CMD',
    action = wezterm.action.SendKey({ key = 's', mods = 'CTRL' }),
  },

  -- Cmd+D: vertical split
  {
    key = 'd',
    mods = 'CMD',
    action = wezterm.action.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
  },

  -- Cmd+Shift+D: horizontal split
  {
    key = 'D',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitVertical({ domain = 'CurrentPaneDomain' }),
  },

  -- Cmd+Shift+[ / ]: prev/next tab
  {
    key = '[',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  {
    key = ']',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ActivateTabRelative(1),
  },

  -- Cmd+Option+Arrow / hjkl: navigate between splits
  {
    key = 'LeftArrow',
    mods = 'CMD|OPT',
    action = wezterm.action.ActivatePaneDirection('Left'),
  },
  {
    key = 'RightArrow',
    mods = 'CMD|OPT',
    action = wezterm.action.ActivatePaneDirection('Right'),
  },
  {
    key = 'UpArrow',
    mods = 'CMD|OPT',
    action = wezterm.action.ActivatePaneDirection('Up'),
  },
  {
    key = 'DownArrow',
    mods = 'CMD|OPT',
    action = wezterm.action.ActivatePaneDirection('Down'),
  },
  {
    key = 'h',
    mods = 'CMD|OPT',
    action = wezterm.action.ActivatePaneDirection('Left'),
  },
  {
    key = 'j',
    mods = 'CMD|OPT',
    action = wezterm.action.ActivatePaneDirection('Down'),
  },
  {
    key = 'k',
    mods = 'CMD|OPT',
    action = wezterm.action.ActivatePaneDirection('Up'),
  },
  {
    key = 'l',
    mods = 'CMD|OPT',
    action = wezterm.action.ActivatePaneDirection('Right'),
  },

  -- Cmd+1~9: switch tab
  {
    key = '1',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(0),
  },
  {
    key = '2',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(1),
  },
  {
    key = '3',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(2),
  },
  {
    key = '4',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(3),
  },
  {
    key = '5',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(4),
  },
  {
    key = '6',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(5),
  },
  {
    key = '7',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(6),
  },
  {
    key = '8',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(7),
  },
  {
    key = '9',
    mods = 'CMD',
    action = wezterm.action.ActivateTab(8),
  },

  -- Cmd+Enter / Shift+Enter: newline without execute
  {
    key = 'Enter',
    mods = 'CMD',
    action = wezterm.action.SendString('\n'),
  },
  {
    key = 'Enter',
    mods = 'SHIFT',
    action = wezterm.action.SendString('\n'),
  },

  -- Cmd+Shift+Enter: Toggle Pane Zoom (Maximize active pane)
  {
    key = 'Enter',
    mods = 'CMD|SHIFT',
    action = wezterm.action.TogglePaneZoomState,
  },

  -- Cmd+Ctrl+Arrows / hjkl: Resize panes
  {
    key = 'LeftArrow',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Left', 5 },
  },
  {
    key = 'RightArrow',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Right', 5 },
  },
  {
    key = 'UpArrow',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Up', 5 },
  },
  {
    key = 'DownArrow',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Down', 5 },
  },
  {
    key = 'h',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Left', 5 },
  },
  {
    key = 'j',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Down', 5 },
  },
  {
    key = 'k',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Up', 5 },
  },
  {
    key = 'l',
    mods = 'CMD|CTRL',
    action = wezterm.action.AdjustPaneSize { 'Right', 5 },
  },


}

-- Copy on select (equivalent to Kitty's copy_on_select)
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.CompleteSelectionOrOpenLinkAtMouseCursor('ClipboardAndPrimarySelection'),
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

-- ===== Performance =====
config.front_end = 'OpenGL'
config.webgpu_power_preference = 'HighPerformance'
config.animation_fps = 60
config.max_fps = 60

-- ===== Visuals & Splits =====
-- Inactive panes: No dimming (consistent background)
config.inactive_pane_hsb = {
  saturation = 1.0,
  brightness = 1.0,
}

-- Prevent accidental clicks when focusing panes
config.swallow_mouse_click_on_pane_focus = true
config.swallow_mouse_click_on_window_focus = true

-- ===== First Run Experience & Config Version Check =====
wezterm.on('gui-startup', function(cmd)
  local home = os.getenv("HOME")
  local current_version = 5  -- Update this when config changes

  -- Check for configuration version
  local version_file = home .. "/.config/kaku/.kaku_config_version"
  local is_first_run = false
  local needs_update = false

  -- Read current user version
  local vf = io.open(version_file, "r")
  if vf then
    -- Has version file, check if update needed
    local user_version = tonumber(vf:read("*all")) or 0
    vf:close()
    if user_version < current_version then
      needs_update = true
    end
  else
    -- New user, show first run
    is_first_run = true
  end

  if is_first_run then
    -- First run experience
    os.execute("mkdir -p " .. home .. "/.config/kaku")

    local resource_dir = wezterm.executable_dir:gsub("MacOS/?$", "Resources")
    local first_run_script = resource_dir .. "/first_run.sh"

    -- Fallback for dev environment
    local f_script = io.open(first_run_script, "r")
    if not f_script then
      first_run_script = wezterm.executable_dir .. "/../../assets/shell-integration/first_run.sh"
    else
      f_script:close()
    end

    wezterm.mux.spawn_window {
      args = { 'bash', first_run_script },
      width = 106,
      height = 22,
    }
    return
  end

  if needs_update then
    -- Re-run guided setup on version upgrades
    local resource_dir = wezterm.executable_dir:gsub("MacOS/?$", "Resources")
    local first_run_script = resource_dir .. "/first_run.sh"

    -- Fallback for dev environment
    local f_script = io.open(first_run_script, "r")
    if not f_script then
      first_run_script = wezterm.executable_dir .. "/../../assets/shell-integration/first_run.sh"
    else
      f_script:close()
    end

    wezterm.mux.spawn_window {
      args = { 'bash', first_run_script },
      width = 106,
      height = 22,
    }
    return
  end

  -- Normal startup
  if not cmd then
    wezterm.mux.spawn_window(cmd or {})
  end
end)


-- Root cause of the right-side ~130pt blank (fixed): Kaku lays out the tab
-- bar with render_metrics (ceil(raw_cell x cell_width) = 21px) but paints it
-- with tab_metrics (with_font_metrics, no cell_width multiplier = 20px).
-- The right status right-aligns to title_width in 21px cells, so it stopped
-- 243 x (21-20) = ~243px short of the window edge. Setting cell_width = 1.0
-- makes both paths agree on 20px cells -> status now reaches the window edge.
config.window_background_opacity = 0.6
config.macos_window_background_blur = 70
-- Kaku's documented traffic-light-free mode. Without INTEGRATED_BUTTONS the
-- retro tab bar can use the full window width for the right status.
config.window_decorations = 'RESIZE|MACOS_FORCE_DISABLE_SHADOW'
config.tab_title_show_basename_only = true
config.enable_scroll_bar = false
config.color_scheme = 'Kaku Dark'
config.line_height = 0.8
config.tab_title_show_foreground_process = true
config.remember_last_cwd = false
config.restore_previous_session = false


return config
