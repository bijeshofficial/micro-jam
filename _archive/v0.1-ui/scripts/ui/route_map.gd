class_name RouteMap
extends Control
## Home screen route map: a winding road climbs toward the mountains through
## fictional towns; each level is a bus stop. Your microbus token waits at
## the current stop and drives on from the last stop you saw.

const STOP_GAP := 230.0
const BELOW := 1      # completed stops shown under the current one
const FADE_TOP := 150.0  # the road disappears into town above this line

var level := 1
var token_t := 0.0    # position along the stops (in stop units, float)
var park_theme: Dictionary = ParkTheme.get_theme("theme_morning")

var _t := 0.0
var _token_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh(animate: bool) -> void:
	level = ProgressionManager.current_level()
	park_theme = ParkTheme.get_theme(ProgressionManager.selected_cosmetic("park_theme"))
	var seen := clampi(ProgressionManager.route_seen_level(), 1, level)
	if _token_tween:
		_token_tween.kill()
	if animate and seen < level:
		token_t = float(seen)
		_token_tween = create_tween()
		_token_tween.tween_interval(0.45)
		_token_tween.tween_callback(func() -> void: AudioManager.play("drive"))
		_token_tween.tween_property(self, "token_t", float(level), 0.9 + 0.2 * (level - seen)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_token_tween.tween_callback(func() -> void:
			AudioManager.horn()
			ProgressionManager.mark_route_seen())
	else:
		token_t = float(level)
		if seen < level:
			ProgressionManager.mark_route_seen()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Map position of a (possibly fractional) stop index.
func stop_pos(n: float) -> Vector2:
	var base_y := size.y - 120.0
	var y := base_y - (n - float(level - BELOW)) * STOP_GAP
	var x := size.x * 0.5 + sin(n * 1.15) * size.x * 0.27
	return Vector2(x, y)


func _draw() -> void:
	var first := level - BELOW - 1
	var last := level + int(size.y / STOP_GAP) + 1
	# Hills and trees beside the road.
	for n in range(first, last + 1):
		var p := stop_pos(float(n))
		if p.y < FADE_TOP + 60.0:
			continue
		var side := -1.0 if sin(n * 1.15) > 0.0 else 1.0
		var hx := p.x + side * size.x * 0.3
		var field := Color("8fcf7a").darkened(0.45 if bool(park_theme["night"]) else 0.0).lerp(ParkTheme.c(park_theme, "dust"), 0.3)
		draw_colored_polygon(DrawKit.ellipse(Vector2(hx, p.y + 40), 150, 60, 24), field)
		if posmod(n, 3) == 0:
			# Terraced field rows.
			for k in 3:
				draw_arc(Vector2(hx, p.y + 70 + k * 16), 120.0 - k * 22.0, PI * 1.15, PI * 1.85, 16, field.darkened(0.15), 5.0, true)
			_house(Vector2(hx + 50 * side, p.y + 30), 1.0, n)
			_tree(Vector2(hx - 60 * side, p.y + 20), 0.9, n)
		elif posmod(n, 3) == 1:
			_house(Vector2(hx - 30 * side, p.y + 34), 0.9, n + 1)
			_tree(Vector2(hx + 60 * side, p.y + 24), 1.0, n + 3)
		else:
			_tree(Vector2(hx - 40 * side, p.y + 10), 1.0, n)
			_tree(Vector2(hx + 30 * side, p.y + 30), 0.8, n + 3)
	# The road: a smooth curve through the stops.
	var pts := PackedVector2Array()
	var steps := (last - first) * 12
	for i in steps + 1:
		var p := stop_pos(lerpf(float(first), float(last), float(i) / steps))
		if p.y >= FADE_TOP:
			pts.append(p)
	if pts.size() < 2:
		return
	draw_polyline(pts, Color("5d5850"), 96.0, true)
	draw_polyline(pts, ParkTheme.c(park_theme, "asphalt"), 80.0, true)
	# Dashed centre line scrolling gently.
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := a.distance_to(b)
		var ph := fposmod(acc - _t * 30.0, 60.0)
		if ph < 30.0:
			draw_line(a, b, Color(1, 1, 1, 0.75), 6.0, true)
		acc += d
	# Stops.
	var f := UIKit.font(true)
	for n in range(maxi(1, first), last + 1):
		if stop_pos(float(n)).y > FADE_TOP + 90.0:
			_stop(f, n)
	# The road vanishes into the town: dust fade at the top edge.
	var dust := ParkTheme.c(park_theme, "dust")
	draw_polygon(PackedVector2Array([Vector2(0, FADE_TOP - 4), Vector2(size.x, FADE_TOP - 4), Vector2(size.x, FADE_TOP + 70), Vector2(0, FADE_TOP + 70)]),
		PackedColorArray([dust, dust, Color(dust, 0.0), Color(dust, 0.0)]))
	# The token: your microbus.
	var tp := stop_pos(token_t)
	var ahead := stop_pos(token_t + 0.05)
	var dir := Park.RIGHT if ahead.x >= tp.x else Park.LEFT
	var bob := sin(_t * 6.0) * 3.0
	BusArt.draw_bus(self, tp + Vector2(0, -34 + bob), 74.0, 2, dir, Color("e63946"), {"name": "Mero Gadi", "livery": String(ProgressionManager.selected_cosmetic_data("livery").get("style", "stripes"))})


func _stop(f: Font, n: int) -> void:
	var p := stop_pos(float(n))
	var tier := ProgressionManager.tier_for(n)
	var done := n < level
	var current := n == level
	# Pole and round bus-stop sign beside the road.
	var sp := p + Vector2(96 if sin(n * 1.15) <= 0.0 else -96, -40)
	draw_line(sp, sp + Vector2(0, 70), Color("4a5263"), 8.0)
	var r := 44.0 if current else 36.0
	if current:
		r += sin(_t * 4.0) * 3.0
	var fill := UIKit.PRIMARY if done else (UIKit.GOLD if current else Color.WHITE)
	if not done and not current and tier != "normal" and tier != "easy":
		fill = UIKit.TIER_COLORS.get(tier, Color.WHITE)
	draw_circle(sp, r + 6, Color("17213f"), true, -1.0, true)
	draw_circle(sp, r, fill, true, -1.0, true)
	draw_circle(sp + Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.5), true, -1.0, true)
	if done:
		draw_polyline(PackedVector2Array([sp + Vector2(-16, 0), sp + Vector2(-4, 12), sp + Vector2(18, -12)]), Color.WHITE, 9.0, true)
	else:
		var label := str(n)
		var fs := 34 if n < 100 else (28 if n < 1000 else 22)
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col := UIKit.INK if fill == Color.WHITE or current else Color.WHITE
		draw_string(f, sp + Vector2(-w * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# Town sign every 5 stops.
	if n % 5 == 0:
		var town := GameData.town(n / 5)
		var fs2 := 30
		var tw := f.get_string_size(town, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var side := 1.0 if sp.x < p.x else -1.0
		var bx := p.x + side * (110.0 + tw * 0.5)
		bx = clampf(bx, tw * 0.5 + 30, size.x - tw * 0.5 - 30)
		var board := Rect2(bx - tw * 0.5 - 20, p.y - 20, tw + 40, 54)
		draw_colored_polygon(DrawKit.rounded_rect(board.grow(4), 12, 4), Color("17213f"))
		draw_colored_polygon(DrawKit.rounded_rect(board, 10, 4), UIKit.SECONDARY)
		draw_string(f, Vector2(board.position.x + 20, board.position.y + 38), town, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color.WHITE)


func _house(p: Vector2, s: float, seed_value: int) -> void:
	var walls := [Color("f2a65a"), Color("fff6dc"), Color("7fb3d5"), Color("f7d774"), Color("e07a5f")]
	var night := bool(park_theme["night"])
	var wall: Color = walls[posmod(seed_value, walls.size())]
	if night:
		wall = wall.darkened(0.5)
	var w := 70.0 * s
	var h := 50.0 * s
	draw_colored_polygon(DrawKit.ellipse(p + Vector2(6, 4), w * 0.7, 10 * s, 12), Color(0, 0, 0, 0.15))
	draw_rect(Rect2(p - Vector2(w * 0.5, h), Vector2(w, h)), wall)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.62, -h), p + Vector2(w * 0.62, -h), p + Vector2(0, -h - 34 * s)]), Color("a8443b").darkened(0.4 if night else 0.0))
	draw_rect(Rect2(p + Vector2(-8, -26) * s, Vector2(16, 26) * s), Color("5b3a2a"))
	draw_rect(Rect2(p + Vector2(14, -38) * s, Vector2(14, 12) * s), Color("ffd76a") if night else Color("3b4a66"))


func _tree(p: Vector2, s: float, seed_value: int) -> void:
	var sway := sin(_t * 1.3 + seed_value) * 3.0
	var night := bool(park_theme["night"])
	draw_rect(Rect2(p + Vector2(-6, -10) * s, Vector2(12, 34) * s), Color("7a5236"))
	var g := Color("3c9a5f").darkened(0.45 if night else 0.0)
	if String(park_theme["weather"]) == "snow":
		g = Color("6fa889")
	draw_circle(p + Vector2(sway, -34) * s, 34 * s, g, true, -1.0, true)
	draw_circle(p + Vector2(sway - 12, -46) * s, 18 * s, g.lightened(0.18), true, -1.0, true)
	if String(park_theme["weather"]) == "snow":
		draw_circle(p + Vector2(sway - 6, -58) * s, 16 * s, Color.WHITE, true, -1.0, true)
