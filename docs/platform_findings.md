# Platform findings (Phase 0)

Status: **A, B and C done (2026-10-05, solo, zombie_theater)** except B8/C3 modification checks
(a probe bug hid their results; fixed, small rerun pending) and the optional off-map weapon test.
Results come from `[PROBE]` lines in `%LOCALAPPDATA%\Plutonium\storage\t5\main\games.log`,
cross-checked against Plutonium's loader lines in `main\console.log`. The "Static evidence" column
is what reading the local reference material suggests. It is a prediction, not a result.

## Static evidence gathered before any launch

| # | Fact | Source (local, read-only) |
|---|---|---|
| S1 | Plutonium ships its own script in `storage\t5\raw\scripts\sp\zm_spawn_fix.gsc` using `main()`/`init()`. So `raw\scripts\sp\` is loaded by Plutonium. | user's Plutonium install |
| S2 | Plutonium T5 GSC has `getFunction(path, name)`, `replaceFunc(old, new)`, `isDedicated()`, `logprint`, `println`. | same file |
| S3 | **Corrected by Batch A:** `logprint` output lands in `storage\t5\main\games.log` (the old `games_sp.log` hasn't been written since 2024). Claude reads it directly after a session. | Batch A run |
| S4 | Damage/kill callbacks: `level.overrideActorDamage` (returns damage), `level.overrideActorKilled`, `level.overridePlayerDamage` (returns damage), with 11/8/11 args. They are called from `_callbackglobal`. Per-entity `self.override*` takes priority. | Reimagined `maps/_callbackglobal.gsc`, `_zombiemode.gsc` |
| S5 | Round notifies are `level` `"start_of_round"`, `"end_of_round"`, `"between_round_over"`. Down and revive are `"player_downed"` and `"player_revived"` (on the player). | Reimagined `_zombiemode.gsc`, `_laststand.gsc` |
| S6 | The stock perk limit is the line `player.num_perks >= 4` inside `vending_trigger_think`. `give_perk` increments `num_perks`. | Plutonium `zm_spawn_fix.gsc`, Reimagined `_zombiemode_perks.gsc` |
| S7 | Score uses `maps/_zombiemode_score::add_to_player_score(points)` and a per-player `zombie_vars["zombie_point_scalar"]`. | Reimagined `_zombiemode_score.gsc` |
| S8 | Pacing vars are `level.zombie_vars["zombie_spawn_delay"]`, `["zombie_max_ai"]` (zombies per round, not the concurrent cap), and `level.zombie_health`. The concurrent cap is `level.zombie_ai_limit` in Reimagined, but stock may hard-code 24 (C9 checks). | Reimagined `_zombiemode.gsc` |
| S9 | Double Tap fire rate is engine-side via the dvar `perk_weapRateMultiplier` and the `specialty_rof` perk. | Reimagined `_zombiemode_perks.gsc` |
| S10 | Third-party `scripts\sp\Zombiemode_perks.gsc` and `maps\_zombiemode_perks.gsc` were installed and would have distorted B7/C6/C7. **The user removed both on 2026-10-05.** Only Plutonium's own `zm_spawn_fix.gsc` remains. | installer warning (names only) |

## Results table

| ID | Result | Evidence (pasted `[PROBE]` text) | Function / hook | Notes |
|---|---|---|---|---|
| A1 `scripts\sp\` | PASS (solo) | `A1 \| PASS \| zombie_theater \| solo \| loaded scripts/sp/ init@0 main=yes@0` | `main()` then `init()`, both at level time 0 | Also loads on the **main menu and in campaign** (console.log). Not canonical. |
| A2 `scripts\sp\zom\` | PASS (solo) | `A2 \| PASS \| zombie_theater \| solo \| loaded scripts/sp/zom/ init@0 main=yes@0` | `main()` then `init()` | **Canonical.** Loads only in zombies maps. Plutonium's blank stub here logs "has no 'main' or 'init'" (harmless). |
| A3 `scripts\sp\<map>\` | PASS (solo) | `A3 \| PASS \| zombie_theater \| solo \| loaded scripts/sp/zombie_theater/ init@0 main=yes@0` | `main()` then `init()` | Loads only on that map. Useful for per-map add-ons. |
| A4 `raw\scripts\sp\` | PASS (solo) | `A4 \| PASS \| zombie_theater \| solo \| loaded raw/scripts/sp/ init@0 main=yes@0` | `main()` then `init()` | Merged into the same virtual `scripts/sp/` as A1 (same-name files would shadow each other). Menu and campaign too. |
| A5 mods folder | SKIPPED | `A5 \| SKIPPED \| ... \| prereq: load mods/bo1sz_probe from the Mods menu` | | Not needed now that A2 works. Co-op and dedicated loading are untested for every A row. |
| B1 connect/spawn | PASS (solo) | `B1 \| PASS \| ... \| connect_notify=connected spawned_notify=yes init_before_player=1 main=1` | `level` `"connected"`, player `"spawned_player"` | `init()` runs before any player exists, so per-player setup must listen for `"connected"`. |
| B2 zombie damage | PASS (solo) | `B2 \| PASS \| ... \| wep=m1911_zm dmg=22 hit=torso_lower mod=MOD_PISTOL_BULLET \| x2 drop=44 want=44` | wrap `level.overrideActorDamage`, return the new damage | **Modifiable.** The doubled damage landed exactly (44/44). Stock callback existed and was still called. |
| B3 zombie death | PASS (solo) | `B3 \| PASS \| ... \| wep=m1911_zm hs=1 hit=helmet bonus+10->10` | wrap `level.overrideActorKilled` | **Modifiable** (side effects on kill work). Headshots arrive as `hit=helmet` as well as `head`; count both. |
| B4 points | PASS (solo) | `B4 \| PASS \| ... \| spy +20 \| add 5000 -> +5000 fn=1 scalar=undef` | `getFunction("maps/_zombiemode_score","add_to_player_score")` | **Modifiable.** `player.zombie_vars["zombie_point_scalar"]` was undefined on stock Kino; find the stock double-points mechanism before relying on a scalar. |
| B5 rounds | PASS (solo) | `B5 \| PASS \| ... \| end_of_round@r1 start_of_round@r2 gap=12s mod=n/a` | `level` `"end_of_round"`, `"start_of_round"`, `level.round_number` | Round break is about 12s. That's the window for archetype pop-ups. |
| B6 weapons | PASS spy / mod inconclusive (solo) | `B6 \| PASS \| ... \| weapon_change=zombie_perk_bottle_revive list_change=yes maxammo stock 0->0` | player `"weapon_change"`, `GetWeaponsList` polling | `weapon_change` also fires for the **perk bottle**, so payoff code must ignore `zombie_perk_bottle_*`. The list change seen was the spawn grenade. GiveMaxAmmo was checked on the bottle (0->0), so modification is **not proven**; the probe listed B6 as modifiable by mistake. |
| B7 perks | PASS (solo) | `B7 \| PASS \| ... \| perk_bought=specialty_quickrevive num_perks 0->1 owned=1 limit=num_perks>=4` | player `"perk_bought"` (with perk name), `player.num_perks` | Stock fires `perk_bought` with the perk name. The limit test is C6. |
| B8 player dmg/down | BLOCKED (solo) | `B8 \| BLOCKED \| ... \| do in game: let a zombie hit you once` | wrap `level.overridePlayerDamage` | Hook installed (`player_damage_stock=1`); no hit occurred while the probe waited. Rerun together with Batch C. |
| B9 zombie spawn | PASS (solo) | `B9 \| PASS \| ... \| spawn hp0=150 hp=150 lvl_hp=150 +100 stuck=1` | poll `GetAiSpeciesArray("axis","all")` | **Modifiable:** setting health 0.5s after spawn sticks. |
| C1 HUD | PASS (solo, user-confirmed) | `C1 \| PASS \| ... \| drawn, 7 ranks, hid at round end` + user: "the hud was shown" | `NewClientHudElem`, `SetText`, `SetShader("white")`, `FadeOverTime` | Rank letter, fill bar and pop-up all work and update live; hiding at round end works. Run 1 hit the watchdog bug; run 2 passed. |
| C2 sound | PASS (solo, user-confirmed) | probe timed out (watchdog bug); user heard all 4 | `PlayLocalSound` | Working aliases: `zmb_cha_ching`, `evt_perk_deny`, `zmb_perks_power_on`, `zmb_switch_flip`. |
| C3 dmg scaling | BLOCKED (solo) | `C3 \| BLOCKED \| ... \| shoot a zombie in the body with a pistol` | B2 hook + `WeaponClass` | The pistol filter never matched. Suspect `WeaponClass("m1911_zm")` is not `"pistol"`; the rerun logs actual class names. The B2 x2 proof already shows per-hit scaling works. |
| C4 ammo refund | PASS (solo) | `C4 \| PASS \| ... \| wep=m1911_zm clip 6->7 size=8` (twice) | `GetWeaponAmmoClip`/`SetWeaponAmmoClip` in kill hook | Bullet refund on headshot kill works. |
| C5 multi-kill | PASS (solo) | `C5 \| PASS \| ... \| 2 kills same frame wep=frag_grenade_zm mod=MOD_GRENADE_SPLASH bonus+50->50` | same-`getTime()` kills in kill hook | Grenade kills sometimes report the **held gun** as weapon (`wep=ak74u_zm mod=MOD_GRENADE_SPLASH`). Payoff code must classify by `mod`, not `weapon`. |
| C6 perk limit | PASS (solo) | `C6 \| PASS \| ... \| owned=5 bought_with_offset=3 num_perks=-96 machines=5` | offset `player.num_perks` | **Perk limit removable** by keeping `num_perks` far below 4 (stock check `num_perks >= 4`). Bought a 5th machine perk on Kino. |
| C7 perks per map | PARTIAL (solo) | `C7 \| PARTIAL \| ... \| machines=5 script shop gave specialty_longersprint has=1` | proximity + `UseButtonPressed` shop, `SetPerk` | Kino machines: QR, Speed Cola, Double Tap, Jugg, Mule Kick. A perk with **no machine on the map** (Stamin-Up) was granted engine-side; awaiting user confirmation of the prompt and its effect. |
| C8 Double Tap 2.0 | PASS (solo, user-confirmed) | `C8 \| PARTIAL \| ... \| rate 0.75->0.8333 ft=0.096 dt=1 x2hits=14 steady=1` + user: "the double tap feels pretty much perfect" | dvar `perk_weapRateMultiplier`, x2 in damage hook, `SetPerk("specialty_bulletaccuracy")` | The user's DT 2.0 spec works as designed (`docs/design/double_tap_2.md`). |
| C9 spawn/cap | PASS (solo) | `C9 \| PASS \| ... \| delay 2->0.475 ai_limit=24 peak=8 hp x1.5 150->225` | `zombie_vars["zombie_spawn_delay"]`, `level.zombie_ai_limit`, spawn health | Spawn delay and spawn health are writable, and `level.zombie_ai_limit` exists (24). A concurrent count above 24 was **not observed** (round 2 peak = 8); verify at a later round during Milestone 6. |
| C10 unused weapons | PARTIAL (solo) | `C10 \| PARTIAL \| ... \| pool=36 give knife_ballistic_bowie_zm:1 \| foreign: not attempted` | `GiveWeapon`/`TakeWeapon` | Giving any weapon in the map's pool works. Off-map weapon not yet attempted (opt-in, may crash). |
| C11 boss base | PASS (solo) | `C11 \| PASS \| ... \| hp=4000 phase=2 hazard_ticks=17 ai=dogs` | promoted zombie; `Earthquake`, `RadiusDamage`, `moveplaybackrate`, `set_zombie_run_cycle` via getFunction | Health scaling, a phase change at 50% and a timed area hazard all work. Kino's only special AI is dogs. |
| C12 input | PASS (solo) | `C12 \| PASS \| ... \| dvar toggle seen after 42s; ads+use combo=no` | poll dvar `probe_codex` | Console/bind toggle works. The ADS+USE combo was not observed (maybe not tried). Co-op clients' dvars untested. |
| C13 round break | PASS (solo) | `C13 \| PASS \| ... \| shown end_of_round -> hidden start_of_round, break=12s` | `end_of_round` → `start_of_round` | |

## Feature verdicts (provisional, to be finalised after Batches B and C)

| Area | Verdict | Depends on | Fallback if it fails |
|---|---|---|---|
| Style meter | provisional GO | B2, B3, C1 | Text-only meter via `iPrintLn` if HUD elements misbehave. |
| Archetypes | provisional GO | B3, B5, C1 | Pop-ups via `iPrintLnBold` at round break. |
| Weapon payoffs | provisional GO | B2, B3, C3–C5 | None. A NO-GO here stops the project (stop-early rule). |
| Economy & perks | provisional ADJUST | C6, C7, C8 | Perks with no machine on the map are sold through a script shop as engine perks with no icon or drink animation. |
| Pacing | provisional ADJUST | C9 | If the concurrent cap is hard-coded, change only spawn delay and health growth. |
| Boss | provisional ADJUST | C11 | Use a buffed regular zombie with scripted phases (no new model) when the map has no suitable special AI. |
| Unused weapons | provisional NO-GO | C10 | Use only weapons already in each map's pool. Adding weapons needs fastfiles, which we won't ship. |

## Canonical install path

`storage	5\scripts\sp\zom\` (A2). It loads in Zombies only, so the mod can never run in
campaign or the frontend. The Batch A summary printed `canonical_path=scripts/sp/` because
it picks the first PASS in list order; A2 is chosen deliberately over it. `tools/install.ps1`
now defaults to `-Target A2`.

## Recommendation (provisional)

Proceed as a Plutonium mod. Static evidence (S1–S9) shows that every system the
design leans on is exposed to script as level callbacks, notifies or level vars,
and Plutonium adds `getFunction` and `replaceFunc` for safe runtime lookup.
A standalone Rust game only makes sense if B2/B3 fail, which would be very
surprising given S4.

## Decisions (2026-10-05)

1. **replaceFunc:** allowed, with an original replacement body (see CLAUDE.md rule 1).
2. **Third-party scripts:** removed by the user before probing (S10).
3. **License:** MIT for our original code. It's the simplest for a mod community to
   reuse and puts no burden on players. It explicitly grants nothing for game assets.
4. **Co-op / dedicated server:** not testable right now. Every `coop` and `server`
   result stays `untested` until a second player or a server is available.
   Solo results must not be generalised to co-op.

## Batch B summary (from the probe)

```
[PROBE] passed=8 partial=0 failed=0 blocked=1 skipped=0
[PROBE] hooks_modifiable=B9,B4,B2,B3,B6   (B6 is wrong; see table)
[PROBE] next_batch=C stop_reason=none
```

Stop-early gate: **cleared.** B2 and B3 are both hookable and modifiable.

## Compile notes

- **2026-10-05, first Batch B attempt:** the map failed to load with
  `Server script compile error / unknown function: @ scripts/sp/zom/bo1sz_probe::probe_c7`
  (from `main\console.log`). The name of the unresolved call is blank. Every builtin in
  `probe_c7` appears in stock BO1 scripts, so "used by stock" does **not** prove that
  Plutonium's T5 compiler accepts it from our source. Working theory: the compiler
  stops at the first unresolved call in file order, so everything above `probe_c7`
  compiled.
- **Confirmed 2026-10-05:** the trimmed probe compiled and ran, so every builtin
  left in `probe.gsc` is proven. Only the names in `sweep_candidates.txt` remain unproven.
- Action: C7, C8, C10, C11 and C12 are parked in `src/scripts/probe/parked_c_tests.txt`
  (not loaded) and report SKIPPED. `tools/install.ps1 -Batch Sweep` installs one
  compile-only file per uncertain builtin (`sweep_candidates.txt`) so we can tell which
  names the compiler knows.
- **Rule from now on:** a builtin counts as proven only after our own file using it has
  compiled in game. `tools/gsc_lint.py` checking against stock usage is a first filter,
  not proof.
- **Builtin sweep (2026-10-05, 2 launches):** `Spawn` → **unknown function** (rejected,
  and it was what broke `probe_c7`). Compiled fine: `SetCursorHint`, `SetHintString`,
  `SetPerk`, `Delete`, `SetClientDvar`, `WeaponFireTime`, `GiveWeapon`, `TakeWeapon`,
  `SwitchToWeapon`, `Earthquake`, `RadiusDamage`, `AdsButtonPressed`, `UseButtonPressed`,
  `UnsetPerk`, `PlaySound`, `RandomInt`, `Distance`. `tools/gsc_lint.py` now rejects `Spawn`.
- **Consequence:** we cannot create entities (triggers, script models, origins) from our
  own source. Workarounds: proximity + `UseButtonPressed` instead of use triggers;
  reuse existing map entities; call stock helper functions that spawn internally via
  `getFunction` (to be tested when needed). C7 is rebuilt this way, and every parked
  test is back in `probe.gsc`.
- **Batch C run 1 watchdog bug:** tests that wait for the player to spawn were marked
  "thread died at stage 'start'" because Kino's intro exceeds 20s. Those threads kept
  running (their `[PROBE-DATA]` lines appear later), but the FAIL had already been recorded.
  Fixed: the `start` stage is exempt, and the stuck threshold is now 30s.
- **Rerun 2 bug (bool vs string):** B8 and C3 stored a true/false result but the wait loop
  compared it with `"pending"`; GSC converts `"pending"` to 0, so a *false* result (health
  drop did not match the expected value) looked pending forever. B8's hook did fire
  (9 calls, first `dmg=45 hp=100 mod=MOD_EXPLOSIVE from=ai`); C3's class filter matched
  (`m1911_zm=pistol`). Both now report the measured drop. Class names seen: `m1911_zm=pistol`,
  `knife_zm=melee`, `ak74u_zm=smg`, `mp40_zm=smg`, `frag_grenade_zm=grenade`.
