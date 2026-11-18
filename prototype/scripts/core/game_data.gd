class_name GameData
extends RefCounted
## Loads card and picture data from res://data. All balance values live in those JSON files.

static var _loaded: bool = false
static var cards: Dictionary = {}
static var card_order: Array = []
static var pictures: Array = []
static var palette: Dictionary = {}
static var hand_size: int = 3
static var rarity_weights: Dictionary = {}
static var starter_deck: Array = []


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Bad JSON in " + path)
	return {}


## Loads the JSON files once. Safe to call repeatedly.
static func ensure_loaded() -> void:
	if _loaded:
		return
	var c := _read("res://data/cards.json")
	hand_size = int(c.get("hand_size", 3))
	rarity_weights = c.get("rarity_weights", {})
	starter_deck = c.get("starter_deck", [])
	for card in c.get("cards", []):
		cards[card["id"]] = card
		card_order.append(card["id"])
	var p := _read("res://data/pictures.json")
	palette = p.get("palette", {})
	pictures = p.get("pictures", [])
	_loaded = true


## Returns a Color for a palette letter such as "R".
static func color_of(letter: String) -> Color:
	return Color.html("#" + String(palette.get(letter, "ffffff")))


## Deterministic Fisher-Yates shuffle using the given generator.
static func shuffle_with(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
