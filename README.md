# ZStats

**Live Zombies stats and a match recap for Black Ops II (Plutonium T6)**

by Xep

[**Download the latest release**](https://github.com/Xeptix/ZStats/releases/latest)

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/F6L1285ROA)

ZStats adds a compact live HUD, a round-MVP callout, and a Game Over recap without
replacing the stock scoreboard. It keeps track of the match while you play and
gives solo players a personal summary or co-op players team awards and their own
summary at the end.

- **See the useful numbers now:** match time, zombies left, points per round
  (PPR), and kills per round (KPR) are on the default HUD.
- **Make the HUD yours:** choose Minimal, Compact, Detailed, or Custom; move and
  scale it, change the background, and show only the rows you want.
- **Keep personal bests:** career records belong to each client and mark new
  bests in orange. Match Only is there when you want a clean slate each game.
- **Read a real match recap:** earned, spent, and ending points are separate;
  the stock scoreboard remains in place.

---

## Requirements

Plutonium T6 (Black Ops II), ordinary round-based Zombies. Grief and Turned
disable ZStats' telemetry and presentation because their scoring does not fit
the co-op stats model.

ZStats is a **mod**, not a loose-script install. Select `zm_zstats` in the Mods
menu. Plutonium loads one mod at a time; use ZBundle when you want ZStats with
the other Z mods. For Black Ops II, ZBundle is included in
[ZPause's Treyarch Bundle download](https://github.com/Xeptix/ZPause/releases/latest);
its installer offers the combined mod.

---

## Install

Download **ZStats T6 v1.0 by Xep.zip** from the release page and extract the
entire archive. Run `installer/windows/install.bat` on Windows or
`installer/linux/install.sh` on Linux. The Windows installer uses the Plutonium
folder under `%localappdata%` by default; pass `-Root <Plutonium folder>` if
yours is elsewhere. The Linux installer asks for the Plutonium folder, or takes
it with `--root <folder>`.

The package installs to:

```text
Plutonium/storage/t6/mods/zm_zstats/scripts/zm/zstats.gsc
Plutonium/storage/t6/mods/zm_zstats/zstats.iwd
Plutonium/storage/t6/images/menu_zm_cac_backing.iwi
```

The image is the shared Z Mods settings background. The installer backs up a
pre-existing replacement and restores it on uninstall when it still owns the
installed copy. If you install by hand, merge the zip's `Plutonium` folder into
your Plutonium folder and preserve any menu image you want to keep yourself.

The installers also accept `-Find` / `--find` to inspect the target without
changing it, `-Uninstall` / `--uninstall` to remove ZStats, and `-Yes` /
`--yes` to skip the confirmation. Start a new Zombies match after installation.

---

## Usage

### Live HUD

Compact is the default: **TIME**, **ZOMBIES**, **PPR**, and **KPR** in a small
top-right card. Minimal shows time and zombies. Detailed adds round time,
match earnings and kills, current-round counters, revives, and separate
**ROUND** and **ROUND KILLS** lines. Custom uses the individual row switches.
The card closes up around enabled rows, including when only the header remains.

PPR means gross points earned divided by rounds you participated in. KPR means
kills divided by those rounds. Joining a game late does not divide your totals
by rounds you missed. **EARNED** is gross match score, not your spendable
balance; it includes the points you start with.

The panel hides while the game's pause menu is open. **TOGGLE ZSTATS HUD** on
that menu hides or restores your panel for the current match only. It does not
change the saved HUD setting, stop tracking, or turn off the Game Over recap.

### Round MVP and Game Over

After a completed round, ZStats posts one MVP callout in the game feed. At Game
Over the stock scoreboard appears first, followed by paginated ZStats cards.
Solo gets a personal summary and records; co-op gets team awards and each
client's own summary. The recap covers kills, headshots, points, spending,
downs, revives, doors, barriers, perks, melee kills, round records, and
completed-round pace. Tied awards say so. Solo-only revive figures show N/A.

A partial final round contributes to the match summary, but never sets a
completed-round PB or a completed-round KPR/PPR record. Values a map cannot
provide exactly display `--` or N/A rather than a made-up zero.

---

## Configuration

Open **ZSTATS SETTINGS** in the Zombies lobby or on the game's pause menu. The
HUD and RECAP categories use the same Z Mods settings screen as the other mods.
The host controls shared HUD and recap rows. Personal PB scope, round-PB
announcements, and **RESET CAREER PERSONAL BESTS** belong to each client.
The reset asks for confirmation and clears PB records without resetting HUD
preferences.

| Setting | Default | What it controls |
|---|---|---|
| ZSTATS HUD | On | Live panel; tracking and recap stay active when it is off. |
| HUD PRESET | Compact | Minimal, Compact, Detailed, or Custom. |
| HUD POSITION | Top right | Any screen corner. |
| HUD SCALE | 100% | Panel and text size. |
| BACKGROUND OPACITY | 22% | Dark panel opacity; 0% leaves text and accent. |
| ZSTATS HEADER | On | Orange title and its spacing. |
| PERSONAL BEST MARKERS | On | Orange PB markers on eligible rows. |
| PERSONAL BEST SCOPE | Career | Saved career records or Match Only comparisons. |
| ROUND PB ANNOUNCEMENT | On | Client-only completed-round PB messages. |
| ROUND MVP | On | Round-end MVP callout. |
| GAME OVER AWARDS | On | ZStats recap after the stock scoreboard. |
| SHOW LOWLIGHTS | Off | Adds the optional Most Downs award. |
| RECAP DURATION | 20 seconds | Total time shared by the recap pages. |

Custom also exposes individual switches for match time, zombies left, PPR,
KPR, round time, earned points, round kills, round points, round headshots,
round revives, and round number. Detailed includes match kills as well as
round kills; the two do not reset together.

Career PBs cover best completed-round kills, headshot kills, melee kills,
points, revives, KPR/PPR, and fastest round, plus highest single-match
earnings, single-match kills, and round reached. A PB belongs to that player,
not the host. It survives a new match until the player resets it.

---

## How it works

ZStats reads the stock Zombies score and player counters rather than replacing
map purchase or scoring code. It observes rounds separately for each player,
freezes completed-round values at the round boundary, and keeps departing
players in the match registry for final co-op awards.

Custom maps are handled by capability: a map using the common round, score,
enemy-count, spending, and intermission paths supplies the matching stats. If
one of those paths is absent, its dependent row or award is omitted or shown
as unavailable. Exact spending depends on the stock `spent_points` event;
balance drops alone are not called purchases.

---

## Notes

- ZStats and other mods that replace the same stock menu file should be used
  through ZBundle, which merges the shared menu and startup owners.
- The client-local pause toggle lasts for the current match. The normal HUD
  setting is the saved host/shared control.
- New PB rows are orange on both Black Ops II and Black Ops III.

---

## Testing

The 1.0 release candidate was played in solo and co-op on stock and
representative custom Zombies maps, including menus, Game Over, and career-PB
persistence. The build also passes ZStats' cross-port source, storage, and
package checks. This does not certify every custom map: one that replaces a
stock startup or ending owner may need its own integration.

---

## Ports

| Game | Repo |
|---|---|
| Black Ops II (T6) | ZStats - you are here |
| Black Ops III (T7) | [ZStatsT7](https://github.com/Xeptix/ZStatsT7) |

Both ports carry the same public version and setting names. The Workshop
edition of T7 uses the same HUD and recap model within that engine's limits.

---

## Other Z Mods

The other mods have their own GitHub documentation and releases:

| Mod | Black Ops II repo |
|---|---|
| ZPause | [ZPause](https://github.com/Xeptix/ZPause) |
| ZShare | [ZShare](https://github.com/Xeptix/ZShare) |
| ZTweaks | [ZTweaks](https://github.com/Xeptix/ZTweaks) |

Use ZBundle to run the Z Mods together in one Plutonium mod slot. On Black Ops II,
get it from [ZPause's Treyarch Bundle release](https://github.com/Xeptix/ZPause/releases/latest)
and choose the combined mod in its installer.

---

## Changelog

### v1.0

- Initial public release for Black Ops II.
- Compact, Minimal, Detailed, and Custom live HUD presets, with a panel that
  sizes to enabled rows and hides during the stock pause menu.
- Participation-aware PPR/KPR, separate match and round kills, and orange PB
  markers for career or match-only records.
- Round MVP callouts and solo/co-op Game Over recaps after the stock scoreboard.
- Per-client career PB storage and reset; personal settings remain editable by
  a client while the host controls shared settings.
- Lobby and pause settings, a client-local pause HUD toggle, installers, and
  ZBundle integration.

---

## Credits

- **Xep** - author
- **Treyarch** - the stock Zombies systems and scripts ZStats observes

## License

MIT - see `LICENSE` in the release archive. ZStats' own code is licensed under
MIT; Treyarch's game scripts and assets are not.
