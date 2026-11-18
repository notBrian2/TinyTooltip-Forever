# TinyTooltip Forever

A port of **TinyTooltip** to **World of Warcraft Forever** (client 1.60, interface 16001).

Download: [CurseForge](https://www.curseforge.com/wow/addons/tinytooltip-forever) ·
[GitHub releases](https://github.com/notBrian2/TinyTooltip-Forever/releases) ·
what's new in [CHANGELOG.md](CHANGELOG.md)

TinyTooltip restyles the game tooltip. It adds class-colored names, class/faction/role icons, guild and realm,
level and race coloring, target and "targeted by" lines, a movable anchor, a health bar and an optional 3D model.
You can rearrange the player tooltip layout by dragging elements in the options.

## Installation

Download the latest release and extract it so that you have
`World of Warcraft\_forever_\Interface\AddOns\TinyTooltip\TinyTooltip.toc`.

The folder must be named `TinyTooltip`. This port replaces the original addon, so don't install both.

## Usage

- `/tt`, `/tip` or `/tinytooltip`: open the options (Settings → AddOns → TinyTooltip)
- `/tt player`, `/tt npc`, `/tt spell`, `/tt statusbar`: open a specific options page
- `/tt reset`: reset all settings (then `/reload`)
- `/tt debug`: print the next player or NPC tooltip's lines to chat (useful for bug reports)

### Settings worth knowing

- **Position**: follow the cursor, a **Static** spot you place with the Anchor button, or Blizzard's default
  tooltip spot (which you can move in Edit Mode), pinned by any corner.
- **Hide in Combat**, **Fixed Spot in Combat**, **Fixed Spot on Unit Frames**: hide the tooltip in combat,
  or move it off the cursor in combat or over unit frames (handy for mouseover healing). The fixed spot is
  your Static spot if you placed one, otherwise Blizzard's tooltip spot.
- The **General**, **Player** and **NPC** pages each have their own copy of these checkboxes. Player and NPC
  set to *inherit* follow General.
- **Fade Out Tooltips**: off by default, so tooltips hide as soon as you mouse off. Turn it on for
  Blizzard's 2-second fade.
- **Hold ALT/CTRL to Show All Lines** and **Hold ALT/CTRL to Spin the 3D Model**: both off by default.
- Item and spell IDs show on their tooltips (always, or only while you hold SHIFT/ALT).

Languages: English, Simplified Chinese, Traditional Chinese and Russian.

## Reporting bugs

Open an issue here or comment on CurseForge. Please say what you did, what you saw and what you expected.
For a unit tooltip problem, also include the output of `/tt debug` and your Position setting.

## What changed for Forever

Forever runs on the modern (12.x) game engine with vanilla content, so many APIs that classic addons use
don't exist. This port:

- replaces the removed `OnTooltipSetUnit/Item/Spell` hooks with `TooltipDataProcessor` post-calls
- moves the options into the modern Settings panel and uses the new color picker
- swaps removed functions for their current equivalents (`GetMouseFoci`, `C_Item`, `C_AddOns`, `C_Spell`, `C_QuestLog`)
- uses vanilla level colors (gray and yellow ranges), since the client ships the retail ones
- fixes load-time errors in the bundled LibGearScore (removed item-quality and level constants)
- handles **secret values**. When the game hides unit data from addons (for example in instances or PvP),
  TinyTooltip leaves the default Blizzard tooltip untouched instead of erroring.

All compatibility code lives in `Compat.lua`.

### Known limitations

- Raid target icons are never shown on tooltips (the client always hides them from addons).
- The "smooth" health bar coloring doesn't work because health values are hidden; "auto" (class/reaction) coloring does.
- Gear score shows `(0)` for players you haven't inspected (same as upstream; you can turn it off in the options).
- The drag-and-drop layout editor (DIY) covers player tooltips only.
- Buffs and debuffs aren't shown on the tooltip.

## Credits

- **M**: original author of [TinyTooltip](https://www.curseforge.com/wow/addons/tinytooltip)
- **Road-block**: classic fork, [Road-block/TinyTooltip](https://github.com/Road-block/TinyTooltip), which this port is based on
- **notBrian2**: WoW Forever port
- Contributors: **msromike** (fixes in 1.0.4), **lich-wang** (Simplified Chinese translation)

## Bundled libraries

LibStub (public domain), CallbackHandler-1.0, LibSharedMedia-3.0 (LGPL 2.1), LibJSON (CC-BY 3.0, Jeffrey Friedl),
LibGearScore (Road-block, modified for Forever), and LibEvent / LibSchedule / LibDropdown (M).

## License

MIT. See [LICENSE](LICENSE).
