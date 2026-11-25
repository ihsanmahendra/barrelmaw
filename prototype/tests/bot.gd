class_name Bot
extends RefCounted
## Simple test bot: scores each card by rough power and plays the best one, then fires.

static func pick(b: Battle) -> int:
	var best := -1
	var best_score := -1.0
	for i in b.hand.size():
		var score := randf() * 0.5
		var id: String = b.hand[i]
		for eff in GameData.cards[id]["effects"]:
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


## Plays a battle to the end with the bot (at most 500 turns).
static func play(b: Battle) -> void:
	var guard := 0
	while not b.over and guard < 500:
		guard += 1
		var p := pick(b)
		if p >= 0:
			b.play_card(p)
		if not b.over:
			b.fire()
