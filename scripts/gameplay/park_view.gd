class_name ParkView
extends Node2D
## Draws the bus park (sidewalk + queue, departure road, loading bays, ring
## road and the parking lot) and animates the events Park returns.
##
## The rules resolve instantly; this view plays them back on its own clock.
## Buses wait on the road if their bay is still being vacated, passengers
## hop one after another and full buses honk and drive off. The player can
## keep tapping while the animation catches up; `idle()` says when it has.

const BUS_SCENE := preload("res://scenes/components/bus_visual.tscn")
const PASSENGER_SCENE := preload("res://scenes/components/passenger_visual.tscn")
const KHALASI_SCENE := preload("res://scenes/components/khalasi_visual.tscn")

const SIDEWALK_H := 150.0
const ROAD_H := 100.0
const DRIVE_SPEED := 2100.0
const HOP_TIME := 0.3
const HOP_GAP := 0.11
const QUEUE_X0 := 196.0
const QUEUE_DX := 74.0
const VISIBLE := 11

signal timeline_done

var park: Park
var level := 1
var theme: Dictionary = ParkTheme.get_theme("theme_morning")
var livery := "stripes"
var outfit := "everyday"

var width := 1080.0
var top := 0.0
var bottom := 1600.0
var lot_rect := Rect2()
## Road and bay sizes; big lots (10+ rows) get a slimmer ring road and
## shorter bays so the buses stay as large as possible.
var ring_w := 84.0
var bay_h := 300.0
var bay_cell := 100.0
var cell := 100.0
var ring := Rect2()
var bays_top := 0.0
var road_y := 0.0
var walk_y := 0.0

var buses: Dictionary = {}          # id -> BusVisual
var queue_nodes: Array = []         # PassengerVisual, front first
var khalasi: KhalasiVisual
var cone_scale: Dictionary = {}     # Vector2i -> scale (animated)
var warning := 0.0

var clock := 0.0
var busy_until := 0.0
var bay_free_at: Array = []
var arrive_at: Dictionary = {}
var queue_t := -10.0
var bus_busy: Dictionary = {}       # id -> clock time it is free again

var _bus_layer: Node2D
var _people_layer: Node2D
var _fx_layer: Node2D
var _more_label: Label
var _warn_tween: Tween
var _t := 0.0
var _hop_streak := 0


func build(p: Park, area: Dictionary, level_value: int) -> void:
	park = p
	level = level_value
	width = float(area.get("width", 1080.0))
	top = float(area.get("top", 0.0))
	bottom = float(area.get("bottom", 1600.0))
	theme = ParkTheme.get_theme(ProgressionManager.selected_cosmetic("theme"))
	livery = String(ProgressionManager.selected_cosmetic_data("livery").get("style", "stripes"))
	outfit = String(ProgressionManager.selected_cosmetic_data("outfit").get("style", "everyday"))
	_layout()
	_people_layer = Node2D.new()
	add_child(_people_layer)
	_bus_layer = Node2D.new()
	_bus_layer.y_sort_enabled = true
	add_child(_bus_layer)
	_fx_layer = Node2D.new()
	_fx_layer.z_index = 30
	add_child(_fx_layer)
	khalasi = KHALASI_SCENE.instantiate()
	khalasi.unit = 0.72
	khalasi.position = Vector2(78, walk_y + 6)
	_people_layer.add_child(khalasi)
	_more_label = UIKit.title("", 34)
	_more_label.size = Vector2(110, 60)
	_more_label.position = Vector2(width - 122, walk_y - 70)
	add_child(_more_label)
	for i in park.bays.size():
		bay_free_at.append(0.0)
	for b in park.buses:
		var id := int(b["id"])
		match String(b["state"]):
			"lot":
				_spawn_bus(id, lot_center(id), cell, int(b["dir"]))
			"bay":
				var k := park.bays.find(id)
				var bv := _spawn_bus(id, bay_center(k), bay_cell, Park.UP)
				bv.show_seats = true
				bv.boarded = int(b["boarded"])
	_fill_queue()
	sync_cones()
	queue_redraw()


func _layout() -> void:
	var big := park.h >= 10 or park.w >= 9
	ring_w = 62.0 if big else 84.0
	bay_h = 262.0 if big else 300.0
	bay_cell = 86.0 if big else 100.0
	var sidewalk_top := top
	walk_y = sidewalk_top + SIDEWALK_H - 18.0
	road_y = sidewalk_top + SIDEWALK_H + ROAD_H * 0.5
	bays_top = sidewalk_top + SIDEWALK_H + ROAD_H
	var lot_top := bays_top + bay_h + ring_w
	var avail_w := width - 2.0 * ring_w - 40.0
	var avail_h := bottom - lot_top - ring_w - 10.0
	cell = floorf(minf(minf(avail_w / park.w, avail_h / park.h), 150.0))
	var size := Vector2(park.w, park.h) * cell
	var y := lot_top + maxf(0.0, (avail_h - size.y) * 0.35)
	lot_rect = Rect2(Vector2((width - size.x) * 0.5, y), size)
	ring = lot_rect.grow(ring_w * 0.5)


# --- Geometry ----------------------------------------------------------------

func cell_center(c: Vector2i) -> Vector2:
	return lot_rect.position + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func lot_center(id: int) -> Vector2:
	var b := park.bus(id)
	return _center_of(int(b["x"]), int(b["y"]), int(b["len"]), int(b["dir"]))


func _center_of(x: int, y: int, length: int, dir: int) -> Vector2:
	var sz := Vector2(1, length) if dir == Park.UP or dir == Park.DOWN else Vector2(length, 1)
	return lot_rect.position + (Vector2(x, y) + sz * 0.5) * cell


func bay_slot_width() -> float:
	return minf(216.0, (width - 40.0) / maxf(1.0, park.bays.size()))


func bay_x(k: int) -> float:
	var n := park.bays.size()
	return width * 0.5 + (k - (n - 1) * 0.5) * bay_slot_width()


func bay_center(k: int) -> Vector2:
	return Vector2(bay_x(k), bays_top + bay_h * 0.5 + 16.0)


func queue_slot(i: int) -> Vector2:
	return Vector2(QUEUE_X0 + i * QUEUE_DX, walk_y)


## Topmost lot bus under `p` (view coordinates), or -1.
func bus_at(p: Vector2) -> int:
	var best := -1
	var best_y := -INF
	for id in buses.keys():
		var bv: BusVisual = buses[id]
		if park.bus(id)["state"] != "lot" or bv.is_moving():
			continue
		if bv.hit_rect().has_point(p) and bv.position.y > best_y:
			best = id
			best_y = bv.position.y
	if best >= 0:
		return best
	# Forgiving taps on crowded lots: the nearest bus within 40% of a cell.
	var best_d := cell * 0.4
	for id in buses.keys():
		var bv: BusVisual = buses[id]
		if park.bus(id)["state"] != "lot" or bv.is_moving():
			continue
		var r := bv.hit_rect()
		var d := Vector2(maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x)), maxf(0.0, maxf(r.position.y - p.y, p.y - r.end.y))).length()
		if d < best_d:
			best_d = d
			best = id
	return best


func bus_visual(id: int) -> BusVisual:
	return buses.get(id)


func idle() -> bool:
	return clock >= busy_until


func time_left() -> float:
	return maxf(0.0, busy_until - clock)


func is_bus_busy(id: int) -> bool:
	return float(bus_busy.get(id, -1.0)) > clock


func _process(delta: float) -> void:
	var was_busy := not idle()
	clock += delta
	_t += delta
	if was_busy and idle():
		timeline_done.emit()
	queue_redraw()


## Runs `fn` at view time `at` (on a tween owned by this view).
func _at(at: float, fn: Callable) -> void:
	busy_until = maxf(busy_until, at)
	var wait := at - clock
	if wait <= 0.0:
		fn.call()
		return
	var tw := create_tween()
	tw.tween_interval(wait)
	tw.tween_callback(fn)


# --- Spawning ----------------------------------------------------------------

func _spawn_bus(id: int, pos: Vector2, c: float, dir: int) -> BusVisual:
	var b := park.bus(id)
	var bv: BusVisual = BUS_SCENE.instantiate()
	bv.setup(id, int(b["len"]), dir, GameData.bus_color(int(b["color"])), c, livery, GameData.bus_name(id * 7 + level))
	bv.sleep = bool(b.get("sleep", false)) and b["state"] == "lot"
	bv.position = pos
	_bus_layer.add_child(bv)
	buses[id] = bv
	return bv


## Tops the visible line up to VISIBLE passengers. With `walk_in`, new ones
## walk in from the right edge.
func _fill_queue(walk_in: bool = false) -> void:
	var start := park.qpos if queue_nodes.is_empty() else (queue_nodes[queue_nodes.size() - 1] as PassengerVisual).qi + 1
	var front_qi := park.qpos if queue_nodes.is_empty() else (queue_nodes[0] as PassengerVisual).qi
	var qi := start
	while queue_nodes.size() < VISIBLE and qi < park.queue.size():
		var pv: PassengerVisual = PoolManager.acquire(PASSENGER_SCENE, _people_layer)
		pv.setup(qi, GameData.bus_color(park.queue[qi]), outfit, qi != front_qi and park.covered.has(qi), 100.0)
		var slot := queue_slot(queue_nodes.size())
		if walk_in:
			pv.position = Vector2(width + 60.0, walk_y)
			pv.walk_to(slot, 0.45)
		else:
			pv.position = slot
		queue_nodes.append(pv)
		qi += 1
	_update_more()


func _update_more() -> void:
	var shown_until := park.qpos
	if not queue_nodes.is_empty():
		shown_until = (queue_nodes[queue_nodes.size() - 1] as PassengerVisual).qi + 1
	var more := park.queue.size() - shown_until
	_more_label.text = "+%d" % more if more > 0 else ""
	queue_redraw()


# --- Events ------------------------------------------------------------------

## Plays a list of Park events. Returns the time (from now) when all of
## them have finished.
func play(events: Array) -> float:
	for e in events:
		match String(e["type"]):
			"wake":
				_on_wake(int(e["bus"]))
			"blocked":
				_on_blocked(e)
			"bays_full":
				_on_bays_full(int(e["bus"]))
			"exit":
				_on_exit(e)
			"tunnel_out":
				_on_tunnel_out(int(e["bus"]))
			"cones_clear":
				_on_cones_clear()
			"board":
				_on_board(e)
			"depart":
				_on_depart(e)
	return time_left()


func _on_wake(id: int) -> void:
	var bv: BusVisual = buses[id]
	bv.wake()
	AudioManager.play("wake")
	HapticsManager.light()
	VFXManager.popup_text(_fx_layer, "AWAKE!", bv.position + Vector2(0, -cell * 0.6), UIKit.GOLD, 48, 70, 0.7)
	bus_busy[id] = clock + 0.3
	busy_until = maxf(busy_until, clock + 0.3)


func _on_blocked(e: Dictionary) -> void:
	var id := int(e["bus"])
	var bv: BusVisual = buses[id]
	var b := park.bus(id)
	var front := Park.front_of(int(b["x"]), int(b["y"]), int(b["len"]), int(b["dir"]))
	var hit: Vector2i = e["cell"]
	var gap := absi(hit.x - front.x) + absi(hit.y - front.y) - 1
	var impact := bv.bump(gap * cell + cell * 0.1)
	var blocker := int(e["blocker"])
	bus_busy[id] = clock + impact * 2.6 + 0.2
	busy_until = maxf(busy_until, clock + impact * 2.6 + 0.2)
	AudioManager.play("drive", 1.3, -6.0)
	_at(clock + impact, func() -> void:
		AudioManager.play("bump")
		AudioManager.horn(1.08)
		HapticsManager.light()
		VFXManager.shake(7.0, 0.16)
		if blocker >= 0 and buses.has(blocker):
			(buses[blocker] as BusVisual).wobble()
			(buses[blocker] as BusVisual).flash_once(0.5)
		elif blocker == Park.CONE:
			_bounce_cone(hit)
		VFXManager.sparkle(_fx_layer, bv.position + Vector2(Park.DIRS[int(b["dir"])]) * cell * (float(b["len"]) * 0.5 + gap), Color.WHITE, 0.6))


func _on_bays_full(id: int) -> void:
	var bv: BusVisual = buses[id]
	bv.wobble()
	AudioManager.play("nope")
	HapticsManager.light()
	pulse_bays()


## Drives a bus out of the lot, around the ring road and into its bay
## (waiting on the road if the bay is still being vacated).
func _on_exit(e: Dictionary) -> void:
	var id := int(e["bus"])
	var bay := int(e["bay"])
	var bv: BusVisual = buses[id]
	bv.sleep = false
	if String(e.get("via", "drive")) == "crane":
		_crane_to_bay(bv, bay)
		return
	var dir := bv.dir
	var start := bv.position
	var pts: Array = []
	match dir:
		Park.UP:
			pts.append(Vector2(start.x, ring.position.y))
		Park.DOWN:
			pts.append(Vector2(start.x, ring.end.y))
		Park.LEFT:
			pts.append(Vector2(ring.position.x, start.y))
		_:
			pts.append(Vector2(ring.end.x, start.y))
	var tx := bay_x(bay)
	var top_y := ring.position.y
	match dir:
		Park.LEFT:
			pts.append(Vector2(ring.position.x, top_y))
		Park.RIGHT:
			pts.append(Vector2(ring.end.x, top_y))
		Park.DOWN:
			var ex: float = (pts[0] as Vector2).x
			var via_left := absf(ex - ring.position.x) + absf(tx - ring.position.x) <= absf(ring.end.x - ex) + absf(ring.end.x - tx)
			var sx := ring.position.x if via_left else ring.end.x
			pts.append(Vector2(sx, ring.end.y))
			pts.append(Vector2(sx, top_y))
	pts.append(Vector2(tx, top_y))
	pts.append(bay_center(bay))
	# Time to reach the bay mouth; wait there if the bay isn't free yet.
	var dist := 0.0
	var from := start
	for i in pts.size() - 1:
		dist += from.distance_to(pts[i])
		from = pts[i]
	var reach := clock + dist / DRIVE_SPEED + 0.08
	var wait := maxf(0.0, float(bay_free_at[bay]) - reach)
	var dur := bv.travel(pts, DRIVE_SPEED, 0.0, {pts.size() - 1: wait}, bay_cell, mini(1, pts.size() - 2))
	arrive_at[id] = clock + dur
	bus_busy[id] = clock + dur
	busy_until = maxf(busy_until, clock + dur)
	bay_free_at[bay] = INF   # taken until this bus departs
	AudioManager.play("drive", randf_range(0.95, 1.08))
	HapticsManager.light()
	_at(clock + dur, func() -> void:
		bv.show_seats = true
		bv.door = 1.0
		AudioManager.play("door", 1.1, -4.0))


func _crane_to_bay(bv: BusVisual, bay: int) -> void:
	var hook := CraneHook.new()
	_fx_layer.add_child(hook)
	hook.target = bv
	hook.position = Vector2(bv.position.x, -200)
	var dest := bay_center(bay)
	var tw := create_tween()
	tw.tween_property(hook, "position", bv.position - Vector2(0, BusArt.body_height(bv.cell) + 20), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		hook.attached = true
		AudioManager.play("crane"))
	tw.tween_property(bv, "lift", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		bv.z_index = 10
		bv.dir = Park.UP)
	tw.tween_property(bv, "position", dest, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(bv, "cell", bay_cell, 0.6)
	tw.tween_property(bv, "lift", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		bv.z_index = 0
		hook.attached = false
		bv.squash(Vector2(1.12, 0.9), 0.25)
		bv.show_seats = true
		AudioManager.play("bump", 1.2)
		VFXManager.shake(6.0, 0.15))
	tw.tween_property(hook, "position:y", -260.0, 0.3)
	tw.tween_callback(hook.queue_free)
	var dur := 0.3 + 0.22 + 0.6 + 0.16
	var id := bv.bus_id
	var wait := maxf(0.0, float(bay_free_at[bay]) - (clock + dur))
	if wait > 0.0:
		tw.pause()
		var hold := create_tween()
		hold.tween_interval(wait)
		hold.tween_callback(tw.play)
	arrive_at[id] = clock + dur + wait
	bus_busy[id] = clock + dur + wait
	busy_until = maxf(busy_until, clock + dur + wait + 0.3)
	bay_free_at[bay] = INF


func _on_tunnel_out(id: int) -> void:
	var b := park.bus(id)
	var dest := lot_center(id)
	var a := Vector2(Park.DIRS[int(b["dir"])])
	var start := dest - a * cell * (float(b["len"]) + 0.6)
	var bv := _spawn_bus(id, start, cell, int(b["dir"]))
	bv.modulate.a = 0.0
	var at := clock + 0.35
	bus_busy[id] = at + 0.5
	busy_until = maxf(busy_until, at + 0.5)
	_at(at, func() -> void:
		bv.modulate.a = 1.0
		bv.travel([dest], 900.0)
		AudioManager.play("tunnel"))
	queue_redraw()


func _on_cones_clear() -> void:
	var at := clock + 0.3
	_at(at, func() -> void:
		AudioManager.play("cones")
		for cn in cone_scale.keys():
			VFXManager.sparkle(_fx_layer, cell_center(cn), Color("ff7f11"), 0.7)
		var tw := create_tween()
		tw.tween_method(_set_cones_scale, 1.0, 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(_clear_cones))


func _clear_cones() -> void:
	cone_scale.clear()
	queue_redraw()


func _set_cones_scale(v: float) -> void:
	for k in cone_scale.keys():
		cone_scale[k] = v
	queue_redraw()


func _bounce_cone(c: Vector2i) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		cone_scale[c] = v
		queue_redraw(), 1.25, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_board(e: Dictionary) -> void:
	var id := int(e["bus"])
	var start := maxf(maxf(clock, queue_t + HOP_GAP), float(arrive_at.get(id, clock)))
	queue_t = start
	busy_until = maxf(busy_until, start + HOP_TIME + 0.05)
	_at(start, _hop.bind(id, int(e["qi"]), int(e["seat"])))


func _hop(id: int, qi: int, seat: int) -> void:
	if queue_nodes.is_empty() or not buses.has(id):
		return
	var pv: PassengerVisual = queue_nodes.pop_front()
	var bv: BusVisual = buses[id]
	pv.reveal()
	_hop_streak += 1
	AudioManager.play("hop", 1.0 + 0.05 * float(seat))
	pv.hop_to(bv.position - Vector2(0, BusArt.body_height(bv.cell) * 0.6), HOP_TIME, func() -> void:
		if is_instance_valid(bv):
			bv.add_passenger()
			HapticsManager.light())
	for i in queue_nodes.size():
		(queue_nodes[i] as PassengerVisual).walk_to(queue_slot(i), 0.2, 0.02 * i)
	_fill_queue(true)
	if not queue_nodes.is_empty():
		var front: PassengerVisual = queue_nodes[0]
		if front.covered:
			front.reveal()
			AudioManager.play("pop", 1.2, -4.0)


func _on_depart(e: Dictionary) -> void:
	var id := int(e["bus"])
	var bay := int(e["bay"])
	var start := maxf(queue_t + HOP_TIME, float(arrive_at.get(id, clock)))
	var leave := start + 0.22
	bay_free_at[bay] = leave + 0.2
	busy_until = maxf(busy_until, leave + 0.6)
	_at(start, func() -> void:
		if not buses.has(id):
			return
		var bv: BusVisual = buses[id]
		bv.door = 0.0
		AudioManager.play("door")
		AudioManager.horn()
		khalasi.bang("")
		AudioManager.play("slap", 1.0, -3.0)
		var shout_at := Vector2(clampf(bv.position.x, 190.0, width - 190.0), bv.position.y - bv.cell * 1.2)
		VFXManager.popup_text(_fx_layer, GameData.town(id + level * 3) + "!", shout_at, Color.WHITE, 40, 90, 1.0)
		bv.squash(Vector2(1.1, 0.92), 0.25)
		VFXManager.sparkle(_fx_layer, bv.position, bv.color.lightened(0.4), 1.0))
	_at(leave, func() -> void:
		if not buses.has(id):
			return
		var bv: BusVisual = buses[id]
		buses.erase(id)
		AudioManager.play("depart", randf_range(0.95, 1.1))
		bv.travel([Vector2(bv.position.x, road_y), Vector2(width + 360.0, road_y)], 1500.0)
		bv.arrived.connect(bv.queue_free))


# --- Boosters / state --------------------------------------------------------

func add_bay_visual() -> void:
	bay_free_at.append(0.0)
	var n := park.bays.size()
	for k in n:
		var id := int(park.bays[k])
		if id >= 0 and buses.has(id):
			var bv: BusVisual = buses[id]
			bv.create_tween().tween_property(bv, "position", bay_center(k), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	VFXManager.sparkle(_fx_layer, bay_center(n - 1), UIKit.GOLD, 1.4)
	AudioManager.play("bay_open")
	queue_redraw()


## Re-colours the waiting line after Shuffle Queue, with a jump.
func shuffle_queue_visual() -> void:
	AudioManager.play("shuffle")
	var front_qi := park.qpos
	for i in queue_nodes.size():
		var pv: PassengerVisual = queue_nodes[i]
		var qi := pv.qi
		var tw := pv.create_tween()
		tw.tween_interval(0.03 * i)
		tw.tween_property(pv, "position:y", walk_y - 90.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			pv.color = GameData.bus_color(park.queue[qi])
			pv.covered = qi != front_qi and park.covered.has(qi)
			pv.queue_redraw())
		tw.tween_property(pv, "position:y", walk_y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	busy_until = maxf(busy_until, clock + 0.03 * queue_nodes.size() + 0.45)


func set_warning(on: bool) -> void:
	if _warn_tween:
		_warn_tween.kill()
		_warn_tween = null
	khalasi.set_worried(on)
	if on:
		_warn_tween = create_tween().set_loops()
		_warn_tween.tween_property(self, "warning", 1.0, 0.4)
		_warn_tween.tween_property(self, "warning", 0.3, 0.4)
	else:
		warning = 0.0


func pulse_bays() -> void:
	var tw := create_tween()
	tw.tween_property(self, "warning", 1.0, 0.1)
	tw.tween_property(self, "warning", 0.0, 0.4)


func highlight_bus(id: int, on: bool) -> void:
	if buses.has(id):
		(buses[id] as BusVisual).highlight = 1.0 if on else 0.0


func clear_highlights() -> void:
	for id in buses.keys():
		(buses[id] as BusVisual).highlight = 0.0


## Win: every waiting thing cheers.
func celebrate() -> float:
	khalasi.cheer(2.0)
	for k in park.bays.size():
		VFXManager.sparkle(_fx_layer, bay_center(k), UIKit.GOLD, 1.2)
	return 0.8


func intro_time() -> float:
	return 0.55


## Buses drop into the lot one after another at the start.
func play_intro() -> void:
	var i := 0
	for id in buses.keys():
		var bv: BusVisual = buses[id]
		if park.bus(id)["state"] != "lot":
			continue
		var home := bv.position
		bv.position = home - Vector2(0, 60)
		bv.modulate.a = 0.0
		var tw := bv.create_tween()
		tw.tween_interval(0.025 * i)
		tw.tween_property(bv, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(bv, "position", home, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		i += 1
	for k in queue_nodes.size():
		var pv: PassengerVisual = queue_nodes[k]
		var home := pv.position
		pv.position = home + Vector2(width, 0)
		pv.walk_to(home, 0.45, 0.03 * k)


# --- Ground ------------------------------------------------------------------

func _draw() -> void:
	var th := theme
	var asphalt := ParkTheme.c(th, "asphalt")
	var dark := ParkTheme.c(th, "asphalt_dark")
	var paint := ParkTheme.c(th, "paint")
	var dust := ParkTheme.c(th, "dust")
	var bottom_y := bottom + 400.0
	# Sidewalk with paving.
	draw_rect(Rect2(0, top, width, SIDEWALK_H), dust)
	for k in int(width / 90.0) + 1:
		draw_line(Vector2(k * 90.0, top + 10), Vector2(k * 90.0 - 20, top + SIDEWALK_H - 14), Color(0, 0, 0, 0.06), 3.0)
	draw_line(Vector2(0, top + 60), Vector2(width, top + 60), Color(0, 0, 0, 0.05), 3.0)
	# Queue line painted on the paving.
	draw_rect(Rect2(QUEUE_X0 - 40, walk_y + 4, width, 8), Color(ParkTheme.c(th, "bay_paint"), 0.5))
	if _more_label and _more_label.text != "":
		var pill := Rect2(_more_label.position + Vector2(4, 4), _more_label.size - Vector2(8, 8))
		draw_colored_polygon(DrawKit.rounded_rect(pill, 26, 6), Color(0.07, 0.11, 0.3, 0.75))
	# Curb + departure road.
	draw_rect(Rect2(0, top + SIDEWALK_H - 14, width, 14), Color("59607a"))
	draw_rect(Rect2(0, top + SIDEWALK_H, width, bottom_y - top - SIDEWALK_H), asphalt)
	draw_rect(Rect2(0, top + SIDEWALK_H, width, ROAD_H), dark)
	var dash := 0.0
	while dash < width:
		draw_rect(Rect2(dash + 20, road_y - 4, 50, 8), Color(paint, 0.8))
		dash += 110.0
	for k in 3:
		var ax := width * (0.25 + 0.25 * k)
		draw_colored_polygon(PackedVector2Array([Vector2(ax + 26, road_y + 24), Vector2(ax, road_y + 14), Vector2(ax, road_y + 34)]), Color(paint, 0.5))
	# Loading bays.
	var warn_col := Color(1.0, 0.25, 0.3, 0.45 * warning)
	var bay_col := ParkTheme.c(th, "bay_paint")
	for k in park.bays.size():
		var x := bay_x(k)
		var sw := bay_slot_width()
		var r := Rect2(x - sw * 0.5 + 8, bays_top + 10, sw - 16, bay_h - 12)
		draw_rect(r, Color(0, 0, 0, 0.06))
		if warning > 0.01:
			draw_rect(r, warn_col)
		draw_line(r.position, Vector2(r.position.x, r.end.y), bay_col, 7.0)
		draw_line(Vector2(r.end.x, r.position.y), r.end, bay_col, 7.0)
		draw_line(r.position, Vector2(r.end.x, r.position.y), bay_col, 7.0)
		# Bay number painted at the mouth.
		var f := UIKit.font(true)
		var label := str(k + 1)
		draw_string(f, Vector2(x - 14, r.end.y - 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(paint, 0.55))
		if k >= Park.DEFAULT_BAYS:
			DrawKit.outline(self, DrawKit.rounded_rect(r.grow(4), 12, 4), Color(1, 0.85, 0.3, 0.6 + 0.4 * sin(_t * 4.0)), 5.0)
	# Ring road lane marking and the lot.
	var lane := ring
	var segs := [[lane.position, Vector2(lane.end.x, lane.position.y)], [Vector2(lane.end.x, lane.position.y), lane.end],
		[lane.end, Vector2(lane.position.x, lane.end.y)], [Vector2(lane.position.x, lane.end.y), lane.position]]
	for sgm in segs:
		var a: Vector2 = sgm[0]
		var b: Vector2 = sgm[1]
		var len_ := a.distance_to(b)
		var t := 0.0
		while t < len_:
			var p0 := a.lerp(b, t / len_)
			var p1 := a.lerp(b, minf(len_, t + 34.0) / len_)
			draw_line(p0, p1, Color(paint, 0.55), 5.0)
			t += 70.0
	_draw_lot(asphalt, paint)
	# Grass verges down both screen edges.
	var grass := ParkTheme.c(th, "ground")
	for side in [0.0, 1.0]:
		var vx: float = 0.0 if side == 0.0 else width - 40.0
		draw_rect(Rect2(vx, bays_top + bay_h + 6, 40, bottom_y), grass)
		draw_rect(Rect2(vx + (36.0 if side == 0.0 else 0.0), bays_top + bay_h + 6, 4, bottom_y), grass.darkened(0.25))
	# Bushes along the screen edges (sway gently).
	for side in [0.0, 1.0]:
		for k in 6:
			var by := ring.position.y + k * (ring.size.y / 5.0)
			var bx: float = 18.0 if side == 0.0 else width - 18.0
			var sway := sin(_t * 1.4 + k) * 3.0
			draw_circle(Vector2(bx + sway, by), 26, Color("3c9a5f").darkened(0.4 if bool(th["night"]) else 0.0), true, -1.0, true)
			draw_circle(Vector2(bx + sway - 8, by - 10), 16, Color("57b878").darkened(0.4 if bool(th["night"]) else 0.0), true, -1.0, true)
	_draw_tunnel()
	_draw_cones()


## The parking lot: a plain rectangle, or a shaped lot (round, octagon,
## diamond, plus) with grass and bushes in the cells outside its outline.
## Every parking cell gets painted bay lines.
func _draw_lot(asphalt: Color, paint: Color) -> void:
	var lot := lot_rect
	var shaped := park.shape != "rect" and park.shape != ""
	if shaped:
		var grass := ParkTheme.c(theme, "ground")
		draw_colored_polygon(DrawKit.rounded_rect(lot.grow(6), 22, 6), grass.darkened(0.08))
		draw_colored_polygon(DrawKit.rounded_rect(lot, 18, 6), grass)
		var paved := LotShape.paved_polygon(lot, park.shape, cell * 0.62)
		var curb := Geometry2D.offset_polygon(paved, 9.0, Geometry2D.JOIN_ROUND)
		if not curb.is_empty():
			draw_colored_polygon(curb[0], Color("59607a"))
		draw_colored_polygon(paved, asphalt.lightened(0.08))
		# Bushes and flowers on the grass outside the lot.
		var cols := [Color("ff5fa2"), Color("ffd84a"), Color.WHITE]
		for hc in park.holes:
			var c := Vector2i(int(hc[0]), int(hc[1]))
			var p := cell_center(c)
			if Geometry2D.is_point_in_polygon(p, paved):
				continue
			var k := (c.x * 7 + c.y * 13) % 5
			if k <= 1:
				draw_circle(p + Vector2(0, 6), cell * 0.3, Color(0, 0, 0, 0.12), true, -1.0, true)
				draw_circle(p, cell * 0.28, Color("3c9a5f"), true, -1.0, true)
				draw_circle(p - Vector2(cell * 0.08, cell * 0.1), cell * 0.16, Color("57b878"), true, -1.0, true)
			elif k == 2:
				for f in 3:
					draw_circle(p + Vector2((f - 1) * cell * 0.18, (f % 2) * cell * 0.12), cell * 0.07, cols[f], true, -1.0, true)
	else:
		draw_colored_polygon(DrawKit.rounded_rect(lot.grow(10), 18, 6), Color("59607a"))
		draw_colored_polygon(DrawKit.rounded_rect(lot.grow(4), 12, 6), asphalt.lightened(0.08))
	# Painted bay lines on every parking cell.
	for y in park.h:
		for x in park.w:
			if shaped and park.is_hole(Vector2i(x, y)):
				continue
			var r := Rect2(lot.position + Vector2(x, y) * cell, Vector2(cell, cell))
			draw_rect(r.grow(-2), Color(paint, 0.22), false, 2.5)


func _draw_tunnel() -> void:
	if park.tunnel.is_empty():
		return
	var t := park.tunnel
	var cells := Park.tunnel_cells(t, park.w, park.h)
	for c in cells:
		var r := Rect2(lot_rect.position + Vector2(c) * cell, Vector2(cell, cell)).grow(-6)
		draw_rect(r, Color(1, 0.8, 0.2, 0.18))
		for k in 3:
			draw_line(r.position + Vector2(k * r.size.x / 3.0, r.size.y), r.position + Vector2(k * r.size.x / 3.0 + r.size.x / 3.0, 0), Color(1, 0.8, 0.2, 0.35), 4.0)
	# The tunnel mouth just outside the lot edge.
	var edge := String(t["edge"])
	var pos := int(t["pos"])
	var mouth: Vector2
	var horizontal := edge != "bottom"
	match edge:
		"left":
			mouth = Vector2(lot_rect.position.x - ring_w * 0.62, lot_rect.position.y + (pos + 0.5) * cell)
		"right":
			mouth = Vector2(lot_rect.end.x + ring_w * 0.62, lot_rect.position.y + (pos + 0.5) * cell)
		_:
			mouth = Vector2(lot_rect.position.x + (pos + 0.5) * cell, lot_rect.end.y + ring_w * 0.62)
	var sz := Vector2(ring_w * 0.95, cell * 1.25) if horizontal else Vector2(cell * 1.25, ring_w * 0.95)
	var r := Rect2(mouth - sz * 0.5, sz)
	# Hazard-striped portal with a dark opening.
	draw_colored_polygon(DrawKit.rounded_rect(r.grow(14), 26, 6), Color("17213f"))
	draw_colored_polygon(DrawKit.rounded_rect(r.grow(10), 24, 6), Color("ffc300"))
	var n := 8
	for k in n:
		var t0 := float(k) / n
		var t1 := (k + 0.5) / n
		if horizontal:
			draw_rect(Rect2(r.position.x - 10, r.position.y - 10 + t0 * (r.size.y + 20), r.size.x + 20, (t1 - t0) * (r.size.y + 20)), Color("17213f"))
		else:
			draw_rect(Rect2(r.position.x - 10 + t0 * (r.size.x + 20), r.position.y - 10, (t1 - t0) * (r.size.x + 20), r.size.y + 20), Color("17213f"))
	draw_colored_polygon(DrawKit.rounded_rect(r, 18, 6), Color("0d1018"))
	draw_colored_polygon(DrawKit.rounded_rect(r.grow(-10), 12, 6), Color("1f2433"))
	# Waiting buses: small colour chips in order + count badge.
	var waiting := park.tunnel_waiting()
	var f := UIKit.font(true)
	var base := mouth + (Vector2(0, -sz.y * 0.5 - 44) if horizontal else Vector2(-sz.x * 0.5 - 44, 0))
	for i in waiting.size():
		var col := GameData.bus_color(int(park.bus(int(waiting[i]))["color"]))
		var p := base + (Vector2(0, -i * 30) if horizontal else Vector2(-i * 30, 0))
		draw_colored_polygon(DrawKit.rounded_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), 7, 3), Color("1f2433"))
		draw_colored_polygon(DrawKit.rounded_rect(Rect2(p - Vector2(13, 9), Vector2(26, 18)), 5, 3), col)
	if not waiting.is_empty():
		draw_string_outline(f, mouth + Vector2(-18, 14), "x%d" % waiting.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color("1f2433"))
		draw_string(f, mouth + Vector2(-18, 14), "x%d" % waiting.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)


func sync_cones() -> void:
	cone_scale.clear()
	for cn in park.cones:
		cone_scale[Vector2i(int(cn[0]), int(cn[1]))] = 1.0
	queue_redraw()


func _draw_cones() -> void:
	for c in cone_scale.keys():
		var s := float(cone_scale[c])
		if s <= 0.01:
			continue
		var p := cell_center(c) + Vector2(0, cell * 0.25)
		var u := cell / 100.0 * s
		draw_colored_polygon(DrawKit.ellipse(p + Vector2(4, 4) * u, 36 * u, 12 * u, 16), Color(0, 0, 0, 0.25))
		draw_colored_polygon(DrawKit.rounded_rect(Rect2(p - Vector2(36, 8) * u, Vector2(72, 14) * u), 5 * u, 3), Color("d35400"))
		var cone := PackedVector2Array([p + Vector2(-26, -2) * u, p + Vector2(26, -2) * u, p + Vector2(8, -66) * u, p + Vector2(-8, -66) * u])
		draw_colored_polygon(cone, Color("ff7f11"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-19, -24) * u, p + Vector2(19, -24) * u, p + Vector2(14, -40) * u, p + Vector2(-14, -40) * u]), Color.WHITE)
		DrawKit.outline(self, cone, Color("7a2e00"), 3.0 * u)
