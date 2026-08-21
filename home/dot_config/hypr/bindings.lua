-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

hl.unbind("SUPER + SHIFT + M") -- previously: Music
o.bind("SUPER + SHIFT + M", "Omarchy Spotify","omarchy shell -q quickshell.spotify.player togglePlayer")

hl.unbind("SUPER + SLASH") -- previously monitor scaling
o.bind("SUPER + SLASH", "Everything", "omarchy-shell shell toggle b.everything")

-- Swap SUPER+F and SUPER+SHIFT+F: Omarchy's defaults have F = fullscreen,
-- SHIFT+F = file manager (nautilus) - flipped here, so F now opens the
-- file manager and SHIFT+F fullscreens. Dispatcher calls are copied
-- straight from default/hypr/bindings/tiling.lua and applications.lua,
-- just swapped onto the other key.
hl.unbind("SUPER + F") -- previously: Full screen
hl.unbind("SUPER + SHIFT + F") -- previously: File manager

o.bind("SUPER + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + SHIFT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Vim-style directional movement: SUPER + J/K focus the window to the
-- left/right, SUPER + H/L switch to the previous/next workspace. Deliberately
-- not doing up/down on J/K - see the comment block below on why, and on how
-- this interacts with the CAGS home row mods in keyd/default.conf.
--
-- SUPER + K was Omarchy's default "open keybindings menu" - unbind it so K
-- is free. That menu is still reachable via SUPER+SPACE (root menu) or
-- running 'omarchy-menu-keybindings' from a terminal. H, J, L had nothing
-- bound at the plain SUPER level already, so no unbind needed for those.
hl.unbind("SUPER + K") -- previously: Keybindings menu

o.bind("SUPER + J", "Focus left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + K", "Focus right window", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + H", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + L", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))

-- Notes on this approach:
--
-- 1. Dispatcher choice / scrolling vs dwindle: this deliberately reuses the
--    exact same hl.dsp.focus({direction=...}) call Omarchy's own SUPER+LEFT/
--    RIGHT arrow bindings already use (see default.hypr.bindings.tiling) -
--    not the scrolling layout's own layoutmsg-based "focus l/r" (which
--    additionally recenters/wraps columns). Hyprland doesn't yet have one
--    dispatcher that's fully layout-aware across dwindle and the newer
--    scrolling layout (see hyprwm/Hyprland discussion #13731) - but since
--    your looknfeel.lua already runs general.layout = "scrolling" in
--    production today using this exact dispatcher via the arrow keys, J/K
--    are guaranteed to behave identically to whatever LEFT/RIGHT already do
--    for you right now, in both layouts. If you ever toggle to dwindle and
--    miss the scrolling layout's auto-centering on focus change, that's the
--    tradeoff - swap the direction bindings to
--    hl.dsp.layout("focus l/r") for scrolling-only centering, at the cost of
--    it not being the same call dwindle understands.
--    H/L (workspace switching) have no such caveat - workspaces aren't a
--    per-layout concept, so "e-1"/"e+1" behave identically everywhere.
--
-- 2. Up/down intentionally left off J/K: dwindle and scrolling don't agree
--    on what "vertical" even means (dwindle's tree can split either way,
--    scrolling is a single row of columns), so a vim-style K-is-up mapping
--    would be inconsistent between the two anyway. SUPER + UP/DOWN (arrows)
--    still exist unchanged for that.
--
-- 3. Interaction with CAGS home row mods (keyd/default.conf): H is untouched
--    by keyd, no interaction. J/K/L, though, are all lettermod() keys there
--    (meta/shift/alt respectively) - each only resolves to the modifier
--    layer if the key itself is held past ~200ms, or held while another key
--    is pressed afterward. In a SUPER+J/K/L chord you press Super first,
--    which resets keyd's idle timer right before the letter tap, so in
--    practice the letter fires immediately and the shortcut lands reliably.
--    The one real failure mode: if you hold the letter key itself for a
--    beat (not just Super) - e.g. thinking with Super+K held down - keyd
--    will resolve that as the CAGS layer instead of emitting 'k', and the
--    Hyprland bind silently won't fire that press. Same reason NOT to use a
--    hold-to-repeat bind (binde) here even though Hyprland supports it -
--    holding past ~200ms is exactly what keyd is watching for. Quick,
--    deliberate taps (which is how you'd naturally use a WM shortcut
--    anyway) avoid this entirely.
