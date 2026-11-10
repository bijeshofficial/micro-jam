extends SceneTree
## Searches real generated levels for moments worth filming and writes them to
## tools/shorts/moments.json. Everything is checked with the real rules
## (Park) and the solver, so a "only one bus works" clip is actually true.
##   godot --headless --path . --script res://tools/shorts/find_moments.gd
##
## pick:    one free bay, 3+ drivable buses, exactly one keeps the level winnable.
## cascade: every other bay holds a waiting bus; one tap makes them all fill and leave.
## mystery: a grey bus with one blocker that can drive away, so it can be revealed.

const OUT := "res://tools/shorts/moments.json"
const BUDGET := 6000
const CLEAN := ["cones", "covered", "sleep", "taxi"]   # twists that don't confuse a short clip

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	GameData.preload_all()
	rng.seed = 2026
	var picks: Array = []
	var cascades: Array = []
	var mysteries: Array = []
	var t0 := Time.get_ticks_msec()
	for n in range(25, 320):
		if Time.get_ticks_msec() - t0 > 480000:
			break
		var lvl := LevelGenerator.generate(n)
		if lvl.is_empty():
			continue
		var twists: Array = lvl.get("twists", [])
		var count: int = (lvl["buses"] as Array).size()
		if twists.has("mystery"):
			mysteries.append_array(_mystery(n, lvl))
		if twists.all(func(t: String) -> bool: return CLEAN.has(t)) and count >= 12 and count <= 30:
			if picks.size() < 40:
				var m := _pick(n, lvl)
				if not m.is_empty():
					picks.append(m)
			if cascades.size() < 40:
				var c := _cascade(n, lvl)
				if not c.is_empty():
					cascades.append(c)
		if n % 25 == 0:
			print("L%d  picks %d  cascades %d  mysteries %d  (%d s)" % [n, picks.size(), cascades.size(), mysteries.size(), (Time.get_ticks_msec() - t0) / 1000])
	picks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	cascades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	mysteries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"pick": picks, "cascade": cascades, "mystery": mysteries}))
	f.close()
	print("FOUND picks %d, cascades %d, mysteries %d in %d s" % [picks.size(), cascades.size(), mysteries.size(), (Time.get_ticks_msec() - t0) / 1000])
	for m in picks.slice(0, 6):
		print("  pick L%d  trap=%s  left=%d  rows=%d  chain=%d  score=%.1f" % [m["level"], m["trap"], m["vehicles_left"], m["rows"], m["right_departs"], m["score"]])
	for m in cascades.slice(0, 6):
		print("  cascade L%d  departs=%d  bays=%d  left=%d  score=%.1f" % [m["level"], m["departs"], m["bays"], m["vehicles_left"], m["score"]])
	quit()


func _copy(p: Park) -> Park:
	return Park.from_level(p.to_dict())


func _winnable(p: Park) -> int:   # 1 yes, 0 proven no, -1 ran out of budget
	if p.is_failed():
		return 0
	var r := ParkSolver.solve(p.to_dict(), BUDGET)
	if bool(r["solvable"]):
		return 1
	return -1 if bool(r["aborted"]) else 0


## Walks from the level's start, parking buses the line doesn't want yet (each
## step stays winnable), until one bay is left. Returns the tap list, or [].
func _walk(p: Park) -> Array:
	var path: Array = []
	var guard := 0
	while p.bays_used() < p.bays.size() - 1 and guard < 14:
		guard += 1
		var ex: Array = p.exitable()
		var front := p.front_color()
		var wait: Array = ex.filter(func(id: int) -> bool: return int(p.bus(id)["color"]) != front)
		var pool: Array = wait if not wait.is_empty() and rng.randf() < 0.85 else ex
		if pool.is_empty():
			return []
		var id: int = pool[rng.randi() % pool.size()]
		var q := _copy(p)
		q.tap(id)
		if _winnable(q) != 1:
			continue
		p.load_dict(q.to_dict())
		path.append(id)
	return path if p.bays_used() == p.bays.size() - 1 else []


func _spread(p: Park, ids: Array) -> bool:
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Dictionary = p.bus(ids[i])
			var b: Dictionary = p.bus(ids[j])
			if absi(int(a["x"]) - int(b["x"])) + absi(int(a["y"]) - int(b["y"])) < 3:
				return false
	return true


func _pick(n: int, lvl: Dictionary) -> Dictionary:
	var best := {}
	for w in 10:
		var p := Park.from_level(lvl)
		var path := _walk(p)
		if path.is_empty() or p.is_failed() or p.bay_matching(p.front_color()) >= 0:
			continue
		var ex: Array = p.exitable()
		if ex.size() < 3:
			continue
		var right: Array = []
		var wrong: Array = []
		var unknown := false
		for id in ex:
			var q := _copy(p)
			q.tap(id)
			var w2 := _winnable(q)
			if w2 == 1:
				right.append(id)
			elif w2 == 0:
				wrong.append(id)
			else:
				unknown = true
		if unknown or right.size() != 1 or wrong.size() < 2:
			continue
		# Show the right bus and two wrong ones, far enough apart to label.
		var trap_ids: Array = wrong.filter(func(id: int) -> bool: return int(p.bus(id)["color"]) == p.front_color())
		var wrong_pool: Array = trap_ids + wrong.filter(func(id: int) -> bool: return not trap_ids.has(id))
		var opts: Array = [right[0], wrong_pool[0], wrong_pool[1]]
		if not _spread(p, opts):
			continue
		var cols := {}
		for id in opts:
			cols[int(p.bus(id)["color"])] = true
		var left: int = p.lot_buses().size()
		var trap := not trap_ids.is_empty()
		# The clip ends on the right bus: a chain of buses leaving is the payoff.
		var after := _copy(p)
		var right_departs := 0
		for e in after.tap(right[0]):
			if String(e["type"]) == "depart":
				right_departs += 1
		if right_departs < 1:
			continue
		var score := 10.0 * cols.size() + 0.5 * left + (25.0 if trap else 0.0) + 18.0 * right_departs - (25.0 if p.h >= 10 else 0.0)
		if best.is_empty() or score > float(best["score"]):
			# Fails how fast? Play the wrong bus on until the level dies.
			var fail_path := _fail_path(p, wrong_pool[0])
			if fail_path.is_empty():
				continue
			best = {"kind": "pick", "level": n, "start": p.to_dict(), "options": opts, "right": right[0], "wrong": wrong_pool[0],
				"fail_path": fail_path, "right_departs": right_departs, "trap": trap, "vehicles_left": left, "rows": p.h, "score": score}
	return best


## Shortest way the level ends after tapping `first` (tries a few random games).
func _fail_path(p: Park, first: int) -> Array:
	var best: Array = []
	for t in 12:
		var q := _copy(p)
		var path: Array = [first]
		q.tap(first)
		var guard := 0
		while not q.is_failed() and guard < 6:
			guard += 1
			var ex: Array = q.exitable()
			if ex.is_empty():
				break
			var id: int = ex[rng.randi() % ex.size()]
			q.tap(id)
			path.append(id)
		if q.is_failed() and (best.is_empty() or path.size() < best.size()):
			best = path
	return best if best.size() <= 4 else []


func _cascade(n: int, lvl: Dictionary) -> Dictionary:
	var best := {}
	for w in 30:
		var p := Park.from_level(lvl)
		var path := _walk(p)
		if path.is_empty() or path.size() > 7 or p.is_failed():
			continue
		for id in p.exitable():
			if int(p.bus(id)["color"]) != p.front_color():
				continue
			var q := _copy(p)
			var departs := 0
			for e in q.tap(id):
				if String(e["type"]) == "depart":
					departs += 1
			if departs < p.bays.size() - 1:
				continue
			var left: int = q.lot_buses().size()
			var score := 20.0 * departs + 0.5 * left - float(path.size()) - (25.0 if p.h >= 10 else 0.0)
			if best.is_empty() or score > float(best["score"]):
				best = {"kind": "cascade", "level": n, "path": path, "trigger": id, "departs": departs, "bays": p.bays.size(), "vehicles_left": left, "score": score}
	return best


func _mystery(n: int, lvl: Dictionary) -> Array:
	var out: Array = []
	var p := Park.from_level(lvl)
	var pairs: Array = []
	var used := {}
	for b in p.buses:
		var id := int(b["id"])
		if not bool(b["mystery"]) or b["state"] != "lot":
			continue
		var blockers := {}
		for c in p.path(id):
			var v := p.at(c)
			if v >= 0:
				blockers[v] = true
			elif v == Park.CONE:
				blockers[-99] = true
		if blockers.size() != 1 or blockers.has(-99):
			continue
		var bl: int = blockers.keys()[0]
		var bb: Dictionary = p.bus(bl)
		if used.has(bl) or bool(bb["mystery"]) or not p.exitable().has(bl):
			continue
		used[bl] = true
		pairs.append({"mystery": id, "blocker": bl, "color": int(b["color"])})
	if pairs.is_empty():
		return out
	# Single reveal, and how it plays: does the line want that colour next?
	for pair in pairs:
		var q := _copy(p)
		q.tap(int(pair["blocker"]))
		var wanted: bool = not q.is_failed() and q.front_color() == int(pair["color"]) and q.bay_matching(q.front_color()) < 0
		out.append({"kind": "mystery", "level": n, "pairs": [pair], "wanted": wanted, "failed": q.is_failed(),
			"score": (40.0 if wanted else 10.0) + rng.randf()})
	if pairs.size() >= 3:
		var q := _copy(p)
		var ok := true
		for pair in pairs.slice(0, 3):
			q.tap(int(pair["blocker"]))
			ok = ok and not q.is_failed()
		if ok:
			out.append({"kind": "mystery", "level": n, "pairs": pairs.slice(0, 3), "wanted": false, "failed": false, "score": 50.0 + rng.randf()})
	return out
