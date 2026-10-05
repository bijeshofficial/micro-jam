class_name RouteMap
extends Control
## The Home route map: a full-screen, draggable road that winds up through
## changing scenery (meadows, terraced hills, river valley, pine forest,
## snowy passes). Every level is a glossy stop; every 5th gets a town sign,
## every 10th a gift chest. Your microbus waits at the current stop and
## drives on from the last stop you saw. Tap the current stop to play.

signal play_requested

const GAP := 250.0                 # world px between stops
const BIOME_LEN := 25              # levels per scenery band
const ROAD_W := 112.0
## [ground, ground dark, tree, accent] per biome.
const BIOMES := [
	[Color("86dd6f"), Color("6cc95a"), Color("2f9e57"), Color("ffd84a")],   # meadow
	[Color("a6dd5c"), Color("8bc64a"), Color("3f9a3f"), Color("ff8a3d")],   # terraced hills
	[Color("72d48c"), Color("57bd74"), Color("238a5a"), Color("4fb4ff")],   # river valley
	[Color("5fbf74"), Color("479f5d"), Color("1f6e46"), Color("ff5fa2")],   # pine forest
	[Color("e6f1ff"), Color("c9dcf5"), Color("3d7a6a"), Color("8fc4ff")],   # snowy pass
]

var level := 1
var token_t := 1.0          # bus position in stop units (float)
## Screen y of world y = 0 (scrolling moves this).
var scroll := 0.0
var top_pad := 150.0
var bottom_pad := 420.0

var _t := 0.0
var _token_tween: Tween
var _drag_from := Vector2.ZERO
var _dragging := false
var _dragged := false
var _vel := 0.0
var _last_move := 0
var _settle: Tween
var _bridges: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(func() -> void: center_on(token_t, false))


func refresh(animate: bool) -> void:
	level = ProgressionManager.current_level()
	var seen := clampi(ProgressionManager.route_seen_level(), 1, level)
	if _token_tween:
		_token_tween.kill()
	if animate and seen < level:
		token_t = float(seen)
		_token_tween = create_tween()
		_token_tween.tween_interval(0.5)
		_token_tween.tween_callback(AudioManager.play.bind("drive"))
		_token_tween.tween_property(self, "token_t", float(level), 0.9 + 0.15 * minf(level - seen, 6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_token_tween.tween_callback(_arrived)
	else:
		token_t = float(level)
		if seen < level:
			ProgressionManager.mark_route_seen()
	center_on(float(level), false)


func _arrived() -> void:
	AudioManager.horn()
	ProgressionManager.mark_route_seen()


# --- Geometry ----------------------------------------------------------------

func world_y(n: float) -> float:
	return -n * GAP


func stop_x(n: float) -> float:
	return size.x * 0.5 + sin(n * 0.95) * size.x * 0.27


## Screen position of a (fractional) stop.
func stop_pos(n: float) -> Vector2:
	return Vector2(stop_x(n), world_y(n) + scroll)


## Puts stop n at about 58% of the visible area.
func center_on(n: float, animate: bool = true) -> void:
	var view_h := size.y - top_pad - bottom_pad
	var target := top_pad + view_h * 0.62 - world_y(n)
	target = _clamp_scroll(target)
	if _settle:
		_settle.kill()
	if animate:
		_settle = create_tween()
		_settle.tween_property(self, "scroll", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		scroll = target


func _clamp_scroll(v: float) -> float:
	# Lowest: level 1 sits just above the PLAY button. Highest: 12 stops ahead.
	var lo := size.y - bottom_pad - 60.0 - world_y(1.0)
	var hi := top_pad + 120.0 - world_y(float(level + 12))
	return clampf(v, lo, maxf(lo, hi))


func is_centered() -> bool:
	var view_h := size.y - top_pad - bottom_pad
	return absf(stop_pos(float(level)).y - (top_pad + view_h * 0.62)) < GAP * 1.5


# --- Input: drag to scroll, tap the current stop to play ---------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_dragged = false
			_vel = 0.0
			_drag_from = event.position
			if _settle:
				_settle.kill()
		else:
			_dragging = false
			if not _dragged and event.position.distance_to(stop_pos(float(level))) < 110.0:
				play_requested.emit()
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		if absf(event.position.y - _drag_from.y) > 18.0:
			_dragged = true
		if _dragged:
			scroll = _clamp_scroll(scroll + event.relative.y)
			var now := Time.get_ticks_msec()
			var dt := maxf(1.0, float(now - _last_move)) / 1000.0
			_vel = lerpf(_vel, event.relative.y / dt, 0.4)
			_last_move = now
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	if not _dragging and absf(_vel) > 5.0:
		scroll = _clamp_scroll(scroll + _vel * delta)
		_vel *= pow(0.04, delta)
	queue_redraw()


# --- Drawing -----------------------------------------------------------------

func _biome(n: float) -> int:
	return int(floor(maxf(0.0, n - 1.0) / BIOME_LEN)) % BIOMES.size()


## Ground colour at stop n, blended across biome borders.
func _ground(n: float, dark: bool = false) -> Color:
	var k := 1 if dark else 0
	var b := _biome(n)
	var into := fposmod(maxf(0.0, n - 1.0), float(BIOME_LEN))
	var col: Color = BIOMES[b][k]
	if into > BIOME_LEN - 3.0:
		col = col.lerp(BIOMES[(b + 1) % BIOMES.size()][k], (into - (BIOME_LEN - 3.0)) / 3.0)
	return col


func _draw() -> void:
	var W := size.x
	var H := size.y
	# Visible stop range (world y grows upward with the level).
	var n_top := (scroll - 0.0) / GAP + 1.5
	var n_bottom := (scroll - H) / GAP - 1.5
	var first := int(floor(n_bottom))
	var last := int(ceil(n_top))
	# Ground in horizontal bands with stripes for texture.
	var y := H
	var band := 60.0
	while y > -band:
		var n := (scroll - y) / GAP
		var col := _ground(n)
		draw_rect(Rect2(0, y - band, W, band + 1), col)
		var stripe := int(floor((scroll - y) / band))
		if stripe % 2 == 0:
			draw_rect(Rect2(0, y - band, W, band + 1), Color(1, 1, 1, 0.05))
		y -= band
	_bridges.clear()
	for n in range(first, last + 1):
		_scenery(n)
	_road(maxi(first, 0), last)
	for by in _bridges:
		_bridge(float(by))
	for n in range(maxi(first, 1), last + 1):
		_stop(n)
	_token()
	_clouds()


## Trees, houses, fields, ponds and rivers beside the road for stop n.
func _scenery(n: int) -> void:
	if n < 0:
		return
	var b := _biome(float(n))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(n * 7919 + 13)
	var p := stop_pos(float(n))
	var side := -1.0 if stop_x(float(n)) > size.x * 0.5 else 1.0
	var far_x := size.x * 0.5 + side * size.x * 0.33
	var mid := p.y + GAP * 0.5
	# River every 9 stops in the river valley (and once a band elsewhere).
	if (b == 2 and n % 3 == 0) or n % BIOME_LEN == 12:
		_river(mid)
	match b:
		0:
			_patch(Vector2(far_x, p.y + 30), 150, 70, _ground(float(n), true))
			_tree(Vector2(far_x - 60 * side, p.y), 1.0, BIOMES[0][2])
			_tree(Vector2(far_x + 40 * side, p.y + 40), 0.8, BIOMES[0][2])
			_flowers(Vector2(far_x + 10, p.y + 70), rng)
			if n % 2 == 0:
				_house(Vector2(size.x * 0.5 - side * size.x * 0.36, mid), 1.0, n)
		1:
			_terraces(Vector2(far_x, p.y + 20), side)
			if n % 2 == 1:
				_house(Vector2(far_x + 20 * side, p.y - 10), 1.0, n)
			_tree(Vector2(size.x * 0.5 - side * size.x * 0.4, mid), 0.9, BIOMES[1][2])
		2:
			_tree(Vector2(far_x, p.y), 1.1, BIOMES[2][2])
			_tree(Vector2(far_x + 70 * side, p.y + 50), 0.8, BIOMES[2][2])
			_pond(Vector2(size.x * 0.5 - side * size.x * 0.37, mid + 20))
		3:
			for k in 3:
				_pine(Vector2(far_x + (k - 1) * 70 * side, p.y + k * 26 - 20), 1.0 - k * 0.1, BIOMES[3][2], false)
			_pine(Vector2(size.x * 0.5 - side * size.x * 0.4, mid), 0.9, BIOMES[3][2], false)
		4:
			_pine(Vector2(far_x, p.y), 1.0, BIOMES[4][2], true)
			_pine(Vector2(far_x + 60 * side, p.y + 40), 0.8, BIOMES[4][2], true)
			if n % 2 == 0:
				_house(Vector2(size.x * 0.5 - side * size.x * 0.36, mid), 0.95, n)
			_rock(Vector2(far_x - 50 * side, p.y + 80))


func _road(first: int, last: int) -> void:
	var pts := PackedVector2Array()
	var steps := (last - first) * 10
	for i in steps + 1:
		pts.append(stop_pos(lerpf(float(first), float(last), float(i) / steps)))
	if pts.size() < 2:
		return
	var shadow := PackedVector2Array()
	for q in pts:
		shadow.append(q + Vector2(0, 10))
	draw_polyline(shadow, Color(0, 0, 0, 0.16), ROAD_W + 26, true)
	draw_polyline(pts, Color("2b3150"), ROAD_W + 22, true)
	draw_polyline(pts, Color("f4f6fb"), ROAD_W + 8, true)
	draw_polyline(pts, Color("616a85"), ROAD_W - 8, true)
	# Yellow centre dashes.
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if fposmod(acc, 70.0) < 38.0:
			draw_line(a, b, Color("ffd23f"), 9.0, true)
		acc += a.distance_to(b)


func _stop(n: int) -> void:
	var p := stop_pos(float(n))
	if p.y < -120 or p.y > size.y + 120:
		return
	var tier := ProgressionManager.tier_for(n)
	var done := n < level
	var current := n == level
	var r := 62.0 if current else 50.0
	if current:
		var glow := 0.5 + 0.5 * sin(_t * 4.0)
		for k in 3:
			draw_circle(p, r + 18.0 + k * 10.0 + glow * 6.0, Color(1, 0.9, 0.3, 0.16 - k * 0.04), true, -1.0, true)
	var base: Color
	var edge: Color
	if done:
		base = Color("3fd27f")
		edge = Color("17894a")
	elif current:
		base = Color("ffcf3a")
		edge = Color("d47b00")
	elif tier == "super":
		base = Color("ff4d5e")
		edge = Color("a81d2b")
	elif tier == "hard":
		base = Color("ff8a2a")
		edge = Color("b85200")
	else:
		base = Color("5b9bff")
		edge = Color("1f45b8")
	DrawKit.glossy_circle(self, p, r, base, edge, 6.0, 9.0)
	var f := UIKit.font(true)
	var label := str(n)
	var fs := int(r * (0.78 if n < 100 else (0.64 if n < 1000 else 0.5)))
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := p + Vector2(-w * 0.5, fs * 0.32 - 4)
	draw_string_outline(f, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, edge.darkened(0.5))
	draw_string(f, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if done:
		# Three little stars on finished stops.
		for k in 3:
			var sp := p + Vector2((k - 1) * 30, -r - 4 + (6 if k != 1 else 0))
			draw_colored_polygon(DrawKit.star(sp, 16, 7), Color("8a5a00"))
			draw_colored_polygon(DrawKit.star(sp - Vector2(0, 2), 14, 6), Color("ffd84a"))
	if not done and (tier == "hard" or tier == "super"):
		var txt := "SUPER HARD" if tier == "super" else "HARD"
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var br := Rect2(p.x - tw * 0.5 - 16, p.y + r - 6, tw + 32, 40)
		draw_colored_polygon(DrawKit.rounded_rect(br.grow(3), 14, 4), Color("0d1544"))
		draw_colored_polygon(DrawKit.rounded_rect(br, 12, 4), edge)
		draw_string(f, br.position + Vector2(16, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	# Gift chest every 10 levels, town sign every 5.
	var side := 1.0 if stop_x(float(n)) < size.x * 0.5 else -1.0
	if n % 10 == 0:
		var claimed := (SaveManager.game().get("milestones_claimed", []) as Array).has(n)
		_chest(p + Vector2(side * 130, -10), claimed)
	elif n % 5 == 0:
		_sign(p + Vector2(side * 175, -80), GameData.town(n / 5))


func _token() -> void:
	var p := stop_pos(token_t)
	var ahead := stop_pos(token_t + 0.05)
	var dir := Park.RIGHT if ahead.x >= p.x else Park.LEFT
	var bob := sin(_t * 6.0) * 3.0
	var moving := _token_tween != null and _token_tween.is_running()
	if moving:
		for k in 3:
			draw_circle(p + Vector2(-50 if dir == Park.RIGHT else 50, 10) + Vector2(randf_range(-6, 6), k * 4), 12.0 - k * 3, Color(1, 1, 1, 0.5), true, -1.0, true)
	BusArt.draw_bus(self, p + Vector2(0, -78 + bob), 82.0, 2, dir, Color("e63946"), {"name": "Mero Gadi", "livery": String(ProgressionManager.selected_cosmetic_data("livery").get("style", "stripes")), "arrow": false})


func _clouds() -> void:
	# Two soft clouds drifting high up, out of the way of the stops.
	for i in 2:
		var x := fposmod(_t * (16.0 + i * 7.0) + i * 520.0, size.x + 500.0) - 250.0
		var yy := top_pad + 30.0 + i * 120.0
		var a := 0.32
		for k in 4:
			draw_circle(Vector2(x + k * 50, yy - (20 if k % 2 == 1 else 0)), 44.0 + (k % 2) * 14.0, Color(1, 1, 1, a), true, -1.0, true)
		draw_circle(Vector2(x + 75, yy + 18), 50, Color(1, 1, 1, a), true, -1.0, true)


# --- Scenery pieces ----------------------------------------------------------

func _patch(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_colored_polygon(DrawKit.ellipse(c, rx, ry, 28), col)


func _tree(p: Vector2, s: float, col: Color) -> void:
	var sway := sin(_t * 1.3 + p.x * 0.01) * 3.0
	draw_colored_polygon(DrawKit.ellipse(p + Vector2(8, 6) * s, 34 * s, 12 * s, 16), Color(0, 0, 0, 0.15))
	draw_rect(Rect2(p + Vector2(-7, -18) * s, Vector2(14, 24) * s), Color("8a5a36"))
	draw_circle(p + Vector2(sway, -48) * s, 40 * s, col, true, -1.0, true)
	draw_circle(p + Vector2(sway - 14, -60) * s, 22 * s, col.lightened(0.2), true, -1.0, true)
	draw_circle(p + Vector2(sway + 16, -40) * s, 18 * s, col.darkened(0.12), true, -1.0, true)


func _pine(p: Vector2, s: float, col: Color, snowy: bool) -> void:
	draw_colored_polygon(DrawKit.ellipse(p + Vector2(8, 4) * s, 30 * s, 10 * s, 16), Color(0, 0, 0, 0.15))
	draw_rect(Rect2(p + Vector2(-6, -14) * s, Vector2(12, 18) * s), Color("6b4428"))
	for k in 3:
		var y := -14.0 - k * 26.0
		var w := 42.0 - k * 10.0
		var tri := PackedVector2Array([p + Vector2(-w, y) * s, p + Vector2(w, y) * s, p + Vector2(0, y - 46) * s])
		draw_colored_polygon(tri, col.lightened(k * 0.08))
		if snowy:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.45, y - 26) * s, p + Vector2(w * 0.45, y - 26) * s, p + Vector2(0, y - 46) * s]), Color.WHITE)


func _house(p: Vector2, s: float, seed_value: int) -> void:
	var walls := [Color("ff9f6b"), Color("fff1c9"), Color("8ec9ff"), Color("ffd84a"), Color("ff7f9a"), Color("b8f0a0")]
	var roofs := [Color("e63946"), Color("1d7fe0"), Color("8e44ad"), Color("12b5b0")]
	var wall: Color = walls[posmod(seed_value, walls.size())]
	var roof: Color = roofs[posmod(seed_value / 2, roofs.size())]
	var w := 86.0 * s
	var h := 60.0 * s
	draw_colored_polygon(DrawKit.ellipse(p + Vector2(10, 4), w * 0.7, 12 * s, 14), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(p - Vector2(w * 0.5, h), Vector2(w, h)), Color("2b3150"))
	draw_rect(Rect2(p - Vector2(w * 0.5 - 4, h - 4), Vector2(w - 8, h - 4)), wall)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.64, -h), p + Vector2(w * 0.64, -h), p + Vector2(0, -h - 42 * s)]), Color("2b3150"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.56, -h - 3), p + Vector2(w * 0.56, -h - 3), p + Vector2(0, -h - 36 * s)]), roof)
	draw_rect(Rect2(p + Vector2(-10, -30) * s, Vector2(20, 30) * s), Color("6b4428"))
	draw_rect(Rect2(p + Vector2(16, -46) * s, Vector2(18, 16) * s), Color("3b4a66"))
	draw_rect(Rect2(p + Vector2(-34, -46) * s, Vector2(18, 16) * s), Color("3b4a66"))


func _terraces(c: Vector2, side: float) -> void:
	for k in 4:
		var col := Color("b9e66e") if k % 2 == 0 else Color("8fcf4f")
		var r := Rect2(c.x - 140 + k * 10 * side, c.y - 60 + k * 30, 260, 28)
		draw_colored_polygon(DrawKit.rounded_rect(r, 14, 4), col)
		draw_line(r.position + Vector2(10, r.size.y), r.end - Vector2(10, 0), Color(0, 0, 0, 0.12), 4.0)


func _flowers(c: Vector2, rng: RandomNumberGenerator) -> void:
	var cols := [Color("ff5fa2"), Color("ffd84a"), Color.WHITE, Color("ff7f11")]
	for k in 5:
		var q := c + Vector2(rng.randf_range(-70, 70), rng.randf_range(-20, 20))
		draw_circle(q, 7, cols[k % cols.size()], true, -1.0, true)
		draw_circle(q, 3, Color("ffd84a") if k % 2 == 0 else Color("ff7f11"), true, -1.0, true)


func _pond(c: Vector2) -> void:
	draw_colored_polygon(DrawKit.ellipse(c, 92, 44, 28), Color("2a7fd0"))
	draw_colored_polygon(DrawKit.ellipse(c - Vector2(0, 4), 84, 36, 28), Color("4fb4ff"))
	draw_arc(c + Vector2(-20, -6), 22, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.6), 4.0, true)


func _rock(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 0), c + Vector2(-20, -30), c + Vector2(8, -38), c + Vector2(34, -10), c + Vector2(30, 0)]), Color("8b97b3"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -30), c + Vector2(8, -38), c + Vector2(0, -20)]), Color.WHITE)


## A river across the map; the road crosses on a bridge.
func _river(y: float) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var x := size.x * i / 20.0
		pts.append(Vector2(x, y + sin(i * 0.8 + y * 0.01) * 16.0))
	draw_polyline(pts, Color("2a7fd0"), 92.0, true)
	draw_polyline(pts, Color("4fb4ff"), 76.0, true)
	for i in 6:
		var x := fposmod(_t * 40.0 + i * 190.0, size.x)
		draw_line(Vector2(x, y - 10), Vector2(x + 34, y - 10), Color(1, 1, 1, 0.5), 4.0)
	_bridges.append(y)


## Railings where the road crosses a river (drawn over the road).
func _bridge(y: float) -> void:
	var n := (scroll - y) / GAP
	for side in [-1.0, 1.0]:
		var a := Vector2(stop_x(n + 0.2), y - 0.2 * GAP) + Vector2(side * (ROAD_W * 0.5 + 8), 0)
		var b := Vector2(stop_x(n - 0.2), y + 0.2 * GAP) + Vector2(side * (ROAD_W * 0.5 + 8), 0)
		draw_line(a, b, Color("2b3150"), 18.0, true)
		draw_line(a, b, Color("c98a52"), 11.0, true)
		for k in 4:
			var q := a.lerp(b, k / 3.0)
			draw_circle(q, 10, Color("2b3150"), true, -1.0, true)
			draw_circle(q, 7, Color("e0a46a"), true, -1.0, true)


func _chest(p: Vector2, open: bool) -> void:
	var bob := 0.0 if open else sin(_t * 3.0) * 4.0
	var c := p + Vector2(0, bob)
	if not open:
		for k in 3:
			draw_circle(c, 64.0 - k * 12.0, Color(1, 0.9, 0.3, 0.1), true, -1.0, true)
	draw_colored_polygon(DrawKit.ellipse(p + Vector2(0, 40), 50, 12, 16), Color(0, 0, 0, 0.2))
	var body := Rect2(c + Vector2(-46, -6), Vector2(92, 48))
	draw_colored_polygon(DrawKit.rounded_rect(body.grow(4), 12, 4), Color("2b3150"))
	draw_colored_polygon(DrawKit.rounded_rect(body, 10, 4), Color("c96a2a"))
	draw_rect(Rect2(body.position + Vector2(0, 14), Vector2(92, 9)), Color("ffcf3a"))
	if open:
		draw_colored_polygon(DrawKit.rounded_rect(Rect2(c + Vector2(-46, -46), Vector2(92, 30)), 12, 4), Color("e08a3a"))
		for k in 3:
			draw_circle(c + Vector2(-22 + k * 22, -8), 12, Color("ffd84a"), true, -1.0, true)
	else:
		var lid := Rect2(c + Vector2(-48, -36), Vector2(96, 34))
		draw_colored_polygon(DrawKit.rounded_rect(lid.grow(4), 16, 4), Color("2b3150"))
		draw_colored_polygon(DrawKit.rounded_rect(lid, 14, 4), Color("e08a3a"))
		draw_rect(Rect2(c + Vector2(-8, -36), Vector2(16, 78)), Color("ffcf3a"))
		draw_colored_polygon(DrawKit.rounded_rect(Rect2(c + Vector2(-14, -14), Vector2(28, 24)), 6, 3), Color("fff2a8"))


func _sign(p: Vector2, text: String) -> void:
	var f := UIKit.font(true)
	var fs := 32
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := clampf(p.x, tw * 0.5 + 34, size.x - tw * 0.5 - 34)
	var board := Rect2(x - tw * 0.5 - 22, p.y - 30, tw + 44, 60)
	draw_rect(Rect2(board.position.x + 18, board.end.y - 4, 10, 56), Color("6b4428"))
	draw_rect(Rect2(board.end.x - 28, board.end.y - 4, 10, 56), Color("6b4428"))
	draw_colored_polygon(DrawKit.rounded_rect(board.grow(5), 16, 4), Color("0d1544"))
	DrawKit.gradient_fill(self, DrawKit.rounded_rect(board, 12, 4), Color("3fd27f"), Color("1fa860"))
	draw_string_outline(f, board.position + Vector2(22, 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color("0b5a32"))
	draw_string(f, board.position + Vector2(22, 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
