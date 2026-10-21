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
        focus_fit_method = 0,
        column_width = 1,
    }
})

-- column_width/fullscreen_on_one_column are global, not per-monitor
-- (Hyprland has no native override), so rederive both from the focused
-- monitor's logical width on every monitor change. Tune the constants
-- below to taste. `hyprctl keyword` doesn't work on this Lua-native config
-- - use hl.config() directly instead, which works fine at runtime
-- (confirmed via `hyprctl repl`), not just load time.
local WIDE_THRESHOLD = 1600 -- logical px; laptop panel is ~1440
local WIDE_COLUMN_WIDTH = 0.65
local NARROW_COLUMN_WIDTH = 1.0
-- Laptop: a lone window fullscreens, same as upstream default. External:
-- a lone window stays at column_width's fraction instead of jumping full
-- width when a second window opens.
local WIDE_FULLSCREEN_ON_ONE_COLUMN = false
local NARROW_FULLSCREEN_ON_ONE_COLUMN = true

-- Takes an explicit monitor rather than always calling hl.get_active_monitor()
-- internally: confirmed live that hl.get_active_monitor() lags by one switch
-- inside a monitor.focused callback (still returns the PREVIOUSLY focused
-- monitor at the moment the event fires), which applied each monitor's
-- settings one switch late - looking "reversed" when alternating between
-- two monitors. monitor.focused's own event argument is the actually-correct
-- newly-focused monitor, so callers pass that through instead.
local function apply_scrolling_layout(mon)
  mon = mon or hl.get_active_monitor()
  if not mon then return end

  local logical_width = mon.width / mon.scale
  local wide = logical_width > WIDE_THRESHOLD

  -- NOT "wide and X or Y" - that idiom breaks when X is itself `false`
  -- (as WIDE_FULLSCREEN_ON_ONE_COLUMN is here): Lua falls through to Y
  -- regardless of `wide`. Confirmed hit this live - fullscreen_on_one_column
  -- came back `true` while docked to the wide monitor.
  local column_width, fullscreen_on_one_column
  if wide then
    column_width, fullscreen_on_one_column = WIDE_COLUMN_WIDTH, WIDE_FULLSCREEN_ON_ONE_COLUMN
  else
    column_width, fullscreen_on_one_column = NARROW_COLUMN_WIDTH, NARROW_FULLSCREEN_ON_ONE_COLUMN
  end

  hl.config({
    scrolling = {
      column_width = column_width,
      fullscreen_on_one_column = fullscreen_on_one_column,
    },
  })
end

-- monitor.focused passes the newly-focused monitor directly - see the
-- comment on apply_scrolling_layout above for why that matters here.
hl.on("monitor.focused", apply_scrolling_layout)
-- monitor.added/removed pass the monitor that was added/removed, not
-- necessarily the one now focused - ignore that arg, fall back to
-- hl.get_active_monitor() inside apply_scrolling_layout.
hl.on("monitor.added", function() apply_scrolling_layout() end)
hl.on("monitor.removed", function() apply_scrolling_layout() end)

-- Also re-run on every full reload, via config.reloaded rather than a
-- plain inline call. hyprland.lua requires hypr.looknfeel (this file)
-- BEFORE default.hypr.toggles, which is what disables the laptop panel
-- while docked - so an inline call here would run before that toggle is
-- re-applied, observing a transiently stale "active monitor" on each
-- reload. Confirmed hit this live: fullscreen_on_one_column/column_width
-- reverted to the laptop's values while docked to the external monitor.
-- config.reloaded fires once the whole chain has settled.
hl.on("config.reloaded", apply_scrolling_layout)
apply_scrolling_layout() -- still run inline too, for the very first load

