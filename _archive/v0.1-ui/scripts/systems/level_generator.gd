class_name LevelGenerator
extends RefCounted
## Seeded, guaranteed-solvable bus-park levels. Same level number = same
## layout, so bugs are reproducible.
##
## Construction runs in reverse: pick an exit order, then place buses one by
## one from the LAST to leave to the FIRST. A placement is accepted only if
## its exit path crosses no bus already placed (those leave later, so they
## will still be parked). Buses placed afterwards may sit in earlier paths:
## that is the jam. The passenger queue is built from the exit order with a
## controlled interleave (`window` buses boarding at once), then verified by
## playing the order lazily under the real rules (never more bays than the
## level has). A bounded solver double-checks it and semi-random playouts
## measure how punishing it is; HARD tiers keep the most punishing candidate.
##
## Levels 1-20 come from data/levels_authored.json.

const COLOR_COUNT := 8


static func tier_for(level: int) -> String:
	var r: Dictionary = GameData.difficulty()["rhythm"]
	if level <= int(r.get("plain_until", 4)):
		return "normal"
	if level % int(r.get("super_every", 10)) == 0:
		return "super"
	if level % int(r.get("hard_every", 5)) == 0:
		return "hard"
	if level > 10 and (level - 1) % int(r.get("hard_every", 5)) == 0:
		return "easy"
	return "normal"


static func level_seed(level: int) -> int:
	return hash("micro-jam/level/%d" % level)


## Interpolated ramp values plus the tier's adjustments for `level`.
static func params_for(level: int) -> Dictionary:
	var cfg := GameData.difficulty()
	var ramp: Array = cfg["ramp"]
	var lo: Dictionary = ramp[0]
	var hi: Dictionary = ramp[ramp.size() - 1]
	for i in ramp.size() - 1:
		if level >= int(ramp[i]["level"]) and level <= int(ramp[i + 1]["level"]):
			lo = ramp[i]
			hi = ramp[i + 1]
			break
	if level > int(hi["level"]):
		lo = hi
	var span := maxf(1.0, float(int(hi["level"]) - int(lo["level"])))
	var t := clampf(float(level - int(lo["level"])) / span, 0.0, 1.0)
	var lerp_key := func(k: String) -> float: return lerpf(float(lo[k]), float(hi[k]), t)
	var tier := tier_for(level)
	var tc: Dictionary = cfg["tiers"][tier]
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed(level) ^ 0x5eed
	var p := {
		"level": level,
		"tier": tier,
		"w": int(round(lerp_key.call("w"))),
		"h": int(round(lerp_key.call("h"))),
		"buses": int(round(lerp_key.call("buses"))) + int(tc.get("bus_delta", 0)) + rng.randi_range(0, int(cfg.get("bus_jitter", 1))),
		"colors": int(round(lerp_key.call("colors"))),
		"big": float(lerp_key.call("big")),
		"window": int(round(lerp_key.call("window"))) + int(tc.get("window_delta", 0)),
		"bays": Park.DEFAULT_BAYS,
		"twists": [],
	}
	# A lot never gets fuller than this share of its cells.
	var cap := int(float(p["w"] * p["h"]) * float(cfg.get("max_fill", 0.82)) / (2.0 + float(p["big"])))
	p["buses"] = clampi(int(p["buses"]), 3, mini(cap, int(cfg.get("max_buses", 26))))
	p["colors"] = clampi(int(p["colors"]), 2, mini(COLOR_COUNT, int(p["buses"])))
	p["window"] = clampi(int(p["window"]), 1, 3)
	var twists: Dictionary = cfg["twists"]
	var chance := float(cfg.get("twist_chance", 0.5))
	for id in ["sleep", "cones", "covered", "tunnel"]:
		var from := int(twists[id]["from"])
		if level < from:
			continue
		if level == from or rng.randf() < chance:
			(p["twists"] as Array).append(id)
	return p


static func generate(level: int) -> Dictionary:
	var authored := GameData.authored_level(level)
	if not authored.is_empty():
		var a := authored.duplicate(true)
		a["tier"] = String(a.get("tier", tier_for(level)))
		return a
	return generate_with(params_for(level), level_seed(level))


## Builds a level from explicit parameters (tools/author_levels.gd uses this).
static func generate_with(p: Dictionary, seed_value: int) -> Dictionary:
	var cfg := GameData.difficulty()
	var gen: Dictionary = cfg["generator"]
	var tc: Dictionary = cfg["tiers"][String(p.get("tier", "normal"))]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var want := int(tc.get("candidates", 3))
	var candidates: Array = []
	var attempts := 0
	var buses := int(p["buses"])
	while candidates.size() < want:
		attempts += 1
		var trial := p.duplicate(true)
		trial["buses"] = buses
		var lvl := _try_build(rng, trial)
		if not lvl.is_empty():
			lvl["fail_rate"] = ParkSolver.fail_rate(lvl, int(gen.get("playouts", 24)), rng.randi())
			candidates.append(lvl)
		elif attempts % int(gen.get("shrink_every", 8)) == 0 and buses > 3:
			buses -= 1   # too crowded to place: one bus fewer
		if attempts >= int(gen.get("max_attempts", 60)) and not candidates.is_empty():
			break
		if attempts > 400:
			break
	if candidates.is_empty():
		push_error("LevelGenerator: could not build level %d" % int(p["level"]))
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["fail_rate"]) < float(b["fail_rate"]))
	# Preference order for the tier, then the first one the bounded solver
	# verifies (every candidate is already solvable by construction).
	var order: Array = range(candidates.size())
	match String(tc.get("pick", "median")):
		"max":
			order.reverse()
		"median":
			var mid := candidates.size() / 2
			order.sort_custom(func(a: int, b: int) -> bool: return absi(a - mid) < absi(b - mid))
	var chosen: Dictionary = candidates[order[0]]
	for i in order:
		var cand: Dictionary = candidates[i]
		var check := ParkSolver.solve(cand, int(gen.get("node_budget", 20000)))
		cand["verified"] = bool(check["solvable"])
		cand["solver_nodes"] = int(check["nodes"])
		cand["dead_ends"] = int(check["fails"])
		if cand["verified"]:
			chosen = cand
			break
	return chosen


static func _try_build(rng: RandomNumberGenerator, p: Dictionary) -> Dictionary:
	var cfg := GameData.difficulty()
	var tw: Dictionary = cfg["twists"]
	var w := int(p["w"])
	var h := int(p["h"])
	var n := int(p["buses"])
	var twists: Array = p.get("twists", [])
	var grid := PackedInt32Array()
	grid.resize(w * h)
	grid.fill(Park.EMPTY)
	var path_count := PackedInt32Array()
	path_count.resize(w * h)
	path_count.fill(0)

	# Tunnel: a reserved 3-cell spot at a lot edge; its buses leave in order.
	var tunnel := {}
	var tunnel_path := {}
	var tunnel_idx: Array = []
	if twists.has("tunnel"):
		var edge: String = ["left", "right", "bottom"][rng.randi() % 3]
		var span := w if edge == "bottom" else h
		tunnel = {"edge": edge, "pos": rng.randi_range(1, span - 2), "order": [], "next": 0}
		for c in Park.tunnel_cells(tunnel, w, h):
			grid[c.y * w + c.x] = Park.RESERVED
		var sp := Park.tunnel_spawn(tunnel, 3, w, h)
		for c in Park.path_of(int(sp["x"]), int(sp["y"]), 3, int(sp["dir"]), w, h):
			tunnel_path[c] = true
		var tn := clampi(rng.randi_range(int(tw["tunnel"]["buses_min"]), int(tw["tunnel"]["buses_max"])), 1, maxi(1, n / 3))
		var pool: Array = range(maxi(1, n / 4), n)
		for k in tn:
			if pool.is_empty():
				break
			tunnel_idx.append(pool.pop_at(rng.randi() % pool.size()))
		tunnel_idx.sort()
	var t_first: int = tunnel_idx[0] if not tunnel_idx.is_empty() else n

	# Cones: barrier tiles that vanish after `cone_clear` buses have left.
	var cone_clear := int(tw["cones"].get("clear_after", 3))
	var cones: Array = []
	if twists.has("cones"):
		var k := rng.randi_range(1, int(tw["cones"].get("max", 3)))
		for i in k * 6:
			if cones.size() >= k:
				break
			var c := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(1, h - 2))
			if grid[c.y * w + c.x] == Park.EMPTY and not tunnel_path.has(c):
				grid[c.y * w + c.x] = Park.CONE
				cones.append([c.x, c.y])

	# Place buses from the last to leave (i = n-1) to the first (i = 0).
	var placed: Array = []   # index = exit order
	placed.resize(n)
	var big := float(p["big"])
	for i in range(n - 1, -1, -1):
		var want_len := 3 if rng.randf() < big else 2
		if tunnel_idx.has(i):
			var sp := Park.tunnel_spawn(tunnel, want_len, w, h)
			placed[i] = {"len": want_len, "x": int(sp["x"]), "y": int(sp["y"]), "dir": int(sp["dir"]), "tunnel": true}
			continue
		var best := {}
		var best_score := -INF
		for length in [want_len, 5 - want_len]:
			for y in h:
				for x in w:
					for dir in 4:
						var cs := Park.cells_of(x, y, length, dir)
						var ok := true
						for c in cs:
							if c.x >= w or c.y >= h or grid[c.y * w + c.x] != Park.EMPTY:
								ok = false
								break
							if i > t_first and tunnel_path.has(c):
								ok = false
								break
						if not ok:
							continue
						var pth := Park.path_of(x, y, length, dir, w, h)
						for c in pth:
							var v := grid[c.y * w + c.x]
							if v >= 0 or v == Park.RESERVED or (v == Park.CONE and i < cone_clear):
								ok = false
								break
						if not ok:
							continue
						var score := 0.0
						for c in cs:
							score += 3.0 * path_count[c.y * w + c.x]
							for d in Park.DIRS:
								var nb: Vector2i = c + d
								if nb.x >= 0 and nb.y >= 0 and nb.x < w and nb.y < h and grid[nb.y * w + nb.x] >= 0:
									score += 0.6
						if pth.is_empty():
							score -= 1.5   # parked right at the edge: no challenge
						score += rng.randf() * 3.0
						if score > best_score:
							best_score = score
							best = {"len": length, "x": x, "y": y, "dir": dir}
			if not best.is_empty():
				break
		if best.is_empty():
			return {}
		placed[i] = best
		for c in Park.cells_of(int(best["x"]), int(best["y"]), int(best["len"]), int(best["dir"])):
			grid[c.y * w + c.x] = i
		for c in Park.path_of(int(best["x"]), int(best["y"]), int(best["len"]), int(best["dir"]), w, h):
			path_count[c.y * w + c.x] += 1

	# Colours: every colour at least once, then random.
	var colors := int(p["colors"])
	var palette: Array = range(COLOR_COUNT)
	_shuffle(palette, rng)
	palette = palette.slice(0, colors)
	var col_list: Array = palette.duplicate()
	while col_list.size() < n:
		col_list.append(palette[rng.randi() % colors])
	_shuffle(col_list, rng)

	# Bus ids by position (top-left first), tunnel buses last in tunnel order,
	# so the ids don't give the exit order away.
	var regular: Array = []
	for i in n:
		if not tunnel_idx.has(i):
			regular.append(i)
	regular.sort_custom(func(a: int, b: int) -> bool:
		var pa: Dictionary = placed[a]
		var pb: Dictionary = placed[b]
		return int(pa["y"]) * 100 + int(pa["x"]) < int(pb["y"]) * 100 + int(pb["x"]))
	var id_of := {}
	for i in regular:
		id_of[i] = id_of.size()
	for i in tunnel_idx:
		id_of[i] = id_of.size()
	var bus_list: Array = []
	bus_list.resize(n)
	for i in n:
		var pl: Dictionary = placed[i]
		var is_t := bool(pl.get("tunnel", false))
		bus_list[int(id_of[i])] = {
			"id": int(id_of[i]), "x": int(pl["x"]), "y": int(pl["y"]), "len": int(pl["len"]),
			"dir": int(pl["dir"]), "color": int(col_list[i]), "sleep": false,
			"state": "tunnel" if is_t else "lot",
		}
	var solution: Array = []
	for i in n:
		solution.append(int(id_of[i]))
	if not tunnel.is_empty():
		var ord: Array = []
		for i in tunnel_idx:
			ord.append(int(id_of[i]))
		tunnel["order"] = ord
		# The first tunnel bus waits on the spot from the start.
		bus_list[int(ord[0])]["state"] = "lot"

	# Sleeping drivers (never the very first bus out).
	if twists.has("sleep"):
		var k := rng.randi_range(1, int(tw["sleep"].get("max", 3)))
		var pool: Array = regular.duplicate()
		pool.erase(0)
		for j in mini(k, pool.size()):
			var pick: int = pool.pop_at(rng.randi() % pool.size())
			bus_list[int(id_of[pick])]["sleep"] = true

	# Queue: up to `window` buses board at the same time.
	var window := int(p["window"])
	var queue: Array = []
	var active: Array = []
	var head := 0
	while head < n or not active.is_empty():
		while active.size() < window and head < n:
			var b: Dictionary = bus_list[solution[head]]
			active.append([int(b["color"]), Park.capacity_for(int(b["len"]))])
			head += 1
		var pick := 0 if rng.randf() < 0.45 else rng.randi() % active.size()
		queue.append(int(active[pick][0]))
		active[pick][1] = int(active[pick][1]) - 1
		if int(active[pick][1]) <= 0:
			active.remove_at(pick)

	var covered: Array = []
	if twists.has("covered"):
		var ratio := float(tw["covered"].get("ratio", 0.35))
		for qi in range(1, queue.size()):
			if rng.randf() < ratio:
				covered.append(qi)

	var lvl := {
		"level": int(p["level"]),
		"tier": String(p.get("tier", "normal")),
		"w": w, "h": h,
		"bay_count": int(p.get("bays", Park.DEFAULT_BAYS)),
		"buses": bus_list,
		"queue": queue,
		"covered": covered,
		"cones": cones,
		"cone_clear": cone_clear,
		"tunnel": tunnel,
		"twists": _present_twists(twists, cones, tunnel, covered),
		"solution": solution,
	}
	var run := ParkSolver.lazy_run(lvl, solution)
	if not bool(run["ok"]) or int(run["max_bays"]) > int(lvl["bay_count"]):
		return {}
	lvl["plan_bays"] = int(run["max_bays"])
	return lvl


static func _present_twists(twists: Array, cones: Array, tunnel: Dictionary, covered: Array) -> Array:
	var out: Array = []
	for t in twists:
		if t == "cones" and cones.is_empty():
			continue
		if t == "tunnel" and tunnel.is_empty():
			continue
		if t == "covered" and covered.is_empty():
			continue
		out.append(t)
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
