extends SceneTree
## Balance check for card levels (design/gdd/card-packs.md, acceptance 8.10). Plays every stage with the
## bot while every card in the deck is at one level, and prints the win rate and 3-star rate.
## Run: LEVEL=3 PER_STAGE=30 godot --headless --path . --script res://tests/level_balance.gd
## LEVEL: level of every card (1 = today's balance). PER_STAGE: games per stage. FROM / TO: stage range.
## CARDS: optional comma list; only these cards get the level. EXTRA: optional comma list of cards added to every deck. MULTI=1: the bot spends extra plays.

func _init() -> void:
	GameData.ensure_loaded()
	var level := int(OS.get_environment("LEVEL")) if OS.get_environment("LEVEL") != "" else 1
	var per_stage := int(OS.get_environment("PER_STAGE")) if OS.get_environment("PER_STAGE") != "" else 30
	var from_stage := int(OS.get_environment("FROM")) if OS.get_environment("FROM") != "" else 0
	var to_stage := int(OS.get_environment("TO")) if OS.get_environment("TO") != "" else Stages.TOTAL - 1
	var only := OS.get_environment("CARDS").split(",", false)  # optional: level only these cards
	var multi := OS.get_environment("MULTI") == "1"  # the bot also spends extra plays
	var extra := OS.get_environment("EXTRA").split(",", false)  # optional: cards added to every deck (Transcended cards)
	var levels := {}
	for id in GameData.card_order:
		if only.is_empty() or only.has(id):
			levels[id] = level
	var wins := 0
	var three := 0
	var games := 0
	var bucket_wins := {}
	var bucket_games := {}
	var bucket_three := {}
	for stage in range(from_stage, to_stage + 1):
		for r in per_stage:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + stage * 1000 + r
			seed(rng.randi())
			var deck: Array = Stages.deck_for(stage)
			deck.append_array(extra)
			var b := Stages.new_battle(stage, deck, rng.randi(), levels)
			Bot.play(b, multi)
			var k := stage / 10
			bucket_games[k] = int(bucket_games.get(k, 0)) + 1
			games += 1
			if b.won:
				wins += 1
				bucket_wins[k] = int(bucket_wins.get(k, 0)) + 1
				if b.star_rating() == 3:
					three += 1
					bucket_three[k] = int(bucket_three.get(k, 0)) + 1
	for k in bucket_games:
		print("  stages %3d-%3d  win %3.0f%%  3-star %3.0f%%" % [k * 10 + 1, k * 10 + 10, 100.0 * int(bucket_wins.get(k, 0)) / int(bucket_games[k]), 100.0 * int(bucket_three.get(k, 0)) / int(bucket_games[k])])
	print("LEVEL %d  win %.1f%%  3-star %.1f%%  (%d games)" % [level, 100.0 * wins / games, 100.0 * three / games, games])
	quit()
