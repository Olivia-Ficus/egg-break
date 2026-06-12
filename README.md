# egg-break

When you see the egg, it is already too late.

It parks a small fried egg on your screen. Click it to start a countdown. When the countdown ends, the egg detaches from its parked position, grows into a demand layer, and stays present until you take a real break.

The visual system uses transparent PNG assets exported from Figma:

- `assets/egg_sauce_ring.png`
- `assets/egg_white.png`
- `assets/egg_yolk.png`
- `assets/egg_full.png` as an optional reference

## Requirements

- macOS
- [Hammerspoon](https://www.hammerspoon.org/)
- Accessibility and/or Input Monitoring permission for Hammerspoon

Install Hammerspoon with Homebrew:

```bash
brew install --cask hammerspoon
```

## Install

## Fast lane: yell at Codex / Claude Code

Open Codex, Claude Code, or whichever digital intern you currently trust, and say:

Clone https://github.com/Olivia-Ficus/egg-break.git, run the install script, then verify that ~/.hammerspoon/init.lua loads ~/.hammerspoon/egg-break/init.lua. Do not overwrite my existing Hammerspoon config.

That is the “I have already stared at enough terminals today” route.

## Manual install
Clone the project:

```bash
git clone https://github.com/Olivia-Ficus/egg-break.git
cd egg-break
```

Then run:

```bash
./install.sh
```

The installer copies this project to:

```text
~/.hammerspoon/egg-break
```

Then it appends this loader line to `~/.hammerspoon/init.lua` only if the line is not already present:

```lua
dofile(os.getenv("HOME") .. "/.hammerspoon/egg-break/init.lua")
```

It does not overwrite your existing Hammerspoon config.

After installing:

1. Open Hammerspoon.
2. Grant Accessibility and/or Input Monitoring permissions if macOS asks.
3. Choose Hammerspoon menu bar -> Reload Config.

If everything works, a small egg should appear on your screen.
Congratulations. You now own a tiny accountability breakfast.

## Controls

- `cmd + alt + ctrl + B`: toggle overlay visibility
- `cmd + alt + ctrl + R`: reset to parked idle
- `cmd + alt + ctrl + P`: pause or resume
- `cmd + alt + ctrl + T`: toggle timer text
- `cmd + alt + ctrl + D`: force demand state for testing
- `cmd + alt + ctrl + S`: force recovery shrink for testing
- `cmd + alt + ctrl + 1..6`: force visual audit states

In the small parked state:

- Click the egg to open the timer picker.
- Long-press for about half a second, then drag to move the parked position.

In demand state:

- Click controls are disabled.
- The egg grows and moves slowly.
- Recovery starts only after 10 continuous minutes with no keyboard input, mouse click, scroll, or mouse movement.

The egg only shrinks back after you leave your keyboard, mouse, scroll wheel, and pointer untouched for 10 continuous minutes.

Not “I opened another tab.”
Not “I moved my mouse to check Slack.”
A real break.

Eggie cares about your health more than you do.
Say thanks to Eggie.

## Permissions

Hammerspoon may need Accessibility and/or Input Monitoring permission so `hs.eventtap` can observe that activity happened.

Screen Recording is intentionally not needed.

## Privacy And Security

egg-break is local-only.

- No network calls
- No analytics
- No external API
- No Screen Recording permission
- No screen capture
- No clipboard access
- No typed-content logging
- No simulated keyboard or mouse events
- Only activity timestamps are used

Input observation only updates an internal `lastActivityAt` timestamp. It does not store keys, typed text, mouse coordinates history, app names, screenshots, or clipboard content.

## Configuration

Defaults live in:

```text
~/.hammerspoon/egg-break/modules/breathing_break_config.lua
```

Useful settings:

- `smallEggSize = 118`: parked egg visual size
- `requiredBreakSeconds = 600`: 10 minutes of no activity before recovery
- `growToMaxSeconds = 180`: time to grow to demand size
- `recoveryShrinkSeconds = 32`: shrink-back duration
- `maxDemandCoverage = 0.50`: demand size target
- `eggLayerRegistrationConstraint = true`: keeps sauce, white, and yolk close to the Figma composition
- `eggUseUnifiedLayerFrame = true`: renders all egg layers into the same registered image frame
- `eggLayerBreathEnabled = false`: disables independent layer scaling that can make the egg look jittery
- `eggVisibleScaleCompensation = 1.8`: compensates for transparent padding in the Figma PNG canvas
- `maxDemandEggCanvasShortSide = 1.65`: allows the transparent egg canvas to exceed the screen short side so the visible egg can approach half-screen coverage
- `demandMaxSpeed = 34`: maximum demand-state drift speed, in screen points per second
- `demandSteeringSeconds = 9.0`: how slowly the egg turns toward a new target
- `demandRetargetDistance = 160`: picks the next drift target early so movement does not stop at a point
- `fps = 24`: animation frame rate

## Assets

Runtime assets live in:

```text
~/.hammerspoon/egg-break/assets/
```

The three rendered layer assets should share the same transparent canvas size so they align like `egg_full.png`.

## Uninstall

From the installed folder or original project folder:

```bash
./uninstall.sh
```

This removes:

```text
~/.hammerspoon/egg-break
```

Then remove this loader line from `~/.hammerspoon/init.lua`:

```lua
dofile(os.getenv("HOME") .. "/.hammerspoon/egg-break/init.lua")
```

The uninstall script does not aggressively rewrite your Hammerspoon config.

Reload Hammerspoon after removing the line.

## Troubleshooting

- Overlay does not appear: reload Hammerspoon config and check that the loader line exists in `~/.hammerspoon/init.lua`.
- Overlay does not appear over fullscreen apps: Hammerspoon fullscreen behavior varies by macOS and app; make sure the Hammerspoon Dock icon is hidden by this config and reload.
- Timer picker does not open: click the egg itself, not the surrounding transparent canvas.
- Drag does not start: hold for about half a second, then move more than a few pixels.
- Activity is not detected: check System Settings -> Privacy & Security -> Accessibility and Input Monitoring for Hammerspoon.
- Demand does not recover: mouse movement counts as activity; leave keyboard, mouse, scroll wheel, and pointer untouched for 10 continuous minutes.
- Missing egg asset alert: confirm the PNG files exist in `~/.hammerspoon/egg-break/assets/`.
- Timer looks odd after sleep: countdown is deadline-based, but Hammerspoon timers pause visually during system sleep; use reset if needed.

## Project Structure

```text
egg-break/
  README.md
  LICENSE
  install.sh
  uninstall.sh
  init.lua
  modules/
    breathing_break_overlay.lua
    breathing_break_config.lua
  assets/
    egg_sauce_ring.png
    egg_white.png
    egg_yolk.png
    egg_full.png
```
