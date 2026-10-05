# Boss (Milestone 7): design proposal

Status: **proposal, awaiting user approval.** Nothing below is built.

## Constraints from Phase 0 and later findings

- No `Spawn` from our scripts, and a 24-alive engine limit: the boss is a **promoted zombie**
  (the first zombie spawned in the boss round), as proven in Phase 0 C11 (4000 HP, phase change at
  50%, sprint, timed area hazard all worked).
- No new models, textures or sounds: the boss is identified by a HUD name and health bar,
  screen shake, existing sound aliases and its behaviour.
- All boss damage passes through our actor-damage hooks, so per-phase damage rules are possible.

## Encounter

| Item | Proposal |
|---|---|
| When | Round 25 (`boss.csv`); if that's a dog round, the next normal round |
| Name | **Der Eiserne** ("the Iron One"); original name, editable in the CSV |
| Health | 40 x that round's zombie health x number of players (≈ 116,000 solo at round 25 with Milestone 6 pacing) |
| Adds | The round's normal zombies keep spawning; the round can't end while the boss lives |
| HUD | Name and a health bar at the top centre, phase text under it |

### Phases

| Phase | HP | Check | Behaviour |
|---|---|---|---|
| 1. **Onslaught** | 100–66% | Damage race | Walks toward you. 45s timer: if you haven't pushed it below 66% by then it **enrages** (sprints, and phase 2's pulses start early). |
| 2. **Hunt** | 66–33% | Mobility | Sprints. Every 6s a **telegraphed pulse**: a screen-shake warning, then 1s later area damage around it (radius 220, capped at 60 damage per pulse). Keep moving and keep distance. |
| 3. **Iron Skin** | 33–0% | Armour / burst | Takes **25% damage** from everything except headshots and explosives. Every 12s its armour cracks for 4s ("ARMOUR DOWN!"): all damage x2. |

### Safeguards

- One hit can take at most 10% of max health. Insta-Kill, nukes and any one-shot effect can't skip the fight.
- Stock's stuck-zombie failsafe could kill or reposition a boss that stops moving. **Unverified:**
  if it triggers, the boss gets a script watchdog that keeps it in play.
- Style and archetypes apply normally. A boss kill is a big style event.

## Victory

When it dies: a large **"VICTORY"** screen with a run summary (round, highest style rank,
archetypes and tiers) and a sound. Then, per `boss.csv`:
- `end_on_victory 1` (default): the game ends through the stock game-over sequence
  (`level notify("end_game")`, **unverified**).
- `end_on_victory 0`: keep playing endlessly.

## Testing aids

`set bo1sz_boss_now 1` promotes the next spawned zombie to the boss immediately;
`set bo1sz_boss_test 1` scales its health down for quick tests.

## Feasibility

| Piece | Status |
|---|---|
| Promotion, health, phases, sprint, area hazard, screen shake | Proven (C11) |
| HUD name, bar and text | Proven (style meter HUD) |
| Per-phase damage rules and one-hit cap | Proven mechanism (actor damage hook, B2) |
| Stock failsafe interaction | Unknown; watchdog planned |
| Game-over via `end_game` | Unverified; fallback is the victory screen, then endless play |
