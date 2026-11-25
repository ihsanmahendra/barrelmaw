"""Writes the "levels" bonuses into data/cards.json (levels 2, 3, 4, 5 of every card).
Run from the prototype folder: python3 tools/make_card_levels.py
Budget (design/gdd/card-packs.md 3.5): levels 2-4 add at most 1.0 power, level 5 at most 2.0,
all together at most 5.0. 1 hit = 1.0, 1 barrel = 0.8, 1 card = 2.0; a hit on a doubling card = 2.0."""
import json

AMMO = lambda n: {"kind": "ammo", "n": n}
RAND = lambda n: {"kind": "clear_random", "n": n}
COLOR = lambda n: {"kind": "clear_color", "n": n}
DRAW = lambda n: {"kind": "draw", "n": n}
BUMP = lambda kind, n: {"bump": kind, "n": n}

# A hit on a shape card clears a whole row, column or area, so shapes get almost no extra hits.
# Measured with tests/level_balance.gd (all cards at one level, 10,000 bot games):
# "+2 hits on every shape card" alone moved the win rate from 52% to 77%; every other family moved it 0-5 points.
NONE = []
FAMILIES = {
    # Hit-type bonuses go on the cards where a hit is worth the least; barrel bonuses on the rest.
    "hit_boost": (["power_shot", "heavy_round", "overclock", "tidy_up"],
                  [[AMMO(1)], NONE, [AMMO(1)], [AMMO(1)]]),
    "utility": (["skip", "wildcard", "focus", "clone", "second_wind", "roulette"],
                [[AMMO(1)], NONE, [AMMO(1)], [AMMO(1)]]),
    "draw": (["quick_draw", "sniper", "triple_draw"],
             [[AMMO(1)], NONE, [AMMO(1)], [DRAW(1)]]),
    "added_ball": (["reload", "arsenal"],
                   [[BUMP("add_shooter", 1)], NONE, [BUMP("add_shooter", 1)], [BUMP("add_shooter", 1)]]),
    "shape": (["row_strike", "column_strike", "cross_strike", "diagonal", "blast", "wild_row",
               "wild_column", "wild_cross", "prism", "pierce_blast"],
              [NONE, NONE, [RAND(1)], [RAND(1)]]),
    "multiplier": (["rapid_fire", "echo", "double_blast"],
                   [NONE, [RAND(1)], NONE, [RAND(1)]]),
    "small_removal": (["scatter", "pick_off", "pixel_rain"],
                      [NONE, [RAND(1)], NONE, [RAND(1)]]),
    "color_removal": (["color_bomb", "color_storm", "maelstrom"],
                      [NONE, [COLOR(1)], NONE, [COLOR(1)]]),
    # Transcended cards: a ball bump on a two-ball card is worth 2, so they gain barrels or hits instead.
    "transcended_balls": (["davy_ledger"], [NONE, [RAND(1)], NONE, [RAND(1)]]),
    "transcended_turn": (["ghost_compass", "phantom_echo"], [[AMMO(1)], NONE, [AMMO(1)], [AMMO(1)]]),
}

d = json.load(open("data/cards.json"))
by_id = {c["id"]: c for c in d["cards"]}
done = set()
for name, (ids, levels) in FAMILIES.items():
    for i in ids:
        by_id[i]["levels"] = json.loads(json.dumps(levels))
        done.add(i)
missing = set(by_id) - done
assert not missing, missing
json.dump(d, open("data/cards.json", "w"), indent=1)
print("levels written for", len(done), "cards")
