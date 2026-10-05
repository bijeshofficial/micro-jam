class_name BusWipe
extends Control
## Screen transition: a big microbus drives across, pulling a striped
## curtain over the old screen (phase 0 -> 1); a second one pushes it off
## to reveal the new screen (phase 1 -> 2).

const CURTAIN := Color("ffc300")
const ROAD := Color("8d8678")

@export var phase := 0.0:
	set(v):
		phase = clampf(v, 0.0, 2.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if phase <= 0.001 or phase >= 1.999:
		return
	var W := size.x
	var H := size.y
	var cell := clampf(W * 0.2, 120.0, 260.0)
	var L := cell * 3.0
	var front: float
	var c0: float
	var c1: float
	if phase <= 1.0:
		front = lerpf(0.0, W + L * 0.6, phase)
		c0 = 0.0
		c1 = front - L * 0.6
	else:
		front = lerpf(0.0, W + L, phase - 1.0)
		c0 = front - cell * 0.2
		c1 = W
	if c1 > c0:
		var r := Rect2(c0, 0, c1 - c0, H)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(c0, H)]),
			PackedColorArray([CURTAIN.lightened(0.2), CURTAIN.lightened(0.2), Color("ff9f1a"), Color("ff9f1a")]))
		# Plain bunting along the top.
		var cols := [Color("e63946"), Color("1d7fe0"), Color("2ec27e"), Color("ff5fa2"), Color("8e44ad")]
		var bx := c0 - fposmod(c0, 90.0)
		var i := int(bx / 90.0)
		while bx < c1:
			var a := maxf(bx, c0)
			var b := minf(bx + 80.0, c1)
			if b > a:
				draw_colored_polygon(PackedVector2Array([Vector2(a, 60), Vector2(b, 60), Vector2((a + b) * 0.5, 130)]), cols[posmod(i, cols.size())])
			bx += 90.0
			i += 1
		draw_line(Vector2(c0, 60), Vector2(c1, 60), Color("17213f"), 4.0)
		var road := Rect2(c0, H * 0.5 - cell * 0.75, c1 - c0, cell * 1.5)
		draw_rect(road, ROAD)
		var x := c0 - fposmod(c0, 140.0)
		while x < c1:
			if x + 70 > c0:
				draw_rect(Rect2(maxf(x, c0), H * 0.5 - 6, minf(70.0, c1 - maxf(x, c0)), 12), Color(1, 1, 1, 0.8))
			x += 140.0
		var f := UIKit.font(true)
		var fs := int(W * 0.11)
		var t := "MICRO JAM"
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := Vector2((W - tw) * 0.5, H * 0.28)
		if tp.x + tw > c0 and tp.x < c1:
			draw_string_outline(f, tp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.24), Color("17213f"))
			draw_string(f, tp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Dust puffs behind the bus.
	for i in 4:
		var px := front - L - 30.0 - i * 60.0
		draw_circle(Vector2(px, H * 0.5 + cell * 0.25 + (i % 2) * 20.0), cell * (0.22 - i * 0.04), Color(1, 1, 1, 0.5 - i * 0.1), true, -1.0, true)
	BusArt.draw_bus(self, Vector2(front - L * 0.5, H * 0.5 + cell * 0.15), cell, 3, Park.RIGHT, Color("e63946"), {"name": "Mero Gadi", "livery": "stripes", "arrow": false})
