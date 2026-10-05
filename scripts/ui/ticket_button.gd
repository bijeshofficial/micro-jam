class_name TicketButton
extends GameButton
## The PLAY button, shaped like a bus ticket: notched sides, a perforated
## stub with a little bus, a 3D lip and gloss.


static func ticket_poly(r: Rect2, notch: float, radius: float) -> PackedVector2Array:
	var pts := DrawKit.rounded_rect(r, radius, 6)
	var cy := r.get_center().y
	# Rebuild with notches: walk the rounded rect and splice semicircles
	# into the left and right edges at mid-height.
	var out := PackedVector2Array()
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		out.append(a)
		# Right edge going down crosses cy.
		if absf(a.x - r.end.x) < 0.5 and absf(b.x - r.end.x) < 0.5 and a.y < cy and b.y > cy:
			for k in 13:
				var t := PI * k / 12.0
				out.append(Vector2(r.end.x - sin(t) * notch, cy - cos(t) * notch))
		# Left edge going up crosses cy.
		if absf(a.x - r.position.x) < 0.5 and absf(b.x - r.position.x) < 0.5 and a.y > cy and b.y < cy:
			for k in 13:
				var t := PI * k / 12.0
				out.append(Vector2(r.position.x + sin(t) * notch, cy + cos(t) * notch))
	return out


func _draw() -> void:
	var c := _colors()
	var lip := _lip()
	var notch := size.y * 0.16
	var r := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(ticket_poly(Rect2(r.position + Vector2(0, lip * 0.6 + 6), r.size), notch, 26), Color(0.03, 0.05, 0.15, 0.3))
	var outer := ticket_poly(r, notch, 26)
	var dark: Color = (c[1] as Color).darkened(0.45)
	draw_colored_polygon(outer, dark)
	DrawKit.aa_rim(self, outer, dark)
	var inner := r.grow(-5)
	draw_colored_polygon(ticket_poly(inner, notch - 5, 22), c[1])
	var l := lip * (1.0 - _press)
	var body := Rect2(inner.position + Vector2(0, lip - l), Vector2(inner.size.x, inner.size.y - lip))
	DrawKit.gradient_fill(self, ticket_poly(body, notch - 5, 22), (c[0] as Color).lightened(0.3), c[0])
	var g := Rect2(body.position + Vector2(40, 10), Vector2(body.size.x - 80, body.size.y * 0.36))
	DrawKit.gradient_fill(self, DrawKit.rounded_rect(g, g.size.y * 0.5, 6), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.05))
	# Perforation and the stub with a bus.
	var px := body.position.x + body.size.x * 0.24
	var y := body.position.y + 14
	while y < body.end.y - 10:
		draw_circle(Vector2(px, y), 4.0, (c[1] as Color).darkened(0.2), true, -1.0, true)
		y += 18.0
	BusArt.draw_bus(self, Vector2(body.position.x + body.size.x * 0.12, body.get_center().y + 8), body.size.y * 0.32, 2, Park.RIGHT, Color("e63946"), {"arrow": false, "shadow": false})


func _layout_row() -> void:
	super._layout_row()
	if _row:
		_row.offset_left = size.x * 0.24
