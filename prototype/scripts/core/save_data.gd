class_name SaveData
extends RefCounted
## Saved progress: best stars per stage and whether the tutorial was done. Stored in
## user://save.cfg (browser storage on the web build).

static var path: String = "user://save.cfg"
static var _stars: Dictionary = {}  # stage index -> best stars (1-3); missing means not cleared
static var _loaded: bool = false
static var tutorial_done: bool = false
## Debug mode: every stage can be opened, so the whole map can be explored. Saved with the progress.
static var debug_unlock: bool = false
static var _specials_seen: Dictionary = {}  # kind -> true once the first-time explanation was shown
static var _gift_date: String = ""  # date (YYYY-MM-DD) the daily gift was last claimed
static var _gift_card: String = ""  # claimed gift card waiting for the next stage
static var _intros: Dictionary = {}  # stage index -> true once its New cards screen was shown
static var _packs: Dictionary = {}  # collection, chests, Doubloons, Pearls, pity (see Collection.new_state)
static var _last_shot_date: String = ""  # day the Last Shot count belongs to; only moves forward
static var _last_shot_count: int = 0  # Last Shots taken that day

const LAST_SHOT_FREE_PER_DAY: int = 1

static var _daily: Dictionary = {}  # Daily Haul: date -> {first, best, paid} (see DailyHaul.record)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	PackConfig.ensure_loaded()
	_packs = Collection.normalize({})
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		Rewards.migrate(_packs, false)  # a brand new player gets no welcome gift, the daily crate starts it
		return
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	debug_unlock = bool(cfg.get_value("progress", "debug_unlock", false))
	_gift_date = str(cfg.get_value("progress", "gift_date", ""))
	_gift_card = str(cfg.get_value("progress", "gift_card", ""))
	_last_shot_date = str(cfg.get_value("progress", "last_shot_date", ""))
	_last_shot_count = int(cfg.get_value("progress", "last_shot_count", 0))
	var haul: Variant = cfg.get_value("progress", "daily_haul", {})
	if haul is Dictionary:
		_daily = haul
	var sp: Variant = cfg.get_value("progress", "specials_seen", {})
	if sp is Dictionary:
		for k in sp:
			_specials_seen[str(k)] = true
	var seen: Variant = cfg.get_value("progress", "intros", {})
	if seen is Dictionary:
		for k in seen:
			_intros[int(k)] = true
	var saved: Variant = cfg.get_value("progress", "stars", {})
	if saved is Dictionary:
		for k in saved:
			_stars[int(k)] = clampi(int(saved[k]), 0, 3)
	var stored: Variant = cfg.get_value("packs", "state", {}) if cfg.has_section_key("packs", "state") else null
	if stored is Dictionary:
		_packs = Collection.normalize(stored)
	else:
		# Save from before card packs: existing players get the Welcome Aboard crates once.
		Rewards.migrate(_packs, tutorial_done or not _stars.is_empty())
		save()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "debug_unlock", debug_unlock)
	var out := {}
	for k in _stars:
		out[str(k)] = _stars[k]
	cfg.set_value("progress", "stars", out)
	cfg.set_value("progress", "gift_date", _gift_date)
	cfg.set_value("progress", "gift_card", _gift_card)
	cfg.set_value("progress", "last_shot_date", _last_shot_date)
	cfg.set_value("progress", "last_shot_count", _last_shot_count)
	cfg.set_value("progress", "daily_haul", _daily)
	cfg.set_value("progress", "specials_seen", _specials_seen)
	var seen_out := {}
	for k in _intros:
		seen_out[str(k)] = true
	cfg.set_value("progress", "intros", seen_out)
	cfg.set_value("packs", "state", _packs)
	cfg.save(path)


## Best stars earned on a stage (0 = never cleared).
static func stars(index: int) -> int:
	_ensure_loaded()
	return int(_stars.get(index, 0))


## Records a cleared stage; keeps the best rating. Returns the best rating before this win (0 = first clear).
static func record(index: int, stars_earned: int) -> int:
	_ensure_loaded()
	var before := stars(index)
	_stars[index] = maxi(before, clampi(stars_earned, 1, 3))
	save()
	return before


## The card pack state (a Dictionary shared with Collection, Packs and Rewards). Call save() after changing it.
static func pack_state() -> Dictionary:
	_ensure_loaded()
	return _packs


## Best stars of every stage as an array indexed by stage (0 = not cleared).
static func best_stars() -> Array:
	_ensure_loaded()
	var out: Array = []
	for i in Stages.TOTAL:
		out.append(stars(i))
	return out


## True once the New cards screen for this stage has been shown.
static func intro_seen(index: int) -> bool:
	_ensure_loaded()
	return _intros.has(index)


static func mark_intro_seen(index: int) -> void:
	_ensure_loaded()
	_intros[index] = true
	save()


## Today's date in the player's local time, e.g. "2026-11-19".
static func today() -> String:
	return Time.get_date_string_from_system()


## True when the daily gift has not been claimed yet today.
static func daily_available() -> bool:
	_ensure_loaded()
	return _gift_date != today()


## Records today's gift: the card joins the deck of the next stage that is played.
static func claim_daily(card_id: String) -> void:
	_ensure_loaded()
	_gift_date = today()
	_gift_card = card_id
	save()


## The claimed gift card still waiting to be used, or "".
static func pending_gift() -> String:
	_ensure_loaded()
	return _gift_card


## Returns the waiting gift card (and clears it); "" if there is none.
static func take_pending_gift() -> String:
	_ensure_loaded()
	var c := _gift_card
	if c != "":
		_gift_card = ""
		save()
	return c


## Free Last Shots still available on `date` (today by default). Unused days do not stack.
static func last_shot_left(date: String = "") -> int:
	_ensure_loaded()
	var day := today() if date == "" else date
	return LAST_SHOT_FREE_PER_DAY - (_last_shot_count if day <= _last_shot_date else 0)


## Spends one Last Shot. Returns false when none is left.
static func use_last_shot(date: String = "") -> bool:
	_ensure_loaded()
	var day := today() if date == "" else date
	if last_shot_left(day) <= 0:
		return false
	if day > _last_shot_date:
		_last_shot_date = day
		_last_shot_count = 0
	_last_shot_count += 1
	save()
	return true


## True once the Daily Haul is open to the player.
static func daily_haul_open() -> bool:
	return stars(DailyHaul.UNLOCK_STAGE - 1) > 0


## Today's Daily Haul record ({first, best, paid}), or {} before the first finished attempt.
static func daily_entry(date: String) -> Dictionary:
	_ensure_loaded()
	return _daily.get(date, {})


## Records a finished Daily Haul attempt, pays its Doubloons and returns how many it paid.
static func daily_finish(date: String, result: Dictionary) -> int:
	_ensure_loaded()
	var pay := DailyHaul.record(_daily, date, result)
	_packs["doubloons"] = int(_packs["doubloons"]) + pay
	save()
	return pay


static func special_seen(kind: String) -> bool:
	_ensure_loaded()
	return _specials_seen.has(kind)


static func mark_special_seen(kind: String) -> void:
	_ensure_loaded()
	_specials_seen[kind] = true
	save()


static func set_debug_unlock(on: bool) -> void:
	_ensure_loaded()
	debug_unlock = on
	save()


static func mark_tutorial_done() -> void:
	_ensure_loaded()
	tutorial_done = true
	save()


## Index of the furthest stage the player may play: the first not yet cleared.
static func highest_unlocked() -> int:
	_ensure_loaded()
	var i := 0
	while i < Stages.TOTAL - 1 and stars(i) > 0:
		i += 1
	return i


static func is_unlocked(index: int) -> bool:
	return debug_unlock or index <= highest_unlocked()


static func total_stars() -> int:
	_ensure_loaded()
	var n := 0
	for k in _stars:
		n += int(_stars[k])
	return n


static func cleared_count() -> int:
	_ensure_loaded()
	var n := 0
	for k in _stars:
		if int(_stars[k]) > 0:
			n += 1
	return n


## Drops everything held in memory and loads the file again (used by the tests to check what was saved).
static func reload_from_disk() -> void:
	_stars.clear()
	_intros.clear()
	_specials_seen.clear()
	_gift_date = ""
	_gift_card = ""
	_last_shot_date = ""
	_last_shot_count = 0
	_daily = {}
	tutorial_done = false
	debug_unlock = false
	_packs = {}
	_loaded = false
	_ensure_loaded()


## Forgets all progress (used by the tests and a future "reset" option).
static func reset() -> void:
	_stars.clear()
	_intros.clear()
	_specials_seen.clear()
	_gift_date = ""
	_gift_card = ""
	_last_shot_date = ""
	_last_shot_count = 0
	_daily = {}
	tutorial_done = false
	debug_unlock = false
	_loaded = true
	PackConfig.ensure_loaded()
	_packs = Collection.normalize({})
	Rewards.migrate(_packs, false)
	save()
