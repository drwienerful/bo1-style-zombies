# bo1-style-zombies

A script-only (GSC) mod for **Call of Duty: Black Ops Zombies** on the
[Plutonium](https://plutonium.pw) T5 client. It aims for a roguelike-flavoured run
with a style meter, emergent archetypes, better weapon variety, and a late-game boss.

**Status:** Milestone 2. The style meter works in game (`docs/design/style_meter.md`).
Player reference: [CODEX.md](CODEX.md). Phase 0 findings: [docs/platform_findings.md](docs/platform_findings.md).

## Requirements

You need your own legitimate copy of Black Ops and a Plutonium install. This repo
contains **no game files** of any kind: only scripts and data we wrote ourselves.

## Install

```powershell
powershell -ExecutionPolicy Bypass -File tools\install.ps1             # install the mod
powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Uninstall  # remove it
```

The installer copies only our `bo1sz_*.gsc` files into
`%LOCALAPPDATA%\Plutonium\storage\t5\scripts\sp\zom\` (loaded in Zombies only).
Disable without uninstalling: `set bo1sz_enable 0` in the console before loading a map.

## Phase 0 probe (re-testing)

```powershell
# Batch A: which folders load scripts?
powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Batch A -Map zombie_theater
# Batch B / C: hook and capability tests (enable in console: set probe_batch b)
powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Batch B
# Remove everything we installed
powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Uninstall
```

Results print as `[PROBE] ...` lines on screen, in the console, in
`%LOCALAPPDATA%\Plutonium\storage\t5\main\games.log`, and in the `probe_log` dvar.

Our scripts install to `storage\t5\scripts\sp\zom\`, which Plutonium loads only in Zombies.

## Development

```bash
git config core.hooksPath .githooks       # block game files at commit time
python tools/check_no_game_files.py --all # same check CI runs
python tools/gsc_lint.py                  # offline bracket/unknown-call lint
```

See [CLAUDE.md](CLAUDE.md) for the project rules.

## Credits and inspiration

- [BO1-Reimagined](https://github.com/Jbleezy/BO1-Reimagined) by Jbleezy. We studied
  it to learn how a mature BO1 mod organises its scripts. No code or assets
  from it are included here.
- The Plutonium team, for the T5 client and its script extensions.
- Devil May Cry's style meter inspired the concept of our meter. Our rank names
  and visuals are original.
