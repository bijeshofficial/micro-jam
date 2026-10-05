class_name BusArt
extends RefCounted
## Code-drawn die-cast toy buses in a 3/4 top-down view: the roof faces the
## camera and the south side shows below it, with a strong drop shadow.
## Used by the lot buses, the bays, the loading screen, the route map token,
## the screen wipe and the shop previews, so final sprites can replace one
## function.
##
## draw_bus(ci, center, cell, length, dir, color, opts)
##   center: middle of the footprint on the ground
##   cell:   lot cell size in px (the bus is length x 1 cells)
##   dir:    0 up, 1 right, 2 down, 3 left (the way the bus faces)
##   opts:   livery ("stripes" | "zigzag" | "flowers" | "racer" | "tassels"),
##           name (sun-strip text), seats (capacity), boarded (int),
##           seat_color (Color), arrow (bool), sleep (bool), flash (0..1),
##           lift (0..1, crane), door (0..1 open), shadow (bool), time (float)

const GLASS := Color("2a3a55")
const GLASS_HI := Color("6f8db8")
const TYRE := Color("2b2b30")
const CHROME := Color("e9eef2")
const LIGHT := Color("fff3b0")
const OUTLINE := Color("1f2433")
const SKIN := [Color("c98b5e"), Color("d9a07a"), Color("b87a50"), Color("e0ae84")]


static func footprint(center: Vector2, cell: float, length: int, dir: int) -> Rect2:
	var lw := cell * 0.78
	var ll := cell * (float(length) - 0.14)
	var sz := Vector2(lw, ll) if dir == 0 or dir == 2 else Vector2(ll, lw)
	return Rect2(center - sz * 0.5, sz)


## Height of the visible side band.
static func body_height(cell: float) -> float:
	return cell * 0.26


static func draw_bus(ci: CanvasItem, center: Vector2, cell: float, length: int, dir: int, color: Color, opts: Dictionary = {}) -> void:
	var fp := footprint(center, cell, length, dir)
	var hgt := body_height(cell)
	var lift := float(opts.get("lift", 0.0))
	var r := cell * 0.2
	# Shadow on the ground (grows and softens when the crane lifts the bus).
	if bool(opts.get("shadow", true)):
		var so := Vector2(cell * 0.08, cell * 0.12) * (1.0 + lift * 2.5)
		var sh := Rect2(fp.position + so - Vector2(2, 2), fp.size + Vector2(4, 4))
		ci.draw_colored_polygon(DrawKit.rounded_rect(sh, r, 6), Color(0.1, 0.08, 0.15, 0.32 * (1.0 - lift * 0.5)))
	var up := Vector2(0, -hgt - lift * cell * 0.6)
	# Body: from the footprint bottom up to the raised roof.
	var body := Rect2(fp.position + up, Vector2(fp.size.x, fp.size.y + hgt))
	var side := color.darkened(0.32)
	var body_pts := DrawKit.rounded_rect(body.grow(cell * 0.03), r + 2, 6)
	ci.draw_colored_polygon(body_pts, OUTLINE)
	ci.draw_colored_polygon(DrawKit.rounded_rect(body, r, 6), side)
	_side_details(ci, fp, body, hgt, cell, length, dir, color, opts)
	# Roof.
	var roof := Rect2(fp.position + up, fp.size)
	var roof_pts := DrawKit.rounded_rect(roof, r, 6)
	DrawKit.gradient_fill(ci, roof_pts, color.lightened(0.22), color.lerp(side, 0.15))
	_livery(ci, roof, cell, length, dir, color, opts)
	_windscreen(ci, roof, cell, dir, color, opts)
	if int(opts.get("seats", 0)) > 0:
		_seats(ci, roof, cell, length, dir, opts)
	elif bool(opts.get("arrow", true)):
		_arrow(ci, roof, cell, dir)
	if length >= 3:
		_rack(ci, roof, cell, dir)
	# Gloss along the roof's top edge.
	var gl := Rect2(roof.position + Vector2(cell * 0.08, cell * 0.05), Vector2(roof.size.x - cell * 0.16, cell * 0.09))
	if gl.size.x > 4:
		ci.draw_colored_polygon(DrawKit.rounded_rect(gl, gl.size.y * 0.5, 4), Color(1, 1, 1, 0.28))
	DrawKit.outline(ci, roof_pts, Color(1, 1, 1, 0.35), 2.0)
	var flash := float(opts.get("flash", 0.0))
	if flash > 0.0:
		ci.draw_colored_polygon(DrawKit.rounded_rect(body, r, 6), Color(1, 1, 1, 0.55 * flash))
	if bool(opts.get("sleep", false)):
		_zzz(ci, roof, cell, float(opts.get("time", 0.0)))


## The visible south face: long side (windows, door, wheels) for buses
## facing left/right, front or rear face for buses facing down/up.
static func _side_details(ci: CanvasItem, fp: Rect2, body: Rect2, hgt: float, cell: float, length: int, dir: int, color: Color, opts: Dictionary) -> void:
	var band := Rect2(Vector2(body.position.x, body.end.y - hgt), Vector2(body.size.x, hgt))
	var wr := cell * 0.11
	# Wheels peeking under the band.
	var wy := band.end.y - wr * 0.35
	if dir == 1 or dir == 3:
		for fx in [0.2, 0.8]:
			ci.draw_circle(Vector2(band.position.x + band.size.x * fx, wy), wr, TYRE, true, -1.0, true)
			ci.draw_circle(Vector2(band.position.x + band.size.x * fx, wy), wr * 0.45, CHROME, true, -1.0, true)
		# Windows row.
		var n := length * 2
		var ww := (band.size.x - cell * 0.36) / n
		for i in n:
			var wx := band.position.x + cell * 0.18 + i * ww
			var win := Rect2(wx + ww * 0.12, band.position.y + hgt * 0.14, ww * 0.76, hgt * 0.44)
			ci.draw_colored_polygon(DrawKit.rounded_rect(win, 3, 2), GLASS)
			ci.draw_line(win.position + Vector2(2, 2), win.position + Vector2(win.size.x * 0.5, 2), GLASS_HI, 2.0)
		# Door near the front, opens on boarding.
		var front_left := dir == 3
		var dx := band.position.x + (cell * 0.3 if front_left else band.size.x - cell * 0.3 - ww * 0.8)
		var door := Rect2(dx, band.position.y + hgt * 0.1, ww * 0.8, hgt * 0.8)
		ci.draw_colored_polygon(DrawKit.rounded_rect(door, 3, 2), GLASS.lerp(color, 0.25) if float(opts.get("door", 0.0)) < 0.5 else Color("141a26"))
		# Lights.
		var hx := band.position.x + 5.0 if front_left else band.end.x - 5.0
		ci.draw_circle(Vector2(hx, band.position.y + hgt * 0.5), cell * 0.05, LIGHT, true, -1.0, true)
		var tx := band.end.x - 5.0 if front_left else band.position.x + 5.0
		ci.draw_circle(Vector2(tx, band.position.y + hgt * 0.5), cell * 0.04, Color("ff5a4f"), true, -1.0, true)
		# A coloured stripe along the side.
		ci.draw_rect(Rect2(band.position.x + 4, band.position.y + hgt * 0.68, band.size.x - 8, hgt * 0.1), Color(1, 1, 1, 0.55))
	else:
		for fx in [0.16, 0.84]:
			var wc := Vector2(band.position.x + band.size.x * fx, wy)
			ci.draw_colored_polygon(DrawKit.rounded_rect(Rect2(wc - Vector2(wr * 0.7, wr), Vector2(wr * 1.4, wr * 1.6)), wr * 0.5, 3), TYRE)
		if dir == 2:
			# Front face: big windscreen, headlights, bumper.
			var ws := Rect2(band.position.x + band.size.x * 0.12, band.position.y + hgt * 0.1, band.size.x * 0.76, hgt * 0.48)
			ci.draw_colored_polygon(DrawKit.rounded_rect(ws, 4, 3), GLASS)
			ci.draw_line(ws.position + Vector2(4, 3), ws.position + Vector2(ws.size.x * 0.4, 3), GLASS_HI, 2.0)
			for fx in [0.17, 0.83]:
				ci.draw_circle(Vector2(band.position.x + band.size.x * fx, band.position.y + hgt * 0.74), cell * 0.06, LIGHT, true, -1.0, true)
			ci.draw_rect(Rect2(band.position.x + band.size.x * 0.3, band.position.y + hgt * 0.7, band.size.x * 0.4, hgt * 0.12), CHROME)
		else:
			# Rear face: small window, tail lights, ladder.
			var rw := Rect2(band.position.x + band.size.x * 0.24, band.position.y + hgt * 0.12, band.size.x * 0.52, hgt * 0.4)
			ci.draw_colored_polygon(DrawKit.rounded_rect(rw, 3, 2), GLASS)
			for fx in [0.15, 0.85]:
				ci.draw_circle(Vector2(band.position.x + band.size.x * fx, band.position.y + hgt * 0.6), cell * 0.045, Color("ff5a4f"), true, -1.0, true)
			ci.draw_rect(Rect2(band.position.x + band.size.x * 0.25, band.position.y + hgt * 0.72, band.size.x * 0.5, hgt * 0.1), Color(0, 0, 0, 0.25))


## Axis helpers: along = unit vector toward the front; across = perpendicular.
static func _along(dir: int) -> Vector2:
	return Vector2(Park.DIRS[dir])


static func _windscreen(ci: CanvasItem, roof: Rect2, cell: float, dir: int, color: Color, opts: Dictionary) -> void:
	var a := _along(dir)
	var c := roof.get_center()
	var half_len := (roof.size.y if dir == 0 or dir == 2 else roof.size.x) * 0.5
	var half_w := (roof.size.x if dir == 0 or dir == 2 else roof.size.y) * 0.5
	var across := Vector2(-a.y, a.x)
	# Glass across the front of the roof.
	var f0 := c + a * (half_len - cell * 0.1)
	var f1 := c + a * (half_len - cell * 0.32)
	var ww := half_w - cell * 0.07
	var glass := PackedVector2Array([f0 + across * ww * 0.86, f0 - across * ww * 0.86, f1 - across * ww, f1 + across * ww])
	ci.draw_colored_polygon(glass, GLASS)
	ci.draw_line(f0.lerp(f1, 0.3) + across * ww * 0.6, f0.lerp(f1, 0.3) + across * ww * 0.1, GLASS_HI, maxf(2.0, cell * 0.025), true)
	# Sun-strip with the bus's name, a band just behind the glass.
	var s0 := f1
	var s1 := c + a * (half_len - cell * 0.42)
	var strip := PackedVector2Array([s0 + across * ww, s0 - across * ww, s1 - across * ww, s1 + across * ww])
	var strip_col := Color("ffd23f") if color.get_luminance() < 0.6 or color.h > 0.2 else Color("e63946")
	ci.draw_colored_polygon(strip, strip_col)
	var label := String(opts.get("name", ""))
	if label != "" and cell >= 60.0:
		var fs := int(clampf(cell * 0.11, 8.0, 16.0))
		var f := UIKit.font(true)
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var mid := s0.lerp(s1, 0.5)
		var rot := 0.0
		match dir:
			1:
				rot = -PI * 0.5
			3:
				rot = PI * 0.5
		var scale := minf(1.0, (ww * 1.8) / maxf(1.0, tw))
		ci.draw_set_transform(mid, rot, Vector2(scale, scale))
		ci.draw_string(f, Vector2(-tw * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("3a1d10"))
		ci.draw_set_transform(Vector2.ZERO)
	if String(opts.get("livery", "")) == "tassels":
		# A fringe of tassels hanging over the windscreen.
		for k in 7:
			var t := (float(k) + 0.5) / 7.0
			var base := (s0 + across * ww).lerp(s0 - across * ww, t)
			var col: Color = [Color("e63946"), Color("ffc300"), Color("2ec27e"), Color("1d7fe0")][k % 4]
			ci.draw_colored_polygon(PackedVector2Array([base - across * cell * 0.04, base + across * cell * 0.04, base + a * cell * 0.09]), col)


static func _livery(ci: CanvasItem, roof: Rect2, cell: float, length: int, dir: int, color: Color, opts: Dictionary) -> void:
	var style := String(opts.get("livery", "stripes"))
	var a := _along(dir)
	var across := Vector2(-a.y, a.x)
	var c := roof.get_center()
	var half_len := (roof.size.y if dir == 0 or dir == 2 else roof.size.x) * 0.5
	var half_w := (roof.size.x if dir == 0 or dir == 2 else roof.size.y) * 0.5
	var back := c - a * (half_len - cell * 0.1)
	var front := c + a * (half_len - cell * 0.46)
	var accent := Color.WHITE if color.get_luminance() < 0.7 else Color("1f2433")
	match style:
		"zigzag":
			for side in [-1.0, 1.0]:
				var pts := PackedVector2Array()
				var steps := length * 4
				for i in steps + 1:
					var t := float(i) / steps
					var off: float = side * (half_w - cell * (0.1 if i % 2 == 0 else 0.2))
					pts.append(back.lerp(front, t) + across * off)
				ci.draw_polyline(pts, Color(accent, 0.8), maxf(2.0, cell * 0.04), true)
		"flowers":
			var n := length * 2
			for i in n:
				var t := (float(i) + 0.5) / n
				var p := back.lerp(front, t) + across * (half_w * 0.45 * (1.0 if i % 2 == 0 else -1.0))
				var pr := cell * 0.06
				for k in 5:
					var ang := TAU * k / 5.0
					ci.draw_circle(p + Vector2(cos(ang), sin(ang)) * pr, pr * 0.75, Color("fff4f8"), true, -1.0, true)
				ci.draw_circle(p, pr * 0.6, Color("ffc300"), true, -1.0, true)
		"racer":
			for off in [-0.13, 0.13]:
				var o: float = off * cell
				ci.draw_line(back + across * o, front + across * o, Color(accent, 0.85), cell * 0.08, true)
			var sq := cell * 0.07
			for k in 4:
				var p := back + a * sq * 0.5 + across * (sq * (k - 1.5))
				ci.draw_rect(Rect2(p - Vector2(sq, sq) * 0.5, Vector2(sq, sq)), Color("1f2433") if k % 2 == 0 else Color.WHITE)
		_:
			# Classic: two hand-painted stripes along both edges.
			for side in [-1.0, 1.0]:
				var o: float = side * (half_w - cell * 0.13)
				ci.draw_line(back + across * o, front + across * o, Color(accent, 0.75), maxf(2.0, cell * 0.035), true)
				var o2: float = side * (half_w - cell * 0.2)
				ci.draw_line(back + across * o2, front + across * o2, Color("ffc300", 0.85), maxf(2.0, cell * 0.03), true)


static func _arrow(ci: CanvasItem, roof: Rect2, cell: float, dir: int) -> void:
	var a := _along(dir)
	var across := Vector2(-a.y, a.x)
	var c := roof.get_center() - a * cell * 0.12
	var s := cell * 0.17
	var tip := c + a * s
	var pts := PackedVector2Array([tip, c - a * s * 0.2 + across * s, c - a * s * 0.2 - across * s])
	ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.92))
	ci.draw_line(c - a * s * 0.15, c - a * s * 1.15, Color(1, 1, 1, 0.92), s * 0.6, true)
	DrawKit.outline(ci, pts, Color(0, 0, 0, 0.18), 2.0)


static func _rack(ci: CanvasItem, roof: Rect2, cell: float, dir: int) -> void:
	# Roof luggage on big buses, near the back.
	var a := _along(dir)
	var across := Vector2(-a.y, a.x)
	var half_len := (roof.size.y if dir == 0 or dir == 2 else roof.size.x) * 0.5
	var p := roof.get_center() - a * (half_len - cell * 0.42)
	var cols := [Color("8e5a3c"), Color("3f7cc0"), Color("d14b3b")]
	for k in 3:
		var q := p + across * cell * (0.17 * (k - 1)) + a * cell * (0.05 if k == 1 else 0.0)
		var bx := Rect2(q - Vector2(cell * 0.08, cell * 0.08), Vector2(cell * 0.16, cell * 0.16))
		ci.draw_colored_polygon(DrawKit.rounded_rect(bx, cell * 0.03, 2), cols[k])
		ci.draw_rect(Rect2(bx.position + Vector2(0, bx.size.y * 0.4), Vector2(bx.size.x, bx.size.y * 0.14)), Color(0, 0, 0, 0.18))


## Seats on the roof: empty sockets that fill with passenger heads.
static func _seats(ci: CanvasItem, roof: Rect2, cell: float, length: int, dir: int, opts: Dictionary) -> void:
	var cap := int(opts.get("seats", 4))
	var boarded := int(opts.get("boarded", 0))
	var col: Color = opts.get("seat_color", Color.WHITE)
	var a := _along(dir)
	var across := Vector2(-a.y, a.x)
	var c := roof.get_center() - a * cell * 0.15
	var rows := cap / 2
	var span := cell * (float(length) - 0.9)
	var rad := cell * 0.12
	for i in cap:
		var row := i / 2
		var t := 0.5 if rows <= 1 else float(row) / float(rows - 1)
		var p := c + a * lerpf(span * 0.5, -span * 0.5, t) + across * cell * 0.17 * (-1.0 if i % 2 == 0 else 1.0)
		ci.draw_circle(p, rad + 2.0, Color(0, 0, 0, 0.25), true, -1.0, true)
		if i < boarded:
			ci.draw_circle(p + Vector2(0, rad * 0.25), rad, col.darkened(0.1), true, -1.0, true)
			ci.draw_circle(p - Vector2(0, rad * 0.2), rad * 0.72, SKIN[i % SKIN.size()], true, -1.0, true)
			ci.draw_arc(p - Vector2(0, rad * 0.32), rad * 0.62, PI * 1.05, PI * 1.95, 8, Color("2b1d16"), rad * 0.4, true)
		else:
			ci.draw_circle(p, rad, Color(1, 1, 1, 0.35), true, -1.0, true)


static func _zzz(ci: CanvasItem, roof: Rect2, cell: float, time: float) -> void:
	var f := UIKit.font(true)
	for k in 3:
		var ph := fposmod(time * 0.6 + k / 3.0, 1.0)
		var p := roof.get_center() + Vector2(cell * (0.1 + ph * 0.35), -cell * (0.1 + ph * 0.7))
		var fs := int(cell * (0.22 + ph * 0.16))
		var col := Color(1, 1, 1, 1.0 - ph)
		ci.draw_string_outline(f, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.12, 0.15, 0.35, 1.0 - ph))
		ci.draw_string(f, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
