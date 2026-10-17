class_name ConfettiShower
extends Node2D
## Level-complete confetti: a short pop from each bottom corner. Paper bits
## flip as they tumble (darker on the back) and fade out within ~1.8 s.
## Squares, curly ribbons and a few gold stars in the bus palette, drawn in
## one _draw call; the node frees itself when done.

const COLORS := ["e63946", "1d7fe0", "ffc300", "2ec27e", "8e44ad", "ff7f11", "ff5fa2", "2fd6f7"]
const GRAVITY := 1500.0
const DRAG := 1.5
const LIFE := 1.3

enum { SQUARE, RIBBON, DOT, STAR }

var _pieces: Array[Dictionary] = []
var _t := 0.0
var _size := Vector2(1080, 1920)


func burst(width: float, height: float) -> void:
	_size = Vector2(width, height)
	z_index = 45
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Cannons: bottom-left aims up-right, bottom-right aims up-left.
	for side in [-1.0, 1.0]:
		var origin := Vector2(width * 0.5 + side * (width * 0.5 + 20.0), height * 0.8)
		for i in 30:
			var ang := deg_to_rad(-90.0 - side * rng.randf_range(18.0, 40.0))
			var speed := rng.randf_range(1700.0, 2500.0)
			_add(rng, origin + Vector2(0, rng.randf_range(-30, 30)), Vector2(cos(ang), sin(ang)) * speed, rng.randf_range(0.0, 0.08))


func _add(rng: RandomNumberGenerator, pos: Vector2, vel: Vector2, delay: float) -> void:
	var roll := rng.randf()
	var kind := SQUARE if roll < 0.6 else (RIBBON if roll < 0.85 else STAR)
	var col := Color(COLORS[rng.randi() % COLORS.size()])
	if kind == STAR:
		col = Color("ffd84a")
	_pieces.append({
		"pos": pos, "vel": vel, "delay": delay, "kind": kind, "col": col,
		"rot": rng.randf_range(0.0, TAU), "spin": rng.randf_range(-7.0, 7.0),
		"flip": rng.randf_range(0.0, TAU), "flip_speed": rng.randf_range(6.0, 13.0),
		"sway": rng.randf_range(30.0, 90.0), "sway_f": rng.randf_range(1.5, 3.2), "phase": rng.randf_range(0.0, TAU),
		"fall": rng.randf_range(300.0, 480.0), "size": rng.randf_range(1.0, 1.5),
	})


func _process(delta: float) -> void:
	_t += delta
	for p in _pieces:
		if _t < float(p["delay"]):
			continue
		var v: Vector2 = p["vel"]
		v.y += GRAVITY * delta
		v *= exp(-DRAG * delta)
		# Once slowed down, paper flutters: capped fall speed plus a sway.
		var cap: float = p["fall"]
		if v.y > cap:
			v.y = lerpf(v.y, cap, minf(1.0, 8.0 * delta))
		p["vel"] = v
		var sway: float = float(p["sway"]) * float(p["sway_f"]) * cos(_t * float(p["sway_f"]) + float(p["phase"])) * delta
		p["pos"] = (p["pos"] as Vector2) + v * delta + Vector2(sway, 0)
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		p["flip"] = float(p["flip"]) + float(p["flip_speed"]) * delta
	queue_redraw()
	if _t > LIFE + 0.5:
		queue_free()


func _draw() -> void:
	var fade := clampf((LIFE + 0.5 - _t) / 0.5, 0.0, 1.0)
	for p in _pieces:
		if _t < float(p["delay"]):
			continue
		var pos: Vector2 = p["pos"]
		if pos.y > _size.y + 60.0:
			continue
		var flip := cos(float(p["flip"]))
		var col: Color = p["col"]
		if flip < 0.0:
			col = col.darkened(0.28)   # the back of the paper
		col.a = fade
		var s: float = p["size"]
		match int(p["kind"]):
			SQUARE:
				draw_set_transform(pos, float(p["rot"]), Vector2(1.0, maxf(0.12, absf(flip))) * s)
				draw_rect(Rect2(-12, -8, 24, 16), col)
			RIBBON:
				draw_set_transform(pos, float(p["rot"]), Vector2(1.0, maxf(0.25, absf(flip))) * s)
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(Vector2(k * 7.0 - 21.0, sin(k * 1.3 + _t * 9.0 + float(p["phase"])) * 6.0))
				draw_polyline(pts, col, 6.0, true)
			DOT:
				draw_set_transform(pos, 0.0, Vector2(maxf(0.2, absf(flip)), 1.0) * s)
				draw_circle(Vector2.ZERO, 8.0, col, true, -1.0, true)
			STAR:
				draw_set_transform(pos, float(p["rot"]), Vector2(maxf(0.25, absf(flip)), 1.0) * s)
				draw_colored_polygon(DrawKit.star(Vector2.ZERO, 15.0, 6.5), col)
				draw_circle(Vector2(-3, -4), 3.0, Color(1, 1, 1, 0.7 * fade), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
