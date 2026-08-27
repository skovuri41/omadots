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

-- Close window: SUPER+Q instead of the default SUPER+W. Confirmed against
-- literal source that plain SUPER+Q is free (only SUPER+CTRL+Q exists, bound
-- to the calculator - different combo, no conflict), so no unbind needed
-- for Q itself, only for W.
hl.unbind("SUPER + W") -- previously: Close window

o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Personal webapp/app launcher row: SUPER+SHIFT+<key>. Every one uses
-- Omarchy's own { webapp = ... , focus = true } / { launch = ..., focus =
-- "^regex$" } binding shapes (see default/hypr/bindings/applications.lua's
-- WhatsApp/Google Photos/Maps/Messages entries and the Obsidian launch/focus
-- entry) specifically because those already implement "launch it, or focus
-- the existing window if it's already open" - not reinventing that logic.
--
-- Several of these keys already had a default Omarchy binding - unbound
-- each one first (see the comment above each), same reasoning as the
-- H/J/K/L fix earlier: o.bind()-ing an already-bound key without unbinding
-- throws and silently kills everything after it in the file.
--
-- Two defaults got relocated rather than dropped (SUPER+ALT+<key>, same
-- convention as before) since they're independent apps, not being replaced
-- by anything in this list:
--   Omawrite (was SUPER+SHIFT+W)     -> SUPER+ALT+W
--   Google Photos (was SUPER+SHIFT+P) -> SUPER+ALT+P
-- Signal (was SUPER+SHIFT+G) was briefly relocated to SUPER+ALT+G too, but
-- dropped entirely per your request - no shortcut for Signal at all now,
-- only reachable via the app launcher (SUPER+SPACE). For the record: that
-- wasn't actually a duplicate/conflicting bind with Omarchy's own defaults -
-- SUPER+ALT+G (2 modifiers, Signal) and SUPER+SHIFT+ALT+G (3 modifiers,
-- WhatsApp - untouched, still there) are genuinely different key combos,
-- not the same one registered twice. Removing it anyway since you don't
-- want it.
-- Two were NOT relocated, on the assumption you don't use Basecamp's HEY
-- (you're replacing Email with Fastmail below, and nothing here uses HEY
-- Calendar) - say the word if that assumption's wrong and I'll put them
-- back on an ALT-tier key instead of leaving them unbound:
--   Calendar (was SUPER+SHIFT+C, hey.com) - dropped
--   Email (was SUPER+SHIFT+E, hey.com) - dropped (SUPER+SHIFT+ALT+E "New
--     email" still points at hey.com too - let me know if you want that
--     unbound/relocated as well)

hl.unbind("SUPER + SHIFT + G") -- previously: Signal
hl.unbind("SUPER + SHIFT + W") -- previously: Omawrite
hl.unbind("SUPER + SHIFT + P") -- previously: Google Photos
hl.unbind("SUPER + SHIFT + A") -- previously: ChatGPT (moving to G below)
hl.unbind("SUPER + SHIFT + C") -- previously: Calendar (hey.com)
hl.unbind("SUPER + SHIFT + E") -- previously: Email (hey.com)
hl.unbind("SUPER + SHIFT + X") -- previously: X (same key, adding focus=true)
hl.unbind("SUPER + SHIFT + Y") -- previously: YouTube (same key, adding focus=true)
-- SUPER+SHIFT+R and SUPER+SHIFT+H had nothing bound - no unbind needed.

o.bind("SUPER + ALT + W", "Omawrite", { launch = "omawrite" })
o.bind("SUPER + ALT + P", "Google Photos", { webapp = "https://photos.google.com/", focus = true })

o.bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/", focus = true })
o.bind("SUPER + SHIFT + W", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/", focus = true })
o.bind("SUPER + SHIFT + A", "Amazon", { webapp = "https://www.amazon.com/", focus = true })
o.bind("SUPER + SHIFT + H", "Robinhood", { webapp = "https://robinhood.com/", focus = true })
o.bind("SUPER + SHIFT + G", "ChatGPT", { webapp = "https://chatgpt.com", focus = true })
o.bind("SUPER + SHIFT + E", "Fastmail", { webapp = "https://app.fastmail.com/", focus = true })
o.bind("SUPER + SHIFT + R", "Reddit", { webapp = "https://www.reddit.com/", focus = true })

-- These two are native apps, not webapps - `launch` is the command to run,
-- `focus` is a regex matched against the window's *class* to detect an
-- already-open instance - two different things, so confirming the
-- executable name doesn't by itself confirm the focus regex. `launch`
-- values below are your confirmed executable names; `focus` (window class)
-- is still my best guess in both cases, not verified against your actual
-- machine - check after first launch with:
--   hyprctl clients -j | jq '.[] | {class, title}'
-- and adjust the `focus` regex below if it doesn't land.
--
-- Claude desktop: launch confirmed by you. Class guessed as "claude" from
-- the claude-desktop-bin AUR package's PKGBUILD (StartupWMClass=claude) -
-- correct if that's the AUR package behind your claude-desktop executable.
o.bind("SUPER + SHIFT + C", "Claude desktop", { launch = "claude-desktop", focus = "^claude$" })

-- Bitwarden desktop: launch confirmed by you as bitwarden-desktop (updated
-- from my earlier wrong guess of "bitwarden"). Class still guessed as
-- "Bitwarden" (capitalized product name, common Electron convention) - not
-- verified, and the executable name being bitwarden-desktop doesn't confirm
-- it either way.
o.bind("SUPER + SHIFT + P", "Bitwarden", { launch = "bitwarden-desktop", focus = "^Bitwarden$" })

-- Spotify (native desktop client, AUR - see dev-stack-software.txt). This
-- replaces Omarchy's own default SUPER+SHIFT+M ({ omarchy = "spotify" }),
-- which you'd already overridden above with a Quickshell mini-player toggle
-- instead - that toggle is a panel, not a real window, so it can't be
-- workspace-assigned (see windowrules.lua). This is a second, independent
-- way to get at Spotify: a full app window you can actually put on a
-- workspace. Key is SUPER+SHIFT+U - picked arbitrarily since every letter
-- with an obvious "S for Spotify"/"M for Music" mnemonic was already taken
-- (S = Google Maps, M = your Quickshell toggle, both left as-is since you
-- didn't ask to change either) - say the word if you'd rather free up S or
-- M for this instead.
-- `focus` (class) is an unverified guess, same caveat as Claude
-- desktop/Bitwarden above - check with hyprctl clients -j after first launch.
o.bind("SUPER + SHIFT + U", "Spotify", { launch = "spotify", focus = "^[Ss]potify$" })

-- Emacs GUI frame via the daemon: -c new frame, -n don't block the shell,
-- -q skip the "waiting for emacs..." message, -a '' auto-starts the daemon
-- with 'emacs --daemon' if it isn't already running. Complements the
-- terminal-side emacsclient usage (ec/emax/ediff aliases, git core.editor)
-- already in this repo - same daemon, this just adds a GUI-frame shortcut.
-- Confirmed free at the plain SUPER level (checked every default binding
-- file - only SUPER+CTRL+E "Emojis" exists, different combo).
o.bind("SUPER + E", "Emacs", "emacsclient -cnqua ''")

-- Vim-style directional movement: SUPER + J/K focus the window to the
-- left/right, SUPER + H/L switch to the previous/next workspace. Deliberately
-- not doing up/down on J/K - see the comment block below on why, and on how
-- this interacts with the CAGS home row mods in keyd/default.conf.
--
-- CORRECTION: an earlier version of this only unbound SUPER+K before adding
-- these, on the mistaken belief that H/J/L were unbound by default. They
-- were not - J and L each already had a default binding, and o.bind()-ing
-- an already-bound key without unbinding it first throws (per this file's
-- own guidance up top: "unbind it first, then bind the key again"), which
-- aborted the rest of this block's execution - so none of H/J/K/L took
-- effect, not just the ones that actually conflicted. All four are unbound
-- below before rebinding, and the two defaults that were living on J/L are
-- relocated to SUPER+ALT+<key> rather than just dropped, matching Omarchy's
-- own ALT-tier convention (e.g. SUPER+ALT+F = full width vs SUPER+F =
-- fullscreen):
--   SUPER+K was "Keybindings menu" - not relocated, still reachable via
--     SUPER+SPACE (root menu) or 'omarchy-menu-keybindings' from a terminal.
--   SUPER+J was "Toggle window split" (dwindle-only) - moved to SUPER+ALT+J.
--   SUPER+L was "Toggle workspace layout" - the actual scrolling/dwindle
--     switch we've been discussing - moved to SUPER+ALT+L, since you're
--     actively using both layouts and this is the only way to flip between
--     them.
--   SUPER+H had nothing bound - not calling hl.unbind() on it at all, since
--     that's exactly the kind of "assumed safe" shortcut that caused this
--     bug in the first place; better to only unbind keys confirmed bound.
hl.unbind("SUPER + K") -- previously: Keybindings menu
hl.unbind("SUPER + J") -- previously: Toggle window split
hl.unbind("SUPER + L") -- previously: Toggle workspace layout

o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

o.bind("SUPER + J", "Focus left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + K", "Focus right window", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + H", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + L", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))

-- Workspace back-and-forth toggle, on SUPER + P as requested. This is
-- different from H/L above: e-1/e+1 step sequentially through workspaces in
-- order, while Hyprland's "previous" workspace keyword is a true
-- back-and-forth toggle - jump to whichever workspace was last active, press
-- again to jump right back, regardless of workspace number/order.
--
-- Turns out Omarchy already ships exactly this dispatcher by default -
-- hl.dsp.focus({ workspace = "previous" }) - just bound to the easy-to-miss
-- SUPER+CTRL+TAB chord as "Former workspace" (default/hypr/bindings/
-- tiling.lua). That tracks with "I don't think it's enabled" - it was there,
-- just not on a key you'd stumble onto. Left that default binding in place
-- (harmless to have two paths to the same toggle) and added this second,
-- easier one on SUPER + P.
--
-- SUPER + P wasn't free: Omarchy's default has it as "Pseudo window"
-- (hl.dsp.window.pseudo(), dwindle-layout-only pseudo-tiling, same
-- tiling.lua) - unbound below per your instruction. Still reachable via the
-- root menu / 'omarchy-menu-keybindings' if you ever want it back on
-- another key - say the word.
hl.unbind("SUPER + P") -- previously: Pseudo window

o.bind("SUPER + P", "Former workspace (back and forth)", hl.dsp.focus({ workspace = "previous" }))

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

-- Cycle windows within a Hyprland window group (tabbed/stacked windows).
-- Confirmed SUPER+F11/F12 are unbound in every default binding file.
-- Note: there's no existing bind in this setup that actually GROUPS windows
-- together in the first place (Hyprland's "togglegroup" dispatcher) - these
-- two only cycle within a group once one exists. Say the word if you want a
-- togglegroup bind added too.
-- hl.dsp.group.* isn't something I found in Omarchy's own literal source
-- the way everything else in this file is - sourced from a community
-- Hyprland Lua API reference instead, so treat this one as slightly less
-- certain: verify it actually cycles group members after chezmoi apply.
o.bind("SUPER + F11", "Previous window in group", hl.dsp.group.prev())
o.bind("SUPER + F12", "Next window in group", hl.dsp.group.next())
