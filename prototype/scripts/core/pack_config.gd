class_name PackConfig
extends RefCounted
## Loads res://data/packs.json (chest tiers, odds, pity, merge costs, rewards). See
## design/gdd/card-packs.md. All values live in the JSON file.

static var _loaded: bool = false
static var data: Dictionary = {}
static var chests: Array = []  # ordered by tier, lowest first
static var _by_id: Dictionary = {}
static var _rarities: Array = []


static func ensure_loaded() -> void:
	if _loaded:
		return
	var f := FileAccess.open("res://data/packs.json", FileAccess.READ)
	if f == null:
		push_error("Cannot open res://data/packs.json")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		push_error("Bad JSON in packs.json")
		return
	data = parsed
	chests = data.get("chests", [])
	for c in chests:
		_by_id[str(c["id"])] = c
	_rarities = data.get("rarities", [])
	_loaded = true


static func chest(id: String) -> Dictionary:
	ensure_loaded()
	return _by_id.get(id, {})


## Order of rarities from lowest to highest (common ... transcended).
static func rank(rarity: String) -> int:
	ensure_loaded()
	return _rarities.find(rarity)


static func rarity_at(rank_index: int) -> String:
	ensure_loaded()
	return str(_rarities[clampi(rank_index, 0, _rarities.size() - 1)])


static func max_level() -> int:
	ensure_loaded()
	return int(data.get("max_level", 5))


## Spare copies needed to go from `level` to `level + 1`; 0 when the card is already at max level.
static func step(rarity: String, level: int) -> int:
	ensure_loaded()
	if level >= max_level():
		return 0
	var steps: Array = data.get("merge_steps", {}).get(rarity, [])
	if level < 1 or level > steps.size():
		return 0
	return int(steps[level - 1])


## Total spare copies needed to take a card from level 1 to max level.
static func total_to_max(rarity: String) -> int:
	var n := 0
	for lv in range(1, max_level()):
		n += step(rarity, lv)
	return n


static func pearls_for(rarity: String) -> int:
	ensure_loaded()
	return int(data.get("pearls", {}).get(rarity, 0))


static func pity(key: String) -> float:
	ensure_loaded()
	return float(data.get("pity", {}).get(key, 0))


static func transcended_unlock_cleared() -> int:
	ensure_loaded()
	return int(data.get("transcended_unlock_cleared", 50))
