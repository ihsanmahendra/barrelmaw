class_name Rewards
extends RefCounted
## Where chests, Doubloons and Pearls come from: the daily crate, stage rewards, the Port Market and the
## one-time migration gift. Pure functions on a Collection state Dictionary.
## Rules: design/gdd/card-packs.md, sections 3.7, 3.9, 4.4 and 4.5.

## Days between two "YYYY-MM-DD" dates (negative when `to_date` is earlier).
static func days_between(from_date: String, to_date: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(from_date)
	var b := Time.get_unix_time_from_datetime_string(to_date)
	return int(roundf(float(b - a) / 86400.0))


# ---------- daily crate ----------

## Adds the crates earned since the last visit (skipped days stack up to the cap). The saved date only
## ever moves forward, so setting the device clock back cannot claim twice.
static func daily_accrue(st: Dictionary, today: String) -> void:
	var d: Dictionary = st["daily"]
	var cap := int(PackConfig.data["daily"]["stack_cap"])
	if str(d["accrued_to"]) == "":
		d["stack"] = mini(int(d["stack"]) + 1, cap)
		d["accrued_to"] = today
		return
	var days := days_between(str(d["accrued_to"]), today)
	if days > 0:
		d["stack"] = mini(int(d["stack"]) + days, cap)
		d["accrued_to"] = today


static func daily_available(st: Dictionary, today: String) -> bool:
	daily_accrue(st, today)
	return int(st["daily"]["stack"]) > 0


## Claims one stacked daily crate. Every 7th claim is an Ironbound Chest. Returns the chest id, or "".
static func daily_claim(st: Dictionary, today: String) -> String:
	if not daily_available(st, today):
		return ""
	var d: Dictionary = st["daily"]
	var cfg: Dictionary = PackConfig.data["daily"]
	d["stack"] = int(d["stack"]) - 1
	d["claimed"] = int(d["claimed"]) + 1
	var chest := str(cfg["streak_chest"]) if int(d["claimed"]) % int(cfg["streak_days"]) == 0 else str(cfg["chest"])
	Packs.grant(st, chest)
	return chest


# ---------- stage rewards ----------

static func _grant_list(st: Dictionary, out: Dictionary, chest_id: String, n: int) -> void:
	Packs.grant(st, chest_id, n)
	out[chest_id] = int(out.get(chest_id, 0)) + n


## Pays out a won stage. `old_stars` is the best rating before this win (0 = first clear), `new_stars` the
## rating of this win and `best_stars` the best ratings of all stages after recording it (index = stage).
## Returns {doubloons, chests: {chest id: count}} for the results screen.
static func stage_clear(st: Dictionary, index: int, old_stars: int, new_stars: int, best_stars: Array, today: String) -> Dictionary:
	var cfg: Dictionary = PackConfig.data["doubloons"]
	var out := {"doubloons": 0, "chests": {}}
	var stage_no := index + 1
	if old_stars <= 0:
		out["doubloons"] = int(cfg["first_clear"]) + int(cfg["per_star"]) * new_stars
		var key := "first_%d" % index
		if not st["claimed"].has(key):
			st["claimed"][key] = true
			if Stages.is_boss(index):
				for pair in PackConfig.data["boss_rewards"].get(str(stage_no), []):
					_grant_list(st, out["chests"], str(pair[0]), int(pair[1]))
			elif Stages.is_elite(index):
				var el: Dictionary = PackConfig.data["elite_reward"]
				_grant_list(st, out["chests"], str(el["chest"]), int(el["count"]))
	elif new_stars > old_stars:
		out["doubloons"] = int(cfg["per_star"]) * (new_stars - old_stars)
	else:
		var r: Dictionary = st["replays"]
		if str(r["date"]) != today:
			r["date"] = today
			r["n"] = 0
		if int(r["n"]) < int(cfg["replays_per_day"]):
			r["n"] = int(r["n"]) + 1
			out["doubloons"] = int(cfg["replay"])
	st["doubloons"] = int(st["doubloons"]) + int(out["doubloons"])
	_night_milestones(st, out, best_stars)
	return out


## Night-world milestone: an Abyssal Vault when all ten stages ending at 55, 65, ... 95 have 3 stars.
static func _night_milestones(st: Dictionary, out: Dictionary, best_stars: Array) -> void:
	var m: Dictionary = PackConfig.data["night_milestones"]
	var block := int(m["block"])
	for s in m["stages"]:
		var key := "night_%d" % int(s)
		if st["claimed"].has(key):
			continue
		var all3 := true
		for i in range(int(s) - block, int(s)):
			if i < 0 or i >= best_stars.size() or int(best_stars[i]) < 3:
				all3 = false
				break
		if all3:
			st["claimed"][key] = true
			_grant_list(st, out["chests"], str(m["chest"]), 1)


# ---------- Port Market ----------

static func market_price(rarity: String) -> int:
	return int(PackConfig.data["market"]["price_multiplier"]) * PackConfig.pearls_for(rarity)


static func week_of(date_str: String) -> int:
	return int(floorf(float(Time.get_unix_time_from_datetime_string(date_str)) / 604800.0))


static func market_limit(rarity: String) -> int:
	var m: Dictionary = PackConfig.data["market"]
	return int(m["weekly_limit_transcended"]) if rarity == "transcended" else int(m["weekly_limit"])


## Buys one copy of a card with Pearls. Returns false when the card is not available to the player,
## the player has too few Pearls, or the weekly limit is used up.
static func market_buy(st: Dictionary, id: String, progress: int, catalog: Dictionary, today: String) -> bool:
	if not Collection.unlocked_ids(progress, catalog, st).has(id):
		return false
	var rarity := Collection.rarity_of(catalog, id)
	var mk: Dictionary = st["market"]
	var wk := week_of(today)
	if int(mk["week"]) != wk:
		mk["week"] = wk
		mk["buys"] = {}
	var bought := 0
	var is_top := rarity == "transcended"  # Transcended copies have their own weekly limit
	for k in mk["buys"]:
		if catalog.has(str(k)) and (str(catalog[str(k)]["rarity"]) == "transcended") == is_top:
			bought += int(mk["buys"][k])
	if bought >= market_limit(rarity):
		return false
	var price := market_price(rarity)
	if int(st["pearls"]) < price:
		return false
	st["pearls"] = int(st["pearls"]) - price
	mk["buys"][id] = int(mk["buys"].get(id, 0)) + 1
	Collection.add_copy(st, id, catalog)
	return true


# ---------- migration ----------

## Run after loading a save. Existing players (any progress) get the Welcome Aboard crates once.
static func migrate(st: Dictionary, has_progress: bool) -> void:
	if has_progress and not bool(st["welcome_given"]):
		var w: Dictionary = PackConfig.data["welcome"]
		Packs.grant(st, str(w["chest"]), int(w["count"]))
	st["welcome_given"] = true
