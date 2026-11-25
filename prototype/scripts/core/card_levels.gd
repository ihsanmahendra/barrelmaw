class_name CardLevels
extends RefCounted
## What a card does at each level. cards.json gives every card a "levels" list with the bonus for levels
## 2, 3, 4 and 5 (index 0 is level 2). Each entry is a list of effects that are added to the card:
##   {"kind": "ammo", "n": 1}            one more hit on the next cannonball
##   {"kind": "clear_random", "n": 1}    one more random barrel removed (same for clear_color, draw)
##   {"bump": "add_shooter", "n": 1}     adds hits to the cannonball the card adds
## The power budget rules are in design/gdd/card-packs.md (3.5) and checked by the tests.

const PP_HIT: float = 1.0
const PP_BARREL: float = 0.8
const PP_DRAW: float = 2.0
const LEVEL_CAP_PP: float = 1.0  # most power one of levels 2 to 4 may add
const MASTERY_CAP_PP: float = 2.0  # most power level 5 may add
const TOTAL_CAP_PP: float = 5.0  # most power all levels together may add (or 40% of the base power)


## The effects the card has at `level`: the base effects plus the bonuses of levels 2 up to `level`.
static func effects_for(card: Dictionary, level: int) -> Array:
	var effects: Array = (card["effects"] as Array).duplicate(true)
	var bonuses: Array = card.get("levels", [])
	for lv in range(2, mini(level, bonuses.size() + 1) + 1):
		for entry in bonuses[lv - 2]:
			if entry.has("bump"):
				for eff in effects:
					if eff["kind"] == entry["bump"]:
						eff["n"] = int(eff.get("n", 0)) + int(entry["n"])
						break
			else:
				effects.append((entry as Dictionary).duplicate())
	return effects


## Total of everything levels 2 up to `level` add: {hits, barrels, cards}.
static func bonus_totals(card: Dictionary, level: int) -> Dictionary:
	var t := {"hits": 0, "barrels": 0, "cards": 0}
	var bonuses: Array = card.get("levels", [])
	for lv in range(2, mini(level, bonuses.size() + 1) + 1):
		for entry in bonuses[lv - 2]:
			var n := int(entry["n"])
			var kind: String = str(entry.get("bump", entry.get("kind", "")))
			match kind:
				"ammo", "add_shooter":
					t["hits"] += n
				"clear_random", "clear_color":
					t["barrels"] += n
				"draw":
					t["cards"] += n
	return t


## Short text for what the level adds, e.g. "+2 hits, +1 barrel". Empty at level 1.
static func bonus_text(card: Dictionary, level: int) -> String:
	if level < 2:
		return ""
	var t := bonus_totals(card, level)
	var parts: Array = []
	if int(t["hits"]) > 0:
		parts.append("+%d hit%s" % [t["hits"], "" if int(t["hits"]) == 1 else "s"])
	if int(t["barrels"]) > 0:
		parts.append("+%d barrel%s" % [t["barrels"], "" if int(t["barrels"]) == 1 else "s"])
	if int(t["cards"]) > 0:
		parts.append("+%d card%s" % [t["cards"], "" if int(t["cards"]) == 1 else "s"])
	return ", ".join(parts)


## Cannonballs the card adds (Jones' Ledger adds two); a bump on the ball applies to each.
static func _ball_count(card: Dictionary) -> float:
	for eff in card["effects"]:
		if eff["kind"] == "add_shooter":
			return float(eff.get("count", 1))
	return 1.0


static func _has_double(card: Dictionary) -> bool:
	for eff in card["effects"]:
		if eff["kind"] == "double":
			return true
	return false


## Power points of one bonus entry. A hit on a card that doubles its hits is worth two.
static func entry_power(entry: Dictionary, card: Dictionary) -> float:
	var n := float(entry.get("n", 0))
	var kind: String = str(entry.get("bump", entry.get("kind", "")))
	match kind:
		"ammo":
			return n * PP_HIT * (2.0 if _has_double(card) else 1.0)
		"add_shooter":
			return n * PP_HIT * _ball_count(card)
		"clear_random", "clear_color":
			return n * PP_BARREL
		"draw":
			return n * PP_DRAW
	return 999.0  # not a kind levels may use


## Power of the card's own effects, used for the "40% of base" part of the total cap.
static func base_power(card: Dictionary) -> float:
	var p := 0.0
	for eff in card["effects"]:
		var n := float(eff.get("n", 0))
		match eff["kind"]:
			"ammo":
				p += n * PP_HIT * (2.0 if _has_double(card) else 1.0)
			"add_shooter":
				p += n * PP_HIT * float(eff.get("count", 1))
			"clear_random", "clear_color":
				p += n * PP_BARREL
			"draw":
				p += n * PP_DRAW
	return p


## Power each level adds: an array of 4 numbers for levels 2 to 5.
static func level_powers(card: Dictionary) -> Array:
	var out: Array = []
	for entries in card.get("levels", []):
		var p := 0.0
		for entry in entries:
			p += entry_power(entry, card)
		out.append(p)
	return out
