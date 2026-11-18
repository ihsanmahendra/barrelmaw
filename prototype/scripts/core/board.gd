class_name Board
extends RefCounted
## Grid of colored cells. An empty cell is the empty string.
## Some cells are special barrels (bomb, ammo crate, iron, cursed skull); they keep their color for
## matching but trigger or behave differently when hit. See Battle for the rules.

const SPECIALS: Array = ["bomb", "ammo", "iron", "curse"]

var w: int = 0
var h: int = 0
var cells: Array = []
var special: Array = []  # "" or one of SPECIALS, per cell
var hp: Array = []  # hits needed to break each cell (2 for iron, otherwise 1)


func _init(rows: Array = []) -> void:
	h = rows.size()
	for r in rows:
		w = maxi(w, String(r).length())
	for y in h:
		for x in w:
			var ch := String(rows[y])[x] if x < String(rows[y]).length() else "."
			cells.append("" if ch == "." else ch)
			special.append("")
			hp.append(1)


func get_c(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return ""
	return cells[y * w + x]


func is_exposed(x: int, y: int) -> bool:
	return get_c(x - 1, y) == "" or get_c(x + 1, y) == "" or get_c(x, y - 1) == "" or get_c(x, y + 1) == ""


func remove_at(x: int, y: int) -> bool:
	if get_c(x, y) == "":
		return false
	cells[y * w + x] = ""
	special[y * w + x] = ""
	hp[y * w + x] = 1
	return true


func get_special(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= w or y >= h:
		return ""
	return special[y * w + x]


func get_hp(x: int, y: int) -> int:
	if get_c(x, y) == "":
		return 0
	return hp[y * w + x]


func set_special(x: int, y: int, kind: String) -> void:
	if get_c(x, y) == "":
		return
	special[y * w + x] = kind
	hp[y * w + x] = 2 if kind == "iron" else 1


func set_hp(x: int, y: int, value: int) -> void:
	if get_c(x, y) != "":
		hp[y * w + x] = value


## Plain copy of the three per-cell arrays, used to restore the board after a preview.
func save_state() -> Array:
	return [cells.duplicate(), special.duplicate(), hp.duplicate()]


func restore_state(state: Array) -> void:
	cells = state[0].duplicate()
	special = state[1].duplicate()
	hp = state[2].duplicate()


func count() -> int:
	var n := 0
	for c in cells:
		if c != "":
			n += 1
	return n


func color_counts() -> Dictionary:
	var d := {}
	for c in cells:
		if c != "":
			d[c] = int(d.get(c, 0)) + 1
	return d


## Color letter with the most remaining cells, or "" if the board is empty.
func most_common() -> String:
	var best := ""
	var best_n := 0
	var counts := color_counts()
	var keys: Array = counts.keys()
	keys.sort()
	for k in keys:
		if counts[k] > best_n:
			best_n = counts[k]
			best = k
	return best
