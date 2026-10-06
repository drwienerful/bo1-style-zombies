#!/usr/bin/env python3
"""Build a player release zip: dist/bo1-style-zombies-v<version>.zip

Contains only our own files: the mod scripts, the installer, README, CODEX, LICENSE and a
short INSTALL.txt. Every file is checked with tools/check_no_game_files.py first, and the
mod is linted. dist/ is gitignored.

Usage: python tools/make_release.py
"""
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MOD = ROOT / "src" / "scripts" / "mod"

INSTALL_TXT = """bo1-style-zombies v{version}
============================

Requirements: your own copy of Call of Duty: Black Ops and Plutonium (plutonium.pw) with
T5 run at least once.

Install (easy):
  1. Unzip this folder anywhere.
  2. Right-click tools\\install.ps1 > "Run with PowerShell".
     (Or open PowerShell in this folder and run:
      powershell -ExecutionPolicy Bypass -File tools\\install.ps1)
  3. Start Plutonium T5 and play any Zombies map.

Install (manual):
  Copy every file from src\\scripts\\mod\\ into
  %LOCALAPPDATA%\\Plutonium\\storage\\t5\\scripts\\sp\\zom\\
  (paste that path into the File Explorer address bar; create the folders if missing).

Uninstall:
  powershell -ExecutionPolicy Bypass -File tools\\install.ps1 -Uninstall
  (or delete the bo1sz_*.gsc files from the folder above)

In game: hold ADS + USE for the codex. Full guide: CODEX.md and README.md.
Co-op: only the host needs the mod.
"""


def version():
    text = (MOD / "bo1sz_main.gsc").read_text(encoding="utf-8")
    m = re.search(r'return "(\d+\.\d+\.\d+)";', text)
    if not m:
        sys.exit("version not found in bo1sz_main.gsc")
    return m.group(1)


def main():
    ver = version()
    files = sorted(MOD.glob("bo1sz_*.gsc"))
    files += [ROOT / "tools" / "install.ps1", ROOT / "README.md", ROOT / "CODEX.md", ROOT / "LICENSE"]
    rel = [str(f.relative_to(ROOT)).replace("\\", "/") for f in files]

    py = sys.executable
    for cmd in (["tools/check_no_game_files.py", *rel], ["tools/gsc_lint.py", "src/scripts/mod"],
                ["tools/build_balance.py", "--check"], ["tools/build_codex.py", "--check"]):
        r = subprocess.run([py, *cmd], cwd=ROOT)
        if r.returncode != 0:
            sys.exit(f"release aborted: {' '.join(cmd)} failed")

    out = ROOT / "dist" / f"bo1-style-zombies-v{ver}.zip"
    out.parent.mkdir(exist_ok=True)
    top = f"bo1-style-zombies-v{ver}"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f, r in zip(files, rel):
            z.write(f, f"{top}/{r}")
        z.writestr(f"{top}/INSTALL.txt", INSTALL_TXT.format(version=ver))
    print(f"wrote {out.relative_to(ROOT)} ({len(files) + 1} files)")


if __name__ == "__main__":
    main()
