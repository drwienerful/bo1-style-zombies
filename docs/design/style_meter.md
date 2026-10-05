# Style meter (Milestone 2, as built)

Source: `src/scripts/mod/bo1sz_style.gsc`. Tunables: `data/balance/style.csv`,
`style_ranks.csv`, `style_events.csv`. All numbers below are current defaults.

## Ranks

| | Name | Gain mult | Decay/s |
|---|---|---|---|
| D | Dawdling | 1.0 | 3 |
| C | Cold-Blooded | 0.9 | 6 |
| B | Butcher | 0.8 | 8 |
| A | Annihilator | 0.7 | 11 |
| S | Slaughterhouse | 0.6 | 14 |
| SS | Spine-Shattering | 0.5 | 18 |
| SSS | Schutzstaffel Slayer | 0.4 | 22 |

Each rank has a 100-point gauge. Overflow carries into the next rank. Decay starts 2s after the
last style event (any hit or kill). An empty gauge drops one rank and keeps 60% of the gauge.

## Scoring

| Event | Points | Archetype |
|---|---|---|
| Hit (other weapons) | 2, head 4; one per frame; cap 8/s | by weapon class |
| Hit (shotgun, explosive) | 3 per zombie hit; cap 20/s | brawler / demolitions |
| Kill | 5 | by weapon class |
| Headshot kill | 12 + 4 per streak step (max 5 steps) | gunslinger |
| Multi-kill (same frame) | 10 per extra kill | marksman / brawler / demolitions |
| Melee kill | 15 | brawler |
| Explosive kill | 6 | demolitions |
| Long range (>1200 units, bullets) | 12 | marksman |
| Clutch (below 35% health) | 12 | none |
| Variety (class not in last 3 kills) | 8 | none |
| Revive (credited to the reviver) | 25 | support |

One kill's events are summed into one award whose tag is the biggest event. Repeating the same
tag multiplies the award by 0.75 each time (floor 0.3); a different tag resets it. Hits skip
this penalty because they are rate-capped instead.

## Penalties

- Taking damage drops one rank (1.5s cooldown). The gauge is kept.
- Going down resets to D with an empty gauge.
- Low rank is the baseline game, never a penalty.

## Affinity

Every award adds its points to a hidden per-run `player.bo1sz_aff[archetype]`. Milestone 5 reads it.

## Not yet scored

Trap kills and dive-and-shoot kills need checking how the game credits them. Rank bonuses
(points, ammo and power-up chances, handling) are planned for Milestone 3.

## Playtest notes

- Kills alone left the player at D early on; per-hit scoring fixed this (user, 2026-10-05).
- Shotgun and grenade per-zombie scoring was requested so weaker area weapons build style
  fast; the user confirmed it feels faster. Automatic fire felt about right.
