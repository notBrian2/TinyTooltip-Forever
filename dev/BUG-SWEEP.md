# Bug sweep (started 2026-10-05, after 1.0.6)

Releases kept fixing one report at a time against a mock built from guesses. This sweep records real
client behaviour first, audits all the code, then fixes everything in one release (1.1.0).

## Phases

1. **Recorder + audit** (done 2026-10-05). `dev/TinyTooltipRecorder/` is a separate dev-only addon,
   never shipped (`.pkgmeta` and the release zip leave out `dev/`).
2. **Brian's play session.** `/ttrec` opens a panel with 9 steps (about 20 min). Some steps switch
   TinyTooltip's Position to Default, Cursor Right, Cursor, Static, or Default Bottom Left. Finish, logout, or
   the next login puts his own settings back. `/reload` saves to
   `WTF/Account/<id>/SavedVariables/TinyTooltipRecorder.lua`.
3. **Analyse and fix.** Load that file with lupa. Turn the real raw/final line sets into rig fixtures and add
   fade/hide timing to the mock. Every fix needs a check that fails on 1.0.6.
4. **1.1.0.** One release, then Brian runs the same checklist once more to compare against the first recording.

## What the recorder logs (GameTooltip only)

- `build`: data type, owner, anchor type, mouse focus, the raw client lines with their `TooltipDataLineType`,
  TinyTooltip's final lines (hidden ones flagged), point, alpha, unit context (player/party/connected/
  classification/dead/PvP), and `tinyUnitRows`. Identical consecutive builds collapse into `repeats`.
- `late`: lines that changed 0.5 s after a build.
- `owner` (SetOwner + caller), `defanchor` (after TinyTooltip's anchor hook), `worldcursor` (anchor type),
  `fadeout`, `hide` (caller), `clearinfo`, `onshow`/`onhide`, `show` / `show-during-fade` (caller),
  and `state` (shown, alpha, mouseover, owner, anchor, line count) on every change.
- `step`, `mark` (the Mark Problem button: a full snapshot), `note` (`/ttrec note …`), `combat`.

## Known reports

| # | Report | Status / hypothesis |
|---|---|---|
| R1 | Party members: zone shown twice (other zone), "Offline" twice (offline) — ixlone, 2026-10-04 | Can't reproduce (no party). Likely our `zone` row plus Forever's own zone line below it. `SetDefaultUnitLines` doesn't list the zone or `OFFLINE`. Fix by guess: hide a default-area line that repeats a line above it, and add the zone/`OFFLINE` texts to the defaults when TinyTooltip shows them. Note: `GetZone` matches roster names against the surname display name, so our zone row may not even appear. Dedupe covers both cases. |
| R2 | Since 1.0.6, world and unit tooltips fade over a few seconds instead of vanishing; action-bar ones vanish (user_m59…, 2026-10-04) | **Decision (Brian): instant hide is the default.** Blizzard's `SetWorldCursor` and `UnitFrame_OnLeave` call `GameTooltip:FadeOut()`. Hook it to `Hide()`, with an option to keep the fade. The recording confirms which paths call FadeOut. |
| R3 | Tooltip stays up until you hover something else (Dorrian, video, 2026-10-04, likely 1.0.6); Position looks like **Static** (Brian) | Unknown. With Static the owner stays Blizzard's, so `SetWorldCursor` should FadeOut. The recording should show whether FadeOut runs and whether something calls `Show()` during the fade (`show-during-fade`). The R2 fix may cure it if FadeOut is reached. |
| R4 | GearScore "(0)" after the class should be gone (1.0.5) | Not yet seen in game; the recording's final lines will show it. |

## Code audit (1.0.6)

| # | Where | Finding | Severity |
|---|---|---|---|
| A1 | `LinkID.lua:18` `ShowId` | `FindLine(tooltip, name)` is a plain substring search for "Item"/"Spell"/"Quest", so any line containing the word (`Item Level 20`, `Quest Item`, `Spell Power`) counts as the ID line already being there. The ID line is then never added. Match `^Item:` etc. | Medium (IDs missing on any item with such a line; the "Items And IDs" step shows how common) |
| A2 | `Core.lua:630` `filterfunc.samecrossrealm` | `LE_REALM_RELATION_COALESCED` doesn't exist on Forever (now `Enum.RealmRelationship.Coalesced`), so the filter is always true. | Low (filter only) |
| A3 | `Core.lua:382` `GetZone` | Party lookup compares `GetRaidRosterInfo` names with the surname display name; probably never matches on Forever. See R1. | Low/unknown |
| A4 | `Target.lua:31` `UpdateTargetLine` | Runs for any GameTooltip content while a mouseover unit exists; it doesn't check that the tooltip shows that unit. It could add a Target line to a non-unit tooltip. Check `GetUnit()` matches. | Low |
| A5 | `Anchor.lua:30` | The Cursor follower expires after 300 s of continuous hovering. | Trivial |
| A6 | `Unit.lua:174`, `Target.lua:39/42`, `General.lua:149`, `Unit.lua:71` | Places TinyTooltip calls `Show()`. They are harmless unless one runs during a fade; the recording tells (R3). | Watch |
| A7 | `Config.lua:23` | General Position defaults to Cursor Right with `returnInCombat = true`, so in combat tooltips jump to the default spot. Intended upstream behaviour; mention if users report "position changes in combat". | Note |
| A8 | API check | Every other global the addon touches exists in the `forever` UI source (70205): GetCreatureDifficultyColor, UnitSelectionColor, HealthBar_OnValueChanged, GameTooltip_UnitColor, FACTION_BAR_COLORS, ITEM_QUALITY_COLORS, ICON_LIST, CLASS_ICON_TCOORDS, PET_TYPE_SUFFIX, GetQuestDifficultyColor, SharedTooltip_SetBackdropStyle, UnitTokenFromGUID, GetRaidRosterInfo, etc. `EmbeddedItemTooltip_OnTooltipSetItem` is gone but guarded. | OK |
| A9 | `UnitFrame_UpdateTooltip` (Blizzard) | Unit-frame tooltips get a blank line plus "Right-click…" after the data lines, and `UnitFrame_OnLeave` calls `FadeOut()`. Fixtures need both. | Rig |
