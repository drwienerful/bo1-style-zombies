# Archetypes (Milestone 5, as built)

Source: `src/scripts/mod/bo1sz_archetypes.gsc` (engine, pop-ups, augment menu, Brawler capstone),
`bo1sz_payoffs.gsc` (most trait effects), `bo1sz_style.gsc` (affinity, style traits),
`bo1sz_ammo.gsc` (Tech Ascended), `bo1sz_codex.gsc` (overlay). Tunables:
`data/balance/archetypes.csv`, `archetype_rules.csv`, `augments.csv`. Player-facing reference:
`CODEX.md` (generated).

## Design decisions (user, 2026-10-05)

- Six archetypes: Gunslinger, Marksman, Brawler (melee only; briefly named "Jackie Chan"),
  Blaster (shotguns), Demolitions, Tech. Support was removed.
- Brawler Ascended: getting hit no longer drops the style rank. (A faster-melee perk was tried;
  the engine never granted `specialty_fastmeleerecovery`, so it was dropped.)
- Brawler capstone: damage taken x0.5. Blaster: range compensation, +30% shockwave radius,
  chain reactions.
- The augment menu stays open until the player picks (the auto-pick at round start closed it
  before it could be read).

## Affinity sources

Every style award credits one archetype. Hits and kills credit the archetype of the weapon used
(pistol → Gunslinger, sniper/FN FAL → Marksman, shotgun → Blaster, launcher/grenade →
Demolitions, wonder weapons/claymores/monkeys → Tech); melee always credits Brawler. Headshot,
streak, long-range and explosive bonuses use the weapon's archetype too (they were hard-wired
to Gunslinger/Marksman/Demolitions until a shotgun-only playtest exposed it).

## Testing aids

`set bo1sz_arch_test 1` before loading: round gates x0.2, affinity gates x0.1 (Awakened round 1,
Ascended round 3, capstone round 4). `set bo1sz_arch_eval 1` evaluates immediately.
