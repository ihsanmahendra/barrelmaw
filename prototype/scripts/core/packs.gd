class_name Packs
extends RefCounted
## Chests: inventory, buying, rolling cards with pity, and the saved reveal. Pure functions on a
## state Dictionary (see Collection) so they can be tested; `open_saved` is the glue the UI uses.
## Rules: design/gdd/card-packs.md, sections 3.2, 3.3, 4.1 and 4.2.

static func count(st: Dictionary, chest_id: String) -> int:
	return int(st["chests"].get(chest_id, 0))


static func grant(st: Dictionary, chest_id: String, n: int = 1) -> void:
	st["chests"][chest_id] = count(st, chest_id) + n


## True when the player has cleared enough stages for this chest to be usable.
static func is_unlocked(chest_id: String, progress: int) -> bool:
	var c := PackConfig.chest(chest_id)
	return not c.is_empty() and progress >= int(c["unlock_cleared"])


## Buys a chest with Doubloons. Returns false when locked or too expensive.
static func buy(st: Dictionary, chest_id: String, progress: int) -> bool:
	if not is_unlocked(chest_id, progress):
		return false
	var price := int(PackConfig.chest(chest_id)["price"])
	if int(st["doubloons"]) < price:
		return false
	st["doubloons"] = int(st["doubloons"]) - price
	grant(st, chest_id)
	return true


## Picks a rarity from a table of percents ({rarity: weight}).
static func _roll_rarity(odds: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for r in odds:
		total += float(odds[r])
	var x := rng.randf() * total
	var acc := 0.0
	var last := ""
	for r in odds:
		if float(odds[r]) <= 0.0:
			continue
		acc += float(odds[r])
		last = str(r)
		if x < acc:
			return str(r)
	return last


## Steps down to the nearest lower rarity that has an unlocked card (never an empty slot).
static func _resolve(rarity: String, pools: Dictionary) -> String:
	var i := PackConfig.rank(rarity)
	while i > 0 and (pools[PackConfig.rarity_at(i)] as Array).is_empty():
		i -= 1
	return PackConfig.rarity_at(i)


static func _pick(rarity: String, pools: Dictionary, st: Dictionary, rng: RandomNumberGenerator) -> String:
	var pool: Array = pools[rarity]
	if rarity == "transcended":
		# Duplicate protection: usually favor a Transcended card the player does not own yet.
		var unowned: Array = []
		for id in pool:
			if not st["owned"].has(id):
				unowned.append(id)
		if not unowned.is_empty() and rng.randf() < PackConfig.pity("duplicate_protection"):
			return str(unowned[rng.randi_range(0, unowned.size() - 1)])
	return str(pool[rng.randi_range(0, pool.size() - 1)])


## The scripted first Driftwood Crate: two copies of the most common starter card (merge-ready at once)
## plus one more starter card.
static func first_crate_cards(starter: Array) -> Array:
	var counts := {}
	var best := ""
	for id in starter:
		counts[id] = int(counts.get(id, 0)) + 1
		if best == "" or int(counts[id]) > int(counts[best]):
			best = str(id)
	var out: Array = [best, best]
	for id in starter:
		if str(id) != best:
			out.append(str(id))
			break
	return out


## Rolls a chest: updates pity, adds the cards to the collection and returns the cards in the order
## they should be revealed (lowest rarity first): [{id, rarity, new, pearls}].
static func roll_chest(chest: Dictionary, st: Dictionary, progress: int, catalog: Dictionary, rng: RandomNumberGenerator, pools_cache: Dictionary = {}) -> Array:
	var pools: Dictionary = pools_cache if not pools_cache.is_empty() else Collection.pools(progress, catalog, st)
	var flags: Array = chest["pity"]
	var epic_pity := flags.has("epic")
	var legend_pity := flags.has("legendary")
	var pity: Dictionary = st["pity"]
	var epic_rank := PackConfig.rank("epic")
	var legend_rank := PackConfig.rank("legendary")
	var rarities: Array = []
	for s in chest["slots"]:
		for i in int(s["count"]):
			var r := _roll_rarity(s["odds"], rng)
			if epic_pity:
				pity["since_epic"] = int(pity["since_epic"]) + 1
			if legend_pity:
				pity["since_legendary"] = int(pity["since_legendary"]) + 1
			if legend_pity and int(pity["since_legendary"]) >= int(PackConfig.pity("legendary")) \
					and PackConfig.rank(r) < legend_rank and not (pools["legendary"] as Array).is_empty():
				r = "legendary"
			elif epic_pity and int(pity["since_epic"]) >= int(PackConfig.pity("epic")) \
					and PackConfig.rank(r) < epic_rank and not (pools["epic"] as Array).is_empty():
				r = "epic"
			r = _resolve(r, pools)
			if PackConfig.rank(r) >= epic_rank:
				pity["since_epic"] = 0
			if PackConfig.rank(r) >= legend_rank:
				pity["since_legendary"] = 0
			rarities.append(r)
	# Transcended pity: a Vault that has gone too long without one makes its last card Transcended.
	if flags.has("transcended") and not (pools["transcended"] as Array).is_empty():
		if rarities.has("transcended"):
			pity["vault_dry"] = 0
		else:
			pity["vault_dry"] = int(pity["vault_dry"]) + 1
			if int(pity["vault_dry"]) >= int(PackConfig.pity("vault_dry")):
				rarities[rarities.size() - 1] = "transcended"
				pity["vault_dry"] = 0
	rarities.sort_custom(func(a: String, b: String) -> bool: return PackConfig.rank(a) < PackConfig.rank(b))
	var out: Array = []
	for r in rarities:
		var id := _pick(str(r), pools, st, rng)
		out.append(Collection.add_copy(st, id, catalog))
	return out


## Opens one chest from the inventory. The result is committed to the state (cards added, pity moved,
## reveal queued) before anything is shown, so it cannot be rerolled by quitting.
## Returns {ok, reason, chest, cards}.
static func open_chest(st: Dictionary, chest_id: String, progress: int, catalog: Dictionary, rng: RandomNumberGenerator, starter: Array) -> Dictionary:
	var chest := PackConfig.chest(chest_id)
	if chest.is_empty():
		return {"ok": false, "reason": "unknown chest"}
	if not is_unlocked(chest_id, progress):
		return {"ok": false, "reason": "locked"}
	if count(st, chest_id) <= 0:
		return {"ok": false, "reason": "none left"}
	st["chests"][chest_id] = count(st, chest_id) - 1
	var cards: Array = []
	if chest_id == "crate" and not bool(st["first_crate_done"]):
		st["first_crate_done"] = true
		for id in first_crate_cards(starter):
			if catalog.has(id):
				cards.append(Collection.add_copy(st, str(id), catalog))
	if cards.is_empty():
		cards = roll_chest(chest, st, progress, catalog, rng)
	st["pending"].append({"chest": chest_id, "cards": cards})
	return {"ok": true, "reason": "", "chest": chest_id, "cards": cards}


## Oldest reveal the player has not seen yet, removed from the queue; {} when there is none.
static func take_pending(st: Dictionary) -> Dictionary:
	var q: Array = st["pending"]
	if q.is_empty():
		return {}
	return q.pop_front()


## What the UI calls: opens a chest from the saved state and writes the save at once.
static func open_saved(chest_id: String) -> Dictionary:
	GameData.ensure_loaded()
	var st := SaveData.pack_state()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var res := open_chest(st, chest_id, SaveData.highest_unlocked(), GameData.cards, rng, GameData.starter_deck)
	if bool(res["ok"]):
		SaveData.save()
	return res
