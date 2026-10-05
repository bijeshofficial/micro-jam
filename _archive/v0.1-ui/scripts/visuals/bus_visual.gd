class_name BusVisual
extends Node2D
## One bus on screen. Draws itself with BusArt and knows how to drive along
## a list of waypoints (axis-aligned segments; it turns at each corner),
## bump, wobble, wake up, get lifted by the crane and fill its seats.
## Replace _draw() with sprites for final art; gameplay only uses the
## public methods below.

signal arrived

var bus_id := -1
var cell := 100.0:
	set(v):
		cell = v
		queue_redraw()
var length := 2
var dir := 0:
	set(v):
		dir = v
		queue_redraw()
var color := Color.RED
var livery := "stripes"
var bus_name := ""
var sleep := false:
	set(v):
		sleep = v
		queue_redraw()
var show_seats := false:
	set(v):
		show_seats = v
		queue_redraw()
var boarded := 0:
	set(v):
		boarded = v
		queue_redraw()
var lift := 0.0:
	set(v):
		lift = v
		queue_redraw()
var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()
var door := 0.0:
	set(v):
		door = v
		queue_redraw()
var highlight := 0.0:
	set(v):
		highlight = v
		queue_redraw()

var _t := 0.0
var _move_tween: Tween
var _fx_tween: Tween


func setup(id: int, length_value: int, dir_value: int, col: Color, cell_value: float, livery_value: String, name_value: String) -> void:
	bus_id = id
	length = length_value
	dir = dir_value
	color = col
	cell = cell_value
	livery = livery_value
	bus_name = name_value
	queue_redraw()


func capacity() -> int:
	return Park.capacity_for(length)


func _process(delta: float) -> void:
	if sleep or highlight > 0.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if highlight > 0.0:
		var fp := BusArt.footprint(Vector2.ZERO, cell, length, dir).grow(cell * 0.12)
		var pulse := 0.5 + 0.5 * sin(_t * 7.0)
		DrawKit.outline(self, DrawKit.rounded_rect(Rect2(fp.position - Vector2(0, BusArt.body_height(cell)), fp.size + Vector2(0, BusArt.body_height(cell))), cell * 0.28, 6), Color(1, 1, 1, highlight * (0.5 + 0.5 * pulse)), cell * 0.07)
	BusArt.draw_bus(self, Vector2.ZERO, cell, length, dir, color, {
		"livery": livery, "name": bus_name, "sleep": sleep, "time": _t,
		"seats": capacity() if show_seats else 0, "boarded": boarded, "seat_color": color,
		"lift": lift, "flash": flash, "door": door, "arrow": not show_seats,
	})


## Screen-space rect of the bus (taps).
func hit_rect() -> Rect2:
	var fp := BusArt.footprint(Vector2.ZERO, cell, length, dir)
	var h := BusArt.body_height(cell)
	return Rect2(position + fp.position - Vector2(0, h), fp.size + Vector2(0, h)).grow(cell * 0.05)


func is_moving() -> bool:
	return _move_tween != null and _move_tween.is_running()


func stop_motion() -> void:
	if _move_tween:
		_move_tween.kill()
		_move_tween = null


## Drives through `points` (starting from the current position) at `speed`
## px/s after `delay` s. `waits` maps a waypoint index to a pause before
## that leg. Turns face each leg's direction. Returns the total duration.
func travel(points: Array, speed: float, delay: float = 0.0, waits: Dictionary = {}, cell_to: float = -1.0, scale_from_leg: int = 0) -> float:
	stop_motion()
	_move_tween = create_tween()
	if delay > 0.0:
		_move_tween.tween_interval(delay)
	var total := delay
	var from := position
	for i in points.size():
		var to: Vector2 = points[i]
		var d := from.distance_to(to)
		if waits.has(i) and float(waits[i]) > 0.0:
			_move_tween.tween_interval(float(waits[i]))
			total += float(waits[i])
		if d < 0.5:
			from = to
			continue
		var leg_dir := _dir_of(to - from)
		var dur := d / speed
		_move_tween.tween_callback(_face.bind(leg_dir))
		var tr := _move_tween.tween_property(self, "position", to, dur).from(from)
		if i == 0:
			tr.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		elif i == points.size() - 1:
			tr.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if cell_to > 0.0 and i == scale_from_leg:
			_move_tween.parallel().tween_property(self, "cell", cell_to, dur)
		total += dur
		from = to
	_move_tween.tween_callback(_on_arrived)
	return total


func _on_arrived() -> void:
	squash(Vector2(1.08, 0.92))
	arrived.emit()


func _face(d: int) -> void:
	if d != dir:
		dir = d
		squash(Vector2(0.92, 1.08) if d == 0 or d == 2 else Vector2(1.08, 0.92))


static func _dir_of(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return 1 if v.x > 0 else 3
	return 2 if v.y > 0 else 0


func squash(s: Vector2, dur: float = 0.18) -> void:
	if _fx_tween:
		_fx_tween.kill()
	_fx_tween = create_tween()
	_fx_tween.tween_property(self, "scale", s, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(self, "scale", Vector2.ONE, dur * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Drives forward `dist` px toward its front, bumps, and reverses back.
## Returns the moment of impact (s).
func bump(dist: float) -> float:
	stop_motion()
	var home := position
	var a := Vector2(Park.DIRS[dir])
	var hit := home + a * maxf(dist, cell * 0.12)
	var go := clampf(dist / 1400.0, 0.06, 0.4)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", hit, go).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_move_tween.tween_callback(func() -> void: squash(Vector2(1.12, 0.88) if dir == 0 or dir == 2 else Vector2(0.88, 1.12), 0.2))
	_move_tween.tween_property(self, "position", hit - a * cell * 0.06, 0.06)
	_move_tween.tween_property(self, "position", home, go * 1.3 + 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return go


func wobble() -> void:
	var tw := create_tween()
	for k in 3:
		tw.tween_property(self, "rotation", 0.06 * (1 if k % 2 == 0 else -1), 0.05)
	tw.tween_property(self, "rotation", 0.0, 0.06)


func flash_once(strength: float = 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(self, "flash", strength, 0.05)
	tw.tween_property(self, "flash", 0.0, 0.25)


func wake() -> void:
	sleep = false
	squash(Vector2(1.15, 0.86), 0.3)
	flash_once(0.8)


func add_passenger() -> void:
	boarded = mini(boarded + 1, capacity())
	squash(Vector2(1.06, 0.95), 0.14)
