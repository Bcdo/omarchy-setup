-- Personal keybinding overrides. Loaded after Omarchy's defaults, so unbind a
-- default before rebinding the same key.
--
-- See current bindings: omarchy menu keybindings --print

-- Proton instead of HEY for calendar and email.
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.proton.me" })
hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://mail.proton.me" })
hl.unbind("SUPER + SHIFT + ALT + E") -- HEY "New email"

-- GitHub instead of WhatsApp.
hl.unbind("SUPER + SHIFT + ALT + G")
o.bind("SUPER + SHIFT + ALT + G", "GitHub", { webapp = "https://github.com", focus = true })

-- Google web apps are removed by remove-webapps.txt, so drop their bindings.
hl.unbind("SUPER + SHIFT + CTRL + G") -- Google Messages
hl.unbind("SUPER + SHIFT + P") -- Google Photos
hl.unbind("SUPER + SHIFT + S") -- Google Maps

-- Activity monitor on Super+Shift+T (Omarchy's default is Super+Ctrl+T).
o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })
