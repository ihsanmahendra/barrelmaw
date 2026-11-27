class_name Stages
extends RefCounted
## The 100 stages: one picture each, difficulty rising. Stages 1-50 are the day world and 51-100 the night world. Stage numbers shown to the player start
## at 1; code uses 0-based indexes. Every 5th stage is tougher, every 10th is a boss.

const TOTAL: int = 100
const NIGHT_START: int = 50  # index of the first night stage (stage 51)


## True for the night world, stages 51-100.
static func is_night(index: int) -> bool:
	return index >= NIGHT_START


static func is_boss(index: int) -> bool:
	return (index + 1) % 10 == 0


static func is_elite(index: int) -> bool:
	return (index + 1) % 5 == 0 and not is_boss(index)


# The rule that makes each elite stage different (design/balance/rebalance.md 3.3). Keys are stage numbers.
# Powder Keg is day only: night stages have so few cannonballs that extra bombs would make them easier.
const ELITE_RULES: Dictionary = {
	5: "keg", 15: "iron", 25: "short", 35: "keg", 45: "iron",
	55: "short", 65: "iron", 75: "short", 85: "iron", 95: "short",
}
# kind -> [name shown to the player, line shown to the player]
const ELITE_TEXT: Dictionary = {
	"keg": ["Powder Keg", "Bombs are packed in, but cannonballs are scarce. Set off chains."],
	"iron": ["Iron Hull", "A quarter of the barrels are iron. They take two hits."],
	"short": ["Short Hand", "Short-handed crew: 2 cards each turn instead of 3."],
}
const KEG_BOMB_FACTOR: int = 3
const KEG_MIN_BOMBS: int = 5
const IRON_SHARE: float = 0.25
const IRON_MIN_EXTRA: int = 4
const SHORT_HAND_SIZE: int = 2


# The rule each boss strikes with (design/gdd/boss-rules.md). Keys are stage numbers. The slack and star
# limits of these stages were tuned with the rule in play: change them together.
const BOSS_RULES: Dictionary = {
	10: "ghost", 20: "armor", 30: "curse", 40: "ghost", 50: "armor",
	60: "curse", 70: "ghost", 80: "armor", 90: "curse", 100: "ghost",
}
const BOSS_TEXT: Dictionary = {
	"ghost": ["Ghost Tide", "Every third shot, sunken barrels rise again."],
	"armor": ["Iron Kraken", "Every third shot, the Kraken armors your barrels."],
	"curse": ["Skull Storm", "Every third shot, skulls wash aboard."],
}
const STRIKE_SHARE: float = 0.04  # of the picture's barrels, per strike
const STRIKE_MIN: int = 2


static func boss_rule(index: int) -> String:
	return String(BOSS_RULES.get(index + 1, ""))


static func boss_rule_name(index: int) -> String:
	var rule := boss_rule(index)
	return "" if rule == "" else String(BOSS_TEXT[rule][0])


static func boss_rule_line(index: int) -> String:
	var rule := boss_rule(index)
	return "" if rule == "" else String(BOSS_TEXT[rule][1])


## Barrels a strike affects on this stage.
static func strike_size(index: int) -> int:
	var n := 0
	for r in picture(index)["rows"]:
		for ch in String(r):
			if ch != ".":
				n += 1
	return maxi(STRIKE_MIN, int(round(n * STRIKE_SHARE)))


## The elite rule of a stage: "keg", "iron", "short" or "" for none.
static func elite_modifier(index: int) -> String:
	return String(ELITE_RULES.get(index + 1, ""))


static func elite_name(index: int) -> String:
	var mod := elite_modifier(index)
	return "" if mod == "" else String(ELITE_TEXT[mod][0])


static func elite_line(index: int) -> String:
	var mod := elite_modifier(index)
	return "" if mod == "" else String(ELITE_TEXT[mod][1])


## Cards offered each turn.
static func hand_size_for(index: int) -> int:
	return SHORT_HAND_SIZE if elite_modifier(index) == "short" else GameData.hand_size


## Cannonballs per barrel on the board, relative to 1.0. Below 1.0 on purpose: the deck must supply
## the missing damage. Comes from SLACK_TABLE (design/balance/rebalance.py); stages past the
## table use a formula.
static func slack(index: int) -> float:
	if index < SLACK_TABLE.size():
		return float(SLACK_TABLE[index])
	return maxf(0.3, 0.55 - 0.004 * float(index - SLACK_TABLE.size()))


# Per-stage slack, from design/balance/rebalance-values.json: the rough test bot wins about 87% of stage 1,
# falling to about 43% at stage 50, then 50% to 25% across the night stages 51-100 (boss and elite stages sit
# below that). A person who uses the card preview does clearly better than this simple bot. Late stages give
# very few cannonballs on purpose: by then the unlocked cards (shapes, bombs, blasts) have to do the work.
# Slack, star limits and elite rules were measured together: change them together.
const SLACK_TABLE: Array = [0.65, 0.74, 0.49, 0.58, 0.33, 0.52, 0.48, 0.41, 0.41, 0.62, 0.41, 0.44, 0.38, 0.43, 0.46, 0.35, 0.46, 0.4, 0.46, 0.51, 0.26, 0.26, 0.29, 0.41, 0.28, 0.24, 0.26, 0.28, 0.24, 0.26, 0.12, 0.18, 0.23, 0.17, 0.1, 0.16, 0.15, 0.21, 0.17, 0.16, 0.09, 0.12, 0.13, 0.08, 0.2, 0.09, 0.14, 0.16, 0.15, 0.17, 0.01, 0.03, 0.06, 0.12, 0.01, 0.01, 0.04, 0.01, 0.01, 0.15, 0.07, 0.08, 0.09, 0.06, 0.11, 0.08, 0.03, 0.06, 0.05, 0.08, 0.01, 0.05, 0.06, 0.07, 0.05, 0.01, 0.01, 0.04, 0.05, 0.08, 0.01, 0.01, 0.01, 0.06, 0.06, 0.01, 0.01, 0.03, 0.06, 0.01, 0.02, 0.04, 0.04, 0.04, 0.04, 0.06, 0.04, 0.06, 0.05, 0.08]

# Turn limits for 3 and 2 stars, from the same file: 3 stars is the median number of turns of a bot that reads
# the card preview, 2 stars is its 80th percentile (and at least 2 turns more than 3 stars).
const STAR3_TURNS: Array = [6, 6, 6, 7, 5, 7, 6, 7, 7, 10, 8, 9, 8, 10, 11, 8, 10, 10, 12, 13, 4, 5, 6, 7, 7, 7, 6, 7, 6, 7, 5, 5, 6, 6, 6, 6, 6, 7, 6, 6, 6, 6, 6, 6, 8, 6, 7, 8, 8, 10, 3, 3, 4, 5, 5, 5, 4, 5, 5, 9, 6, 5, 5, 5, 6, 5, 5, 5, 5, 8, 6, 5, 5, 6, 6, 6, 6, 6, 6, 7, 6, 6, 6, 6, 7, 6, 7, 6, 6, 7, 5, 7, 7, 7, 7, 7, 7, 8, 8, 9]
const STAR2_TURNS: Array = [8, 8, 8, 9, 7, 9, 8, 9, 9, 12, 10, 11, 10, 12, 13, 10, 12, 12, 14, 15, 6, 7, 8, 9, 9, 9, 8, 9, 8, 9, 7, 7, 8, 8, 8, 8, 8, 9, 8, 8, 8, 8, 8, 8, 10, 8, 9, 10, 10, 12, 5, 5, 6, 7, 7, 7, 6, 7, 7, 11, 8, 7, 7, 7, 8, 7, 7, 7, 7, 10, 8, 7, 7, 8, 8, 8, 8, 8, 8, 9, 8, 8, 8, 8, 9, 8, 9, 8, 8, 9, 7, 9, 9, 9, 9, 9, 9, 10, 10, 11]


## Turn limit for 3 stars; falls back to a size-based guess if the table is short.
static func star3_turns(index: int) -> int:
	return int(STAR3_TURNS[index]) if index < STAR3_TURNS.size() else 8 + index / 2


static func star2_turns(index: int) -> int:
	return int(STAR2_TURNS[index]) if index < STAR2_TURNS.size() else 11 + index * 2 / 3


## How many special barrels of each kind a stage has. They appear gradually: bombs from stage 3,
## supply crates from stage 5, iron barrels from stage 8 and cursed skulls from stage 12. Powder Keg and
## Iron Hull stages then add far more bombs or iron.
static func specials_for(index: int) -> Dictionary:
	var cells := 0
	for r in picture(index)["rows"]:
		for ch in String(r):
			if ch != ".":
				cells += 1
	var tough := 1 if is_boss(index) else 0
	var d := {}
	if index >= 2:
		d["bomb"] = 1 + index / 14 + tough
	if index >= 4:
		d["ammo"] = 1 + index / 25
	if index >= 7:
		d["iron"] = 1 + index / 8 + tough
	if index >= 11:
		d["curse"] = 1 + index / 14 + tough
	if is_night(index):  # the night world is tougher: more iron barrels and cursed skulls
		d["iron"] = int(d.get("iron", 0)) + 2 + (index - NIGHT_START) / 12
		d["curse"] = int(d.get("curse", 0)) + 1 + (index - NIGHT_START) / 18
	# Never more than a fifth of the barrels are special: trim whichever kind has the most.
	_trim_specials(d, maxi(1, cells / 5))
	_apply_elite_rule(d, elite_modifier(index), cells)
	return d


## Takes special barrels away until at most `limit` are left, one at a time from whichever kind has the most.
## The kind in `keep` is only trimmed when nothing else is left to trim.
static func _trim_specials(d: Dictionary, limit: int, keep: String = "") -> void:
	while _special_total(d) > limit:
		var biggest := ""
		for kind in ["iron", "curse", "bomb", "ammo"]:
			if kind != keep and int(d.get(kind, 0)) > int(d.get(biggest, 0)):
				biggest = kind
		if biggest == "":
			biggest = keep
		d[biggest] = int(d[biggest]) - 1


## Powder Keg packs in bombs and Iron Hull iron barrels; those stages may be 40% special instead of 20%.
static func _apply_elite_rule(d: Dictionary, mod: String, cells: int) -> void:
	var kind := ""
	if mod == "keg":
		kind = "bomb"
		d[kind] = maxi(KEG_MIN_BOMBS, KEG_BOMB_FACTOR * int(d.get(kind, 0)))
	elif mod == "iron":
		kind = "iron"
		d[kind] = maxi(int(d.get(kind, 0)) + IRON_MIN_EXTRA, int(round(cells * IRON_SHARE)))
	else:
		return
	_trim_specials(d, cells * 2 / 5, kind)


static func _special_total(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


## Index of the next boss stage at or after index (stage 10, 20, ... 50 are index 9, 19, ... 49).
static func next_boss(index: int) -> int:
	return mini(TOTAL - 1, (index / 10) * 10 + 9)


## A random card for the daily gift: mostly rare, sometimes epic, rarely legendary.
static func roll_gift(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	var rarity := "rare" if roll < 0.70 else ("epic" if roll < 0.95 else "legendary")
	var pool: Array = []
	for id in GameData.card_order:
		if GameData.cards[id]["rarity"] == rarity:
			pool.append(id)
	return pool[rng.randi_range(0, pool.size() - 1)]


static func picture(index: int) -> Dictionary:
	return GameData.pictures[index]


static func title(index: int) -> String:
	var rule := elite_name(index)
	var tag := "  BOSS" if is_boss(index) else ("  " + rule.to_upper() if rule != "" else "")
	return "Stage %d  -  %s%s" % [index + 1, picture(index)["name"], tag]


static func new_battle(index: int, deck: Array, seed_value: int, levels: Dictionary = {}) -> Battle:
	var b := Battle.new(picture(index)["rows"], deck, slack(index), hand_size_for(index), seed_value, {}, specials_for(index))
	b.levels = levels
	if boss_rule(index) != "":
		b.boss_rule = boss_rule(index)
		b.strike_size = strike_size(index)
	b.star2_turns = star2_turns(index)
	b.star3_turns = star3_turns(index)
	return b


# New cards join the deck every 10 stages. Keys are the 0-based index of the first stage that has
# them (stage 11, 21, 31 and 41). Together with the starter deck every card in cards.json appears.
const UNLOCKS: Dictionary = {
	10: ["heavy_round", "pick_off", "rapid_fire", "tidy_up", "sniper", "cross_strike"],
	20: ["diagonal", "color_bomb", "clone", "overclock", "second_wind", "wild_row"],
	30: ["wild_column", "arsenal", "triple_draw", "echo", "blast", "wild_cross"],
	40: ["color_storm", "pierce_blast", "double_blast", "roulette", "prism", "pixel_rain"],
}


## Cards introduced at this stage (empty for most stages).
static func unlocks_at(index: int) -> Array:
	return UNLOCKS.get(index, [])


## The deck used for a stage: the starter deck plus every card unlocked up to that stage.
static func deck_for(index: int) -> Array:
	var deck: Array = GameData.starter_deck.duplicate()
	var keys: Array = UNLOCKS.keys()
	keys.sort()
	for k in keys:
		if int(k) <= index:
			deck.append_array(UNLOCKS[k])
	return deck
