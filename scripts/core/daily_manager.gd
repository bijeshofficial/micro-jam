extends Node
## Daily tasks and the Daily Jam.
##
## Each calendar day the player gets 3 easy tasks picked from
## data/daily.json (seeded by the date, so everyone gets the same ones).
## A task's progress is how much its stat has grown since the day started.
## Finishing all three opens a bonus chest.
##
## The Daily Jam is one extra level per day, generated from the date and
## sized to the player's progress. It never costs lives. Clearing it on
## consecutive days builds a streak that adds bonus coins.

signal changed

const DATA := "res://data/daily.json"

## Tests set this to fake the calendar ("YYYY-MM-DD").
var date_override := ""

var _level_cache: Dictionary = {}   # date -> level dict


func _ready() -> void:
	SaveManager.loaded.connect(refresh)
	SaveManager.progress_reset.connect(refresh)
	refresh.call_deferred()


func config() -> Dictionary:
	return GameData.load_json(DATA)


func today() -> String:
	return date_override if date_override != "" else GameManager.today()


func _state() -> Dictionary:
	var g := SaveManager.game()
	if typeof(g.get("daily")) != TYPE_DICTIONARY:
		g["daily"] = {}
	return g["daily"]


## Rolls the day over when the date changed.
func refresh() -> void:
	if SaveManager.data.is_empty():
		return
	var st := _state()
	if String(st.get("date", "")) == today() and not (st.get("tasks", []) as Array).is_empty():
		return
	st["date"] = today()
	st["chest_claimed"] = false
	var pool: Array = (config().get("tasks", []) as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("micro-jam/daily/" + today())
	var picked: Array = []
	var n := int(config().get("per_day", 3))
	while picked.size() < n and not pool.is_empty():
		var t: Dictionary = pool.pop_at(rng.randi() % pool.size())
		var targets: Array = t.get("targets", [1])
		picked.append({
			"id": t["id"],
			"target": int(targets[rng.randi() % targets.size()]),
			"base": SaveManager.game_stat(String(t["stat"])),
			"claimed": false,
		})
	st["tasks"] = picked
	SaveManager.save_game()
	changed.emit()


func _def(id: String) -> Dictionary:
	for t in config().get("tasks", []):
		if t["id"] == id:
			return t
	return {}


## [{id, text, target, progress, done, claimed, reward}]
func tasks() -> Array:
	refresh()
	var out: Array = []
	for t in _state().get("tasks", []):
		var d := _def(String(t["id"]))
		if d.is_empty():
			continue
		var target := int(t["target"])
		var gained := SaveManager.game_stat(String(d["stat"])) - int(t["base"])
		var label := String(d.get("text_one", d["text"])) if target == 1 and d.has("text_one") else String(d["text"])
		if label.contains("%d"):
			label = label % target
		out.append({
			"id": t["id"], "text": label, "target": target,
			"progress": clampi(gained, 0, target), "done": gained >= target,
			"claimed": bool(t["claimed"]), "reward": d.get("reward", {}),
		})
	return out


func can_claim(i: int) -> bool:
	var list := tasks()
	return i >= 0 and i < list.size() and bool(list[i]["done"]) and not bool(list[i]["claimed"])


func claim_task(i: int) -> Dictionary:
	if not can_claim(i):
		return {}
	var reward: Dictionary = tasks()[i]["reward"]
	(_state()["tasks"] as Array)[i]["claimed"] = true
	_grant(reward)
	return reward


func all_claimed() -> bool:
	for t in tasks():
		if not bool(t["claimed"]):
			return false
	return true


func chest_ready() -> bool:
	return all_claimed() and not bool(_state().get("chest_claimed", false))


func chest_claimed() -> bool:
	return bool(_state().get("chest_claimed", false))


func claim_chest() -> Dictionary:
	if not chest_ready():
		return {}
	_state()["chest_claimed"] = true
	var reward: Dictionary = config().get("chest", {})
	_grant(reward)
	return reward


func chest_reward() -> Dictionary:
	return config().get("chest", {})


## Tasks ready to claim, plus the chest.
func claimable_count() -> int:
	var n := 0
	for i in tasks().size():
		if can_claim(i):
			n += 1
	if chest_ready():
		n += 1
	return n


func _grant(reward: Dictionary) -> void:
	for k in reward.keys():
		if k == "coins":
			CurrencyManager.add_coins(int(reward[k]), false)
		else:
			BoosterManager.grant(k, int(reward[k]), false)
	AchievementManager.refresh()
	SaveManager.save_game()
	changed.emit()


# --- Daily Jam -----------------------------------------------------------------

func challenge_done_today() -> bool:
	return String(_state().get("challenge_date", "")) == today()


## Days in a row the Daily Jam was cleared (still counts until tomorrow).
func streak() -> int:
	var last := String(_state().get("challenge_date", ""))
	if last == today() or last == _yesterday():
		return int(_state().get("streak", 0))
	return 0


func challenge_reward() -> int:
	var c: Dictionary = config().get("challenge", {})
	var next_streak := streak() + (0 if challenge_done_today() else 1)
	return int(c.get("reward_coins", 40)) + int(c.get("streak_bonus", 10)) * (mini(next_streak, int(c.get("streak_cap", 7))) - 1)


## The Daily Jam for today: generated from the date, sized to the player's
## progress, always a normal-tier level (no lives needed).
func challenge_level() -> Dictionary:
	var key := today()
	if _level_cache.has(key):
		return (_level_cache[key] as Dictionary).duplicate(true)
	var c: Dictionary = config().get("challenge", {})
	var base := maxi(int(c.get("min_level", 18)), ProgressionManager.current_level())
	var p := LevelGenerator.params_for(base)
	p["tier"] = "normal"
	p["level"] = 0
	var lvl := LevelGenerator.generate_with(p, hash("micro-jam/daily-jam/" + key))
	lvl["daily"] = true
	lvl["tier"] = "daily"
	_level_cache.clear()
	_level_cache[key] = lvl
	return lvl.duplicate(true)


## Records today's Daily Jam win. Returns {coins, streak}.
func complete_challenge() -> Dictionary:
	if challenge_done_today():
		return {"coins": 0, "streak": streak()}
	var coins := challenge_reward()
	var st := _state()
	st["streak"] = streak() + 1
	st["challenge_date"] = today()
	SaveManager.add_game_stat("daily_jams")
	CurrencyManager.add_coins(coins, false)
	AchievementManager.refresh()
	SaveManager.save_game()
	changed.emit()
	return {"coins": coins, "streak": int(st["streak"])}


func _yesterday() -> String:
	var d := Time.get_unix_time_from_datetime_string(today() + "T12:00:00") - 86400
	return Time.get_datetime_string_from_unix_time(int(d)).substr(0, 10)


## Seconds until local midnight (when tasks and the Daily Jam reset).
func seconds_to_reset() -> int:
	var t := Time.get_time_dict_from_system()
	return maxi(0, 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"])))


func reset_text() -> String:
	var s := seconds_to_reset()
	return "%dh %02dm" % [s / 3600, (s / 60) % 60]
