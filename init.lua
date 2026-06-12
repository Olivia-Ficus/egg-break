-- egg-break Hammerspoon loader.
-- This file is loaded from the user's global ~/.hammerspoon/init.lua with:
-- dofile(os.getenv("HOME") .. "/.hammerspoon/egg-break/init.lua")

local projectDir = os.getenv("HOME") .. "/.hammerspoon/egg-break"
package.path = projectDir .. "/?.lua;" .. projectDir .. "/?/init.lua;" .. package.path

-- Hiding the Dock icon helps hs.canvas overlays remain visible over fullscreen
-- Spaces on modern macOS. Hammerspoon keeps running in the menu bar.
pcall(function()
  hs.dockicon.hide()
end)

local breakOverlay = require("modules.breathing_break_overlay")
breakOverlay.start()

local mods = { "cmd", "alt", "ctrl" }

hs.hotkey.bind(mods, "B", function()
  breakOverlay.toggle()
end)

hs.hotkey.bind(mods, "R", function()
  breakOverlay.reset()
end)

hs.hotkey.bind(mods, "P", function()
  breakOverlay.togglePause()
end)

hs.hotkey.bind(mods, "D", function()
  breakOverlay.forceDemand()
end)

hs.hotkey.bind(mods, "S", function()
  breakOverlay.forceRecovery()
end)

hs.hotkey.bind(mods, "T", function()
  breakOverlay.toggleTimer()
end)

hs.hotkey.bind(mods, "1", function()
  breakOverlay.forceAuditParkedIdle()
end)

hs.hotkey.bind(mods, "2", function()
  breakOverlay.forceAuditCountdownActive()
end)

hs.hotkey.bind(mods, "3", function()
  breakOverlay.forceAuditDemandProgress(0.25)
end)

hs.hotkey.bind(mods, "4", function()
  breakOverlay.forceAuditDemandProgress(0.50)
end)

hs.hotkey.bind(mods, "5", function()
  breakOverlay.forceAuditDemandProgress(1.00)
end)

hs.hotkey.bind(mods, "6", function()
  breakOverlay.forceAuditRecoveryHalfway()
end)
