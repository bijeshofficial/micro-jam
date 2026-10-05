class_name ParkBackdrop
extends Control
## The living background behind every screen: a clear sky, hazy blue
## mountains, drifting clouds and birds, colourful plain bunting, a tea stall
## with steam and sign boards with fictional town names. Below `horizon`
## (fraction of the height) is green ground. Weather comes from the theme
## (rain, snow, stars, festival lanterns).

var theme_id := "theme_morning":
	set(v):
		theme_id = v
		_theme = ParkTheme.get_theme(v)
		queue_redraw()
## Where the ground starts (0..1 of the height).
var horizon := 0.3:
	set(v):
		horizon = v
		queue_redraw()
## Draw the town strip (tea stall, signs, houses) on the horizon.
var town := true
## Draw weather particles over the whole rect.
var weather := true
## Bunting across the sky when the town strip is off.
var bunting := true

var _theme: Dictionary = ParkTheme.get_theme("theme_morning")
var _t := 0.0
var _rain: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 42
	for i in 70:
		_rain.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.4)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var W := size.x
	var H := size.y
	var hy := H * horizon
	var th := _theme
	# Sky.
	var sky := PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, hy + 2), Vector2(0, hy + 2)])
	draw_polygon(sky, PackedColorArray([ParkTheme.c(th, "sky_top"), ParkTheme.c(th, "sky_top"), ParkTheme.c(th, "sky_bottom"), ParkTheme.c(th, "sky_bottom")]))
	if bool(th["night"]):
		_stars(W, hy)
	# Sun / moon.
	if String(th["sun"]) != "":
		var sp := Vector2(W * 0.8, hy * 0.28 + 30)
		for k in 4:
			draw_circle(sp, 90.0 - k * 16.0, Color(ParkTheme.c(th, "sun"), 0.12 + k * 0.05), true, -1.0, true)
		draw_circle(sp, 46, ParkTheme.c(th, "sun"), true, -1.0, true)
		if bool(th["night"]):
			draw_circle(sp + Vector2(16, -10), 40, ParkTheme.c(th, "sky_top").lerp(ParkTheme.c(th, "sky_bottom"), 0.2), true, -1.0, true)
	# Mountains: far haze, then the near range with snow caps.
	_range(W, hy, hy * 0.42, 0.0013, 7.0, ParkTheme.c(th, "mountain_far"), ParkTheme.c(th, "snow"), 0.35)
	_range(W, hy, hy * 0.3, 0.0021, 2.0, ParkTheme.c(th, "mountain"), ParkTheme.c(th, "snow"), 0.55)
	_clouds(W, hy)
	_birds(W, hy)
	if town:
		_town(W, hy)
	elif bunting:
		_bunting(W, hy - 70, 18.0)
	# Ground.
	var grass := ParkTheme.c(th, "ground")
	draw_rect(Rect2(0, hy, W, H - hy), grass)
	draw_rect(Rect2(0, hy, W, 12), grass.darkened(0.12))
	var band := hy + 40.0
	var k := 0
	while band < H:
		if k % 2 == 0:
			draw_rect(Rect2(0, band, W, 40), Color(1, 1, 1, 0.05))
		band += 40.0
		k += 1
	if bool(th["festival"]) and (town or bunting):
		_lanterns(W, hy)
	if weather:
		match String(th["weather"]):
			"rain":
				_rain_fx(W, H)
			"snow":
				_snow_fx(W, H)


func _range(W: float, hy: float, height: float, freq: float, phase: float, col: Color, snow: Color, snow_amt: float) -> void:
	var pts := PackedVector2Array([Vector2(0, hy)])
	var peaks: Array = []
	var x := 0.0
	while x <= W + 20:
		var n := sin(x * freq * 3.1 + phase) * 0.5 + sin(x * freq * 7.3 + phase * 2.0) * 0.3 + sin(x * freq * 13.0 + phase) * 0.2
		var y := hy - height * (0.55 + 0.45 * n)
		pts.append(Vector2(x, y))
		peaks.append(Vector2(x, y))
		x += 18.0
	pts.append(Vector2(W + 20, hy))
	draw_colored_polygon(pts, col)
	# Snow on the upper part of each slope.
	var top := hy - height
	var line := top + height * snow_amt * 0.6
	for i in range(1, peaks.size() - 1):
		var p: Vector2 = peaks[i]
		if p.y < line and p.y <= (peaks[i - 1] as Vector2).y and p.y <= (peaks[i + 1] as Vector2).y:
			var d := line - p.y
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(d * 0.9, d), p + Vector2(d * 0.3, d * 0.8), p + Vector2(0, d), p + Vector2(-d * 0.4, d * 0.75), p + Vector2(-d * 0.9, d)]), Color(snow, 0.9))


func _clouds(W: float, hy: float) -> void:
	var night := bool(_theme["night"])
	var col := Color(1, 1, 1, 0.85) if not night else Color(0.75, 0.8, 0.95, 0.18)
	if String(_theme["weather"]) == "rain":
		col = Color(0.9, 0.92, 0.96, 0.9)
	for i in 4:
		var speed := 14.0 + i * 6.0
		var x := fposmod(_t * speed + i * 330.0, W + 500.0) - 250.0
		var y := hy * (0.14 + 0.13 * i)
		var s := 1.0 - i * 0.12
		for k in 4:
			draw_circle(Vector2(x + k * 46 * s, y - (18 if k % 2 == 1 else 0) * s), (40 + (k % 2) * 14) * s, col, true, -1.0, true)
		draw_rect(Rect2(x - 4, y, 150 * s, 30 * s), col)


func _birds(W: float, hy: float) -> void:
	if bool(_theme["night"]):
		return
	var col := Color(0.2, 0.24, 0.35, 0.7)
	for i in 3:
		var x := fposmod(_t * (60.0 + i * 15.0) + i * 400.0, W + 300.0) - 150.0
		var y := hy * 0.35 + sin(_t * 1.5 + i) * 20.0 + i * 26.0
		var flap := sin(_t * 9.0 + i * 2.0) * 8.0
		draw_polyline(PackedVector2Array([Vector2(x - 16, y - 4 - flap), Vector2(x, y), Vector2(x + 16, y - 4 - flap)]), col, 4.0, true)


func _stars(W: float, hy: float) -> void:
	for i in 40:
		var x := fposmod(i * 197.3, W)
		var y := fposmod(i * 83.7, hy * 0.75)
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + i)
		draw_circle(Vector2(x, y), 2.0 + tw * 1.5, Color(1, 1, 0.9, 0.4 + tw * 0.5), true, -1.0, true)


## Little houses, the tea stall with steam, sign boards and bunting.
func _town(W: float, hy: float) -> void:
	var night := bool(_theme["night"])
	var walls := [Color("f2a65a"), Color("e8dcc6"), Color("7fb3d5"), Color("f7d774"), Color("e07a5f"), Color("c9e4ca")]
	var x := -20.0
	var i := 0
	while x < W:
		var w := 110.0 + float((i * 37) % 60)
		var h := 70.0 + float((i * 53) % 70)
		var wall: Color = walls[i % walls.size()]
		if night:
			wall = wall.darkened(0.55)
		draw_rect(Rect2(x, hy - h, w, h), wall)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, hy - h), Vector2(x + w + 8, hy - h), Vector2(x + w - 6, hy - h - 24), Vector2(x + 6, hy - h - 24)]), Color("a8443b").darkened(0.5 if night else 0.0))
		for k in int(w / 40.0):
			var win := Rect2(x + 14 + k * 40, hy - h + 20, 20, 24)
			draw_rect(win, Color("ffd76a") if night else Color("3b4a66"))
		x += w + 6
		i += 1
	# Tea stall on the left with steam.
	var sx := W * 0.08
	draw_rect(Rect2(sx, hy - 96, 160, 96), Color("2ec27e").darkened(0.5 if night else 0.1))
	for k in 5:
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 10 + k * 36, hy - 120), Vector2(sx + 26 + k * 36, hy - 120), Vector2(sx + 26 + k * 36, hy - 92), Vector2(sx - 10 + k * 36, hy - 92)]), Color("e63946") if k % 2 == 0 else Color("fff6dc"))
	draw_rect(Rect2(sx + 20, hy - 60, 120, 14), Color("fff6dc"))
	var f := UIKit.font(true)
	draw_string(f, Vector2(sx + 30, hy - 66), "CHIYA", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("fff6dc"))
	for k in 3:
		var ph := fposmod(_t * 0.5 + k / 3.0, 1.0)
		draw_circle(Vector2(sx + 120 + sin(ph * 6.0 + k) * 10, hy - 70 - ph * 90), 10 + ph * 14, Color(1, 1, 1, 0.5 * (1.0 - ph)), true, -1.0, true)
	# Two route sign boards.
	for k in 2:
		var bx := W * (0.55 + k * 0.24)
		draw_rect(Rect2(bx - 4, hy - 120, 8, 120), Color("4a5263"))
		var board := Rect2(bx - 90, hy - 170, 180, 58)
		draw_colored_polygon(DrawKit.rounded_rect(board.grow(4), 12, 4), Color("1f2433"))
		draw_colored_polygon(DrawKit.rounded_rect(board, 10, 4), Color("1d7fe0") if k == 0 else Color("2ec27e"))
		var town_name := GameData.town(k * 5 + 1)
		var fs := 26
		var tw := f.get_string_size(town_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(bx - tw * 0.5, board.position.y + 40), town_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Plain bunting across the top of the town.
	_bunting(W, hy - 190, 26.0)


func _bunting(W: float, y: float, sag: float) -> void:
	var cols := [Color("e63946"), Color("ffc300"), Color("1d7fe0"), Color("2ec27e"), Color("ff7f11"), Color("ff5fa2")]
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector2(W * t, y + sin(t * PI * 2.0) * sag * 0.4 + 4.0 * sin(t * PI) * sag * 0.5))
	draw_polyline(pts, Color("4a5263"), 3.0, true)
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var sway := sin(_t * 2.0 + i) * 3.0
		var tip := a.lerp(b, 0.5) + Vector2(sway, 30)
		draw_colored_polygon(PackedVector2Array([a + (b - a) * 0.1, a + (b - a) * 0.9, tip]), cols[i % cols.size()])


func _lanterns(W: float, hy: float) -> void:
	var y := hy - 250.0
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector2(W * t, y + 4.0 * sin(t * PI) * 22.0))
	draw_polyline(pts, Color("5b3a2a"), 3.0, true)
	var cols := [Color("ff5fa2"), Color("ffc300"), Color("ff7f11"), Color("8e44ad")]
	for i in range(1, 12):
		var p: Vector2 = pts[i] + Vector2(sin(_t * 1.6 + i) * 4.0, 34)
		draw_line(pts[i], p - Vector2(0, 22), Color("5b3a2a"), 2.0)
		var col: Color = cols[i % cols.size()]
		draw_colored_polygon(DrawKit.ellipse(p, 20, 24, 16), col)
		draw_colored_polygon(DrawKit.ellipse(p, 12, 24, 12), col.lightened(0.3))
		draw_rect(Rect2(p.x - 10, p.y - 28, 20, 6), Color("5b3a2a"))


func _rain_fx(W: float, H: float) -> void:
	for r in _rain:
		var v: Vector3 = r
		var y := fposmod(v.y * H + _t * 1300.0 * v.z, H + 60.0) - 30.0
		var x := fposmod(v.x * W - y * 0.18, W)
		draw_line(Vector2(x, y), Vector2(x - 6, y + 34 * v.z), Color(0.85, 0.9, 1.0, 0.45), 3.0, true)


func _snow_fx(W: float, H: float) -> void:
	for r in _rain:
		var v: Vector3 = r
		var y := fposmod(v.y * H + _t * 110.0 * v.z, H + 20.0) - 10.0
		var x := fposmod(v.x * W + sin(_t * v.z + v.x * 10.0) * 30.0, W)
		draw_circle(Vector2(x, y), 4.0 * v.z, Color(1, 1, 1, 0.85), true, -1.0, true)
