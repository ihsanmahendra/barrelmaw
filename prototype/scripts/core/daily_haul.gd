class_name DailyHaul
extends RefCounted
## The daily challenge (design/gdd/daily-challenge.md): one stage a day, the same for everyone on that date,
## played with every stage card at level 1 and scored by turns. Pure rules; no UI and no saving.

const UNLOCK_STAGE: int = 10  # stage number that has to be cleared
const REWARD: int = 20  # Doubloons for the first win of a date
const STRIDE: int = 29  # step through the pool, so no picture repeats within the pool size
const FIRST_STAGE: int = 41
const LAST_STAGE: int = 99
const DECK_INDEX: int = 48  # a stage index whose deck holds every stage card (34 cards)
const HISTORY: int = 30  # dates kept in the save


## 0-based indexes of the stages a day can use: 41 to 99 without elite and boss stages.
static func pool() -> Array:
	var out: Array = []
	for n in range(FIRST_STAGE, LAST_STAGE + 1):
		if n % 5 != 0:
			out.append(n - 1)
	return out


static func days_since_1970(date: String) -> int:
	return int(floorf(float(Time.get_unix_time_from_datetime_string(date)) / 86400.0))


static func stage_index(date: String) -> int:
	var p := pool()
	return p[posmod(days_since_1970(date) * STRIDE, p.size())]


## The date as a number, e.g. 20261127.
static func seed_of(date: String) -> int:
	return int(date.replace("-", ""))


## Par is the stage's 3-star turn limit.
static func par(date: String) -> int:
	return Stages.star3_turns(stage_index(date))


## The day's battle. The player's progress, card levels, Captain's Slots and gifts have no part in it.
static func new_battle(date: String) -> Battle:
	var i := stage_index(date)
	var b := Battle.new(Stages.picture(i)["rows"], Stages.deck_for(DECK_INDEX), Stages.slack(i), Stages.hand_size_for(i),
		seed_of(date), {}, Stages.specials_for(i))
	b.star2_turns = Stages.star2_turns(i)
	b.star3_turns = Stages.star3_turns(i)
	return b


## A finished attempt: {won, turns, hits}.
static func result_of(b: Battle) -> Dictionary:
	return {"won": b.won, "turns": b.turns, "hits": b.shots_left()}


## True when result `a` beats `b`: a win first, then fewer turns, then more cannonball hits left.
static func better(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["won"]) != bool(b["won"]):
		return bool(a["won"])
	if int(a["turns"]) != int(b["turns"]):
		return int(a["turns"]) < int(b["turns"])
	return int(a["hits"]) > int(b["hits"])


## Records a finished attempt in `history` (date -> {first, best, paid}) and returns the Doubloons it pays.
## The first finished attempt of a date is the score to share; later ones only update the best.
static func record(history: Dictionary, date: String, result: Dictionary) -> int:
	if not history.has(date):
		history[date] = {"first": result.duplicate(), "best": result.duplicate(), "paid": false}
	var entry: Dictionary = history[date]
	if better(result, entry["best"]):
		entry["best"] = result.duplicate()
	var pay := 0
	if bool(result["won"]) and not bool(entry["paid"]):
		entry["paid"] = true
		pay = REWARD
	var dates: Array = history.keys()
	dates.sort()
	while dates.size() > HISTORY:
		history.erase(dates.pop_front())
	return pay


static func share_text(date: String, result: Dictionary) -> String:
	var turns := int(result["turns"])
	var score := "cleared in %d turn%s" % [turns, "" if turns == 1 else "s"] if bool(result["won"]) else "not cleared"
	return "Barrelmaw daily %s: %s (par %d)" % [date, score, par(date)]
