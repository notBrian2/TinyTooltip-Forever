# Changelog

## 1.0.1 (2026-09-19)

- Forever surnames: the full name (first name + surname) is shown once, in class color. Before, the surname
  also appeared as a title and in the realm slot.
- The own realm name is no longer appended to every player (Forever unit names don't carry a realm).
- Title detection uses plain matching and still shows titles when the PvP name has only the first name.

## 1.0.0 (2026-09-19)

First release for WoW Forever (interface 16001), based on Road-block/TinyTooltip 9.0.11.

- Single TOC for Forever; removed the Vanilla/TBC/Wrath TOCs.
- New `Compat.lua`: wrappers for removed APIs, secret-value helpers, Settings panel registration.
- Unit, item, spell and aura tooltip hooks moved to `TooltipDataProcessor`.
- Secret-value guards throughout. Restricted units fall back to the default tooltip; health text is passed
  through secret-safe APIs.
- Options: Settings API, modern `ColorPickerFrame`, `ThinBorderTemplate` replaced with a backdrop frame.
- Fixed `SetFont` errors from the `"NONE"` / `"NORMAL"` font flags, which this client rejects.
- LibGearScore: fixed load errors from the missing `LE_ITEM_QUALITY_*` and `MAX_PLAYER_LEVEL_TABLE`; uses vanilla brackets.
- Mount source on aura tooltips and link IDs now come from tooltip data (aura spell IDs).
