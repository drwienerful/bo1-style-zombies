# bo1-style-zombies

A script-only (GSC) mod for **Call of Duty: Black Ops Zombies** on the
[Plutonium](https://plutonium.pw) T5 client: a roguelike-flavoured run with a style meter,
emergent archetypes, stronger weapon payoffs, an open perk economy, and a late-game boss.

**Version 1.1.0.** Full player reference: **[CODEX.md](CODEX.md)**.

## What it adds

- **Style meter** (D → SSS) that fills with hits, headshots, multi-kills, melee and more;
  higher ranks pay bonus points and ammo.
- **Weapon payoffs** that make every weapon class worth using (pistol headshot streaks,
  sniper piercing, shotgun shockwaves, launcher blast points) and **double ammo**.
- **No perk limit** (escalating surcharge), **Double Tap 2.0**, **tier II perk upgrades**, and a
  **perk shop** at your spawn point for perks the map has no machine for.
- **Archetypes** that awaken from how you play: Gunslinger, Marksman, Brawler, Blaster,
  Demolitions, Tech, each with an Ascended tier, augments, and a capstone.
- **Run blessings**, **faster late-game pacing**, and **Der Eiserne**, a three-phase boss at
  round 25 with a victory ending.

## Requirements

- Your own legitimate copy of Call of Duty: Black Ops and a working
  [Plutonium](https://plutonium.pw) T5 install (run it once so its folders exist).
- Windows with PowerShell. Python 3 is optional (the installer lints the scripts with it first).

This repository contains **no game files** of any kind: only scripts and data written for it.

## Install

1. Download the latest zip from **[Releases](https://github.com/drwienerful/bo1-style-zombies/releases/latest)** and unzip it
   (or clone this repository).
2. In the repository folder, run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\install.ps1
   ```
   It copies only the mod's `bo1sz_*.gsc` files into
   `%LOCALAPPDATA%\Plutonium\storage\t5\scripts\sp\zom\`, which Plutonium loads only in
   Zombies. It never reads or changes any game file.
3. Start Plutonium T5 and play any Zombies map. You'll see "bo1-style-zombies v1.1.0" a few
   seconds after spawning.

**Uninstall:** `powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Uninstall`
(removes only the mod's own files).

**Turn it off without uninstalling:** in the console before loading a map, `set bo1sz_enable 0`.
Single features can be turned off the same way: `bo1sz_style`, `bo1sz_payoffs`, `bo1sz_ammo`,
`bo1sz_perks`, `bo1sz_archetypes`, `bo1sz_pacing`, `bo1sz_boss`, `bo1sz_modifiers` (set to `0`).

## In game

- **Codex overlay:** `set bo1sz_codex 1` (or `2`, `3`) shows your style, archetype traits and
  augments; `set bo1sz_codex 0` closes it. Tip: `bind F2 "set bo1sz_codex 1"`.
- **Perk tier II:** hold USE at the machine of a perk you own.
- **Perk shop:** hold USE at your spawn point.
- **Augments:** offered at the round break when an archetype ascends; tap USE to move, hold
  USE to choose.

## Known limits

- **24 zombies alive at once** is an engine limit no script can raise.
- Tested solo on Kino der Toten. **Co-op and dedicated servers are untested.**
- Perks from the shop have no HUD icon (their icons aren't loaded on maps without the machine).

## For developers

Rules and conventions: [CLAUDE.md](CLAUDE.md). Tuning lives in `data/balance/*.csv`; run
`python tools/build_balance.py` (and `tools/build_codex.py`) after editing. Design notes are in
`docs/design/`, platform findings in [docs/platform_findings.md](docs/platform_findings.md).

```bash
git config core.hooksPath .githooks        # block game files at commit time
python tools/check_no_game_files.py --all  # same check CI runs
python tools/gsc_lint.py                   # offline lint (brackets, unproven builtins)
```

Debug and test commands (points, boss now, test modes, flood) need `set bo1sz_dev 1` first.
The Phase 0 feasibility probe is kept for re-testing: `tools/install.ps1 -Batch A|B|C|Sweep`.

## Credits and inspiration

- [BO1-Reimagined](https://github.com/Jbleezy/BO1-Reimagined) by Jbleezy. We studied it to learn
  how a mature BO1 mod organises its scripts. No code or assets from it are included here.
- The Plutonium team, for the T5 client and its script extensions.
- Devil May Cry's style meter inspired the concept of our meter. Our rank names and visuals are
  original.

## License

MIT for the code and data in this repository only. See [LICENSE](LICENSE).
