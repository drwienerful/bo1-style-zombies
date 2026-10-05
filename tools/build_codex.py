#!/usr/bin/env python3
"""Generate CODEX.md (the player-facing reference) from data/balance/*.csv.

Usage:
  python tools/build_codex.py          # write CODEX.md
  python tools/build_codex.py --check  # exit 1 if CODEX.md is stale (CI / pre-commit)
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "balance"
OUT = ROOT / "CODEX.md"


def rows(name):
    with (DATA / f"{name}.csv").open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def kv(name):
    return {r["key"]: r["value"] for r in rows(name)}


def table(header, body):
    out = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in body]
    return "\n".join(out)


def render():
    style = kv("style")
    pay = kv("payoffs")
    perks = kv("perks")
    rules = kv("archetype_rules")
    ranks = rows("style_ranks")
    events = rows("style_events")
    tiers = rows("perk_tiers")
    archs = rows("archetypes")
    boss = kv("boss")
    mods = rows("modifiers")
    shop = rows("shop")
    augs = rows("augments")
    arch_name = {a["id"]: a["name"] for a in archs}

    parts = [
        "# Codex",
        "",
        "Generated from `data/balance/*.csv` by `tools/build_codex.py`. Do not edit by hand.",
        "In game: `set bo1sz_codex 1` (or 2, 3) opens the overlay, `set bo1sz_codex 0` closes it.",
        "",
        "## Style meter",
        "",
        f"Stylish play fills the meter; each rank holds a {style['gauge_max']}-point gauge. After "
        f"{int(style['idle_grace_ms']) // 1000}s without a hit or kill it drains, faster at higher ranks. "
        "Getting hit drops one rank; going down resets it to D. A low rank is just the normal game, "
        "never a penalty. The meter doesn't drain between rounds.",
        "",
        f"**Kill chains:** kills within {int(style['chain_window_ms']) // 1000}s of each other build a chain "
        f"(\"Chain xN\" under the meter); each link adds {int(float(style['chain_step']) * 100)}% to kill style, "
        f"up to x{style['chain_max_mult']}.",
        "",
        table(["Rank", "Name", "Bonus points per kill", "Ammo-on-kill chance"],
              [[r["letter"], r["word"], "+" + r["kill_bonus"], r["ammo_chance"] + "%"] for r in ranks]),
        "",
        "Style points per action (repeating the same action gives less each time):",
        "",
        table(["Action", "Style"], [[e["name"].replace("_", " "), e["points"]] for e in events]),
        "",
        "## Weapon payoffs",
        "",
        table(["Weapon", "Payoff"], [
            ["Pistols", f"Headshot-kill streaks ramp damage up to x{pay['pistol_max_mult']}; "
                        f"+{pay['pistol_step_points']} points per step; headshot kills refund a bullet"],
            ["Snipers (and FN FAL)", f"Headshots x{pay['sniper_headshot_mult']}; each extra zombie pierced "
                                     f"takes +{int(float(pay['sniper_pierce_mult']) * 100)}% damage and pays "
                                     f"+{pay['sniper_pierce_points']}"],
            ["Shotguns", f"Each blast sends a shockwave through the crowd behind the target; "
                         f"+{pay['shotgun_extra_kill_points']} per extra kill; {pay['shotgun_refund_kills']} kills "
                         f"refund {pay['shotgun_refund']} shells"],
            ["Launchers", f"+{pay['launcher_hit_points']} per zombie caught in a blast; "
                          f"{pay['launcher_refund_kills']}+ kills refund a round"],
            ["Any weapon", f"Headshot kill +{pay['style_headshot_points']}, extra multi-kill "
                           f"+{pay['style_multi_points']}, long range +{pay['style_long_range_points']}, "
                           f"melee +{pay['style_melee_points']}"],
            ["All guns", "Double ammo: a hidden spare reserve refills a gun once when it runs dry"],
        ]),
        "",
        "Wonder weapons don't get the weapon-class payoffs.",
        "",
        "## Perks",
        "",
        f"No perk limit. The first {perks['stock_limit']} perks cost the normal price; each extra perk adds "
        f"{perks['surcharge_step']} x its extra number. Double Tap 2.0: double bullet damage, "
        "+20% fire rate, steadier hip-fire.",
        "",
        "Hold USE at the machine of a perk you own to buy its tier II:",
        "",
        table(["Tier", "Price", "Effect"], [[t["name"], t["price"], t["desc"]] for t in tiers]),
        "",
        "### Perk shop",
        "",
        "At your spawn point, hold USE to open the Perk Shop. It sells perks that have no machine on "
        "the current map (tap USE to move, hold USE to buy). The usual surcharge applies, and you lose "
        "shop perks when you go down.",
        "",
        table(["Perk", "Price", "Effect"], [[x["name"], x["price"], x["desc"]] for x in shop]),
        "",
        "## Run blessings",
        "",
        "Each run gets one random blessing, announced in round 1. It applies to everyone.",
        "",
        table(["Blessing", "Effect"], [[m["name"], m["desc"]] for m in mods]),
        "",
        "## Archetypes",
        "",
        f"Your play quietly builds affinity for six archetypes. At round breaks you can earn: "
        f"**Awakened** (round {rules['awaken_round']}+, {rules['awaken_aff']} affinity), "
        f"**Ascended** (round {rules['ascend_round']}+, {rules['ascend_aff']} affinity, at most "
        f"{rules['max_ascended']} archetypes, plus a choice of 1 of 3 augments) and the **Capstone** "
        f"(round {rules['cap_round']}+, {rules['cap_aff']} affinity, at least "
        f"{int(float(rules['cap_focus']) * 100)}% of all your affinity, one archetype only). "
        f"If nothing has awakened by round {rules['generalist_round']} and no archetype has "
        f"{int(float(rules['generalist_focus']) * 100)}% of your affinity, you're a **Generalist**: "
        f"+{rules['generalist_kill_points']} points per kill. Tiers are never taken away.",
        "",
        table(["Archetype", "Awakened", "Ascended", "Capstone"],
              [[a["name"], a["awakened"], a["ascended"], a["capstone"]] for a in archs]),
        "",
        "Affinity comes from: pistols and headshots (Gunslinger), snipers, piercing and range "
        "(Marksman), melee (Brawler), shotguns (Blaster), launchers and explosives (Demolitions), "
        "wonder weapons, claymores and monkeys (Tech).",
        "",
        "## Boss",
        "",
        f"At round {boss['round']} (or the next normal round), the first zombie becomes **{boss['name']}**, "
        f"with {boss['hp_mult']}x that round's zombie health per player. Its name and health bar appear at the top.",
        "",
        table(["Phase", "Health", "What happens"], [
            ["1. Onslaught", f"100-{int(float(boss['phase2_at']) * 100)}%",
             f"Push it below {int(float(boss['phase2_at']) * 100)}% within {boss['p1_timer']}s or it enrages and sprints"],
            ["2. Hunt", f"{int(float(boss['phase2_at']) * 100)}-{int(float(boss['phase3_at']) * 100)}%",
             f"It sprints; every {boss['p2_pulse_interval']}s \"PULSE INCOMING\" warns of a {boss['p2_pulse_damage']}-damage pulse around it"],
            ["3. Iron Skin", f"{int(float(boss['phase3_at']) * 100)}-0%",
             f"Only headshots and explosives do full damage; every {boss['p3_crack_interval']}s \"ARMOUR DOWN!\" "
             f"gives {boss['p3_crack_seconds']}s of x{boss['p3_crack_mult']} damage"],
        ]),
        "",
        f"No single moment can take more than {int(float(boss['hit_cap_frac']) * 100)}% of its health. "
        f"Defeating it shows VICTORY, gives the killer {boss['kill_points']} points, and ends the game.",
        "",
        "## Augments",
        "",
        "Offered 1 of 3 when an archetype ascends: tap USE to move, hold USE to choose.",
        "",
        table(["Archetype", "Augment", "Effect"],
              [[arch_name.get(a["arch"], a["arch"]), a["name"], a["desc"]] for a in augs]),
        "",
    ]
    return "\n".join(parts)


def main(argv):
    text = render()
    if "--check" in argv:
        cur = OUT.read_text(encoding="utf-8").replace("\r\n", "\n") if OUT.exists() else ""
        if cur != text:
            print("CODEX.md is stale: run python tools/build_codex.py")
            return 1
        print("CODEX.md is up to date")
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print("wrote CODEX.md")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
