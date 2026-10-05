# Double Tap 2.0 (design note, Milestone 4)

Requested by the user on 2026-10-05. Not implemented yet; Phase 0 only checks feasibility.

## Spec (user's words, condensed)

1. **Two bullets per round consumed.** Damage output doubles while ammo use stays the same.
2. **Fire rate +20%** (not stock's +33%).
3. **Recoil management** for more accurate aim.

## How each part maps onto what Phase 0 proved

| Part | Implementation | Status |
|---|---|---|
| 2x damage per round | Actor-damage hook (B2, proven): bullet damage (`MOD_PISTOL_BULLET`, `MOD_RIFLE_BULLET`) x2 while the attacker has `specialty_rof`. Headshot, piercing and Pack-a-Punch multipliers apply first, because the hook sees final stock damage. | Feasible now. A literal second projectile would need `MagicBullet` (not yet compile-tested). x2 damage gives the same output with no extra tracer. |
| +20% fire rate | `perk_weapRateMultiplier` = 1 / 1.2 ≈ **0.8333** (fire time multiplier). Stock is **0.75** (≈ +33%). | Dvar is writable (C8). The x2 damage path is being verified in the Batch C rerun. |
| Recoil management | Weapon recoil lives in weapon files (not shippable). The engine has no recoil dvar (checked the dvar dump). Closest script-reachable effects: `specialty_bulletaccuracy` + `perk_weapSpreadMultiplier` (stock 0.65) for hip-fire spread, and `perk_damageKickReduction` for flinch when hit. | **ADJUST:** "recoil" becomes "tighter hip-fire spread and less flinch". True recoil reduction isn't possible script-only. The probe checks whether the steady-aim perk can be granted. |

## Never-nerf check

Fire rate drops from stock +33% to +20%, but damage per round doubles:

| | Stock DT | DT 2.0 |
|---|---|---|
| Fire-rate multiplier | 1.33x | 1.20x |
| Damage per round | 1x | 2x |
| **DPS** | **1.33x** | **2.40x** |
| **Damage per magazine** | **1x** | **2x** |

DT 2.0 is a strict upgrade in sustained DPS and ammo efficiency. The fire-rate part alone
is lower than stock, and the user explicitly requested that trade. Recorded here as an
approved exception to the "no reduction of any individual stat" reading of rule 7.

## Tunables (to go into `data/balance/perks.csv` at Milestone 4)

`dt2_damage_mult=2.0`, `dt2_rate_mult=0.8333`, `dt2_spread_mult=0.65`,
`dt2_applies_to=bullets` (explosives and melee excluded unless the user says otherwise).
