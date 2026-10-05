#!/usr/bin/env python3
"""Cheap offline sanity check for our GSC files (there is no T5 compiler we can run).

Catches the failures that stop a map from loading:
  - unbalanced (), [], {} outside strings/comments
  - calls to a function that is neither defined in the file nor a builtin we have
    verified exists in T5/Plutonium (see VERIFIED_BUILTINS)
  - ::refs to functions that are not defined in the file
It is not a parser; a clean result does not prove the script compiles.

Usage: python tools/gsc_lint.py [files...]   (default: every .gsc under src/)
"""
import re
import sys
from pathlib import Path

# Each name below is used by stock BO1 scripts or by Plutonium's own shipped
# zm_spawn_fix.gsc. Add a name only after confirming it there.
VERIFIED_BUILTINS = {
    # flow / engine
    "isdefined", "isalive", "isplayer", "isai", "gettime", "int", "getarraykeys",
    "strtok", "getsubstr", "issubstr", "tolower", "getplayers", "getaispeciesarray",
    "getentarray", "spawn", "earthquake", "radiusdamage", "precacheshader",
    "precachestring", "logprint", "println", "iprintln", "iprintlnbold",
    "getdvar", "getdvarint", "getdvarfloat", "setdvar", "setclientdvar",
    "weaponclass", "weaponclipsize", "weaponfiretime", "newclienthudelem",
    "distance", "randomint",
    # Plutonium additions (proven in storage/t5/raw/scripts/sp/zm_spawn_fix.gsc)
    "getfunction", "replacefunc", "isdedicated",
    # entity / player methods
    "getweaponammoclip", "setweaponammoclip", "getweaponammostock", "givemaxammo",
    "getcurrentweapon", "getweaponslist", "giveweapon", "takeweapon", "hasweapon",
    "switchtoweapon", "hasperk", "setperk", "unsetperk", "playlocalsound",
    "playsound", "adsbuttonpressed", "usebuttonpressed", "attackbuttonpressed",
    "setcursorhint", "sethintstring", "delete", "destroy", "settext", "setshader",
    "setvalue", "fadeovertime", "scaleovertime",
}
KEYWORDS = {"if", "while", "for", "switch", "return", "wait", "foreach", "else",
            "case", "thread", "waittill", "notify", "endon", "waittillframeend"}


def strip(src: str) -> str:
    """Blank out comments and string literals, keeping line structure."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            i = j
        elif src.startswith("/*", i) or src.startswith("/#", i):
            end = "*/" if src[i + 1] == "*" else "#/"
            j = src.find(end, i + 2)
            j = n if j < 0 else j + 2
            out.append("\n" * src.count("\n", i, j))
            i = j
        elif c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            out.append('""')
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def lint(path: Path) -> list:
    errs = []
    code = strip(path.read_text(encoding="utf-8"))

    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for ln, line in enumerate(code.splitlines(), 1):
        for ch in line:
            if ch in "([{":
                stack.append((ch, ln))
            elif ch in pairs:
                if not stack or stack[-1][0] != pairs[ch]:
                    errs.append(f"{path}:{ln}: unbalanced '{ch}'")
                else:
                    stack.pop()
    for ch, ln in stack:
        errs.append(f"{path}:{ln}: unclosed '{ch}'")

    defined = {m.group(1).lower() for m in re.finditer(r"^([A-Za-z_]\w*)\s*\(", code, re.M)}
    for m in re.finditer(r"::\s*([A-Za-z_]\w*)", code):
        if m.group(1).lower() not in defined:
            ln = code.count("\n", 0, m.start()) + 1
            errs.append(f"{path}:{ln}: ::{m.group(1)} not defined in this file")
    for m in re.finditer(r"(?<![:\w])([A-Za-z_]\w*)\s*\(", code):
        name = m.group(1).lower()
        if name in KEYWORDS or name in defined or name in VERIFIED_BUILTINS:
            continue
        ln = code.count("\n", 0, m.start()) + 1
        # Function definitions at column 0 are in `defined`; anything else is a call.
        errs.append(f"{path}:{ln}: call to unverified function '{m.group(1)}'")
    return errs


def main(argv):
    files = [Path(a) for a in argv] or sorted(Path("src").rglob("*.gsc"))
    errs = []
    for f in files:
        errs += lint(f)
    for e in errs:
        print(e)
    print(f"gsc_lint: {len(files)} file(s), {len(errs)} problem(s)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
