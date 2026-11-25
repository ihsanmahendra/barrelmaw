class_name PackTests
extends RefCounted
## Checks for card packs, merge, levels, rewards and the save. Called from run_tests.gd.
## Spec: design/gdd/card-packs.md, section 8 (acceptance criteria 1 to 5 and 8 to 9).

var failures: int = 0
const TEST_SAVE: String = "user://test_packs_save.cfg"


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func run() -> void:
	PackConfig.ensure_loaded()
	test_pack_data()
	test_odds()
	test_pity()
	test_no_impossible_pulls()
	test_merge_math()
	test_first_crate_and_open_rules()
	test_daily()
	test_stage_rewards()
	test_market()
	test_duplicate_protection()
	test_save_and_migration()


## Real cards plus four stand-in Transcended cards (the real ones arrive in a later phase).
func _catalog() -> Dictionary:
	var c := GameData.cards.duplicate()
	for i in 4:
		c["t%d" % i] = {"id": "t%d" % i, "name": "T%d" % i, "rarity": "transcended"}
	return c


## Deep equality that ignores key order.
func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_pack_data() -> void:
	var prev_unlock := -1
	for c in PackConfig.chests:
		check(int(c["unlock_cleared"]) >= prev_unlock, "chests are ordered by unlock stage: " + str(c["id"]))
		prev_unlock = int(c["unlock_cleared"])
		var cards := 0
		for s in c["slots"]:
			var total := 0
			for r in s["odds"]:
				total += int(s["odds"][r])
				check(PackConfig.rank(str(r)) >= 0, "known rarity in odds: " + str(r))
			check(total == 100, "odds sum to 100 for %s, got %d" % [c["id"], total])
			cards += int(s["count"])
		check(cards == int(c["cards"]), "slot counts add up to cards for " + str(c["id"]))
	for r in PackConfig.data["rarities"]:
		check(PackConfig.data["merge_steps"][r].size() == PackConfig.max_level() - 1, "a merge step per level for " + str(r))
		check(PackConfig.pearls_for(str(r)) > 0, "pearl value for " + str(r))
	check(PackConfig.total_to_max("common") == 18 and PackConfig.total_to_max("transcended") == 12, "spare copies to max level match the design")
	check(PackConfig.step("rare", PackConfig.max_level()) == 0, "no step beyond max level")


## 8.1: observed rarity rates are within 1 point of the tables (pity off).
func test_odds() -> void:
	var catalog := _catalog()
	var st := Collection.new_state()
	var pools := Collection.pools(100, catalog, st)
	for chest_src in PackConfig.chests:
		var chest: Dictionary = chest_src.duplicate(true)
		chest["pity"] = []
		var rng := _rng(11)
		var n := 12000
		var seen := {}
		for i in n:
			for c in Packs.roll_chest(chest, st, 100, catalog, rng, pools):
				seen[c["rarity"]] = int(seen.get(c["rarity"], 0)) + 1
		var total := float(n * int(chest["cards"]))
		for r in PackConfig.data["rarities"]:
			var expected := 0.0
			for s in chest["slots"]:
				expected += float(s["odds"].get(r, 0)) * float(s["count"]) / 100.0
			expected /= float(chest["cards"])
			var got := float(seen.get(r, 0)) / total
			check(absf(got - expected) <= 0.01, "%s %s rate %.3f vs table %.3f" % [chest["id"], r, got, expected])


## 8.2: with pity on, the counters never run past their limits and the guarantees hold.
func test_pity() -> void:
	var catalog := _catalog()
	# The limits promised by the design (acceptance criterion 8.2). The data file may be stricter, never looser.
	var epic_limit := 30
	var leg_limit := 60
	var vault_limit := 6
	check(int(PackConfig.pity("epic")) <= epic_limit and int(PackConfig.pity("legendary")) <= leg_limit and int(PackConfig.pity("vault_dry")) <= vault_limit, "pity thresholds in packs.json are within the design limits")
	for id in ["iron", "coffer", "gilded", "vault"]:
		var chest := PackConfig.chest(id)
		var st := Collection.new_state()
		var pools := Collection.pools(100, catalog, st)
		var rng := _rng(5)
		var worst_epic := 0
		var worst_leg := 0
		var worst_dry := 0
		var cards_since_epic := 0
		var worst_gap := 0
		var cards_since_leg := 0
		var worst_leg_gap := 0
		var vaults_dry := 0
		var worst_vault_streak := 0
		for i in 4000:
			var got := Packs.roll_chest(chest, st, 100, catalog, rng, pools)
			var has_epic := false
			for c in got:
				if PackConfig.rank(str(c["rarity"])) >= PackConfig.rank("epic"):
					has_epic = true
			var has_leg := false
			var has_top := false
			for c in got:
				if PackConfig.rank(str(c["rarity"])) >= PackConfig.rank("legendary"):
					has_leg = true
				if c["rarity"] == "transcended":
					has_top = true
			cards_since_epic = 0 if has_epic else cards_since_epic + got.size()
			cards_since_leg = 0 if has_leg else cards_since_leg + got.size()
			vaults_dry = 0 if has_top else vaults_dry + 1
			worst_gap = maxi(worst_gap, cards_since_epic)
			worst_leg_gap = maxi(worst_leg_gap, cards_since_leg)
			worst_vault_streak = maxi(worst_vault_streak, vaults_dry)
			worst_epic = maxi(worst_epic, int(st["pity"]["since_epic"]))
			worst_leg = maxi(worst_leg, int(st["pity"]["since_legendary"]))
			worst_dry = maxi(worst_dry, int(st["pity"]["vault_dry"]))
		check(worst_epic < epic_limit, "%s: epic counter stays under %d, got %d" % [id, epic_limit, worst_epic])
		check(worst_gap < epic_limit + int(chest["cards"]), "%s: never %d cards without an Epic or better, worst %d" % [id, epic_limit, worst_gap])
		if (chest["pity"] as Array).has("legendary"):
			check(worst_leg < leg_limit, "%s: legendary counter stays under %d, got %d" % [id, leg_limit, worst_leg])
			check(worst_leg_gap < leg_limit + int(chest["cards"]), "%s: never %d cards without a Legendary or better, worst %d" % [id, leg_limit, worst_leg_gap])
		if (chest["pity"] as Array).has("transcended"):
			check(worst_dry < vault_limit, "%s: vault counter stays under %d, got %d" % [id, vault_limit, worst_dry])
			check(worst_vault_streak <= vault_limit, "%s: never more than %d vaults without a Transcended card, worst %d" % [id, vault_limit, worst_vault_streak])
	# Without any Transcended card to give, the vault counter must not build up.
	var st2 := Collection.new_state()
	var rng2 := _rng(9)
	for i in 20:
		Packs.roll_chest(PackConfig.chest("vault"), st2, 100, GameData.cards, rng2)
	check(int(st2["pity"]["vault_dry"]) == 0, "vault pity waits until a Transcended card exists")


## 8.3 and 8.4: never a locked card, never an empty slot, even with the smallest pool.
func test_no_impossible_pulls() -> void:
	var catalog := _catalog()
	for progress in [0, 9, 10, 29, 30, 39, 40, 49, 50, 100]:
		var st := Collection.new_state()
		var allowed := {}
		for id in Collection.unlocked_ids(progress, catalog, st):
			allowed[id] = true
		var pools := Collection.pools(progress, catalog, st)
		var rng := _rng(progress + 1)
		for chest in PackConfig.chests:
			for i in 120:
				var got := Packs.roll_chest(chest, st, progress, catalog, rng, pools)
				check(got.size() == int(chest["cards"]), "full card count for %s at %d cleared" % [chest["id"], progress])
				for c in got:
					check(allowed.has(c["id"]), "%s at %d cleared gave a locked card %s" % [chest["id"], progress, c["id"]])
	var st3 := Collection.new_state()
	var got3 := Packs.roll_chest(PackConfig.chest("vault"), st3, 0, GameData.cards, _rng(1))
	for c in got3:
		check(c["rarity"] == "common", "a vault with only starter cards unlocked steps down to common")
	# Reveal order: lowest rarity first.
	var st4 := Collection.new_state()
	var got4 := Packs.roll_chest(PackConfig.chest("gilded"), st4, 100, _catalog(), _rng(2))
	for i in range(1, got4.size()):
		check(PackConfig.rank(got4[i]["rarity"]) >= PackConfig.rank(got4[i - 1]["rarity"]), "cards are revealed lowest rarity first")


## 8.5: the exact number of copies reaches level 5, one fewer stops at level 4, extras become Pearls.
func test_merge_math() -> void:
	var catalog := _catalog()
	var samples := {"common": "power_shot", "rare": "cross_strike", "epic": "blast", "legendary": "prism", "transcended": "t0"}
	for rarity in samples:
		var id: String = samples[rarity]
		var need := PackConfig.total_to_max(rarity)
		for spares in [need - 1, need]:
			var st := Collection.new_state()
			if rarity == "transcended":
				Collection.add_copy(st, id, catalog)  # the first copy only owns it
			for i in spares:
				Collection.add_copy(st, id, catalog)
			Collection.merge_all(st, catalog)
			var want := PackConfig.max_level() if spares == need else PackConfig.max_level() - 1
			check(Collection.level_of(st, id) == want, "%s with %d spares reaches level %d, got %d" % [rarity, spares, want, Collection.level_of(st, id)])
		# Extras beyond the cost are worth Pearls, both at merge time and at pull time.
		var st2 := Collection.new_state()
		if rarity == "transcended":
			Collection.add_copy(st2, id, catalog)
		for i in need + 3:
			Collection.add_copy(st2, id, catalog)
		Collection.merge_all(st2, catalog)
		check(int(st2["pearls"]) == 3 * PackConfig.pearls_for(rarity), "%s leftover spares become Pearls, got %d" % [rarity, int(st2["pearls"])])
		var res := Collection.add_copy(st2, id, catalog)
		check(int(res["pearls"]) == PackConfig.pearls_for(rarity) and int(st2["pearls"]) == 4 * PackConfig.pearls_for(rarity), "%s copy at max level gives Pearls" % rarity)
		check(not Collection.merge(st2, id, catalog), "no merge at max level")
	var st3 := Collection.new_state()
	check(not Collection.merge(st3, "power_shot", catalog), "cannot merge without copies")
	Collection.add_copy(st3, "power_shot", catalog)
	check(not Collection.is_ready(st3, "power_shot", catalog), "one spare is not enough for level 2")
	Collection.add_copy(st3, "power_shot", catalog)
	check(Collection.is_ready(st3, "power_shot", catalog) and Collection.ready_count(st3, catalog) == 1, "two spares make a common ready")
	check(Collection.merge(st3, "power_shot", catalog) and Collection.level_of(st3, "power_shot") == 2 and Collection.spare_of(st3, "power_shot") == 0, "merge spends the spares")
	check(Collection.levels_for_battle(st3) == {"power_shot": 2}, "battle level table lists cards above level 1")


func test_first_crate_and_open_rules() -> void:
	var catalog := _catalog()
	var st := Collection.new_state()
	var starter: Array = GameData.starter_deck
	check(not bool(Packs.open_chest(st, "crate", 0, catalog, _rng(1), starter)["ok"]), "cannot open a chest you do not have")
	Packs.grant(st, "iron")
	check(Packs.open_chest(st, "iron", 5, catalog, _rng(1), starter)["reason"] == "locked", "Ironbound is locked before stage 10 is cleared")
	check(Packs.count(st, "iron") == 1, "a locked chest is not consumed")
	Packs.grant(st, "crate", 2)
	var first := Packs.open_chest(st, "crate", 0, catalog, _rng(1), starter)
	check(bool(first["ok"]) and first["cards"].size() == 3, "first crate opens")
	check(first["cards"][0]["id"] == "power_shot" and first["cards"][1]["id"] == "power_shot", "first crate holds two copies of the most common starter card")
	check(Collection.is_ready(st, "power_shot", catalog), "first crate makes a card ready to merge at once")
	var second := Packs.open_chest(st, "crate", 0, catalog, _rng(2), starter)
	check(bool(second["ok"]) and second["cards"].size() == 3 and bool(st["first_crate_done"]), "later crates are random")
	check(Packs.count(st, "crate") == 0 and (st["pending"] as Array).size() == 2, "chests are used up and reveals queued")
	check(Packs.take_pending(st)["chest"] == "crate" and (st["pending"] as Array).size() == 1 and not Packs.take_pending(st).is_empty() and Packs.take_pending(st).is_empty(), "pending reveals come out in order")
	# Buying.
	st["doubloons"] = 700
	check(Packs.buy(st, "iron", 10) and int(st["doubloons"]) == 100 and Packs.count(st, "iron") == 2, "buying spends Doubloons")
	check(not Packs.buy(st, "iron", 10) and not Packs.buy(st, "coffer", 10), "too expensive or locked chests cannot be bought")


func test_daily() -> void:
	var st := Collection.new_state()
	check(Rewards.daily_available(st, "2026-11-25"), "daily crate is available on the first day")
	check(Rewards.daily_claim(st, "2026-11-25") == "crate" and Packs.count(st, "crate") == 1, "claim gives a Driftwood Crate")
	check(Rewards.daily_claim(st, "2026-11-25") == "" and not Rewards.daily_available(st, "2026-11-25"), "only one per day")
	check(Rewards.daily_available(st, "2026-11-26"), "next day gives another")
	Rewards.daily_claim(st, "2026-11-26")
	# Skipped days stack up to the cap.
	check(Rewards.daily_available(st, "2026-12-10") and int(st["daily"]["stack"]) == 3, "skipped days stack up to 3")
	# Clock set backwards cannot claim again.
	var st2 := Collection.new_state()
	Rewards.daily_claim(st2, "2026-11-25")
	check(not Rewards.daily_available(st2, "2026-11-20"), "an earlier date gives nothing")
	check(not Rewards.daily_available(st2, "2026-11-25"), "and the real date is still used up")
	# Every 7th claim is an Ironbound Chest.
	var st3 := Collection.new_state()
	var kinds: Array = []
	for d in 7:
		kinds.append(Rewards.daily_claim(st3, "2026-11-%02d" % (10 + d)))
	check(kinds[6] == "iron" and kinds[0] == "crate" and Packs.count(st3, "iron") == 1, "7th claim is an Ironbound Chest, got %s" % str(kinds))
	check(Rewards.days_between("2026-11-25", "2026-12-01") == 6, "date difference across a month")


func test_stage_rewards() -> void:
	var st := Collection.new_state()
	var best: Array = []
	best.resize(100)
	best.fill(0)
	var r := Rewards.stage_clear(st, 0, 0, 3, best, "2026-11-25")
	check(int(r["doubloons"]) == 100 and int(st["doubloons"]) == 100 and (r["chests"] as Dictionary).is_empty(), "first clear with 3 stars pays 100")
	r = Rewards.stage_clear(st, 1, 0, 1, best, "2026-11-25")
	check(int(r["doubloons"]) == 60, "first clear with 1 star pays 60")
	r = Rewards.stage_clear(st, 1, 1, 3, best, "2026-11-25")
	check(int(r["doubloons"]) == 40, "improving by two stars pays 40")
	var paid := 0
	for i in 8:
		paid += int(Rewards.stage_clear(st, 1, 3, 3, best, "2026-11-25")["doubloons"])
	check(paid == 50, "five paid replays per day, got %d" % paid)
	check(int(Rewards.stage_clear(st, 1, 3, 3, best, "2026-11-26")["doubloons"]) == 10, "replays pay again the next day")
	r = Rewards.stage_clear(st, 4, 0, 2, best, "2026-11-25")
	check(r["chests"] == {"crate": 2} and Packs.count(st, "crate") == 2, "elite stage first clear gives 2 crates")
	r = Rewards.stage_clear(st, 4, 0, 2, best, "2026-11-25")
	check((r["chests"] as Dictionary).is_empty(), "the elite reward is paid once")
	r = Rewards.stage_clear(st, 9, 0, 3, best, "2026-11-25")
	check(r["chests"] == {"iron": 2}, "stage 10 boss gives 2 Ironbound Chests")
	r = Rewards.stage_clear(st, 99, 0, 3, best, "2026-11-25")
	check(r["chests"] == {"vault": 2}, "stage 100 boss gives 2 Abyssal Vaults")
	# Night milestone: ten stages ending at 55 all with 3 stars.
	var three: Array = []
	three.resize(100)
	three.fill(0)
	for i in range(45, 54):
		three[i] = 3
	r = Rewards.stage_clear(st, 53, 3, 3, three, "2026-11-25")
	check(not (r["chests"] as Dictionary).has("vault"), "no vault while one stage lacks 3 stars")
	three[54] = 3
	r = Rewards.stage_clear(st, 54, 0, 3, three, "2026-11-25")
	check(int(r["chests"].get("vault", 0)) == 1 and Packs.count(st, "vault") == 3, "ten 3-star stages ending at 55 give a vault (plus 2 from stage 100)")
	r = Rewards.stage_clear(st, 54, 3, 3, three, "2026-11-26")
	check(not (r["chests"] as Dictionary).has("vault"), "the milestone is paid once")


func test_market() -> void:
	var catalog := _catalog()
	var st := Collection.new_state()
	st["pearls"] = 100
	check(Rewards.market_price("common") == 8 and Rewards.market_price("transcended") == 800, "market prices are 8 times the Pearl value")
	check(not Rewards.market_buy(st, "prism", 10, catalog, "2026-11-25"), "a locked card cannot be bought")
	check(Rewards.market_buy(st, "power_shot", 0, catalog, "2026-11-25") and int(st["pearls"]) == 92 and Collection.spare_of(st, "power_shot") == 1, "buying adds a copy and spends Pearls")
	for i in 4:
		check(Rewards.market_buy(st, "power_shot", 0, catalog, "2026-11-25"), "purchase %d within the weekly limit" % (i + 2))
	check(not Rewards.market_buy(st, "power_shot", 0, catalog, "2026-11-25"), "sixth purchase in a week is refused")
	check(Rewards.market_buy(st, "power_shot", 0, catalog, "2026-12-03"), "the limit resets the next week")
	st["pearls"] = 5
	check(not Rewards.market_buy(st, "power_shot", 0, catalog, "2026-12-10"), "not enough Pearls")


## Duplicate protection: all four Transcended cards arrive in a reasonable number of vaults.
func test_duplicate_protection() -> void:
	var catalog := _catalog()
	var total := 0
	var worst := 0
	var runs := 60
	for seed_value in runs:
		var st := Collection.new_state()
		var pools := Collection.pools(100, catalog, st)
		var rng := _rng(seed_value + 100)
		var vaults := 0
		while (st["owned"] as Dictionary).size() < 4 and vaults < 100:
			Packs.roll_chest(PackConfig.chest("vault"), st, 100, catalog, rng, pools)
			vaults += 1
		total += vaults
		worst = maxi(worst, vaults)
	check(float(total) / runs <= 16.0 and worst <= 50, "all four Transcended cards: mean %.1f vaults, worst %d" % [float(total) / runs, worst])


## 8.8 and 8.9: the save round-trips, a pending reveal cannot be rerolled, old saves migrate once.
func test_save_and_migration() -> void:
	var abs_path := ProjectSettings.globalize_path(TEST_SAVE)
	SaveData.path = TEST_SAVE
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(abs_path)
	var catalog := _catalog()
	SaveData.reset()
	var st := SaveData.pack_state()
	check(Packs.count(st, "crate") == 0, "a brand new save has no welcome crates")
	Packs.grant(st, "crate", 2)
	st["doubloons"] = 321
	st["pearls"] = 17
	Collection.add_copy(st, "power_shot", catalog)
	Collection.add_copy(st, "power_shot", catalog)
	Collection.merge(st, "power_shot", catalog)
	Collection.add_copy(st, "t1", catalog)
	st["pity"]["since_epic"] = 12
	Rewards.daily_claim(st, "2026-11-25")
	var opened := Packs.open_chest(st, "crate", 0, catalog, _rng(3), GameData.starter_deck)
	SaveData.save()
	var before := st.duplicate(true)
	SaveData.reload_from_disk()
	var after := SaveData.pack_state()
	check(_same(after, before), "pack state survives a save and load")
	check(Packs.count(after, "crate") == 2 and Collection.level_of(after, "power_shot") == 2 and Collection.level_of(after, "t1") == 1, "copies, levels and chests are kept")
	check((after["pending"] as Array).size() == 1 and _same(after["pending"][0]["cards"], opened["cards"]), "the pending reveal is saved with the same cards")
	var again := Packs.open_chest(after, "crate", 0, catalog, _rng(99), GameData.starter_deck)
	check(bool(again["ok"]) and (after["pending"] as Array).size() == 2, "the next chest opens and queues its own reveal")
	# Old save without packs: existing players get 3 crates once.
	DirAccess.remove_absolute(abs_path)
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "tutorial_done", true)
	cfg.set_value("progress", "stars", {"0": 3, "1": 2})
	cfg.save(TEST_SAVE)
	SaveData.reload_from_disk()
	check(Packs.count(SaveData.pack_state(), "crate") == 3 and bool(SaveData.pack_state()["welcome_given"]), "an old save with progress gets 3 Welcome Aboard crates")
	check(SaveData.stars(0) == 3 and SaveData.cleared_count() == 2, "old progress is untouched by the migration")
	SaveData.reload_from_disk()
	check(Packs.count(SaveData.pack_state(), "crate") == 3, "the welcome gift is not given twice")
	# Old save with no progress at all: nothing to welcome back.
	DirAccess.remove_absolute(abs_path)
	var cfg2 := ConfigFile.new()
	cfg2.set_value("progress", "debug_unlock", false)
	cfg2.save(TEST_SAVE)
	SaveData.reload_from_disk()
	check(Packs.count(SaveData.pack_state(), "crate") == 0, "an empty old save gets no welcome gift")
	# Missing keys from an older pack state are filled in.
	var thin := {"version": 1, "chests": {"crate": 1}}
	Collection.normalize(thin)
	check(thin.has("pity") and thin["pity"].has("vault_dry") and thin["chests"]["crate"] == 1, "normalize fills missing keys and keeps data")
	SaveData.reset()
	DirAccess.remove_absolute(abs_path)
