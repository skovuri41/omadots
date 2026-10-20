-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
 hl.config({
   general = {
     -- No gaps between windows or borders.
     gaps_in = 10,
     gaps_out = 10,
     border_size = 2,
     -- Change to niri-like side-scrolling layout.
     layout = "scrolling",
   },
 })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
 hl.config({
   decoration = {
     -- Use round window corners.
     rounding = 8,
     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
     dim_inactive = true,
     dim_strength = 0.5,
   },
 })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })
hl.config({
    layout = {
        single_window_aspect_ratio = { 1, 1 },
        single_window_aspect_ratio_tolerance = 0.0
    },
    scrolling = {
        fullscreen_on_one_column = true,
        focus_fit_method = 0,
        column_width = 1,
    }
})

-- column_width is global, not per-monitor (Hyprland has no native override),
-- so rederive it from the focused monitor's logical width on every monitor
-- change. Tune the two constants below to taste. `hyprctl keyword` doesn't
-- work on this Lua-native config - use hl.config() directly instead, which
-- works fine at runtime (confirmed via `hyprctl repl`), not just load time.
local WIDE_THRESHOLD = 1600 -- logical px; laptop panel is ~1440
local WIDE_COLUMN_WIDTH = 0.65
local NARROW_COLUMN_WIDTH = 1.0

local function apply_column_width()
  local mon = hl.get_active_monitor()
  if not mon then return end

  local logical_width = mon.width / mon.scale
  local width = (logical_width > WIDE_THRESHOLD) and WIDE_COLUMN_WIDTH or NARROW_COLUMN_WIDTH
  hl.config({ scrolling = { column_width = width } })
end

hl.on("monitor.focused", apply_column_width)
hl.on("monitor.added", apply_column_width)
hl.on("monitor.removed", apply_column_width)

