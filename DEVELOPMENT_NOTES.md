# Duncedmaxxing Development Notes

These notes preserve the important project context in case the chat context gets compacted or reset.

## Core Goal

Duncedmaxxing is a lightweight World of Warcraft Midnight 12.0.5 addon for Survival Hunter PvE, especially Mythic raid combat. The addon should avoid anything that could hurt combat performance.

## Current Feature

Tip of the Spear tracking:

- Tip of the Spear buff: `260286`
- Kill Command: `259489`, predicts `+2` stacks, capped at `3`
- Consumers, each predicts `-1` stack:
  - Boomstick: `1261193`
  - Takedown: `1250646`
  - Wildfire Bomb: `259495`
  - Raptor Strike: `186270`
  - Raptor Swipe: `1262293`
- Buff duration is `10` seconds. Kill Command refreshes the local expiry timer.

## Tracking Model

The in-game aura update can lag on stack consumption, so the addon uses successful player spellcasts as the immediate source of truth.

Aura reads are only used as delayed verification:

- `UNIT_SPELLCAST_SUCCEEDED` predicts stack changes immediately.
- `UNIT_AURA` and delayed `C_UnitAuras.GetPlayerAuraBySpellID` reads sanity-check the result later.
- Aura up-sync after a consumer is suppressed briefly so delayed aura data does not bounce the display back up.
- The tracker does not poll continuously in combat.

## Visual Defaults

Default Tip display:

- segmented bar mode
- total width `247`
- height `10`
- three segments
- solid 1px black border and dividers
- active segment color `b88c03`
- empty segment background black at 50% opacity
- no icon in bar mode
- fully hidden shell when there are zero stacks unless unlocked/test mode makes it visible

Alternate display modes:

- `icons`: three Tip of the Spear icons
- `number`: simple numeric stack count

Addon icon:

- `Media/duncedgers_pony.png`

## Options UI

Configuration is available through a movable popup opened with `/dmax`.

The settings window must not be openable or adjustable in combat. It closes itself on combat start.

Slash commands still exist as fallback/debug commands. `/dmax help` lists them.

Edit Mode-style integration was considered because SenseiClassResourceBar does it, but Sensei uses a larger helper-library setup. For this addon, the movable popup is the preferred lightweight first step because it avoids covering the tracker inside Blizzard's full Options UI. Edit Mode integration can be revisited later if desired.

## API Documentation Rule

Whenever new WoW API or widget API calls are added, update `API_REFERENCES.md`.

Every API call should have either:

- a Warcraft Wiki reference, or
- a direct local example from the user-provided addons.

If no reference can be found, list it under Unsatisfied References.

## Future Ideas

Planned or likely future additions:

- actionbar reskinning
- Pack Leader beast tracking
- possible Edit Mode integration if it can stay lightweight enough
