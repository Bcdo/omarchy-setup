-- Personal input overrides. Uncommented settings replace Omarchy's defaults.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
  input = {
    -- Norwegian and US layouts. Switch with Left Alt + Right Alt by adding
    -- ",grp:alts_toggle" to kb_options.
    kb_layout = "no,us",
    kb_options = "compose:caps",

    -- Keyboard repeat.
    repeat_rate = 40,
    repeat_delay = 600,

    -- Start with numlock on by default.
    numlock_by_default = true,

    touchpad = {
      scroll_factor = 0.4,
    },
  },
})
