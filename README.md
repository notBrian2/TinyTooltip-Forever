# TinyTooltip Forever

A port of **TinyTooltip** to **World of Warcraft Forever** (client 1.60, interface 16001).

TinyTooltip restyles the game tooltip. It adds class-colored names, class/faction/role icons, guild and realm,
level and race coloring, target and "targeted by" lines, a movable anchor, a health bar and an optional 3D model.
You can rearrange the player tooltip layout by dragging elements in the options.

## Credits

- **M**: original author of [TinyTooltip](https://www.curseforge.com/wow/addons/tinytooltip)
- **Road-block**: classic fork, [Road-block/TinyTooltip](https://github.com/Road-block/TinyTooltip), which this port is based on
- **notBrian2**: WoW Forever port

## Installation

Download the latest release and extract it so that you have
`World of Warcraft\_classic_beta_\Interface\AddOns\TinyTooltip\TinyTooltip.toc`
(use your Forever install's folder once the game launches).

The folder must be named `TinyTooltip`. This port replaces the original addon, so don't install both.

## Usage

- `/tt`, `/tip` or `/tinytooltip`: open the options (Settings → AddOns → TinyTooltip)
- `/tt player`, `/tt npc`, `/tt spell`, `/tt statusbar`: open a specific options page
- `/tt reset`: reset all settings (then `/reload`)

## What changed for Forever

Forever runs on the modern (12.x) game engine with vanilla content, so many APIs that classic addons use
don't exist. This port:

- replaces the removed `OnTooltipSetUnit/Item/Spell` hooks with `TooltipDataProcessor` post-calls
- moves the options into the modern Settings panel and uses the new color picker
- swaps removed functions for their current equivalents (`GetMouseFoci`, `C_Item`, `C_AddOns`, `C_Spell`, `C_QuestLog`)
- fixes load-time errors in the bundled LibGearScore (removed item-quality and level constants)
- handles **secret values**. When the game hides unit data from addons (for example in instances or PvP),
  TinyTooltip leaves the default Blizzard tooltip untouched instead of erroring.

All compatibility code lives in `Compat.lua`.

### Known limitations

- Raid target icons are never shown on tooltips (the client always hides them from addons).
- The "smooth" health bar coloring doesn't work because health values are hidden; "auto" (class/reaction) coloring does.
- Gear score shows `(0)` for players you haven't inspected (same as upstream; you can turn it off in the options).

## Bundled libraries

LibStub (public domain), CallbackHandler-1.0, LibSharedMedia-3.0 (LGPL 2.1), LibJSON (CC-BY 3.0, Jeffrey Friedl),
LibGearScore (Road-block, modified for Forever), and LibEvent / LibSchedule / LibDropdown (M).

## License

MIT. See [LICENSE](LICENSE).
