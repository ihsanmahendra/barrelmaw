extends SceneTree
## Prints how many turns the test bot needs to clear each stage, to set the star turn limits.
## godot --headless --path prototype --script res://tests/star_stats.gd

const TRIALS: int = 150


func _init() -> void:
	GameData.ensure_loaded()
	var p60: Array = []
	var p90: Array = []
	for stage in range(int(OS.get_environment("STATS_FROM")) if OS.get_environment("STATS_FROM") != "" else 0, Stages.TOTAL):
		var turns: Array = []
		for r in TRIALS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 700 + stage * 311 + r
			var deck: Array = Stages.deck_for(stage)
			var b := Stages.new_battle(stage, deck, rng.randi())
			var guard := 0
			while not b.over and guard < 500:
				guard += 1
				var pick := _pick(b, rng)
				if pick >= 0:
					b.play_card(pick)
				if not b.over:
					b.fire()
			if b.won:
				turns.append(b.turns)
		turns.sort()
		if turns.is_empty():
			p60.append(99)
			p90.append(99)
			continue
		p60.append(_q(turns, 0.60))
		p90.append(_q(turns, 0.90))
		print("stage %2d wins %3d  turns p10 %d  p25 %d  p50 %d  p60 %d  p75 %d  p90 %d" % [stage + 1, turns.size(), _q(turns, 0.1), _q(turns, 0.25), _q(turns, 0.5), _q(turns, 0.6), _q(turns, 0.75), _q(turns, 0.9)])
	print("P60 (3 stars): ", p60)
	print("P90 (2 stars): ", p90)
	quit(0)


func _q(sorted: Array, p: float) -> int:
	return int(sorted[mini(sorted.size() - 1, int(p * sorted.size()))])


func _pick(b: Battle, rng: RandomNumberGenerator) -> int:
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
