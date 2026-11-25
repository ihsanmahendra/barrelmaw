class_name Battle
extends RefCounted
## One picture. Owns the board, shooter queue, card piles and turn flow.
##
## A turn has two steps: play a card (optional), then fire the front shooter.
## Any block of the shooter's color can be hit. Shooters whose color is gone are removed.

var board: Board
var queue: Array = []  # Array of {color: String, ammo: int}
var draw_pile: Array = []
var discard: Array = []
var hand: Array = []
var mods: Dictionary = {}
var plays_left: int = 1
var cards_played_turn: int = 0
var hand_size: int = 3
var rng := RandomNumberGenerator.new()
var removed_last: Array = []  # Vector2i cells removed by the latest action
var shots_last: Array = []  # {kind, color, anchor, cells} per shot of the latest action, in order
var over: bool = false
var won: bool = false
var turns: int = 0
var drawn_total: int = 0  # cards drawn so far; the UI uses it to animate only new cards
var last_shot_wasted: bool = false
var damaged_last: Array = []  # Vector2i iron barrels hit but not broken by the latest action
var events_last: Array = []  # {kind, pos, amount} special-barrel effects of the latest action
var last_fired: bool = false  # true when the latest action fired a shooter
var pruned_last: int = 0  # shooters removed at the start of the turn because their color is gone
var pruned_balls_last: Array = []  # those removed shooters ({color, ammo}), for the UI to show them leaving
var scripted_hands: Array = []  # tutorial only: fixed hands, used before random draws
var initial_shots: int = 0  # total cannonball hits at the start; used for the star rating
var star2_turns: int = 99  # finish within this many turns for 2 stars (set per stage)
var star3_turns: int = 99  # ... and for 3 stars
var last_played: String = ""  # id of the last card played in this battle (Phantom Echo repeats it)
var levels: Dictionary = {}  # card id -> level (missing = 1); set by Stages.new_battle from the player's collection


## scripted (optional, for the tutorial): {"queue": Array, "hands": Array of Array of card ids}.
## specials (optional): how many special barrels to place, e.g. {"bomb": 2, "iron": 3}.
func _init(rows: Array, deck: Array, slack: float, p_hand_size: int, seed_value: int, scripted: Dictionary = {}, specials: Dictionary = {}) -> void:
	rng.seed = seed_value
	board = Board.new(rows)
	_place_specials(specials)
	hand_size = p_hand_size
	draw_pile = deck.duplicate()
	GameData.shuffle_with(draw_pile, rng)
	if scripted.has("queue"):
		queue = scripted["queue"].duplicate(true)
		scripted_hands = scripted.get("hands", []).duplicate(true)
	else:
		_build_queue(slack)
	initial_shots = shots_left()
	_reset_mods()
	start_turn()


## Scatters the requested special barrels over random cells (each cell gets at most one).
func _place_specials(counts: Dictionary) -> void:
	var cells_left: Array = _all_cells("")
	GameData.shuffle_with(cells_left, rng)
	for kind in Board.SPECIALS:
		for i in int(counts.get(kind, 0)):
			if cells_left.is_empty():
				return
			var p: Vector2i = cells_left.pop_back()
			board.set_special(p.x, p.y, kind)


func _begin_action() -> void:
	removed_last = []
	shots_last = []
	damaged_last = []
	events_last = []
	last_shot_wasted = false


func _reset_mods() -> void:
	mods = {"ammo": 0, "wild": false, "double": false, "shape": "", "free": false}


func _build_queue(slack: float) -> void:
	var counts := board.color_counts()
	var keys: Array = counts.keys()
	keys.sort()
	for color in keys:
		var target: int = ceili(float(counts[color]) * slack)
		var got := 0
		while got < target:
			var a: int = mini([2, 3, 4][rng.randi_range(0, 2)], target - got)
			queue.append({"color": color, "ammo": a})
			got += a
	GameData.shuffle_with(queue, rng)


## Star rating for a won battle: 3 stars within star3_turns, 2 within star2_turns, else 1.
## Zero if the battle was not won.
func star_rating() -> int:
	if not won:
		return 0
	return _stars_for_turn(turns)


## What the rating would be if the picture were cleared this turn (shown live in the HUD).
func projected_stars() -> int:
	return _stars_for_turn(turns)


func _stars_for_turn(turn: int) -> int:
	return 3 if turn <= star3_turns else (2 if turn <= star2_turns else 1)


## The turn limit that keeps the currently projected stars, or -1 when only 1 star is left.
func star_limit() -> int:
	match projected_stars():
		3:
			return star3_turns
		2:
			return star2_turns
	return -1


## Cannonball hits that can still do something: cannonballs whose color is no longer on the board are
## not counted, because they get removed at the start of the next turn.
func shots_left() -> int:
	var counts := board.color_counts()
	var n := 0
	for s in queue:
		if _usable(s, counts):
			n += int(s["ammo"])
	return n


## A cannonball is usable while its color is on the board; a wild one while any barrel is left.
func _usable(s: Dictionary, counts: Dictionary) -> bool:
	return counts.has(s["color"]) or (bool(s.get("wild", false)) and not counts.is_empty())


func _draw_cards(n: int) -> void:
	for i in n:
		if draw_pile.is_empty():
			draw_pile = discard.duplicate()
			discard.clear()
			GameData.shuffle_with(draw_pile, rng)
		if draw_pile.is_empty():
			return
		hand.append(draw_pile.pop_back())
		drawn_total += 1


func _prune_dead_shooters() -> void:
	var counts := board.color_counts()
	var alive: Array = []
	for s in queue:
		if _usable(s, counts):
			alive.append(s)
	pruned_balls_last = []
	for s in queue:
		if not _usable(s, counts):
			pruned_balls_last.append(s.duplicate())
	pruned_last = queue.size() - alive.size()
	queue = alive


func start_turn() -> void:
	_prune_dead_shooters()
	if _check_end():
		return
	plays_left = 1
	cards_played_turn = 0
	turns += 1
	if not scripted_hands.is_empty():
		hand = scripted_hands.pop_front().duplicate()
		drawn_total += hand.size()
	else:
		_draw_cards(hand_size)


## An independent copy of this battle, including the random generator state, so that playing
## the same card on the copy gives exactly the same result as playing it here.
func clone() -> Battle:
	var b := Battle.new([], [], 1.0, 0, 0)
	b.board = Board.new()
	b.board.w = board.w
	b.board.h = board.h
	b.board.cells = board.cells.duplicate()
	b.board.special = board.special.duplicate()
	b.board.hp = board.hp.duplicate()
	b.queue = queue.duplicate(true)
	b.draw_pile = draw_pile.duplicate()
	b.discard = discard.duplicate()
	b.hand = hand.duplicate()
	b.mods = mods.duplicate()
	b.plays_left = plays_left
	b.cards_played_turn = cards_played_turn
	b.hand_size = hand_size
	b.over = over
	b.won = won
	b.turns = turns
	b.drawn_total = drawn_total
	b.scripted_hands = scripted_hands.duplicate(true)
	b.levels = levels
	b.last_played = last_played
	b.rng.seed = rng.seed
	b.rng.state = rng.state
	return b


## What playing the card at hand index i would do, without changing this battle.
## Returns {battle: the copy after the card, card_removed: cells the card itself removes,
## hits_before, hits_after: barrels the next shot hits, targets: cells the next shot hits, drawn}.
func preview_card(i: int) -> Dictionary:
	var c := clone()
	var hits_before := preview_targets().size()
	var hand_after_play := hand.size() - 1
	c.play_card(i)
	var targets := c.preview_targets()
	return {
		"battle": c, "card_removed": c.removed_last.duplicate(), "hits_before": hits_before,
		"hits_after": targets.size(), "targets": targets, "drawn": c.hand.size() - hand_after_play,
	}


## The level of a card in this battle (1 unless the player has merged it).
func level_of(id: String) -> int:
	return clampi(int(levels.get(id, 1)), 1, PackConfig.max_level())


## Plays the card at hand index i. Does not fire: the player presses fire next.
func play_card(i: int) -> bool:
	if over or i < 0 or i >= hand.size() or plays_left <= 0:
		return false
	_begin_action()
	last_fired = false
	var id: String = hand[i]
	hand.remove_at(i)
	discard.append(id)
	for eff in CardLevels.effects_for(GameData.cards[id], level_of(id)):
		_apply(eff)
	if id != "phantom_echo":  # Phantom Echo never repeats itself
		last_played = id
	plays_left -= 1
	cards_played_turn += 1
	_check_end()
	return true


func _apply(eff: Dictionary) -> void:
	var n: int = int(eff.get("n", 0))
	match eff["kind"]:
		"ammo":
			mods["ammo"] += n
		"wild":
			mods["wild"] = true
		"double":
			mods["double"] = true
		"shape":
			mods["shape"] = eff["shape"]
		"skip":
			if queue.size() > 1:
				queue.push_back(queue.pop_front())
		"dup":
			if not queue.is_empty():
				queue.insert(0, queue[0].duplicate())
		"add_shooter":
			var c := board.most_common()
			if c != "":
				for k in int(eff.get("count", 1)):
					var ball := {"color": c, "ammo": n}
					if bool(eff.get("wild", false)):
						ball["wild"] = true  # hits any color
					queue.insert(0, ball)
		"free_turn":
			mods["free"] = true  # firing this turn does not count toward the star turn limit
		"repeat_last":
			if last_played == "" or not GameData.cards.has(last_played):
				_draw_cards(1)
			else:
				var lv := mini(level_of(last_played) + 1, PackConfig.max_level())
				for e in CardLevels.effects_for(GameData.cards[last_played], lv):
					_apply(e)
		"recolor_next":
			var c2 := board.most_common()
			if c2 != "" and not queue.is_empty():
				queue[0]["color"] = c2
		"draw":
			_draw_cards(n)
		"extra_play":
			plays_left += n
		"clear_random":
			_clear_random(n)
		"clear_color":
			_clear_color(n)
		"chaos":
			var pool := [
				{"kind": "clear_random", "n": 6},
				{"kind": "ammo", "n": 5},
				{"kind": "draw", "n": 2},
				{"kind": "extra_play", "n": 1},
				{"kind": "add_shooter", "n": 4},
			]
			_apply(pool[rng.randi_range(0, pool.size() - 1)])


func _all_cells(color: String) -> Array:
	var out: Array = []
	for y in board.h:
		for x in board.w:
			var c := board.get_c(x, y)
			if c == "" or (color != "" and c != color):
				continue
			out.append(Vector2i(x, y))
	return out


func _clear_random(n: int) -> void:
	for i in n:
		var pool := _all_cells("")
		if pool.is_empty():
			return
		_remove_card(pool[rng.randi_range(0, pool.size() - 1)])


func _clear_color(n: int) -> void:
	var color := board.most_common()
	for i in n:
		var pool := _all_cells(color)
		if pool.is_empty():
			return
		_remove_card(pool[0])


## Hits the barrel at p. Iron barrels lose one hit point and only break on the second hit. A barrel
## that breaks triggers its special effect: bombs blow up the 3x3 area around them, crates give a
## free cannonball and skulls weaken the next one.
func _remove(p: Vector2i) -> void:
	var letter := board.get_c(p.x, p.y)
	if letter == "":
		return
	var kind := board.get_special(p.x, p.y)
	if board.get_hp(p.x, p.y) > 1:
		board.set_hp(p.x, p.y, board.get_hp(p.x, p.y) - 1)
		damaged_last.append(p)
		events_last.append({"kind": "iron", "pos": p, "amount": 0})
		return
	board.remove_at(p.x, p.y)
	removed_last.append(p)
	match kind:
		"bomb":
			events_last.append({"kind": "bomb", "pos": p, "amount": 0})
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx != 0 or dy != 0:
						_remove(Vector2i(p.x + dx, p.y + dy))
		"ammo":
			var color := board.most_common()
			if color == "":
				color = letter
			queue.insert(0, {"color": color, "ammo": AMMO_CRATE_HITS})
			events_last.append({"kind": "ammo", "pos": p, "amount": AMMO_CRATE_HITS})
		"curse":
			if not queue.is_empty():
				queue[0]["ammo"] = maxi(1, int(queue[0]["ammo"]) - CURSE_HITS)
			events_last.append({"kind": "curse", "pos": p, "amount": CURSE_HITS})


const AMMO_CRATE_HITS: int = 3  # hits in the cannonball a supply crate adds
const CURSE_HITS: int = 2  # hits a cursed skull takes off the next cannonball


## Removal caused directly by a card effect (not by a shooter). Recorded as its own shot.
func _remove_card(p: Vector2i) -> void:
	var letter := board.get_c(p.x, p.y)
	if letter == "":
		return
	var r0 := removed_last.size()
	var e0 := events_last.size()
	var d0 := damaged_last.size()
	_remove(p)
	shots_last.append({"kind": "card", "color": letter, "anchor": p, "cells": removed_last.slice(r0),
		"events": events_last.slice(e0), "damaged": damaged_last.slice(d0)})


## Cells the front shooter would remove with its pending modifiers. Used by the UI to show
## where the next shot lands. Runs the real shot logic, then restores the board.
func preview_targets() -> Array:
	if over or queue.is_empty():
		return []
	var saved_board := board.save_state()
	var saved_queue := queue.duplicate(true)
	var saved_removed := removed_last
	var saved_shots := shots_last
	var saved_damaged := damaged_last
	var saved_events := events_last
	removed_last = []
	shots_last = []
	damaged_last = []
	events_last = []
	_resolve_shots(queue[0].duplicate())
	var out := removed_last.duplicate()
	for d in damaged_last:  # iron barrels that would be hit but not broken are outlined too
		if not out.has(d):
			out.append(d)
	board.restore_state(saved_board)
	queue = saved_queue
	removed_last = saved_removed
	shots_last = saved_shots
	damaged_last = saved_damaged
	events_last = saved_events
	return out


func _resolve_shots(s: Dictionary) -> void:
	var was_wild: bool = mods["wild"]
	if bool(s.get("wild", false)):
		mods["wild"] = true
	_fire_hits(s)
	mods["wild"] = was_wild


func _fire_hits(s: Dictionary) -> void:
	var ammo: int = int(s["ammo"]) + int(mods["ammo"])
	if mods["double"]:
		ammo *= 2
	for i in ammo:
		var anchor := _find_target(s["color"])
		if anchor.x < 0:
			break
		var start: int = removed_last.size()
		var e0 := events_last.size()
		var d0 := damaged_last.size()
		_hit(anchor, s["color"])
		shots_last.append({"kind": "fire", "color": s["color"], "anchor": anchor, "cells": removed_last.slice(start),
			"events": events_last.slice(e0), "damaged": damaged_last.slice(d0)})


## Fires the front shooter with all pending modifiers, then ends the turn.
func fire() -> void:
	if over:
		return
	if queue.is_empty():
		_check_end()
		return
	_begin_action()
	last_fired = true
	var s: Dictionary = queue.pop_front()
	_resolve_shots(s)
	last_shot_wasted = removed_last.is_empty() and damaged_last.is_empty()
	if mods["free"]:
		turns = maxi(turns - 1, 0)  # Ghost Compass: the next turn takes this one's number again
	_reset_mods()
	discard.append_array(hand)
	hand.clear()
	if not _check_end():
		start_turn()


## Picks where the next bullet lands: lowest row, nearest the center. With a shape modifier,
## picks the spot that clears the most blocks instead.
func _find_target(color: String) -> Vector2i:
	var cx := (board.w - 1) / 2.0
	var best := Vector2i(-1, -1)
	var best_gain := -1
	for y in range(board.h - 1, -1, -1):
		var xs: Array = range(board.w)
		xs.sort_custom(func(a: int, b: int) -> bool: return absf(a - cx) < absf(b - cx))
		for x in xs:
			var c := board.get_c(x, y)
			if c == "" or not (mods["wild"] or c == color):
				continue
			if mods["shape"] == "":
				return Vector2i(x, y)
			var gain := _gain(Vector2i(x, y), color)
			if gain > best_gain:
				best_gain = gain
				best = Vector2i(x, y)
	return best


func _spots(anchor: Vector2i) -> Array:
	var spots: Array = [anchor]
	match mods["shape"]:
		"row":
			for x in board.w:
				spots.append(Vector2i(x, anchor.y))
		"col":
			for y in board.h:
				spots.append(Vector2i(anchor.x, y))
		"cross":
			for x in board.w:
				spots.append(Vector2i(x, anchor.y))
			for y in board.h:
				spots.append(Vector2i(anchor.x, y))
		"diag":
			for k in range(-maxi(board.w, board.h), maxi(board.w, board.h) + 1):
				spots.append(Vector2i(anchor.x + k, anchor.y + k))
				spots.append(Vector2i(anchor.x + k, anchor.y - k))
		"blast":
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					spots.append(Vector2i(anchor.x + dx, anchor.y + dy))
	return spots


func _gain(anchor: Vector2i, color: String) -> int:
	var seen := {}
	for p in _spots(anchor):
		var c := board.get_c(p.x, p.y)
		if c != "" and (p == anchor or mods["wild"] or c == color):
			seen[p] = true
	return seen.size()


func _hit(anchor: Vector2i, color: String) -> void:
	for p in _spots(anchor):
		var c := board.get_c(p.x, p.y)
		if c == "":
			continue
		if p == anchor or mods["wild"] or c == color:
			_remove(p)


func _check_end() -> bool:
	if board.count() == 0:
		over = true
		won = true
	elif queue.is_empty():
		over = true
		won = false
	return over
