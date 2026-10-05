@tool
class_name IconView
extends Control
## Vector icons drawn in code (no emoji, no image files).

@export var icon := "coin":
	set(v):
		icon = v
		queue_redraw()
@export var color := Color("2b2622"):
	set(v):
		color = v
		queue_redraw()
@export var accent := Color.WHITE:
	set(v):
		accent = v
		queue_redraw()
## Game-style drop shadow under the icon (white icons on glossy buttons).
@export var shadow := false:
	set(v):
		shadow = v
		queue_redraw()
@export var shadow_color := Color("26165e"):
	set(v):
		shadow_color = v
		queue_redraw()

const NO_SHADOW := ["coin", "coin_pile", "bus", "ticket", "chest", "flame"]


func _draw() -> void:
	if shadow and not NO_SHADOW.has(icon):
		var off := minf(size.x, size.y) * 0.06
		draw_set_transform(Vector2(0, off))
		_shape(Color(shadow_color, 0.85), Color(shadow_color, 0.85))
		draw_set_transform(Vector2.ZERO)
	_shape(color, accent)



func _shape(_c: Color, _a: Color) -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	var c := size * 0.5
	var u := s / 100.0  # draw on a 100x100 grid
	var o := c - Vector2(50, 50) * u
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * u
	var w := 9.0 * u
	match icon:
		"coin":
			draw_circle(c, 46 * u, Color("b07c14"), true, -1.0, true)
			draw_circle(c + Vector2(0, -3) * u, 42 * u, Color("f2b632"), true, -1.0, true)
			draw_arc(c + Vector2(0, -3) * u, 29 * u, 0, TAU, 40, Color("d69a1c"), 6 * u, true)
			draw_line(p.call(50, 33), p.call(50, 61), Color("b07c14"), 8 * u, true)
		"coin_pile":
			for k in 3:
				var cc := p.call(30 + k * 20, 70 - k * 18) as Vector2
				draw_circle(cc, 26 * u, Color("b07c14"), true, -1.0, true)
				draw_circle(cc + Vector2(0, -3) * u, 23 * u, Color("f2b632"), true, -1.0, true)
				draw_arc(cc + Vector2(0, -3) * u, 15 * u, 0, TAU, 24, Color("d69a1c"), 4 * u, true)
		"heart":
			var pts := PackedVector2Array()
			for i in 40:
				var t := TAU * i / 40.0
				pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)) + 2.0) * 2.7 * u)
			draw_colored_polygon(pts, _c)
			draw_colored_polygon(DrawKit.ellipse(p.call(34, 34), 8 * u, 5 * u, 12), Color(1, 1, 1, 0.5))
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 26 * u, c + Vector2(cos(a), sin(a)) * 44 * u, _c, 16 * u, true)
			draw_circle(c, 32 * u, _c, true, -1.0, true)
			draw_circle(c, 13 * u, _a, true, -1.0, true)
		"plus":
			draw_line(p.call(50, 18), p.call(50, 82), _c, 16 * u, true)
			draw_line(p.call(18, 50), p.call(82, 50), _c, 16 * u, true)
		"shop":
			# A little stall with a striped awning.
			DrawKit.rrect(self, Rect2(p.call(16, 44), Vector2(68, 46) * u), 6 * u, _c)
			for k in 4:
				var x0 := 8.0 + k * 21.0
				draw_colored_polygon(PackedVector2Array([p.call(x0 + 4, 12), p.call(x0 + 25, 12), p.call(x0 + 21, 40), p.call(x0, 40)]), _c if k % 2 == 0 else _c.lightened(0.35))
				draw_circle(p.call(x0 + 10.5, 40), 10.5 * u, _c if k % 2 == 0 else _c.lightened(0.35), true, -1.0, true)
			DrawKit.rrect(self, Rect2(p.call(40, 60), Vector2(20, 30) * u), 4 * u, _a)
		"home":
			draw_colored_polygon(PackedVector2Array([p.call(50, 10), p.call(94, 48), p.call(6, 48)]), _c)
			draw_rect(Rect2(p.call(18, 44), Vector2(64, 46) * u), _c)
			DrawKit.rrect(self, Rect2(p.call(40, 58), Vector2(20, 32) * u), 4 * u, _a)
		"profile":
			draw_circle(p.call(50, 32), 22 * u, _c, true, -1.0, true)
			var sh := PackedVector2Array()
			for i in 21:
				var a := PI + PI * i / 20.0
				sh.append(p.call(50, 94) + Vector2(cos(a) * 40, sin(a) * 36) * u)
			draw_colored_polygon(sh, _c)
		"undo":
			draw_arc(p.call(54, 56), 30 * u, -PI * 0.5, PI * 0.8, 24, _c, 13 * u, true)
			draw_line(p.call(54, 26), p.call(34, 26), _c, 13 * u, true)
			draw_colored_polygon(PackedVector2Array([p.call(10, 26), p.call(38, 6), p.call(38, 46)]), _c)
		"calendar":
			DrawKit.rrect(self, Rect2(p.call(8, 16), Vector2(84, 76) * u), 12 * u, _c)
			DrawKit.rrect(self, Rect2(p.call(8, 16), Vector2(84, 22) * u), 10 * u, _c.darkened(0.25) if _c != Color.WHITE else Color("ffcf3a"))
			draw_line(p.call(28, 6), p.call(28, 24), _c, 9 * u, true)
			draw_line(p.call(72, 6), p.call(72, 24), _c, 9 * u, true)
			for k in 6:
				draw_circle(p.call(26 + (k % 3) * 24, 54 + (k / 3) * 20), 6 * u, _a, true, -1.0, true)
		"tasks":
			DrawKit.rrect(self, Rect2(p.call(14, 12), Vector2(72, 84) * u), 12 * u, _c)
			DrawKit.rrect(self, Rect2(p.call(34, 4), Vector2(32, 16) * u), 6 * u, _c.darkened(0.25) if _c != Color.WHITE else Color("ffcf3a"))
			for k in 3:
				var y := 36.0 + k * 20.0
				draw_polyline(PackedVector2Array([p.call(24, y), p.call(30, y + 6), p.call(40, y - 6)]), _a, 5 * u, true)
				draw_line(p.call(48, y), p.call(76, y), _a, 6 * u, true)
		"chest":
			DrawKit.rrect(self, Rect2(p.call(8, 40), Vector2(84, 52) * u), 10 * u, Color("b8642a"))
			DrawKit.rrect(self, Rect2(p.call(8, 22), Vector2(84, 30) * u), 14 * u, Color("d9823a"))
			draw_rect(Rect2(p.call(8, 46), Vector2(84, 8) * u), Color("ffcf3a"))
			draw_rect(Rect2(p.call(44, 22), Vector2(12, 70) * u), Color("ffcf3a"))
			DrawKit.rrect(self, Rect2(p.call(40, 42), Vector2(20, 18) * u), 4 * u, Color("fff2a8"))
		"target":
			draw_arc(c, 34 * u, 0, TAU, 32, _c, 10 * u, true)
			draw_circle(c, 12 * u, _c, true, -1.0, true)
			for k in 4:
				var a := TAU * k / 4.0
				draw_line(c + Vector2(cos(a), sin(a)) * 34 * u, c + Vector2(cos(a), sin(a)) * 48 * u, _c, 9 * u, true)
		"flame":
			var fl := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0
				var a := PI * 2.0 * t
				var r := 30.0 + 10.0 * sin(a * 3.0) * (1.0 - absf(sin(a * 0.5)))
				fl.append(p.call(50, 62) + Vector2(sin(a) * r, -cos(a) * r * 1.3) * u)
			draw_colored_polygon(DrawKit.ellipse(p.call(50, 64), 32 * u, 30 * u, 24), Color("ff7f11"))
			draw_colored_polygon(PackedVector2Array([p.call(22, 60), p.call(36, 10), p.call(50, 34), p.call(62, 4), p.call(80, 56)]), Color("ff7f11"))
			draw_colored_polygon(DrawKit.ellipse(p.call(50, 70), 18 * u, 18 * u, 18), Color("ffd84a"))
		"crane":
			# Boom, cable and hook.
			draw_line(p.call(12, 90), p.call(12, 18), _c, 10 * u, true)
			draw_line(p.call(8, 18), p.call(90, 18), _c, 10 * u, true)
			draw_line(p.call(12, 40), p.call(34, 18), _c, 6 * u, true)
			draw_line(p.call(74, 18), p.call(74, 52), _c, 5 * u, true)
			draw_arc(p.call(74, 64), 10 * u, -PI * 0.2, PI * 1.2, 10, _c, 6 * u, true)
			DrawKit.rrect(self, Rect2(p.call(2, 84), Vector2(24, 10) * u), 3 * u, _c)
		"bay_plus":
			# A parking bay (U lines) with a plus.
			draw_polyline(PackedVector2Array([p.call(14, 14), p.call(14, 86), p.call(62, 86), p.call(62, 14)]), _c, 9 * u, true)
			draw_circle(p.call(74, 36), 22 * u, _a, true, -1.0, true)
			draw_circle(p.call(74, 36), 18 * u, _c, true, -1.0, true)
			draw_line(p.call(74, 25), p.call(74, 47), _a, 6 * u, true)
			draw_line(p.call(63, 36), p.call(85, 36), _a, 6 * u, true)
		"bus":
			BusArt.draw_bus(self, c + Vector2(0, 6) * u, 44 * u, 2, 1, accent if accent != Color.WHITE else Color("e63946"), {"shadow": false, "arrow": false})
		"ticket":
			var t := DrawKit.rounded_rect(Rect2(p.call(4, 24), Vector2(92, 52) * u), 8 * u, 4)
			draw_colored_polygon(t, Color("ffc300"))
			draw_circle(p.call(4, 50), 9 * u, Color(0, 0, 0, 0), true)
			for k in 5:
				draw_circle(p.call(66, 30 + k * 10), 2.5 * u, Color("b07c14"), true, -1.0, true)
			draw_line(p.call(16, 42), p.call(56, 42), Color("b07c14"), 5 * u, true)
			draw_line(p.call(16, 58), p.call(46, 58), Color("b07c14"), 5 * u, true)
		"horn":
			draw_colored_polygon(PackedVector2Array([p.call(10, 40), p.call(30, 40), p.call(80, 14), p.call(80, 86), p.call(30, 60), p.call(10, 60)]), _c)
			draw_circle(p.call(14, 50), 12 * u, _c, true, -1.0, true)
		"map":
			draw_colored_polygon(PackedVector2Array([p.call(6, 18), p.call(34, 8), p.call(66, 18), p.call(94, 8), p.call(94, 82), p.call(66, 92), p.call(34, 82), p.call(6, 92)]), _c)
			draw_polyline(PackedVector2Array([p.call(16, 74), p.call(36, 50), p.call(58, 62), p.call(84, 28)]), _a, 6 * u, true)
		"shuffle":
			var w2 := 10 * u
			draw_polyline(PackedVector2Array([p.call(8, 28), p.call(30, 28), p.call(62, 72), p.call(80, 72)]), _c, w2, true)
			draw_polyline(PackedVector2Array([p.call(8, 72), p.call(30, 72), p.call(62, 28), p.call(80, 28)]), _c, w2, true)
			draw_colored_polygon(PackedVector2Array([p.call(96, 28), p.call(76, 12), p.call(76, 44)]), _c)
			draw_colored_polygon(PackedVector2Array([p.call(96, 72), p.call(76, 56), p.call(76, 88)]), _c)
		"pause":
			DrawKit.rrect(self, Rect2(p.call(24, 18), Vector2(18, 64) * u), 6 * u, _c)
			DrawKit.rrect(self, Rect2(p.call(58, 18), Vector2(18, 64) * u), 6 * u, _c)
		"play":
			draw_colored_polygon(PackedVector2Array([p.call(28, 14), p.call(86, 50), p.call(28, 86)]), _c)
		"ad":
			DrawKit.rrect(self, Rect2(p.call(6, 18), Vector2(88, 64) * u), 16 * u, _c)
			draw_colored_polygon(PackedVector2Array([p.call(40, 34), p.call(66, 50), p.call(40, 66)]), _a)
		"gift":
			DrawKit.rrect(self, Rect2(p.call(12, 40), Vector2(76, 52) * u), 6 * u, _c)
			DrawKit.rrect(self, Rect2(p.call(6, 28), Vector2(88, 18) * u), 5 * u, _c.darkened(0.12))
			draw_rect(Rect2(p.call(43, 28), Vector2(14, 64) * u), _a)
			draw_arc(p.call(38, 24), 12 * u, PI * 0.1, PI * 1.9, 14, _a, 7 * u, true)
			draw_arc(p.call(62, 24), 12 * u, -PI * 0.9, PI * 0.9, 14, _a, 7 * u, true)
		"trophy":
			draw_colored_polygon(PackedVector2Array([p.call(24, 12), p.call(76, 12), p.call(70, 46), p.call(50, 60), p.call(30, 46)]), _c)
			draw_arc(p.call(24, 28), 14 * u, PI * 0.5, PI * 1.5, 12, _c, 7 * u, true)
			draw_arc(p.call(76, 28), 14 * u, -PI * 0.5, PI * 0.5, 12, _c, 7 * u, true)
			draw_rect(Rect2(p.call(44, 58), Vector2(12, 18) * u), _c)
			DrawKit.rrect(self, Rect2(p.call(28, 76), Vector2(44, 14) * u), 4 * u, _c)
		"lock":
			draw_arc(p.call(50, 44), 20 * u, PI, TAU, 20, _c, 10 * u, true)
			draw_line(p.call(30, 44), p.call(30, 50), _c, 10 * u)
			draw_line(p.call(70, 44), p.call(70, 50), _c, 10 * u)
			DrawKit.rrect(self, Rect2(p.call(18, 46), Vector2(64, 46) * u), 10 * u, _c)
			draw_circle(p.call(50, 66), 7 * u, _a, true, -1.0, true)
		"check":
			draw_polyline(PackedVector2Array([p.call(16, 52), p.call(40, 76), p.call(86, 26)]), _c, 14 * u, true)
		"close":
			draw_line(p.call(22, 22), p.call(78, 78), _c, 13 * u, true)
			draw_line(p.call(78, 22), p.call(22, 78), _c, 13 * u, true)
		"back":
			draw_polyline(PackedVector2Array([p.call(58, 16), p.call(24, 50), p.call(58, 84)]), _c, 13 * u, true)
			draw_line(p.call(26, 50), p.call(84, 50), _c, 13 * u, true)
		"retry":
			draw_arc(c, 32 * u, -PI * 0.35, PI * 1.45, 32, _c, w * 1.3, true)
			draw_colored_polygon(PackedVector2Array([p.call(70, 8), p.call(92, 30), p.call(64, 36)]), _c)
		"star":
			draw_colored_polygon(DrawKit.star(c, 46 * u, 20 * u, 5), _c)
		"sound":
			draw_colored_polygon(PackedVector2Array([p.call(10, 36), p.call(30, 36), p.call(54, 14), p.call(54, 86), p.call(30, 64), p.call(10, 64)]), _c)
			draw_arc(p.call(54, 50), 20 * u, -0.9, 0.9, 12, _c, w, true)
			draw_arc(p.call(54, 50), 36 * u, -0.9, 0.9, 16, _c, w, true)
		"music":
			draw_line(p.call(40, 72), p.call(40, 16), _c, w, true)
			draw_line(p.call(80, 62), p.call(80, 8), _c, w, true)
			draw_line(p.call(40, 18), p.call(80, 10), _c, w * 1.6, true)
			draw_circle(p.call(30, 74), 14 * u, _c, true, -1.0, true)
			draw_circle(p.call(70, 66), 14 * u, _c, true, -1.0, true)
		"vibrate":
			DrawKit.rrect(self, Rect2(p.call(32, 12), Vector2(36, 76) * u), 8 * u, _c)
			DrawKit.rrect(self, Rect2(p.call(38, 20), Vector2(24, 52) * u), 3 * u, _a)
			for side in [-1.0, 1.0]:
				var x0: float = 50.0 + side * 30.0
				var x1: float = 50.0 + side * 42.0
				draw_polyline(PackedVector2Array([p.call(x0, 30), p.call(x1, 40), p.call(x0, 50), p.call(x1, 60), p.call(x0, 70)]), _c, 5 * u, true)
		"bulb":
			draw_circle(p.call(50, 40), 28 * u, _c, true, -1.0, true)
			draw_rect(Rect2(p.call(38, 58), Vector2(24, 18) * u), _c)
			DrawKit.rrect(self, Rect2(p.call(36, 76), Vector2(28, 10) * u), 4 * u, _c.darkened(0.2))
			draw_arc(p.call(50, 40), 16 * u, PI * 1.1, PI * 1.6, 8, _a, 5 * u, true)
		"hand":
			DrawKit.capsule(self, p.call(42, 14), p.call(42, 60), 9 * u, _c)
			DrawKit.rrect(self, Rect2(p.call(30, 50), Vector2(50, 44) * u), 18 * u, _c)
			DrawKit.capsule(self, p.call(58, 48), p.call(58, 60), 8 * u, _c)
			DrawKit.capsule(self, p.call(72, 52), p.call(72, 64), 7 * u, _c)
			DrawKit.capsule(self, p.call(30, 66), p.call(20, 56), 8 * u, _c)
		"clock":
			draw_circle(c, 44 * u, _c, true, -1.0, true)
			draw_circle(c, 34 * u, _a, true, -1.0, true)
			draw_line(c, p.call(50, 28), _c, 8 * u, true)
			draw_line(c, p.call(66, 58), _c, 8 * u, true)
		"pencil":
			draw_colored_polygon(PackedVector2Array([p.call(20, 70), p.call(66, 24), p.call(80, 38), p.call(34, 84)]), _c)
			draw_colored_polygon(PackedVector2Array([p.call(20, 70), p.call(34, 84), p.call(12, 92)]), _c.darkened(0.3))
		_:
			draw_circle(c, 30 * u, _c, true, -1.0, true)
