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

Use `/dmax` to open the movable settings window. The window is blocked in combat and closes itself if combat starts while it is open.

The settings window can adjust:

- display mode: segmented bar, three icons, or a simple stack number
- enabled, combat-only, and hide-when-empty visibility
- position, scale, bar width, height, border size, icon size, icon spacing, and number size
- fill color, border color, text color, and empty-segment opacity
- lock/unlock, preview, reset position, and reset style

The tracker itself is still the v1-style lightweight bar/tracker logic, with the settings UI kept separate from the combat tracking path.

## Commands

- `/dmax unlock`: move the tracker.
- `/dmax lock`: lock the tracker.
- `/dmax reset`: reset position and scale.
- `/dmax test`: preview 3 stacks for a few seconds.
- `/dmax 0`, `/dmax 1`, `/dmax 2`, `/dmax 3`: preview a specific stack count.
- `/dmax scale 1.2`: adjust scale.
- `/dmax hide` / `/dmax show`: disable or enable the tracker.
- `/dmax mode bar`: use the default segmented bar.
- `/dmax mode icons`: use three Tip of the Spear icons.
- `/dmax mode number`: show the stack count as text.
- `/dmax size 247 10`: set bar width and height.
- `/dmax border 1`: set border and divider size.
- `/dmax color b88c03`: set the bar fill color.
- `/dmax empty 50`: set empty segment opacity percentage.
- `/dmax combat on` / `/dmax combat off`: toggle combat-only visibility.
- `/dmax resetstyle`: restore the default look without moving the tracker.

## Restriction notes

This addon avoids protected action buttons, combat automation, combat-log parsing, and in-combat aura spell-ID lookups. If Blizzard marks the player's own spellcast IDs as secret for these abilities in raid combat, an addon cannot safely infer the stack changes from those IDs; in that case the tracker will fail quiet instead of forcing restricted comparisons.
