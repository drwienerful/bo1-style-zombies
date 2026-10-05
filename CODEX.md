# Codex

Generated from `data/balance/*.csv` by `tools/build_codex.py`. Do not edit by hand.
In game: `set bo1sz_codex 1` (or 2, 3) opens the overlay, `set bo1sz_codex 0` closes it.

## Style meter

Stylish play fills the meter; each rank holds a 100-point gauge. After 2s without a hit or kill it drains, faster at higher ranks. Getting hit drops one rank; going down resets it to D. A low rank is just the normal game, never a penalty.

| Rank | Name | Bonus points per kill | Ammo-on-kill chance |
|---|---|---|---|
| D | Dawdling | +0 | 0% |
| C | Cold-Blooded | +4 | 0% |
| B | Butcher | +8 | 3% |
| A | Annihilator | +12 | 5% |
| S | Slaughterhouse | +16 | 8% |
| SS | Spine-Shattering | +24 | 12% |
| SSS | Schutzstaffel Slayer | +32 | 15% |

Style points per action (repeating the same action gives less each time):

| Action | Style |
|---|---|
| kill | 5 |
| headshot | 12 |
| headshot streak | 4 |
| multi kill | 10 |
| long range | 12 |
| melee | 15 |
| explosive | 6 |
| clutch | 12 |
| variety | 8 |
| revive | 25 |
| hit | 2 |
| hit headshot | 4 |
| hit aoe | 3 |

## Weapon payoffs

| Weapon | Payoff |
|---|---|
| Pistols | Headshot-kill streaks ramp damage up to x3.5; +10 points per step; headshot kills refund a bullet |
| Snipers (and FN FAL) | Headshots x3.5; each extra zombie pierced takes +50% damage and pays +20 |
| Shotguns | Each blast sends a shockwave through the crowd behind the target; +25 per extra kill; 3 kills refund 2 shells |
| Launchers | +15 per zombie caught in a blast; 6+ kills refund a round |
| Any weapon | Headshot kill +10, extra multi-kill +10, long range +15, melee +20 |
| All guns | Double ammo: a hidden spare reserve refills a gun once when it runs dry |

Wonder weapons don't get the weapon-class payoffs.

## Perks

No perk limit. The first 4 perks cost the normal price; each extra perk adds 1000 x its extra number. Double Tap 2.0: double bullet damage, +20% fire rate, steadier hip-fire.

Hold USE at the machine of a perk you own to buy its tier II:

| Tier | Price | Effect |
|---|---|---|
| Juggernog II | 3000 | +50 max health |
| Speed Cola II | 3000 | Reloads even faster (0.35x reload time) |
| Double Tap II | 3000 | Fire rate up to +30% |
| Quick Revive II: Scavenger | 3000 | Kills may refill 30% of every gun's magazine (8% chance) |
| Mule Kick II | 3000 | One more spare ammo reserve on every weapon |
| Deadshot II | 3000 | +25% headshot damage |

### Perk shop

At your spawn point, hold USE to open the Perk Shop. It sells perks that have no machine on the current map (tap USE to move, hold USE to buy). The usual surcharge applies, and you lose shop perks when you go down.

| Perk | Price | Effect |
|---|---|---|
| Stamin-Up | 2000 | Run faster and sprint longer |
| PhD Flopper | 2000 | Your own explosives can't hurt you |
| Deadshot Daiquiri | 1500 | Steadier aim and +25% headshot damage |

## Run blessings

Each run gets one random blessing, announced in round 1. It applies to everyone.

| Blessing | Effect |
|---|---|
| Discount Cola | Machine perks refund 25% of their price |
| Deep Pockets | One more spare ammo reserve on every weapon |
| High Roller | Style rank kill bonuses x2 but the meter drains 30% faster |
| Thick Skin | +50 max health |
| Lucky Streak | Kills have a 5% chance to refill 20% of your magazine |
| Head Start | Start with +2000 points |

## Archetypes

Your play quietly builds affinity for six archetypes. At round breaks you can earn: **Awakened** (round 5+, 300 affinity), **Ascended** (round 12+, 1500 affinity, at most 2 archetypes, plus a choice of 1 of 3 augments) and the **Capstone** (round 20+, 4000 affinity, at least 50% of all your affinity, one archetype only). If nothing has awakened by round 8 and no archetype has 35% of your affinity, you're a **Generalist**: +5 points per kill. Tiers are never taken away.

| Archetype | Awakened | Ascended | Capstone |
|---|---|---|---|
| Gunslinger | Pistol streak damage cap x4.5 and streaks last 6s | Pistol headshot kills refund 2 bullets | A 5+ streak refills your magazine on every pistol kill |
| Marksman | Sniper pierce bonus +75% per extra zombie | Long-range kills give double style | Every 3rd sniper headshot kill detonates |
| Brawler | Melee damage x2 | Getting hit no longer drops your style rank | All damage taken -50% |
| Blaster | Shotgun damage holds up at range | Shockwave radius +30% | Shockwave kills set off chain reactions |
| Demolitions | Explosive damage +25% | Explosive kills of 3+ refund a grenade | Launcher kills set off a second blast |
| Tech | Wonder weapon kills give +50% style | Wonder weapons get one extra spare ammo reserve | Wonder weapon kills release a mini shockwave |

Affinity comes from: pistols and headshots (Gunslinger), snipers, piercing and range (Marksman), melee (Brawler), shotguns (Blaster), launchers and explosives (Demolitions), wonder weapons, claymores and monkeys (Tech).

## Boss

At round 25 (or the next normal round), the first zombie becomes **Der Eiserne**, with 40x that round's zombie health per player. Its name and health bar appear at the top.

| Phase | Health | What happens |
|---|---|---|
| 1. Onslaught | 100-66% | Push it below 66% within 45s or it enrages and sprints |
| 2. Hunt | 66-33% | It sprints; every 6s "PULSE INCOMING" warns of a 60-damage pulse around it |
| 3. Iron Skin | 33-0% | Only headshots and explosives do full damage; every 12s "ARMOUR DOWN!" gives 4s of x2.0 damage |

No single moment can take more than 10% of its health. Defeating it shows VICTORY, gives the killer 5000 points, and ends the game.

## Augments

Offered 1 of 3 when an archetype ascends: tap USE to move, hold USE to choose.

| Archetype | Augment | Effect |
|---|---|---|
| Gunslinger | Hot Barrel | +25% pistol damage |
| Gunslinger | Bounty | +20 points per pistol kill |
| Gunslinger | Showboat | +50% style from pistol kills |
| Gunslinger | Speed Loader | Pistol kills refill 20% of the magazine |
| Gunslinger | Steady Hand | Pistol streaks never time out |
| Marksman | Hollow Points | +25% sniper damage |
| Marksman | Collector | +20 points per sniper kill |
| Marksman | Long Game | +50% style from sniper kills |
| Marksman | Chamber | Sniper kills refill 20% of the magazine |
| Marksman | Eagle Eye | Long range starts at half the distance |
| Brawler | Iron Fist | +50% melee damage |
| Brawler | Prize Fighter | +30 points per melee kill |
| Brawler | Crowd Pleaser | +50% style from melee kills |
| Brawler | Quick Hands | Melee kills refill 20% of your gun's magazine |
| Brawler | Shockfist | Melee kills release a small shockwave |
| Blaster | Buckshot | +25% shotgun damage |
| Blaster | Scrap Value | +20 points per shotgun kill |
| Blaster | Loud and Proud | +50% style from shotgun kills |
| Blaster | Shell Belt | Shotgun kills refill 20% of the magazine |
| Blaster | Aftershock | Shockwave damage +50% |
| Demolitions | Bigger Boom | +25% explosive damage |
| Demolitions | Demolition Pay | +20 points per explosive kill |
| Demolitions | Fireworks | +50% style from explosive kills |
| Demolitions | Bandolier | Explosive kills refill 20% of the magazine |
| Demolitions | Short Fuse | Launcher refund at 4 kills instead of 6 |
| Tech | Overclock | +25% wonder weapon damage |
| Tech | Patent | +20 points per wonder weapon kill |
| Tech | Showcase | +50% style from wonder weapon kills |
| Tech | Capacitor | Wonder weapon kills refill 20% of the magazine |
| Tech | Gadgeteer | Claymore and monkey kills +50 points |
