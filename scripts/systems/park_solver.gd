class_name ParkSolver
extends RefCounted
## Fast search over bus-park states, used by the level generator (verify a
## level and measure how punishing it is), the generator test, idle hints
## and the Shuffle Queue booster.
##
## A compact copy of the rules: buses never move except to leave, so the lot
## is a bitmask of buses still parked (lot + tunnel), and each bus's exit
## path is a precomputed list of cell indices. Sleeping drivers are ignored
## (waking is free) and covered passengers don't change the rules. Bays
## are kept as a list in arrival order (which bay a bus uses doesn't matter
## to the rules), so equivalent states share one memo key.


class Sim:
	var n := 0
	var w := 0
	var h := 0
	var color := PackedInt32Array()
	var cap := PackedInt32Array()
	var paths: Array = []                  # bus -> PackedInt32Array of cells
	var owner := PackedInt32Array()        # cell -> regular lot bus (or -1)
	var cone := PackedByteArray()          # cell -> 1 while cones stand
	var cone_clear := 0
	var tunnel_order := PackedInt32Array()
	var is_tunnel := PackedByteArray()
	var queue := PackedInt32Array()
	var bay_count := 5
	# Starting state.
	var mask := 0
	var bays := PackedInt32Array()         # [bus, boarded] pairs, arrival order
	var qpos := 0
	var exits := 0


## Builds a Sim from a level / Park.to_dict() dictionary.
static func build(d: Dictionary) -> Sim:
	var s := Sim.new()
	s.w = int(d.get("w", 4))
	s.h = int(d.get("h", 5))
	var bl: Array = d.get("buses", [])
	s.n = bl.size()
	s.color.resize(s.n)
	s.cap.resize(s.n)
	s.is_tunnel.resize(s.n)
	s.is_tunnel.fill(0)
	s.owner.resize(s.w * s.h)
	s.owner.fill(-1)
	s.cone.resize(s.w * s.h)
	s.cone.fill(0)
	var t: Dictionary = d.get("tunnel", {}) if typeof(d.get("tunnel")) == TYPE_DICTIONARY else {}
	if not t.is_empty():
		for id in t.get("order", []):
			s.tunnel_order.append(int(id))
			s.is_tunnel[int(id)] = 1
	for i in s.n:
		var b: Dictionary = bl[i]
		var length := int(b.get("len", 2))
		s.color[i] = int(b.get("color", 0))
		s.cap[i] = Park.capacity_for(length)
		var x := int(b.get("x", 0))
		var y := int(b.get("y", 0))
		var dir := int(b.get("dir", 0))
		var state := String(b.get("state", "lot"))
		if s.is_tunnel[i] == 1 and state == "tunnel":
			var sp := Park.tunnel_spawn(t, length, s.w, s.h)
			x = int(sp["x"])
			y = int(sp["y"])
			dir = int(sp["dir"])
		var pc := PackedInt32Array()
		for c in Park.path_of(x, y, length, dir, s.w, s.h):
			pc.append(c.y * s.w + c.x)
		s.paths.append(pc)
		if state == "lot" or state == "tunnel":
			s.mask |= 1 << i
			if s.is_tunnel[i] == 0:
				for c in Park.cells_of(x, y, length, dir):
					s.owner[c.y * s.w + c.x] = i
	for cn in d.get("cones", []):
		s.cone[int(cn[1]) * s.w + int(cn[0])] = 1
	s.cone_clear = int(d.get("cone_clear", 3))
	s.exits = int(d.get("exits", 0))
	s.queue = PackedInt32Array(d.get("queue", []))
	s.qpos = int(d.get("qpos", 0))
	s.bay_count = int(d.get("bay_count", Park.DEFAULT_BAYS))
	var occupied: Array = []
	for id in d.get("bays", []):
		if int(id) >= 0:
			occupied.append(int(id))
	occupied.sort_custom(func(a: int, b: int) -> bool: return int(bl[a].get("arrival", 0)) < int(bl[b].get("arrival", 0)))
	for id in occupied:
		s.bays.append(id)
		s.bays.append(int(bl[id].get("boarded", 0)))
	return s


# --- State: [mask, qpos, exits, bays] ----------------------------------------

static func initial(s: Sim) -> Array:
	var st: Array = [s.mask, s.qpos, s.exits, s.bays.duplicate()]
	_resolve(s, st)
	return st


static func _copy(st: Array) -> Array:
	return [st[0], st[1], st[2], (st[3] as PackedInt32Array).duplicate()]


static func _resolve(s: Sim, st: Array) -> void:
	var bays: PackedInt32Array = st[3]
	var q: int = st[1]
	while q < s.queue.size():
		var c := s.queue[q]
		var k := -1
		for i in bays.size() / 2:
			var id := bays[i * 2]
			if s.color[id] == c and bays[i * 2 + 1] < s.cap[id]:
				k = i
				break
		if k < 0:
			break
		bays[k * 2 + 1] += 1
		q += 1
		if bays[k * 2 + 1] >= s.cap[bays[k * 2]]:
			bays.remove_at(k * 2 + 1)
			bays.remove_at(k * 2)
	st[1] = q
	st[3] = bays


static func has_free_bay(s: Sim, st: Array) -> bool:
	return (st[3] as PackedInt32Array).size() / 2 < s.bay_count


static func bays_used(_s: Sim, st: Array) -> int:
	return (st[3] as PackedInt32Array).size() / 2


static func is_won(s: Sim, st: Array) -> bool:
	return int(st[0]) == 0 and int(st[1]) >= s.queue.size() and bays_used(s, st) == 0


static func is_failed(s: Sim, st: Array) -> bool:
	return int(st[1]) < s.queue.size() and not has_free_bay(s, st)


static func tunnel_head(s: Sim, mask: int) -> int:
	for id in s.tunnel_order:
		if mask & (1 << id):
			return id
	return -1


static func can_exit(s: Sim, st: Array, b: int) -> bool:
	var mask: int = st[0]
	if not (mask & (1 << b)):
		return false
	if s.is_tunnel[b] == 1 and tunnel_head(s, mask) != b:
		return false
	var cones_up: bool = int(st[2]) < s.cone_clear
	for c in s.paths[b]:
		var o := s.owner[c]
		if o >= 0 and (mask & (1 << o)):
			return false
		if cones_up and s.cone[c] == 1:
			return false
	return true


static func moves(s: Sim, st: Array) -> Array:
	var out: Array = []
	if not has_free_bay(s, st):
		return out
	for b in s.n:
		if can_exit(s, st, b):
			out.append(b)
	return out


static func apply(s: Sim, st: Array, b: int) -> Array:
	var nx := _copy(st)
	var bays: PackedInt32Array = nx[3]
	bays.append(b)
	bays.append(0)
	nx[3] = bays
	nx[0] = int(nx[0]) & ~(1 << b)
	nx[2] = int(nx[2]) + 1
	_resolve(s, nx)
	return nx


# --- Search ------------------------------------------------------------------

## Depth-first search with memo. Returns {solvable, path (bus ids), nodes,
## fails (dead ends met), aborted (budget hit)}.
static func solve(d: Dictionary, budget: int = 20000) -> Dictionary:
	var s := build(d)
	var ctx := {"nodes": 0, "fails": 0, "budget": budget, "seen": {}, "path": []}
	var ok := _dfs(s, initial(s), ctx)
	var p: Array = ctx["path"]
	p.reverse()
	return {"solvable": ok, "path": p, "nodes": int(ctx["nodes"]), "fails": int(ctx["fails"]), "aborted": int(ctx["nodes"]) > budget}


static func _dfs(s: Sim, st: Array, ctx: Dictionary) -> bool:
	ctx["nodes"] = int(ctx["nodes"]) + 1
	if int(ctx["nodes"]) > int(ctx["budget"]):
		return false
	if is_won(s, st):
		return true
	if is_failed(s, st):
		ctx["fails"] = int(ctx["fails"]) + 1
		return false
	var key := st.hash()
	var seen: Dictionary = ctx["seen"]
	if seen.has(key):
		return false
	seen[key] = true
	var mv := moves(s, st)
	if mv.is_empty():
		ctx["fails"] = int(ctx["fails"]) + 1
		return false
	# Try the buses whose colour is needed soonest first.
	var scored: Array = []
	for b in mv:
		scored.append([_need_rank(s, st, b), b])
	scored.sort_custom(func(a: Array, c: Array) -> bool: return a[0] < c[0])
	for e in scored:
		var b: int = e[1]
		if _dfs(s, apply(s, st, b), ctx):
			(ctx["path"] as Array).append(b)
			return true
	return false


## How soon the queue needs this bus's colour (seats already promised to
## same-colour bay buses are skipped).
static func _need_rank(s: Sim, st: Array, b: int) -> int:
	var c := s.color[b]
	var bays: PackedInt32Array = st[3]
	var promised := 0
	for i in bays.size() / 2:
		var id := bays[i * 2]
		if s.color[id] == c:
			promised += s.cap[id] - bays[i * 2 + 1]
	var seen := 0
	for q in range(int(st[1]), s.queue.size()):
		if s.queue[q] == c:
			seen += 1
			if seen > promised:
				return q - int(st[1])
	return 100000


## First move of a solution from the current state, or -1.
static func hint(d: Dictionary, budget: int = 6000) -> int:
	var r := solve(d, budget)
	if bool(r["solvable"]) and not (r["path"] as Array).is_empty():
		return int(r["path"][0])
	var s := build(d)
	var st := initial(s)
	var mv := moves(s, st)
	if mv.is_empty():
		return -1
	var best: int = mv[0]
	for b in mv:
		if _need_rank(s, st, b) < _need_rank(s, st, best):
			best = b
	return best


## Plays `order` lazily: a bus is only sent out when the front passenger
## can't board. Returns {ok, max_bays}.
static func lazy_run(d: Dictionary, order: Array) -> Dictionary:
	var s := build(d)
	var st := initial(s)
	var used := bays_used(s, st)
	var i := 0
	var guard := 0
	while guard < 1000:
		guard += 1
		if is_won(s, st):
			return {"ok": true, "max_bays": used}
		if is_failed(s, st):
			return {"ok": false, "max_bays": used}
		while i < order.size() and not (int(st[0]) & (1 << int(order[i]))):
			i += 1
		if i >= order.size():
			return {"ok": false, "max_bays": used}
		var b := int(order[i])
		if not can_exit(s, st, b) or not has_free_bay(s, st):
			return {"ok": false, "max_bays": used}
		# Busiest moment: right after the tap, before anyone boards.
		used = maxi(used, bays_used(s, st) + 1)
		st = apply(s, st, b)
		i += 1
	return {"ok": false, "max_bays": used}


static func lazy_ok(d: Dictionary, order: Array) -> bool:
	return bool(lazy_run(d, order)["ok"])


## Share of simulated players that fail: a reasonable but imperfect
## player who prefers a bus matching the front passenger, then one whose
## colour is coming up soon, digs out buses blocking a soon-needed bus, and
## makes a random tap `mistakes` of the time.
## Higher = more punishing level.
static func fail_rate(d: Dictionary, playouts: int, seed_value: int, mistakes: float = 0.2, lookahead: int = 8) -> float:
	var s := build(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var fails := 0
	for p in playouts:
		var st := initial(s)
		var guard := 0
		while guard < 500:
			guard += 1
			if is_won(s, st):
				break
			if is_failed(s, st):
				fails += 1
				break
			var mv := moves(s, st)
			if mv.is_empty():
				fails += 1
				break
			var pick: int = mv[rng.randi() % mv.size()]
			if rng.randf() >= mistakes:
				var q := int(st[1])
				var soon := {}
				for k in range(q, mini(q + lookahead, s.queue.size())):
					if not soon.has(s.queue[k]):
						soon[s.queue[k]] = k - q
				# Digging: a bus parked in the way of a soon-needed bus is
				# worth moving, like a real player clearing a path.
				var dig := {}
				var mask: int = st[0]
				for x in s.n:
					if not (mask & (1 << x)) or not soon.has(s.color[x]) or can_exit(s, st, x):
						continue
					for cell in s.paths[x]:
						var o := s.owner[cell]
						if o >= 0 and (mask & (1 << o)):
							dig[o] = maxf(float(dig.get(o, 0.0)), 2.2 - float(soon[s.color[x]]) * 0.15)
				var best := -INF
				for b in mv:
					var sc := rng.randf() * 0.5 + float(dig.get(b, 0.0))
					var c := s.color[b]
					if soon.has(c):
						sc += 3.0 - float(soon[c]) * 0.25
					if sc > best:
						best = sc
						pick = b
			st = apply(s, st, pick)
	return float(fails) / float(maxi(1, playouts))
