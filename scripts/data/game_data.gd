class_name GameData
extends RefCounted
## Read-only access to the JSON tuning tables in res://data/.
## Gameplay code asks this class for numbers instead of hard-coding them.
## preload_all() runs on the main thread at boot so worker threads (level
## generation) only ever read the cache.

const DIFFICULTY := "res://data/difficulty.json"
const ECONOMY := "res://data/economy.json"
const LEVELS := "res://data/levels_authored.json"
const ACHIEVEMENTS := "res://data/achievements.json"
const META := "res://data/meta.json"

static var _cache: Dictionary = {}


static func preload_all() -> void:
	for p in ["res://data/daily.json", DIFFICULTY, ECONOMY, LEVELS, ACHIEVEMENTS, META]:
		load_json(p)


static func load_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var result: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open %s" % path)
	else:
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
			result = json.data
		else:
			push_error("GameData: %s is not valid JSON (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
	_cache[path] = result
	return result


static func difficulty() -> Dictionary:
	return load_json(DIFFICULTY)


static func economy() -> Dictionary:
	return load_json(ECONOMY)


static func meta() -> Dictionary:
	return load_json(META)


# --- Bus colours -------------------------------------------------------------

static func colors() -> Array:
	return meta().get("colors", [])


static func color_count() -> int:
	return colors().size()


static func bus_color(c: int) -> Color:
	var all := colors()
	if c < 0 or c >= all.size():
		return Color("9aa0a6")
	return Color.html(String(all[c]["hex"]))


static func color_name(c: int) -> String:
	var all := colors()
	if c < 0 or c >= all.size():
		return "?"
	return String(all[c]["name"])


static func towns() -> Array:
	return meta().get("towns", ["Juneli Pul"])


static func bus_names() -> Array:
	return meta().get("bus_names", ["Mero Gadi"])


## Stable decorative name for a bus (sun-strip text).
static func bus_name(seed_value: int) -> String:
	var all := bus_names()
	return String(all[posmod(seed_value, all.size())])


static func town(i: int) -> String:
	var all := towns()
	return String(all[posmod(i, all.size())])


# --- Levels ------------------------------------------------------------------

static func authored_levels() -> Array:
	return load_json(LEVELS).get("levels", [])


static func authored_level(n: int) -> Dictionary:
	for l in authored_levels():
		if int(l["level"]) == n:
			return l
	return {}


# --- Economy -----------------------------------------------------------------

static func price(booster: String) -> int:
	return int(economy()["booster_prices"].get(booster, 999))


static func cosmetics(category: String = "") -> Array:
	var all: Array = economy().get("cosmetics", [])
	if category == "":
		return all
	return all.filter(func(c): return c["category"] == category)


static func cosmetic(id: String) -> Dictionary:
	for c in cosmetics():
		if c["id"] == id:
			return c
	return {}


static func cosmetic_categories() -> Array:
	return economy().get("cosmetic_categories", [])


static func bundle(id: String) -> Dictionary:
	for b in economy().get("bundles", []):
		if b["id"] == id:
			return b
	return {}


static func coin_pack(id: String) -> Dictionary:
	for p in economy().get("coin_packs", []):
		if p["id"] == id:
			return p
	return {}


# --- Meta --------------------------------------------------------------------

static func achievements() -> Array:
	return load_json(ACHIEVEMENTS).get("achievements", [])


static func avatars() -> Array:
	return meta().get("avatars", [])


static func tips() -> Array:
	return meta().get("tips", ["Tip: there is no timer."])


static func color(hex: Variant, fallback: Color = Color.MAGENTA) -> Color:
	if typeof(hex) != TYPE_STRING or String(hex) == "":
		return fallback
	return Color.html(hex)
