# Perks (Milestone 4, as built)

Source: `src/scripts/mod/bo1sz_perks.gsc` (+ `bo1sz_ammo.gsc` for Mule Kick II).
Tunables: `data/balance/perks.csv`, `perk_tiers.csv`.

## No perk limit

The first 4 perks cost stock prices. Each further perk adds a surcharge of 1000 x its extra
index (5th +1000, 6th +2000, ...). The stock machine checks `num_perks >= 4`; the module sets
`num_perks` every 0.2s: it mirrors the real count below 4, and above it allows a purchase only
if the player can afford machine price + surcharge. The surcharge is deducted after
`perk_bought`. A prompt shows "Extra perk: <price> + <surcharge> surcharge", only at machines
selling a perk the player doesn't own.

## Double Tap 2.0

x2 bullet damage, `perk_weapRateMultiplier` 0.8333 (+20%), steady-aim perk while held.
See `double_tap_2.md`.

## Tier II upgrades (3000 each)

Hold USE ~0.75s at the machine of an owned perk. The prompt and a post-purchase pop-up show
the name and a one-line description. Tiers are lost with the perk.

| Tier | Effect |
|---|---|
| Juggernog II | +50 max health |
| Speed Cola II | `perk_weapReloadMultiplier` 0.35 (stock 0.5) |
| Double Tap II | `perk_weapRateMultiplier` 0.769 (+30% total) |
| Quick Revive II: Scavenger | 8% per kill to refill 30% of every carried gun's magazine |
| Mule Kick II | +1 spare ammo reserve per weapon |
| Deadshot II | Headshots x1.25 |

Fire-rate and reload dvars are game-wide: the best tier held by any player applies (co-op untested).

## Findings from playtests (2026-10-05)

- In solo, stock moves the Quick Revive trigger to z ≈ -9894 after purchase. Proximity uses
  each machine's position recorded at load.
- Script-driven Quick Revive regen (setting `player.health`) showed no effect; replaced by
  Scavenger at the user's request. (Jugg II's `maxhealth`/`health` writes do work.)
- Stock plays its "already have this perk" deny sound when USE is first pressed at an owned
  machine; harmless.

## Deferred (user choice)

Missing-perk shop, buyable ammo, weighted ammo-on-kill. Scavenger was folded into Quick Revive II.
