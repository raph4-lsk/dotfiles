local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Font
config.font = wezterm.font('JetBrainsMono NF')
config.font_size = 14.0

-- ─── APPEARANCE ─────────────────────────────────────────────
config.color_scheme = 'Tokyo Night'
config.window_background_opacity = 0.92
config.macos_window_background_blur = 30
config.window_decorations = 'TITLE|RESIZE'
-- bottom must not be 0: the window height is rarely an exact multiple of the cell
-- height, and with nothing to absorb the remainder the last row gets clipped
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false        -- the macOS fancy bar looks like a title bar

config.native_macos_fullscreen_mode = true
-- ─── KEYBOARD ───────────────────────────────────────────────
-- Option must reach the shell as Meta, not as a compose key: that is what
-- fzf's Alt+C and zsh's Alt+B / Alt+F / Alt+. expect. Safe on this machine,
-- the macOS layout is ABC and the brackets come from the QMK LOWER layer.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- ─── PANES: split + navigation ──────────────────────────────
local NVIM_CMD_R = '\x1b[114;9u'

config.keys = {
  -- Split the current pane
  { key = 'd', mods = 'CMD',       action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } }, -- left | right
  { key = 'd', mods = 'CMD|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } }, -- top / bottom
  -- Close the current pane
  { key = 'w', mods = 'CMD',       action = act.CloseCurrentPane { confirm = true } },
  -- Move focus between panes. CMD alone, not CMD|ALT: two fingers instead of
  -- three, and it keeps one rule for the whole machine, CMD outside nvim and
  -- CTRL inside it (nvim splits stay on CTRL+hjkl).
  -- Cost: CMD+h no longer hides WezTerm (CMD+m minimizes) and CMD+k no longer
  -- clears the scrollback (the `cl` alias does).
  { key = 'h', mods = 'CMD', action = act.ActivatePaneDirection 'Left' },
  { key = 'l', mods = 'CMD', action = act.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'CMD', action = act.ActivatePaneDirection 'Up' },
  { key = 'j', mods = 'CMD', action = act.ActivatePaneDirection 'Down' },

  { key = 'Backspace',  mods = 'CMD',       action = act.SendString '\x1b\x7f' },
  { key = 'Backspace',  mods = 'CMD|SHIFT', action = act.SendString '\x1bd' },
  { key = 'LeftArrow',  mods = 'CMD|SHIFT', action = act.SendString '\x1b[H' },
  { key = 'RightArrow', mods = 'CMD|SHIFT', action = act.SendString '\x1b[F' },
  { key = 'LeftArrow',  mods = 'CMD',       action = act.SendString '\x1bb' },
  { key = 'RightArrow', mods = 'CMD',       action = act.SendString '\x1bf' },
  { key = 'UpArrow',    mods = 'CMD',       action = act.SendString '\x1b{' },
  { key = 'DownArrow',  mods = 'CMD',       action = act.SendString '\x1b}' },
  { key = 'u',          mods = 'CMD',       action = act.SendString '\x1f' },
  { key = 'u',          mods = 'CMD|SHIFT', action = act.SendString '\x1bU' },
  { key = 'f',          mods = 'CTRL|CMD',  action = act.ToggleFullScreen },

  { key = 'r', mods = 'CMD', action = wezterm.action_callback(function(window, pane)
    local in_nvim = (pane:get_foreground_process_name() or ''):find('nvim')
    window:perform_action(in_nvim and act.SendString(NVIM_CMD_R) or act.ReloadConfiguration, pane)
  end) },
}

config.colors = {
  split = '#a9b1d6'
}
config.inactive_pane_hsb = { saturation = 0.8, brightness = 0.6 }

-- Fullscreen at launch: no config option does this, the gui-startup hook is required
local mux = wezterm.mux
wezterm.on('gui-startup', function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})
  window:gui_window():toggle_fullscreen()
end)

-- New window (CMD + N) need to open wezterm in Fullscreen too
wezterm.on('window-focus-changed', function(window)
  local key = 'fullscreened_' .. window:window_id()
  if not window:is_focused() or wezterm.GLOBAL[key] then return end
  wezterm.GLOBAL[key] = true
  if not window:get_dimensions().is_full_screen then
    window:toggle_fullscreen()
  end
end)

return config
