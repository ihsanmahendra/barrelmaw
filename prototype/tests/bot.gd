class_name Bot
extends RefCounted
## Simple test bot: scores each card by rough power and plays the best one, then fires.
## Bot.play(b, true) also spends extra plays (Second Wind, Ghost Compass) before firing.

static func score_card(id: String, last_played: String = "") -> float:
	var score := 0.0
	for eff in GameData.cards[id]["effects"]:
		match eff["kind"]:
			"add_shooter":
				score += float(eff.get("n", 1)) * float(eff.get("count", 1))
			"ammo", "clear_random", "clear_color":
				score += float(eff.get("n", 1))
			"free_turn":
				score += 2.0
			"repeat_last":
				# Worth what the last card was worth, a little more because it is a level higher.
				score += 1.0 if last_played == "" else score_card(last_played) + 1.0
			"shape", "wild", "double":
				score += 3.0
			"skip":
				score += 0.5
			_:
				score += 1.0
	return score


static func pick(b: Battle) -> int:
	var best := -1
	var best_score := -1.0
	for i in b.hand.size():
		var score := randf() * 0.5 + score_card(b.hand[i], b.last_played)
		if score > best_score:
			best_score = score
			best = i
	return best


## Plays a battle to the end with the bot (at most 500 turns).
static func play(b: Battle, multi: bool = false) -> void:
	var guard := 0
	while not b.over and guard < 500:
		guard += 1
		var p := pick(b)
		if p >= 0:
			b.play_card(p)
		while multi and not b.over and b.plays_left > 0 and not b.hand.is_empty():
			var q := pick(b)
			if q < 0 or not b.play_card(q):
				break
		if not b.over:
			b.fire()
