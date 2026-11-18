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


## Cannonballs per barrel on the board, relative to 1.0. Below 1.0 on purpose: the deck must supply
## the missing damage. Comes from SLACK_TABLE (tests/tune_slack.gd); stages past the table use a
## formula.
static func slack(index: int) -> float:
	if index < SLACK_TABLE.size():
		return float(SLACK_TABLE[index])
	return maxf(0.3, 0.55 - 0.004 * float(index - SLACK_TABLE.size()))


# Per-stage slack tuned so the test bot wins about 90% of stage 1, falling to about 40-50% at stage 50 and about
# 25-45% across the night stages 51-100 (night slack is tiny on purpose: the cards do most of the work).
# A person who uses the card preview does clearly better than this simple bot. Late stages give very few
# cannonballs on purpose: by then the unlocked cards (shapes, bombs, blasts) have to do the work.
const SLACK_TABLE: Array = [0.67, 0.75, 0.6, 0.67, 0.5, 0.55, 0.5, 0.43, 0.45, 0.62, 0.5, 0.5, 0.53, 0.5, 0.45, 0.5, 0.59, 0.49, 0.63, 0.5, 0.39, 0.29, 0.42, 0.5, 0.33, 0.29, 0.3, 0.32, 0.33, 0.33, 0.15, 0.18, 0.23, 0.17, 0.23, 0.18, 0.15, 0.25, 0.17, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.02, 0.05, 0.05, 0.15, 0.02, 0.02, 0.04, 0.02, 0.02, 0.12, 0.06, 0.05, 0.08, 0.05, 0.02, 0.04, 0.07, 0.02, 0.04, 0.06, 0.02, 0.03, 0.07, 0.09, 0.04, 0.02, 0.02, 0.02, 0.07, 0.05, 0.02, 0.02, 0.02, 0.06, 0.02, 0.02, 0.02, 0.03, 0.05, 0.03, 0.04, 0.02, 0.03, 0.05, 0.04, 0.03, 0.05, 0.04, 0.05, 0.06]

# Turn limits for 3 and 2 stars, from tests/star_stats.gd: the test bot needs about this many turns
# (3 stars is slightly above its median, 2 stars covers nearly all of its wins).
const STAR3_TURNS: Array = [8, 9, 8, 10, 9, 10, 10, 10, 9, 12, 11, 13, 12, 14, 13, 12, 14, 15, 16, 15, 7, 7, 9, 10, 9, 9, 9, 10, 9, 9, 7, 7, 8, 8, 8, 8, 9, 9, 9, 8, 8, 8, 8, 8, 9, 8, 9, 10, 10, 12, 5, 5, 5, 6, 6, 6, 6, 6, 6, 10, 7, 7, 7, 6, 7, 7, 7, 7, 7, 9, 7, 7, 6, 8, 7, 8, 8, 8, 8, 9, 8, 8, 8, 8, 8, 8, 8, 8, 8, 9, 8, 8, 8, 8, 8, 9, 9, 10, 10, 10]
const STAR2_TURNS: Array = [11, 10, 11, 12, 11, 13, 12, 13, 13, 15, 14, 16, 15, 17, 16, 15, 18, 18, 20, 20, 10, 9, 12, 12, 11, 12, 11, 12, 12, 11, 9, 10, 11, 10, 11, 11, 11, 11, 11, 10, 10, 10, 10, 11, 11, 11, 11, 13, 13, 14, 7, 7, 7, 8, 8, 8, 8, 9, 9, 12, 10, 9, 9, 8, 9, 9, 9, 9, 9, 11, 10, 9, 9, 10, 9, 10, 10, 10, 10, 11, 10, 10, 9, 10, 10, 10, 11, 10, 10, 11, 10, 10, 11, 11, 10, 11, 11, 12, 13, 12]


## Turn limit for 3 stars; falls back to a size-based guess if the table is short.
static func star3_turns(index: int) -> int:
	return int(STAR3_TURNS[index]) if index < STAR3_TURNS.size() else 8 + index / 2


static func star2_turns(index: int) -> int:
	return int(STAR2_TURNS[index]) if index < STAR2_TURNS.size() else 11 + index * 2 / 3


## How many special barrels of each kind a stage has. They appear gradually: bombs from stage 3,
## supply crates from stage 5, iron barrels from stage 8 and cursed skulls from stage 12.
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
	var limit := maxi(1, cells / 5)
	while _special_total(d) > limit:
		var biggest := ""
		for kind in ["iron", "curse", "bomb", "ammo"]:
			if int(d.get(kind, 0)) > int(d.get(biggest, 0)):
				biggest = kind
		d[biggest] = int(d[biggest]) - 1
	return d


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
	var tag := "  BOSS" if is_boss(index) else ("  ELITE" if is_elite(index) else "")
	return "Stage %d  -  %s%s" % [index + 1, picture(index)["name"], tag]


static func new_battle(index: int, deck: Array, seed_value: int) -> Battle:
	var b := Battle.new(picture(index)["rows"], deck, slack(index), GameData.hand_size, seed_value, {}, specials_for(index))
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
