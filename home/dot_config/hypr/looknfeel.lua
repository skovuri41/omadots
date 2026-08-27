-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
 hl.config({
   general = {
     -- No gaps between windows or borders.
     gaps_in = 40,
     gaps_out = 40,
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
        column_width = 0.66,
    }
})

