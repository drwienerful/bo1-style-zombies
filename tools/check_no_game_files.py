#!/usr/bin/env python3
"""Refuse anything that is not our own code/data.

Usage:
  python tools/check_no_game_files.py            # check staged files (pre-commit)
  python tools/check_no_game_files.py --all      # check every tracked file (CI)
  python tools/check_no_game_files.py PATH...    # check explicit paths

Exit code 1 on any violation.
"""
import re
import subprocess
import sys
from pathlib import PurePosixPath

# Our own file types, only inside our own top-level directories.
ALLOWED_DIRS = {"src", "data", "tools", "docs"}
ALLOWED_EXTS = {".gsc", ".csv", ".json", ".md", ".py", ".ps1", ".txt"}

# Repo infrastructure files allowed by exact path.
ALLOWED_EXACT = {
    ".gitignore",
    ".gitattributes",
    ".githooks/pre-commit",
    ".github/workflows/guardrails.yml",
    "CLAUDE.md",
    "README.md",
    "CODEX.md",
    "LICENSE",
}

# Never allowed, regardless of location.
DENIED_EXTS = {
    ".ff", ".iwd", ".iwi", ".xpak", ".sabl", ".sabs", ".bik", ".d3dbsp",
    ".wav", ".mp3", ".flac", ".ogg", ".dds", ".tga", ".png", ".jpg",
    ".dll", ".exe", ".gscbin", ".csc", ".str", ".zip", ".7z", ".rar",
    ".menu", ".atr", ".vision", ".efx", ".fx",
}
DENIED_DIR_PARTS = {
    "reference", "maps", "clientscripts", "animscripts", "common_scripts",
    "raw", "zone_source", "xmodel", "xanim", "xmodelparts", "xmodelsurfs",
    "images", "sound", "soundaliases", "weapons", "localizedstrings", "english",
    "mods",
}
# Stock script basenames (BO1 zombies + shared). Our files must never shadow these.
DENIED_NAME_RE = re.compile(
    r"^(_zombiemode.*|_callbackglobal|_laststand|_load.*|_utility.*|_gameskill|"
    r"_weaponobjects|_ballistic_knife|_mgturret|_spawner|_hud.*|_music|_audio|"
    r"_cooplogic|_art|_fx|_destructible.*|_ambient.*|utility|zombie_[a-z0-9_]+|"
    r"zm_spawn_fix|mp_spawn_fix)\.(gsc|csc|gsx)$",
    re.IGNORECASE,
)
# Weapon files have no extension in the game tree; catch by common BO1 suffixes.
DENIED_WEAPON_RE = re.compile(r"_(zm|upgraded_zm|sp|mp)$", re.IGNORECASE)


def check(path: str) -> list:
    p = PurePosixPath(path.replace("\\", "/"))
    errs = []
    parts = [x.lower() for x in p.parts]
    ext = p.suffix.lower()

    for part in parts[:-1]:
        if part in DENIED_DIR_PARTS:
            errs.append(f"denied directory '{part}'")
    if ext in DENIED_EXTS:
        errs.append(f"denied extension '{ext}'")
    if DENIED_NAME_RE.match(p.name):
        errs.append("filename matches a stock script name")
    if ext == "" and DENIED_WEAPON_RE.search(p.name):
        errs.append("looks like a game weapon file")

    if str(p) not in ALLOWED_EXACT:
        if len(parts) < 2 or parts[0] not in ALLOWED_DIRS:
            errs.append(f"not under an allowed directory {sorted(ALLOWED_DIRS)}")
        if ext not in ALLOWED_EXTS:
            errs.append(f"extension '{ext or '(none)'}' not in allowlist")
    return errs


def git_files(args):
    out = subprocess.run(["git", *args], capture_output=True, text=True, check=True)
    return [l for l in out.stdout.splitlines() if l.strip()]


def main(argv):
    if "--all" in argv:
        files = git_files(["ls-files"])
    elif argv:
        files = argv
    else:
        files = git_files(["diff", "--cached", "--name-only", "--diff-filter=ACMR"])

    bad = 0
    for f in files:
        for e in check(f):
            print(f"BLOCKED {f}: {e}")
            bad += 1
    if bad:
        print(f"\n{bad} violation(s). Only our own code/data may be committed (see CLAUDE.md).")
        return 1
    print(f"check_no_game_files: {len(files)} file(s) OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
