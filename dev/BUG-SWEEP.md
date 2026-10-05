# Bug sweep (started 2026-10-05, after 1.0.6)

Releases kept fixing one report at a time against a mock built from guesses. This sweep records real
client behaviour first, audits all the code, then fixes everything in one release (1.1.0).

## Phases

1. **Recorder + audit** (done 2026-10-05). `dev/TinyTooltipRecorder/` is a separate dev-only addon,
   never shipped (`.pkgmeta` and the release zip leave out `dev/`).
2. **Brian's play session** (done 2026-10-05, see Recording 1). `/ttrec` opens a panel with 9 steps (about 20 min). Some steps switch
   TinyTooltip's Position to Default, Cursor Right, Cursor, Static, or Default Bottom Left. Finish, logout, or
   the next login puts his own settings back. `/reload` saves to
   `WTF/Account/<id>/SavedVariables/TinyTooltipRecorder.lua`.
3. **Analyse and fix** (done 2026-10-05: rig 75/75 + 19/19 sweep checks; 1.0.6 fails 9 of the 19). Load that file with lupa. Turn the real raw/final line sets into rig fixtures and add
   fade/hide timing to the mock. Every fix needs a check that fails on 1.0.6.
4. **1.1.0.** One release, then Brian runs the same checklist once more to compare against the first recording.

## Recording 1 (2026-10-05, 1.0.6, client 1.60.1.70205)

Seven minutes, all 9 steps, 1,738 events, 2 Mark Problem presses (Static, Default Bottom Left), both after
the tooltip had hidden normally. Analysed with lupa → JSON → timeline; the scripts are in the 2026-10-05
`0c308ad5-…` session scratchpad (`load.py`, `dump.py`, `fades.py`).

- **Engine fade, measured:** with `ANCHOR_NONE` (Default, corners, Static, and Cursor since 1.0.6) `FadeOut`
  keeps alpha 1 for 1.0 s, fades to 0 over 1.0 s, and hides 2.00 s after the call, every time. The
  callers were `SetWorldCursor` (`GameTooltip.lua:1026`) and `UnitFrame_OnLeave` (`UnitFrame.lua:393`).
  `GetAlpha` does report the fade.
- **Cursor Right (`ANCHOR_CURSOR_RIGHT`):** the engine hides the tooltip at mouse-off (OnHide fires), and
  then `FadeOut` runs. Afterwards `IsShown()` stays true with 0 lines and alpha 1 until the next SetOwner
  (up to 14 s). It's unknown whether anything is visible; nobody marked it.
- **IDs:** with `alwaysShowIdInfo` on, no item or action-button spell got an ID line. Every tooltip has the
  beta's "Press F6 to submit an issue for this Item/Spell/Creature" line. Auras (no F6 line) did get one.
- GearScore "(0)" is gone. `returnInCombat` moved the tooltip to the default spot in combat (A7).
- Recorder limits: `lineData.leftText` was nil for unit and item lines (spell lines worked), so `raw` is
  mostly empty; the `fading` flag stays set in cursor modes because OnHide fires before FadeOut.

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
| R1 | Party members: zone shown twice (other zone), "Offline" twice (offline) — ixlone, 2026-10-04 | **Fixed by guess in 1.1.0:** rows-dedupe (a default line equal to one of TinyTooltip's rows is hidden) plus `OFFLINE` when `statusDC` shows; `GetZone` also works on mouseover and accepts first or display name. Rig: 1.0.6 fails when the roster uses the display name. |
| R2 | Since 1.0.6, world and unit tooltips fade over a few seconds instead of vanishing; action-bar ones vanish (user_m59…, 2026-10-04) | **Confirmed and fixed in 1.1.0:** `FadeOut` post-hook calls `Hide()` unless `general.fadeOut` (General → Fade Out Tooltips, off by default). |
| R3 | Tooltip stays up until you hover something else (Dorrian, video, 2026-10-04, likely 1.0.6); Position looks like **Static** (Brian) | Not reproduced. Every fade ended in a hide, and the one Show during a fade (`Target.lua:39`) didn't extend it. The Cursor Right "shown with 0 lines" state is the best candidate; the 1.1.0 Hide clears it. |
| R4 | GearScore "(0)" after the class should be gone (1.0.5) | **Confirmed gone** (recording). |

## Code audit (1.0.6)

| # | Where | Finding | Severity |
|---|---|---|---|
| A1 | `LinkID.lua:18` `ShowId` | `FindLine(tooltip, name)` is a plain substring search for "Item"/"Spell"/"Quest", so any line containing the word (`Item Level 20`, `Quest Item`, `Spell Power`) counts as the ID line already being there. The ID line is then never added. Match `^Item:` etc. | **Confirmed** by the recording (the F6 line); fixed in 1.1.0: matches `^Item:`. |
| A2 | `Core.lua:630` `filterfunc.samecrossrealm` | `LE_REALM_RELATION_COALESCED` doesn't exist on Forever (now `Enum.RealmRelationship.Coalesced`), so the filter is always true. | Fixed in 1.1.0 (`LE_REALM_RELATION_COALESCED or 2`). |
| A3 | `Core.lua:382` `GetZone` | Party lookup compares `GetRaidRosterInfo` names with the surname display name; probably never matches on Forever. See R1. | Fixed in 1.1.0 with R1. |
| A4 | `Target.lua:31` `UpdateTargetLine` | Runs for any GameTooltip content while a mouseover unit exists; it doesn't check that the tooltip shows that unit. It could add a Target line to a non-unit tooltip. Check `GetUnit()` matches. | Fixed in 1.1.0: only when the tooltip's unit is the mouseover. |
| A5 | `Anchor.lua:30` | The Cursor follower expires after 300 s of continuous hovering. | Fixed in 1.1.0 (`math.huge`). |
| A6 | `Unit.lua:174`, `Target.lua:39/42`, `General.lua:149`, `Unit.lua:71` | Places TinyTooltip calls `Show()`. They are harmless unless one runs during a fade; the recording tells (R3). | Watch |
| A7 | `Config.lua:23` | General Position defaults to Cursor Right with `returnInCombat = true`, so in combat tooltips jump to the default spot. Intended upstream behaviour; mention if users report "position changes in combat". | Note |
| A8 | API check | Every other global the addon touches exists in the `forever` UI source (70205): GetCreatureDifficultyColor, UnitSelectionColor, HealthBar_OnValueChanged, GameTooltip_UnitColor, FACTION_BAR_COLORS, ITEM_QUALITY_COLORS, ICON_LIST, CLASS_ICON_TCOORDS, PET_TYPE_SUFFIX, GetQuestDifficultyColor, SharedTooltip_SetBackdropStyle, UnitTokenFromGUID, GetRaidRosterInfo, etc. `EmbeddedItemTooltip_OnTooltipSetItem` is gone but guarded. | OK |
| A9 | `UnitFrame_UpdateTooltip` (Blizzard) | Unit-frame tooltips get a blank line plus "Right-click…" after the data lines, and `UnitFrame_OnLeave` calls `FadeOut()`. Fixtures need both. | Rig |
