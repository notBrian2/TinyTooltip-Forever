# Changelog

## 1.0.5 (2026-10-03)

- Fixed the creature type showing twice on NPC tooltips, e.g. "7 Beast" and then "Beast" (reported by
  Zaro1996). Forever puts the creature type, and the elite/rare classification, on lines of their own.
  These are now hidden like the player class line in 1.0.4.
- Choosing **Static** as a tooltip position now opens the anchor box straight away if it has never been
  placed. Until the box is dragged, a static tooltip stays in the default bottom-right spot, which looked
  like the setting wasn't working.
- Fixed the "PvP" line staying on PvP-flagged players' tooltips. Forever's own name for it is "Player vs.
  Player", so TinyTooltip never matched the line.
- `/tt debug` now works on NPCs as well as players.

## 1.0.4 (2026-10-02)

- Fixed the class showing twice on player tooltips (reported by ixlone and IAmDetonate). Forever puts the
  class, and sometimes "PvP", on lines of their own, which TinyTooltip didn't hide. These default lines are
  now hidden wherever they appear.
- Fixed the "Target:" line flickering and the tooltip height jumping over unit frames that refresh the
  tooltip on their own timer, such as EllesmereUI (reported by skauert). The line is now added whenever
  the tooltip is rebuilt.
- Fixed a Lua error when opening the static anchor window for one tooltip type after another that uses a
  different corner (reported by user_r29lu4y42fhwsysg; fix by msromike). The window also no longer leaves
  the previous corner highlighted.
- New anchor choices **default top left / bottom left / top right / bottom right**: the tooltip stays in
  Blizzard's tooltip area but is pinned by the chosen corner, so it can hang down from an area moved to the
  top of the screen (left corners by msromike).
- The guild realm (e.g. "ClassicBetaPvP" after the guild name) is now off by default, including for
  existing settings. Forever shows a single realm, so it only revealed which hidden server realm a
  guild was on. You can turn it back on under Player → Guild Realm.
- New `/tt debug`: prints the next player tooltip's lines to chat, for bug reports.
- Fixed an invalid escape sequence in a texture path (msromike). No change in game.

## 1.0.3 (2026-09-22)

- Fixed static ("anchor") tooltip positioning (reported by SwiftyBag). This client attaches the default
  tooltip to its Edit Mode container rather than UIParent, so TinyTooltip never moved it and tooltips
  always showed bottom right. Anchored tooltips now go to the configured point and offset.

## 1.0.2 (2026-09-22)

- Fixed an error when changing the player/NPC background alpha or the tooltip scale in the options
  (reported by ammoJD). The sliders saved these as text (e.g. `"0.90"`), which this client's
  `SetBackdropColor` / `SetScale` reject. They now save numbers, and values already saved as text
  (or imported through the Variables page) are converted when used.

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
