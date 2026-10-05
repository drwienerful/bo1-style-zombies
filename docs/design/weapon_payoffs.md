# Weapon payoffs (Milestone 3, as built)

Source: `src/scripts/mod/bo1sz_payoffs.gsc`, `bo1sz_ammo.gsc`. Tunables: `data/balance/payoffs.csv`,
`style_ranks.csv` (kill_bonus, ammo_chance), `ammo.csv`. Everything adds power or reward; nothing
is reduced. Wonder weapons (`payoffs.excluded_weapons`) get no class payoffs.

| Class | Payoff |
|---|---|
| Pistols | Each consecutive pistol headshot kill adds +50% pistol damage (cap x3.5). The streak resets on any other kill or after 4s. +10 points per step. A headshot kill refunds 1 bullet. |
| Snipers (+ FN FAL via `class_overrides`) | Headshots x3.5. Each extra zombie pierced by one shot takes +50% more damage and pays +20. |
| Shotguns | A shockwave per blast hits zombies just beyond the target for 50% of the round's zombie health. +25 per extra kill per blast; 3 kills refund 2 shells. |
| Launchers | +15 per zombie caught in a blast. 6+ kills refund 1 round. Pistols (upgraded M1911) are excluded. |
| Any | Real points: headshot kill +10, extra multi-kill +10, long range +15, melee +20. |
| Style rank | Per-kill bonus 0/4/8/12/16/24/32 (D..SSS, doubled at the user's request). Ammo-on-kill chance 0/0/3/5/8/12/15% refills 10% of the clip. |
| All weapons | Double ammo: one hidden spare reserve per weapon, refilled when the reserve hits 0. Max Ammo and wall ammo restore it. |

## Playtest history (2026-10-05)

- Pistol streak, refunds and shotgun multi-kill points confirmed in the logs.
- User: FN FAL should play as a sniper; launcher refund on 6+ kills; sniper headshots x3.5 → added.
- Shotgun slowdown worked but breaks trains; a stock knockdown can't animate from script
  (see platform findings); the shockwave was accepted ("it feels good").
- Double ammo confirmed working.
