class_name Park
extends RefCounted
## The bus-park rules, as pure logic (no nodes, no animation).
##
## The lot is a w x h grid. Each bus covers 2 (microbus) or 3 (bus) cells in
## a line and faces up/right/down/left. Tapping a bus drives it forward: if
## every cell from its front to the lot edge is free it leaves the lot and
## takes the first free loading bay; otherwise it bumps the first blocker.
## Passengers wait in one queue; the front one boards the bay bus of the
## same colour that arrived first, automatically, until nobody else can
## board. A full bus departs and frees its bay. New buses take the bay that
## has been free the longest (so the bay doesn't matter to the rules, and a
## bus never waits behind one that is still pulling out).
##
## WIN: every bus has departed and the queue is empty.
## FAIL: every bay is taken and the front passenger matches none of them.
##
## Twists: sleeping drivers (first tap wakes), cone barriers (gone after
## `cone_clear` buses have left), covered passengers (colour hidden until they
## reach the front) and a tunnel that releases buses one by one onto a spot
## at the lot edge.
##
## tap()/crane() return a list of events, in order, for the view to animate.

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const UP := 0
const RIGHT := 1
const DOWN := 2
const LEFT := 3
const EMPTY := -1
const CONE := -2
const RESERVED := -3
const DEFAULT_BAYS := 5

var w := 4
var h := 5
## Bus records: {id, x, y, len, dir, color, sleep, state, boarded}.
## state: "lot" | "tunnel" (waiting inside) | "bay" | "gone".
var buses: Array = []
var grid := PackedInt32Array()
var cones: Array = []          # [[x, y], ...] still standing
var cone_clear := 3
var exits := 0                  # buses that have left the lot
var bays: Array = []            # bus id or -1, left to right
var bay_stamps: Array = []      # when each bay was last freed (lower = longer ago)
var ticks := 0                  # arrival / departure counter
var queue := PackedInt32Array()
var qpos := 0
var covered: Array = []         # queue indices whose colour is hidden
## {edge: "left"|"right"|"bottom", pos: int, order: [bus ids], next: int}
var tunnel: Dictionary = {}
var max_bays_used := 0


static func from_level(d: Dictionary) -> Park:
	var p := Park.new()
	p.load_dict(d)
	return p


static func capacity_for(length: int) -> int:
	return 6 if length >= 3 else 4


func load_dict(d: Dictionary) -> void:
	w = int(d.get("w", 4))
	h = int(d.get("h", 5))
	buses.clear()
	for b in d.get("buses", []):
		var bus: Dictionary = (b as Dictionary).duplicate(true)
		bus["id"] = int(bus.get("id", buses.size()))
		bus["x"] = int(bus.get("x", 0))
		bus["y"] = int(bus.get("y", 0))
		bus["len"] = int(bus.get("len", 2))
		bus["dir"] = int(bus.get("dir", UP))
		bus["color"] = int(bus.get("color", 0))
		bus["sleep"] = bool(bus.get("sleep", false))
		bus["state"] = String(bus.get("state", "lot"))
		bus["boarded"] = int(bus.get("boarded", 0))
		bus["arrival"] = int(bus.get("arrival", 0))
		buses.append(bus)
	cones = (d.get("cones", []) as Array).duplicate(true)
	cone_clear = int(d.get("cone_clear", 3))
	exits = int(d.get("exits", 0))
	var bc := int(d.get("bay_count", d.get("bays_n", DEFAULT_BAYS)))
	var saved_bays: Array = d.get("bays", [])
	bays.clear()
	var saved_stamps: Array = d.get("bay_stamps", [])
	bay_stamps.clear()
	for i in bc:
		bays.append(int(saved_bays[i]) if i < saved_bays.size() else EMPTY)
		bay_stamps.append(int(saved_stamps[i]) if i < saved_stamps.size() else 0)
	ticks = int(d.get("ticks", 0))
	queue = PackedInt32Array(d.get("queue", []))
	qpos = int(d.get("qpos", 0))
	covered = (d.get("covered", []) as Array).duplicate()
	tunnel = (d.get("tunnel", {}) as Dictionary).duplicate(true) if typeof(d.get("tunnel")) == TYPE_DICTIONARY else {}
	if not tunnel.is_empty():
		tunnel["next"] = int(tunnel.get("next", 0))
		tunnel["pos"] = int(tunnel.get("pos", 0))
		var ord: Array = []
		for id in tunnel.get("order", []):
			ord.append(int(id))
		tunnel["order"] = ord
	max_bays_used = int(d.get("max_bays_used", 0))
	_rebuild_grid()


func to_dict() -> Dictionary:
	return {
		"w": w, "h": h,
		"buses": buses.duplicate(true),
		"cones": cones.duplicate(true),
		"cone_clear": cone_clear,
		"exits": exits,
		"bay_count": bays.size(),
		"bays": bays.duplicate(),
		"bay_stamps": bay_stamps.duplicate(),
		"ticks": ticks,
		"queue": Array(queue),
		"qpos": qpos,
		"covered": covered.duplicate(),
		"tunnel": tunnel.duplicate(true),
		"max_bays_used": max_bays_used,
	}


func duplicate_park() -> Park:
	return Park.from_level(to_dict())


# --- Geometry ----------------------------------------------------------------

func bus(id: int) -> Dictionary:
	return buses[id]


static func cells_of(x: int, y: int, length: int, dir: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in length:
		out.append(Vector2i(x, y + i) if dir == UP or dir == DOWN else Vector2i(x + i, y))
	return out


static func front_of(x: int, y: int, length: int, dir: int) -> Vector2i:
	match dir:
		UP:
			return Vector2i(x, y)
		DOWN:
			return Vector2i(x, y + length - 1)
		RIGHT:
			return Vector2i(x + length - 1, y)
	return Vector2i(x, y)


## Cells from just past the front to the lot edge, in driving order.
static func path_of(x: int, y: int, length: int, dir: int, gw: int, gh: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := front_of(x, y, length, dir) + DIRS[dir]
	while c.x >= 0 and c.y >= 0 and c.x < gw and c.y < gh:
		out.append(c)
		c += DIRS[dir]
	return out


func cells(id: int) -> Array[Vector2i]:
	var b: Dictionary = buses[id]
	return cells_of(int(b["x"]), int(b["y"]), int(b["len"]), int(b["dir"]))


func path(id: int) -> Array[Vector2i]:
	var b: Dictionary = buses[id]
	return path_of(int(b["x"]), int(b["y"]), int(b["len"]), int(b["dir"]), w, h)


func in_lot(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func at(c: Vector2i) -> int:
	if not in_lot(c):
		return EMPTY
	return grid[c.y * w + c.x]


func bus_at(c: Vector2i) -> int:
	var v := at(c)
	return v if v >= 0 else EMPTY


func has_cone(c: Vector2i) -> bool:
	return at(c) == CONE


## Spawn placement of a tunnel bus of `length` at the tunnel spot.
static func tunnel_spawn(t: Dictionary, length: int, gw: int, gh: int) -> Dictionary:
	var pos := int(t.get("pos", 0))
	match String(t.get("edge", "left")):
		"right":
			return {"x": gw - length, "y": pos, "dir": LEFT}
		"bottom":
			return {"x": pos, "y": gh - length, "dir": UP}
	return {"x": 0, "y": pos, "dir": RIGHT}


## The 3 reserved cells of the tunnel spot (no other bus may use them).
static func tunnel_cells(t: Dictionary, gw: int, gh: int) -> Array[Vector2i]:
	if t.is_empty():
		return []
	var s := tunnel_spawn(t, 3, gw, gh)
	return cells_of(int(s["x"]), int(s["y"]), 3, int(s["dir"]))


func _rebuild_grid() -> void:
	grid = PackedInt32Array()
	grid.resize(w * h)
	grid.fill(EMPTY)
	for c in tunnel_cells(tunnel, w, h):
		grid[c.y * w + c.x] = RESERVED
	for cn in cones:
		var c := Vector2i(int(cn[0]), int(cn[1]))
		if in_lot(c):
			grid[c.y * w + c.x] = CONE
	for b in buses:
		if b["state"] == "lot":
			for c in cells(int(b["id"])):
				if in_lot(c):
					grid[c.y * w + c.x] = int(b["id"])


func _set_cells(id: int, value: int) -> void:
	for c in cells(id):
		if in_lot(c):
			grid[c.y * w + c.x] = value


# --- Queries -----------------------------------------------------------------

func capacity(id: int) -> int:
	return capacity_for(int(buses[id]["len"]))


func lot_buses() -> Array:
	var out: Array = []
	for b in buses:
		if b["state"] == "lot":
			out.append(int(b["id"]))
	return out


func remaining_buses() -> int:
	var n := 0
	for b in buses:
		if b["state"] != "gone":
			n += 1
	return n


func tunnel_waiting() -> Array:
	var out: Array = []
	if tunnel.is_empty():
		return out
	var ord: Array = tunnel["order"]
	for i in range(int(tunnel["next"]), ord.size()):
		if buses[int(ord[i])]["state"] == "tunnel":
			out.append(int(ord[i]))
	return out


## The free bay that has been empty the longest (ties: leftmost), or -1.
func free_bay() -> int:
	var best := -1
	for i in bays.size():
		if int(bays[i]) == EMPTY and (best < 0 or int(bay_stamps[i]) < int(bay_stamps[best])):
			best = i
	return best


func bays_used() -> int:
	var n := 0
	for b in bays:
		if int(b) != EMPTY:
			n += 1
	return n


func front_color() -> int:
	return queue[qpos] if qpos < queue.size() else -1


func waiting_count() -> int:
	return queue.size() - qpos


func is_covered(qi: int) -> bool:
	return qi != qpos and covered.has(qi)


## First thing in the way of `id`: {blocked, cell, blocker (bus id, CONE)}.
func blocker(id: int) -> Dictionary:
	for c in path(id):
		var v := at(c)
		# The tunnel spot (RESERVED) never blocks: no path crosses it by design.
		if v >= 0 or v == CONE:
			return {"blocked": true, "cell": c, "blocker": v}
	return {"blocked": false}


func can_exit(id: int) -> bool:
	var b: Dictionary = buses[id]
	return b["state"] == "lot" and not bool(b["sleep"]) and not bool(blocker(id)["blocked"])


## Buses that would drive out right now if tapped (and a bay is free).
func exitable() -> Array:
	var out: Array = []
	if free_bay() < 0:
		return out
	for id in lot_buses():
		if not bool(buses[id]["sleep"]) and not bool(blocker(id)["blocked"]):
			out.append(id)
	return out


## The bay whose same-colour bus (with room) arrived first, or -1.
func bay_matching(color: int) -> int:
	var best := -1
	for i in bays.size():
		var id := int(bays[i])
		if id != EMPTY and int(buses[id]["color"]) == color and int(buses[id]["boarded"]) < capacity(id):
			if best < 0 or int(buses[id]["arrival"]) < int(buses[int(bays[best])]["arrival"]):
				best = i
	return best


func is_won() -> bool:
	return qpos >= queue.size() and remaining_buses() == 0


func is_failed() -> bool:
	if qpos >= queue.size():
		return false
	return free_bay() < 0 and bay_matching(front_color()) < 0


## True when only one bay is left and the front passenger has no bus.
func is_warning() -> bool:
	if qpos >= queue.size() or is_failed():
		return false
	return bays_used() >= bays.size() - 1 and bay_matching(front_color()) < 0


# --- Actions -----------------------------------------------------------------

## A player tap on a lot bus.
func tap(id: int) -> Array:
	if id < 0 or id >= buses.size() or buses[id]["state"] != "lot" or is_failed() or is_won():
		return []
	var b: Dictionary = buses[id]
	if bool(b["sleep"]):
		b["sleep"] = false
		return [{"type": "wake", "bus": id}]
	var blk := blocker(id)
	if bool(blk["blocked"]):
		return [{"type": "blocked", "bus": id, "cell": blk["cell"], "blocker": int(blk["blocker"])}]
	if free_bay() < 0:
		return [{"type": "bays_full", "bus": id}]
	return _leave_lot(id, "drive")


## CRANE booster: lift any lot bus straight to a free bay.
func crane(id: int) -> Array:
	if id < 0 or id >= buses.size() or buses[id]["state"] != "lot" or free_bay() < 0:
		return []
	buses[id]["sleep"] = false
	return _leave_lot(id, "crane")


## EXTRA BAY booster.
func add_bay() -> int:
	bays.append(EMPTY)
	bay_stamps.append(-1)   # the new bay is used next
	return bays.size() - 1


func _leave_lot(id: int, via: String) -> Array:
	var events: Array = []
	var bay := free_bay()
	var path_cells := path(id)
	buses[id]["state"] = "bay"
	ticks += 1
	buses[id]["arrival"] = ticks
	bays[bay] = id
	exits += 1
	max_bays_used = maxi(max_bays_used, bays_used())
	_rebuild_grid()
	events.append({"type": "exit", "bus": id, "bay": bay, "via": via, "path": path_cells})
	if not cones.is_empty() and exits >= cone_clear:
		var old := cones.duplicate(true)
		cones.clear()
		_rebuild_grid()
		events.append({"type": "cones_clear", "cones": old})
	if not tunnel.is_empty():
		var ord: Array = tunnel["order"]
		var ti := ord.find(id)
		if ti >= 0:
			tunnel["next"] = ti + 1
			events.append_array(_spawn_tunnel_bus())
	events.append_array(resolve())
	return events


func _spawn_tunnel_bus() -> Array:
	var ord: Array = tunnel["order"]
	var ni := int(tunnel["next"])
	while ni < ord.size() and buses[int(ord[ni])]["state"] != "tunnel":
		ni += 1
	tunnel["next"] = ni
	if ni >= ord.size():
		return []
	var id := int(ord[ni])
	var b: Dictionary = buses[id]
	var s := tunnel_spawn(tunnel, int(b["len"]), w, h)
	b["x"] = int(s["x"])
	b["y"] = int(s["y"])
	b["dir"] = int(s["dir"])
	b["state"] = "lot"
	_set_cells(id, id)
	return [{"type": "tunnel_out", "bus": id}]


## Boards passengers until nobody else can. Returns board/depart events plus
## a final won/failed/warning status event when one applies.
func resolve() -> Array:
	var events: Array = []
	while qpos < queue.size():
		var c := queue[qpos]
		var k := bay_matching(c)
		if k < 0:
			break
		var id := int(bays[k])
		buses[id]["boarded"] = int(buses[id]["boarded"]) + 1
		events.append({"type": "board", "bus": id, "bay": k, "color": c, "qi": qpos, "seat": int(buses[id]["boarded"]) - 1})
		qpos += 1
		if int(buses[id]["boarded"]) >= capacity(id):
			buses[id]["state"] = "gone"
			bays[k] = EMPTY
			ticks += 1
			bay_stamps[k] = ticks
			events.append({"type": "depart", "bus": id, "bay": k})
	if is_won():
		events.append({"type": "won"})
	elif is_failed():
		events.append({"type": "failed"})
	elif is_warning():
		events.append({"type": "warning"})
	return events


## SHUFFLE QUEUE booster: re-orders the waiting passengers (same counts) so
## that the remaining buses can always be served. Returns false if there is
## nothing to shuffle. `rng` adds light, verified interleaving.
func shuffle_queue(rng: RandomNumberGenerator) -> bool:
	if waiting_count() < 2:
		return false
	var order := feasible_exit_order()
	var plans: Array = []
	# Try a lightly interleaved order first, then fall back to strictly grouped.
	for window in [2, 1]:
		plans.append(_plan_queue(order, window, rng))
	var cover_n := 0
	for qi in covered:
		if int(qi) > qpos:
			cover_n += 1
	for plan in plans:
		var trial := duplicate_park()
		var tail: Array = plan
		for i in tail.size():
			trial.queue[qpos + i] = int(tail[i])
		if ParkSolver.lazy_ok(trial.to_dict(), order):
			for i in tail.size():
				queue[qpos + i] = int(tail[i])
			# Keep the same number of umbrellas, spread over the new line.
			var keep: Array = []
			for qi in covered:
				if int(qi) <= qpos:
					keep.append(qi)
			var spots: Array = range(qpos + 1, queue.size())
			for i in mini(cover_n, spots.size()):
				keep.append(spots[rng.randi() % spots.size()])
			covered = keep
			return true
	return false


## Passengers for the bay buses first, then each remaining bus in `order`,
## with up to `window` buses interleaved at a time.
func _plan_queue(order: Array, window: int, rng: RandomNumberGenerator) -> Array:
	var need: Array = []   # [[color, seats_left], ...] in service order
	var in_bays: Array = []
	for k in bays.size():
		if int(bays[k]) != EMPTY:
			in_bays.append(int(bays[k]))
	in_bays.sort_custom(func(a: int, b: int) -> bool: return int(buses[a]["arrival"]) < int(buses[b]["arrival"]))
	for id in in_bays:
		need.append([int(buses[id]["color"]), capacity(id) - int(buses[id]["boarded"])])
	for id in order:
		need.append([int(buses[int(id)]["color"]), capacity(int(id))])
	var out: Array = []
	var head := 0
	# Bay buses are served first, before any interleaving.
	var bay_n := bays_used()
	while head < bay_n:
		for s in int(need[head][1]):
			out.append(int(need[head][0]))
		head += 1
	var active: Array = []
	while head < need.size() or not active.is_empty():
		while active.size() < window and head < need.size():
			active.append(need[head].duplicate())
			head += 1
		var pick := 0 if window <= 1 else (0 if rng.randf() < 0.6 else rng.randi() % active.size())
		out.append(int(active[pick][0]))
		active[pick][1] = int(active[pick][1]) - 1
		if int(active[pick][1]) <= 0:
			active.remove_at(pick)
	return out


## An order in which every remaining bus can leave the lot (always exists:
## leaving only clears the way). Tunnel buses follow their queue.
func feasible_exit_order() -> Array:
	var sim := duplicate_park()
	for b in sim.buses:
		b["sleep"] = false
	var order: Array = []
	var guard := 0
	while guard < 400:
		guard += 1
		var moved := false
		for id in sim.lot_buses():
			if not bool(sim.blocker(id)["blocked"]):
				order.append(id)
				sim.buses[id]["state"] = "gone"
				sim.exits += 1
				if not sim.cones.is_empty() and sim.exits >= sim.cone_clear:
					sim.cones.clear()
				sim._rebuild_grid()
				if not sim.tunnel.is_empty():
					var ti := (sim.tunnel["order"] as Array).find(id)
					if ti >= 0:
						sim.tunnel["next"] = ti + 1
						sim._spawn_tunnel_bus()
				moved = true
				break
		if not moved:
			break
	return order
