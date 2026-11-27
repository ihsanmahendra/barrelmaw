"""Adds the four Transcended cards to data/cards.json (safe to run twice). They are chest-only: they are not in
the starter deck or in Stages.UNLOCKS. Run from the prototype folder, then run tools/make_card_levels.py.
Design: design/gdd/card-packs.md, section 3.6."""
import json

CARDS = [
    {"id": "maelstrom", "name": "Maelstrom", "rarity": "transcended",
     "desc": "Remove up to 20 barrels of the biggest color",
     "effects": [{"kind": "clear_color", "n": 20}]},
    {"id": "davy_ledger", "name": "Jones' Ledger", "rarity": "transcended",
     "desc": "Add two 2-hit cannonballs that can hit any color",
     "effects": [{"kind": "add_shooter", "n": 2, "count": 2, "wild": True}]},
    {"id": "ghost_compass", "name": "Ghost Compass", "rarity": "transcended",
     "desc": "Free turn (no star cost). +3 hits, draw 2, play 1 more",
     "effects": [{"kind": "free_turn"}, {"kind": "ammo", "n": 3}, {"kind": "draw", "n": 2}, {"kind": "extra_play", "n": 1}]},
    {"id": "phantom_echo", "name": "Phantom Echo", "rarity": "transcended",
     "desc": "Repeat last card at +1 level. +1 hit",
     "effects": [{"kind": "repeat_last"}, {"kind": "ammo", "n": 1}]},
]

d = json.load(open("data/cards.json"))
by_id = {c["id"]: i for i, c in enumerate(d["cards"])}
for c in CARDS:
    if c["id"] in by_id:  # keep the levels the other script wrote
        old = d["cards"][by_id[c["id"]]]
        c = dict(c, **({"levels": old["levels"]} if "levels" in old else {}))
        d["cards"][by_id[c["id"]]] = c
    else:
        d["cards"].append(c)
json.dump(d, open("data/cards.json", "w"), indent=1)
print("cards:", len(d["cards"]))
