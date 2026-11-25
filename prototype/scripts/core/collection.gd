class_name Collection
extends RefCounted
## Card copies, levels, merging and Pearls. Every function works on a plain Dictionary "state"
## (the one SaveData keeps under packs), so tests can use a throwaway state.
##
## Rules (design/gdd/card-packs.md, 3.4):
##  - A card unlocked by stage progress is owned at level 1. Transcended cards are owned once pulled.
##  - Each extra copy is a "spare". Spares are spent on the card's own next level (the card itself
##    is never consumed). At max level every extra copy becomes Pearls.

static func new_state() -> Dictionary:
	return {
		"version": 1,
		"spare": {},      # card id -> spare copies
		"level": {},      # card id -> level (missing = 1)
		"owned": {},      # card id -> true for cards owned through chests only (Transcended)
		"equipped": [],   # Transcended card ids placed in the Captain's Slots
		"chests": {},     # chest id -> count in the inventory
		"doubloons": 0,
		"pearls": 0,
		"pity": {"since_epic": 0, "since_legendary": 0, "vault_dry": 0},
		"pending": [],    # chest reveals not acknowledged yet: [{chest, cards: [...]}]
		"first_crate_done": false,
		"welcome_given": false,
		"daily": {"accrued_to": "", "stack": 0, "claimed": 0},
		"replays": {"date": "", "n": 0},
		"market": {"week": -1, "buys": {}},
		"claimed": {},    # reward keys already paid, e.g. "first_9"
	}


## Fills any key that is missing (older saves) and returns the same dictionary.
static func normalize(st: Dictionary) -> Dictionary:
	var defaults := new_state()
	for k in defaults:
		if not st.has(k):
			st[k] = defaults[k]
		elif defaults[k] is Dictionary and st[k] is Dictionary:
			for sub in defaults[k]:
				if not (st[k] as Dictionary).has(sub):
					st[k][sub] = defaults[k][sub]
		elif defaults[k] is Dictionary and not st[k] is Dictionary:
			st[k] = defaults[k]
		elif defaults[k] is Array and not st[k] is Array:
			st[k] = defaults[k]
	return st


static func level_of(st: Dictionary, id: String) -> int:
	return clampi(int(st["level"].get(id, 1)), 1, PackConfig.max_level())


static func spare_of(st: Dictionary, id: String) -> int:
	return int(st["spare"].get(id, 0))


static func rarity_of(catalog: Dictionary, id: String) -> String:
	return str(catalog[id]["rarity"])


## Spare copies the card needs for its next level (0 at max level).
static func need(st: Dictionary, id: String, catalog: Dictionary) -> int:
	return PackConfig.step(rarity_of(catalog, id), level_of(st, id))


static func is_ready(st: Dictionary, id: String, catalog: Dictionary) -> bool:
	var n := need(st, id, catalog)
	return n > 0 and spare_of(st, id) >= n


## Ids of cards the player can use: the starter deck plus stage unlocks for `progress` cleared stages,
## Transcended cards once the player has cleared enough stages, and anything owned through chests.
static func unlocked_ids(progress: int, catalog: Dictionary, st: Dictionary) -> Array:
	var seen := {}
	var out: Array = []
	for id in Stages.deck_for(progress):
		var sid := str(id)
		if catalog.has(sid) and not seen.has(sid):
			seen[sid] = true
			out.append(sid)
	if progress >= PackConfig.transcended_unlock_cleared():
		for id in catalog:
			if str(catalog[id]["rarity"]) == "transcended" and not seen.has(str(id)):
				seen[str(id)] = true
				out.append(str(id))
	for id in st["owned"]:
		if catalog.has(str(id)) and not seen.has(str(id)):
			seen[str(id)] = true
			out.append(str(id))
	return out


## Unlocked cards grouped by rarity: {rarity: [ids]} with every rarity present.
static func pools(progress: int, catalog: Dictionary, st: Dictionary) -> Dictionary:
	var out := {}
	for r in PackConfig.data.get("rarities", []):
		out[str(r)] = []
	for id in unlocked_ids(progress, catalog, st):
		var r := rarity_of(catalog, id)
		if out.has(r):
			out[r].append(id)
	return out


## Adds one copy of a card. Returns {id, rarity, new, pearls}: `new` is true when a Transcended card is
## owned for the first time; `pearls` is what the copy was worth if the card is already at max level.
static func add_copy(st: Dictionary, id: String, catalog: Dictionary) -> Dictionary:
	var rarity := rarity_of(catalog, id)
	var res := {"id": id, "rarity": rarity, "new": false, "pearls": 0}
	if rarity == "transcended" and not st["owned"].has(id):
		st["owned"][id] = true
		st["level"][id] = 1
		res["new"] = true
		return res
	if level_of(st, id) >= PackConfig.max_level():
		var p := PackConfig.pearls_for(rarity)
		st["pearls"] = int(st["pearls"]) + p
		res["pearls"] = p
	else:
		st["spare"][id] = spare_of(st, id) + 1
	return res


## Spends the card's spare copies on its next level. Returns false when it is not ready.
static func merge(st: Dictionary, id: String, catalog: Dictionary) -> bool:
	if not is_ready(st, id, catalog):
		return false
	var n := need(st, id, catalog)
	st["spare"][id] = spare_of(st, id) - n
	st["level"][id] = level_of(st, id) + 1
	if level_of(st, id) >= PackConfig.max_level():
		# Copies left over at max level are worth Pearls instead of being lost.
		var rarity := rarity_of(catalog, id)
		st["pearls"] = int(st["pearls"]) + spare_of(st, id) * PackConfig.pearls_for(rarity)
		st["spare"][id] = 0
	return true


## Merges every ready card (repeatedly, so one card can go up several levels). Returns the level-ups done.
static func merge_all(st: Dictionary, catalog: Dictionary) -> int:
	var done := 0
	var again := true
	while again:
		again = false
		for id in catalog:
			if merge(st, str(id), catalog):
				done += 1
				again = true
	return done


## How many cards are ready to merge (drives the red dot on the Cargo Hold button).
static func ready_count(st: Dictionary, catalog: Dictionary) -> int:
	var n := 0
	for id in catalog:
		if is_ready(st, str(id), catalog):
			n += 1
	return n


## Level table for the battle: {card id: level} for every card above level 1.
static func levels_for_battle(st: Dictionary) -> Dictionary:
	var out := {}
	for id in st["level"]:
		var lv := level_of(st, str(id))
		if lv > 1:
			out[str(id)] = lv
	return out


# ---------- Captain's Slots (Transcended cards in the deck) ----------

## Slots for Transcended cards: 1 once stage 50 is cleared, 2 once stage 100 is cleared.
static func captain_slots(progress: int) -> int:
	if progress >= Stages.TOTAL:
		return 2
	if progress >= PackConfig.transcended_unlock_cleared():
		return 1
	return 0


## Transcended cards that join every deck: the equipped ones the player still owns, up to the slot count.
static func equipped_cards(st: Dictionary, progress: int, catalog: Dictionary) -> Array:
	var out: Array = []
	for id in st["equipped"]:
		if out.size() >= captain_slots(progress):
			break
		if catalog.has(str(id)) and st["owned"].has(str(id)) and not out.has(str(id)):
			out.append(str(id))
	return out


## Puts an owned Transcended card in a free slot. Returns false when it is not owned, already equipped
## or every slot is taken.
static func equip(st: Dictionary, id: String, progress: int, catalog: Dictionary) -> bool:
	if not catalog.has(id) or rarity_of(catalog, id) != "transcended" or not st["owned"].has(id):
		return false
	var now := equipped_cards(st, progress, catalog)
	if now.has(id) or now.size() >= captain_slots(progress):
		return false
	now.append(id)
	st["equipped"] = now
	return true


static func unequip(st: Dictionary, id: String) -> void:
	(st["equipped"] as Array).erase(id)


## The deck for a stage: the stage deck without any Transcended card, plus the equipped ones.
static func deck_with_equipped(deck: Array, st: Dictionary, progress: int, catalog: Dictionary) -> Array:
	var out: Array = []
	for id in deck:
		if not (catalog.has(str(id)) and rarity_of(catalog, str(id)) == "transcended"):
			out.append(id)
	out.append_array(equipped_cards(st, progress, catalog))
	return out
