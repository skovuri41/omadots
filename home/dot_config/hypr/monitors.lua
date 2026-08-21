-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 2

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
-- output = "" matches EVERY connected monitor, forcing scale=2 on all of
-- them - correct for this HiDPI laptop panel, but will misrender any
-- external monitor with a different DPI (e.g. a plain 1080p/1440p display
-- will look oversized/blurry at scale=2). If that happens, uncomment and
-- fill in the per-output override below (find the name with
-- `hyprctl monitors all`) - Hyprland applies monitor rules in order, so add
-- it AFTER this wildcard line.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
