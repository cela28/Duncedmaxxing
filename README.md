# Duncedmaxxing

Lightweight Survival Hunter helper addon for WoW Midnight 12.0.5.

## Tip of the Spear

The tracker predicts Tip of the Spear stacks from the player's own successful spellcasts:

- Kill Command `259489`: +2 stacks, capped at 3.
- Boomstick `1261193`, Takedown `1250646`, Wildfire Bomb `259495`, Raptor Strike `186270`, Raptor Swipe `1262293`: -1 stack.
- Kill Command refreshes the local 10-second Tip of the Spear expiry timer.

It does not poll in combat. It updates immediately from spellcasts, starts a local expiry timer, and uses delayed aura reads as a low-cost sanity check after a short quiet window.

The display is a 247x10 solid-color bar split into three Tip segments with 1px black borders and dividers.

## Settings

Use `/dmax` (alias `/duncedmaxxing`) to open the movable settings window. All configuration is done there.

The settings window can adjust:

- display mode: segmented bar or plain stack number
- enabled and hide-when-empty visibility
- position, scale, bar width, height, border size, and number size
- fill color, border color, text color, and empty-segment opacity
- lock/unlock, preview, reset position, and reset style

The tracker itself is the v1-style lightweight bar/tracker logic, with the settings UI kept separate from the combat tracking path.

## Commands

`/dmax` (alias `/duncedmaxxing`) opens the movable settings window. All configuration is done there — no subcommands.
