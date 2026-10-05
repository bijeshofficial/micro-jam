class_name GameBackdrop
extends Control
## The hub's vivid game background: a deep sky-blue to violet gradient,
## a soft glow at the top, slow drifting bokeh and faint light rays.

const TOP := Color("3fb4ff")
const MID := Color("3a63f2")
const BOTTOM := Color("6a35d6")

var _t := 0.0
var _bokeh: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 18:
		_bokeh.append([rng.randf(), rng.randf(), rng.randf_range(30.0, 110.0), rng.randf_range(0.04, 0.12), rng.randf_range(0.3, 1.0)])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var W := size.x
	var H := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H * 0.5), Vector2(0, H * 0.5)]),
		PackedColorArray([TOP, TOP, MID, MID]))
	draw_polygon(PackedVector2Array([Vector2(0, H * 0.5), Vector2(W, H * 0.5), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([MID, MID, BOTTOM, BOTTOM]))
	# Light rays fanning from the top centre, turning slowly.
	var c := Vector2(W * 0.5, -H * 0.1)
	for i in 10:
		var a := PI * 0.5 + (i - 4.5) * 0.2 + sin(_t * 0.15) * 0.05
		var p1 := c + Vector2(cos(a - 0.05), sin(a - 0.05)) * H * 1.4
		var p2 := c + Vector2(cos(a + 0.05), sin(a + 0.05)) * H * 1.4
		draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(1, 1, 1, 0.035))
	for k in 5:
		draw_circle(Vector2(W * 0.5, 0), W * (0.7 - k * 0.12), Color(1, 1, 1, 0.025), true, -1.0, true)
	# Bokeh drifting upward.
	for b in _bokeh:
		var y := fposmod(float(b[1]) * H - _t * 14.0 * float(b[4]), H + 240.0) - 120.0
		var x := float(b[0]) * W + sin(_t * 0.4 * float(b[4]) + float(b[1]) * 9.0) * 30.0
		draw_circle(Vector2(x, y), float(b[2]), Color(1, 1, 1, float(b[3])), true, -1.0, true)
		draw_arc(Vector2(x, y), float(b[2]), 0, TAU, 40, Color(1, 1, 1, float(b[3]) * 1.2), 2.0, true)
