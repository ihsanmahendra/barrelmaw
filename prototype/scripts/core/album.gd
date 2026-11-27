class_name Album
extends RefCounted
## The Captain's Log (design/gdd/album.md): the 100 pictures on 10 pages. A page with every stage cleared
## pays Doubloons, a page with every star pays a chest; each once, claimed by tapping. Pure rules on the
## pack state (Collection) and the best stars per stage.

const PAGE_SIZE: int = 10
const COMPLETE_DOUBLOONS: int = 100
const MASTER_CHEST: String = "iron"  # Ironbound Chest
const KINDS: Array = ["complete", "mastered"]


static func pages() -> int:
	return int(ceil(Stages.TOTAL / float(PAGE_SIZE)))


## Stage indexes (0-based) shown on a page (0-based).
static func stages_on(page: int) -> Array:
	var out: Array = []
	for i in range(page * PAGE_SIZE, mini((page + 1) * PAGE_SIZE, Stages.TOTAL)):
		out.append(i)
	return out


static func cleared_count(page: int, best_stars: Array) -> int:
	var n := 0
	for i in stages_on(page):
		if int(best_stars[i]) > 0:
			n += 1
	return n


static func star_count(page: int, best_stars: Array) -> int:
	var n := 0
	for i in stages_on(page):
		n += int(best_stars[i])
	return n


static func earned(page: int, kind: String, best_stars: Array) -> bool:
	if kind == "complete":
		return cleared_count(page, best_stars) == stages_on(page).size()
	return star_count(page, best_stars) == stages_on(page).size() * 3


static func key(page: int, kind: String) -> String:
	return "album_%s_%d" % [kind, page]


static func claimed(st: Dictionary, page: int, kind: String) -> bool:
	return st["claimed"].has(key(page, kind))


static func claimable(st: Dictionary, page: int, kind: String, best_stars: Array) -> bool:
	return earned(page, kind, best_stars) and not claimed(st, page, kind)


## True when any page has a reward waiting.
static func waiting(st: Dictionary, best_stars: Array) -> bool:
	for page in pages():
		for kind in KINDS:
			if claimable(st, page, kind, best_stars):
				return true
	return false


## Pays a page reward. Returns false when it is not earned or already paid.
static func claim(st: Dictionary, page: int, kind: String, best_stars: Array) -> bool:
	if not claimable(st, page, kind, best_stars):
		return false
	st["claimed"][key(page, kind)] = true
	if kind == "complete":
		st["doubloons"] = int(st["doubloons"]) + COMPLETE_DOUBLOONS
	else:
		Packs.grant(st, MASTER_CHEST)
	return true
