extends SceneTree
## Finds, per stage, the cannonball slack at which the test bot wins a target share of games,
## and prints a table to paste into Stages.SLACK_TABLE.
## godot --headless --path prototype --script res://tests/tune_slack.gd

const TRIALS: int = 120


func _init() -> void:
	GameData.ensure_loaded()
	var table: Array = []
	for stage in range(int(OS.get_environment("TUNE_FROM")) if OS.get_environment("TUNE_FROM") != "" else 0, Stages.TOTAL):
		# Bot win-rate target. Stages 1-50: 90% falling to about 40%. Night stages 51-100 continue from
		# about 46% down to about 28%. A person using the card preview wins clearly more than this bot.
		var target := 0.90 - 0.010 * stage
		if stage >= Stages.NIGHT_START:
			target = 0.46 - 0.0036 * float(stage - Stages.NIGHT_START)
		if Stages.is_boss(stage):
			target -= 0.05
		elif Stages.is_elite(stage):
			target -= 0.03
		var lo := 0.02
		var hi := 1.30
		for i in 9:
			var mid := (lo + hi) / 2.0
			if _win_rate(stage, mid) < target:
				lo = mid
			else:
				hi = mid
		var s := snappedf((lo + hi) / 2.0, 0.01)
		table.append(s)
		print("stage %2d target %.0f%% slack %.2f (win %.0f%%)" % [stage + 1, target * 100.0, s, _win_rate(stage, s) * 100.0])
	print("SLACK_TABLE: ", table)
	quit(0)


func _bot_pick(b: Battle, rng: RandomNumberGenerator) -> int:
	var best := -1
	var best_score := -1.0
	for i in b.hand.size():
		var score := rng.randf() * 0.5
		for eff in GameData.cards[b.hand[i]]["effects"]:
			match eff["kind"]:
				"ammo", "clear_random", "clear_color", "add_shooter":
					score += float(eff.get("n", 1))
				"shape", "wild", "double":
					score += 3.0
				"skip":
					score += 0.5
				_:
					score += 1.0
		if score > best_score:
			best_score = score
			best = i
	return best


func _win_rate(stage: int, slack: float) -> float:
	var wins := 0
	for r in TRIALS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + stage * 777 + r
		var deck: Array = Stages.deck_for(stage)
		var b := Battle.new(Stages.picture(stage)["rows"], deck, slack, GameData.hand_size, rng.randi(), {}, Stages.specials_for(stage))
		var guard := 0
		while not b.over and guard < 500:
			guard += 1
			var pick := _bot_pick(b, rng)
			if pick >= 0:
				b.play_card(pick)
			if not b.over:
				b.fire()
		if b.won:
			wins += 1
	return float(wins) / TRIALS
