-- Auto-assign specific apps/webapps to a workspace on launch.
--
-- Uses Omarchy's own o.window(match, rules) helper (see the commented
-- example already at the bottom of hyprland.lua: o.window("qemu", {
-- workspace = "5" })) rather than calling Hyprland's lower-level
-- hl.window_rule directly - it's the pattern this codebase already points
-- at, and it's a thin wrapper: a plain string `match` matches window.class;
-- a table `match` (e.g. { title = "..." }) matches whichever key you give
-- it. `rules` takes the same fields as a windowrulev2 line - workspace =
-- "<id>" (also switches you to it when the rule fires) or "<id> silent"
-- (assigns without switching). Source: DeepWiki's read of
-- default/hypr/apps/*.lua, which use this same helper for Omarchy's own
-- built-in app rules (btop, imv, etc.) - I couldn't get eyes on the actual
-- o.window() implementation itself (not surfaced by any fetch I could make
-- work), so treat the exact behavior as reasonably-but-not-fully verified
-- until you see it working.
--
-- CORRECTED #1, after you asked "do they also launch in workspace specified
-- first time?" - the first version of this file matched on live class/title
-- and reasoned that was the safer bet for first-launch placement. That
-- reasoning was backwards. Two things I found after actually digging in:
--
-- 1. Hyprland's `workspace` rule type is NOT dynamically re-evaluated when
--    class/title change later - a maintainer explains why on the Hyprland
--    forum (moving a window away and having its title update again would
--    otherwise yank it right back). So a workspace rule only ever gets one
--    real shot at matching, at/near window creation - live title=/class=
--    buys nothing over initial_title=/initial_class= for this rule type
--    specifically, since there's no ongoing re-evaluation to benefit from.
-- 2. Chromium-family browsers are documented to open a placeholder/dummy
--    surface first, with class/title not populated yet, and only replace it
--    with the real window a moment later - confirmed via a [SOLVED] Arch
--    Forums thread where exactly this broke a browser's startup-workspace
--    rule on class=, fixed by switching to match:initial_class instead.
--    omarchy-launch-webapp drives the same kind of browser --app window, so
--    the same risk applies here.
--
-- CORRECTED #2, after you reported "all webapps launching in same
-- workspace" and then "even spotify not working" - which ruled out anything
-- webapp-specific and pointed at something universal breaking every single
-- rule below, native app included. Root cause, confirmed via Hyprland
-- GitHub discussion #12566 (maintainer dcunited001: "Yes, that was a fairly
-- recent change"): windowrulev2 regex matching now requires the pattern to
-- match the ENTIRE class/title string, not find a substring anywhere inside
-- it - a change that landed between Hyprland 0.49 and 0.52.1, well before
-- Omarchy 4.0 Quattro's Hyprland 0.56. Every pattern below was a bare,
-- unwrapped substring (e.g. "(?i)amazon", "^[Ss]potify") - those only ever
-- match if the ENTIRE title/class equals that pattern exactly, which real
-- window titles/classes essentially never do (a browser tab title is never
-- literally just "Amazon"). That's why every single rule failed uniformly,
-- webapp and native app alike - this wasn't a matching-strategy problem,
-- the patterns themselves could never fire. Fixed below by wrapping every
-- pattern in .* on both sides (so it still matches anywhere inside the
-- string, while satisfying the new full-match requirement), and by fixing
-- the two patterns that were anchored in a way that no longer works under
-- full-match semantics (Bitwarden/Spotify's ^-only class patterns, and X's
-- alternation - see inline comments below).
--
-- Net effect: initial_title/initial_class (captured once, whatever value
-- exists when Hyprland first sees the window) is the theoretically better
-- bet for "does it land on the right workspace on first launch," not live
-- title/class. Both variants are kept below anyway - if initial_title turns
-- out blank for these specific webapp windows on this specific setup (a
-- real possibility per point 2 above, and something I can't test remotely),
-- the live-title rule is still there as a fallback for whatever a
-- subsequent open/focus/reflow does trigger. This is now my best-evidenced
-- guess, not a confirmed fix - genuinely un-testable without your hyprctl
-- output.
--
-- IMPORTANT - every match pattern below is still an unverified guess as to
-- the actual class/title text, not confirmed against your actual windows
-- (only the full-match REGEX SEMANTICS are now confirmed correct). After
-- chezmoi apply, launch each app FRESH (fully quit it first, not just
-- refocus an already-open one) and check both whether it landed on the
-- right workspace AND what Hyprland actually saw:
--   hyprctl clients -j | jq '.[] | {class, title, workspace: .workspace.id}'
-- If something doesn't land right, that's the actual signal to tell me
-- which field was empty/wrong/different - I can't get closer than an
-- educated guess without that.
--
-- Webapps (Amazon, Robinhood, WhatsApp, YouTube, Reddit, X, Fastmail) are
-- all launched via omarchy-launch-webapp, which runs the browser as
-- `--app="<url>"` with no --class flag (checked the literal script source -
-- basecamp/omarchy bin/omarchy-launch-webapp). That means there's no
-- declared, predictable class for these - deliberately NOT writing a class
-- rule (initial or live) for any of them, since a wrong guess here (e.g.
-- matching on the browser's own generic class, like "chromium") would
-- silently vacuum up EVERY chromium window into that workspace, including
-- your regular browsing. title is the only safe bet for webapps - it's also
-- what Omarchy's own "focus if already open" logic keys on for these same
-- binds (bin/omarchy-launch-or-focus matches class OR title), so if that
-- already works for you (SUPER+SHIFT+A etc. re-focusing instead of
-- relaunching), title-matching here is at least proven to work eventually,
-- if not necessarily on the very first frame.
--
-- Native apps (Bitwarden, Spotify) get their own real class, and - unlike
-- browser --app windows - don't have Chromium's dummy-surface startup
-- pattern, so class matching (initial and live) is safe and likely more
-- reliable for these two than title. Same guesses as their `focus` regex in
-- bindings.lua, not independently more/less verified than those - now
-- wrapped in .* on both sides like everything else, since the class is a
-- guess and full-match semantics mean an unwrapped anchor-only pattern
-- would only match if the class were EXACTLY "Bitwarden"/"Spotify" with no
-- extra characters at all (some toolkits append things like an instance
-- suffix), which is a needlessly fragile bet now that substring matching
-- requires explicit .* wrapping anyway.

-- Workspace 3: Amazon, Robinhood, WhatsApp, Bitwarden
o.window({ initial_title = "(?i).*amazon.*" }, { workspace = "3" })
o.window({ title = "(?i).*amazon.*" }, { workspace = "3" })
o.window({ initial_title = "(?i).*robinhood.*" }, { workspace = "3" })
o.window({ title = "(?i).*robinhood.*" }, { workspace = "3" })
o.window({ initial_title = "(?i).*whatsapp.*" }, { workspace = "3" })
o.window({ title = "(?i).*whatsapp.*" }, { workspace = "3" })
o.window("(?i).*bitwarden.*", { workspace = "3" }) -- live class
o.window({ initial_class = "(?i).*bitwarden.*" }, { workspace = "3" })
o.window({ title = "(?i).*bitwarden.*" }, { workspace = "3" })

-- Workspace 4: YouTube, Reddit, X, Spotify
o.window({ initial_title = "(?i).*youtube.*" }, { workspace = "4" })
o.window({ title = "(?i).*youtube.*" }, { workspace = "4" })
o.window({ initial_title = "(?i).*reddit.*" }, { workspace = "4" })
o.window({ title = "(?i).*reddit.*" }, { workspace = "4" })
-- X is the riskiest one here: its tab title is often just "X" or "Home / X"
-- - a single letter is a bad regex target (case-insensitive "x" shows up in
-- all sorts of unrelated window titles), so this is deliberately anchored
-- (whole title "X", or a "... / X" suffix) rather than a bare \bx\b. Under
-- the full-match requirement, the second alternative needs a leading .* to
-- allow anything before "/ X" while still matching the entire string - the
-- previous "/ X$" alone would only have matched a title that was literally
-- just "/ X" with nothing before it. Watch this one specifically after
-- chezmoi apply - if it's grabbing windows it shouldn't, tighten or drop
-- this rule first.
o.window({ initial_title = "(?i)(^X$|.*/ X$)" }, { workspace = "4" })
o.window({ title = "(?i)(^X$|.*/ X$)" }, { workspace = "4" })
o.window("(?i).*spotify.*", { workspace = "4" }) -- live class
o.window({ initial_class = "(?i).*spotify.*" }, { workspace = "4" })
o.window({ title = "(?i).*spotify.*" }, { workspace = "4" })

-- Workspace 5: Fastmail
o.window({ initial_title = "(?i).*fastmail.*" }, { workspace = "5" })
o.window({ title = "(?i).*fastmail.*" }, { workspace = "5" })
