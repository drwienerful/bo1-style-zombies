# CLAUDE.md — bo1-style-zombies

GSC script mod for Call of Duty: Black Ops (T5) **Zombies** on the Plutonium client.
Roguelike-flavoured runs, a style meter, emergent archetypes, weapon payoffs, a late-game boss.

## HARD RULES (non-negotiable)

1. **Never commit game files.** The repo holds only code and data we write ourselves.
   Players use their own legitimate copy of the game and Plutonium.
   - Forbidden in the repo: stock or decompiled game scripts, fastfiles (`.ff`), `.iwd`,
     models, animations, textures (`.iwi`), sounds/music, weapon files, localized strings
     from the game, anything extracted from game installs, anything copied from other
     mods' asset directories.
   - Never replace a stock script by copying it with edits. Our scripts add behaviour by
     loading alongside stock scripts and hooking via threads, callback overrides
     (`level.overrideActorDamage` etc.), and level variables.
   - `replaceFunc` (Plutonium) is **allowed** (user decision, 2026-10-05) as long as the
     replacement body is **original**: written from the behaviour we want, never a
     pasted or lightly edited copy of the stock function. Prefer wrapping (call the stock
     function via `getFunction`, then add our logic) over full replacement. List every
     replaced function in `docs/platform_findings.md`.
2. **Reference material is local-only** in `reference/` (gitignored). Read it to learn
   function names, signatures and patterns. Never paste its code or assets into tracked
   files. Write original implementations; credit inspirations in README.
3. BO1-Reimagined's `License.md` is a warranty disclaimer with no grant of permission.
   Assume **no permission** to reuse its code. To reuse anything specific: stop and ask the
   user to contact the author.
4. No leaked/private code. No circumventing protection. **Zombies only**, solo and private
   co-op, non-commercial. No multiplayer-mode changes.
5. Guardrails: strict `.gitignore`, `.githooks/pre-commit` → `tools/check_no_game_files.py`
   (allowlist of our file types/dirs, denylist of game extensions and stock script
   names). CI runs the same check. Enable locally with
   `git config core.hooksPath .githooks`.
6. `tools/install.ps1` only copies **our** files into the player's Plutonium storage
   folder. It never reads, copies or modifies game files, and only ever deletes files
   carrying our `bo1sz_` prefix.
7. **NEVER NERF.** Every balance change raises a weak option's power, reward or utility.
   Never reduce an existing strong weapon's performance. Never port a Reimagined change
   that nerfs something.

## Layout

| Path | Contents |
|---|---|
| `src/scripts/` | Our GSC only (`probe/` = Phase 0 feasibility probe) |
| `data/balance/*.csv` | Source of truth for tunables (generated into GSC by a tool) |
| `tools/` | installer, balance build script, game-file checker |
| `docs/` | platform findings, design, codex sources |
| `reference/` | **gitignored** local clones (BO1-Reimagined, optional stock script ref) |

## Workflow

- GSC has no offline compiler: a syntax error or a call to an unknown builtin/function
  can stop the map from loading. Work in tiny increments; every module has a dvar to
  disable it; ask the user to run the game and paste console output after each step.
- Prefer `getFunction("maps/<file>", "<name>")` (Plutonium) over static
  `maps\file::func` references for anything optional: a missing function then becomes
  a runtime `undefined` we can report, instead of a link error that blocks loading.
- Only use builtins already proven by stock usage in `reference/` or by Plutonium's own
  shipped script (`storage\t5\raw\scripts\sp\zm_spawn_fix.gsc`, read-only).
- Every feature behind a config dvar. Small commits.
- After each milestone: what works, what feels off, one thing to playtest.
- The game writes `logprint` output to `%LOCALAPPDATA%\Plutonium\storage\t5\games_sp.log`;
  read it after a session instead of asking the user to transcribe.

## Current phase

Milestone 0 (feasibility). **No gameplay code until the user approves
`docs/platform_findings.md`.**
