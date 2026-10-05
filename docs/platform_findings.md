# Platform findings (Phase 0)

Status: **Batch A done (2026-10-05, solo, zombie_theater). Batches B and C not run.**
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
| B1 connect/spawn | untested | | `"connecting"`/`"connected"`, `"spawned_player"` | |
| B2 zombie damage | untested | | wrap `level.overrideActorDamage` | mod = x2 one hit, health drop verified |
| B3 zombie death | untested | | wrap `level.overrideActorKilled` | mod = +10 bonus on headshot kill |
| B4 points | untested | | poll `player.score`, `add_to_player_score` via getFunction | grants 5000 to help B7 |
| B5 rounds | untested | | `start_of_round` / `end_of_round` | |
| B6 weapons | untested | | `"weapon_change"`, `GetWeaponsList` poll | give/take has no notify; polled |
| B7 perks | untested | | `"perk_bought"` notify?, `num_perks` | |
| B8 player dmg/down | untested | | wrap `level.overridePlayerDamage`, `player_downed/revived` | mod = halve one hit |
| B9 zombie spawn | untested | | poll `GetAiSpeciesArray("axis","all")` | mod = +100 hp sticks? |
| C1 HUD | untested | | `NewClientHudElem`, `SetText`, `SetShader("white")` | needs visual confirm |
| C2 sound | untested | | `PlayLocalSound` | aliases: zmb_cha_ching, evt_perk_deny, zmb_perks_power_on, zmb_switch_flip |
| C3 dmg scaling | untested | | B2 hook + `WeaponClass()=="pistol"` | |
| C4 ammo refund | untested | | `SetWeaponAmmoClip` in kill hook | |
| C5 multi-kill | untested | | same-`getTime()` kills in kill hook | |
| C6 perk limit | untested | | offset `num_perks` | full test needs 5+ machines (temple/coast/moon) |
| C7 perks per map | untested | | `zombie_vending` triggers, `trigger_radius_use` shop + `SetPerk` | engine-only perk; HUD icon/bottle not tested |
| C8 Double Tap 2.0 | untested | | dvar `perk_weapRateMultiplier` | damage half = B2 hook (trivial if B2 passes) |
| C9 spawn/cap | untested | | `zombie_spawn_delay`, `zombie_ai_limit`, spawn health | |
| C10 unused weapons | untested | | `GiveWeapon` | expected: only weapons in the map's fastfile; foreign is opt-in (crash risk) |
| C11 boss base | untested | | promote a spawned zombie; `Earthquake`, `RadiusDamage`, `moveplaybackrate`, `set_zombie_run_cycle` | |
| C12 input | untested | | dvar poll `probe_codex`, `AdsButtonPressed+UseButtonPressed` | co-op clients' dvars don't reach the server |
| C13 round break | untested | | `end_of_round` → `start_of_round` | |

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

## Compile notes

- **2026-10-05, first Batch B attempt:** the map failed to load with
  `Server script compile error / unknown function: @ scripts/sp/zom/bo1sz_probe::probe_c7`
  (from `main\console.log`). The name of the unresolved call is blank. Every builtin in
  `probe_c7` appears in stock BO1 scripts, so "used by stock" does **not** prove that
  Plutonium's T5 compiler accepts it from our source. Working theory: the compiler
  stops at the first unresolved call in file order, so everything above `probe_c7`
  compiled.
- Action: C7, C8, C10, C11 and C12 are parked in `src/scripts/probe/parked_c_tests.txt`
  (not loaded) and report SKIPPED. `tools/install.ps1 -Batch Sweep` installs one
  compile-only file per uncertain builtin (`sweep_candidates.txt`) so we can tell which
  names the compiler knows.
- **Rule from now on:** a builtin counts as proven only after our own file using it has
  compiled in game. `tools/gsc_lint.py` checking against stock usage is a first filter,
  not proof.
