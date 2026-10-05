class_name PeopleArt
extends RefCounted
## Code-drawn passengers and the khalasi (bus conductor) mascot.
## Passengers wear their colour; outfits are a cosmetic. Umbrellas hide the
## colour until the passenger reaches the front of the queue.

const SKINS := [Color("c98b5e"), Color("d9a07a"), Color("b87a50"), Color("e0ae84"), Color("a86f48")]
const HAIR := Color("2b1d16")
const INK := Color("1f2433")
const UMBRELLA := Color("4a5263")


## Passenger standing with feet at `feet`. `s` = height in px (~110 normal).
## `variant` picks skin/hair details; `bob` 0..1 adds a walk squash.
static func draw_passenger(ci: CanvasItem, feet: Vector2, s: float, color: Color, variant: int, outfit: String = "everyday", covered: bool = false, face: String = "happy") -> void:
	var u := s / 100.0
	var skin: Color = SKINS[posmod(variant, SKINS.size())]
	# Shadow.
	ci.draw_colored_polygon(DrawKit.ellipse(feet, 26 * u, 8 * u, 16), Color(0, 0, 0, 0.22))
	# Legs.
	var leg := Color("2f3a52") if outfit != "trek" else Color("5b4a3a")
	DrawKit.capsule(ci, feet + Vector2(-9, -4) * u, feet + Vector2(-9, -26) * u, 6 * u, leg)
	DrawKit.capsule(ci, feet + Vector2(9, -4) * u, feet + Vector2(9, -26) * u, 6 * u, leg)
	if covered:
		_umbrella(ci, feet, u)
		return
	# Body (their colour).
	var body := Rect2(feet + Vector2(-22, -66) * u, Vector2(44, 44) * u)
	var bpts := DrawKit.rounded_rect(body, 16 * u, 6)
	ci.draw_colored_polygon(DrawKit.rounded_rect(body.grow(3 * u), 18 * u, 6), INK)
	DrawKit.gradient_fill(ci, bpts, color.lightened(0.18), color.darkened(0.12))
	match outfit:
		"rain":
			# A raincoat with toggles and a hood behind the head.
			for k in 3:
				ci.draw_circle(feet + Vector2(0, -58 + k * 12) * u, 3 * u, Color(1, 1, 1, 0.8), true, -1.0, true)
		"trek":
			# Backpack straps.
			ci.draw_line(feet + Vector2(-12, -64) * u, feet + Vector2(-12, -30) * u, Color("6b4a2a"), 5 * u, true)
			ci.draw_line(feet + Vector2(12, -64) * u, feet + Vector2(12, -30) * u, Color("6b4a2a"), 5 * u, true)
		"festival":
			# A bright patterned scarf.
			for k in 5:
				ci.draw_circle(feet + Vector2(-16 + k * 8, -62 + (k % 2) * 4) * u, 4 * u, [Color("ffc300"), Color("ff5fa2"), Color("2ec27e")][k % 3], true, -1.0, true)
		_:
			# A shoulder bag strap.
			ci.draw_line(feet + Vector2(-16, -64) * u, feet + Vector2(14, -30) * u, Color(0, 0, 0, 0.3), 4 * u, true)
	# Arms.
	DrawKit.capsule(ci, feet + Vector2(-24, -58) * u, feet + Vector2(-27, -36) * u, 6 * u, color.darkened(0.2))
	DrawKit.capsule(ci, feet + Vector2(24, -58) * u, feet + Vector2(27, -36) * u, 6 * u, color.darkened(0.2))
	# Head.
	var head := feet + Vector2(0, -84) * u
	if outfit == "rain":
		ci.draw_circle(head + Vector2(0, -2) * u, 25 * u, color.darkened(0.15), true, -1.0, true)
	ci.draw_circle(head, 21 * u, INK, true, -1.0, true)
	ci.draw_circle(head, 19 * u, skin, true, -1.0, true)
	match posmod(variant, 4):
		0:
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -10) * u, 20 * u, 11 * u, 18), HAIR)
		1:
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -10) * u, 20 * u, 11 * u, 18), HAIR)
			ci.draw_circle(head + Vector2(0, -24) * u, 8 * u, HAIR, true, -1.0, true)
		2:
			# A little cap.
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -12) * u, 20 * u, 10 * u, 18), Color("f4f1ea"))
			ci.draw_rect(Rect2(head + Vector2(-2, -16) * u, Vector2(24, 5) * u), Color("d8d2c4"))
		3:
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -9) * u, 21 * u, 12 * u, 18), Color("4a3428"))
	if outfit == "trek":
		ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -14) * u, 20 * u, 8 * u, 18), color.darkened(0.3))
		ci.draw_rect(Rect2(head + Vector2(-20, -14) * u, Vector2(40, 4) * u), color.darkened(0.45))
	_face(ci, head, u, face)


static func _face(ci: CanvasItem, head: Vector2, u: float, face: String) -> void:
	for sx in [-1.0, 1.0]:
		if face == "worried":
			ci.draw_line(head + Vector2(sx * 7 - 3, -4) * u, head + Vector2(sx * 7 + 3, -6 + sx * 2) * u, HAIR, 2.5 * u, true)
		ci.draw_circle(head + Vector2(sx * 7, 1) * u, 2.8 * u, HAIR, true, -1.0, true)
		ci.draw_circle(head + Vector2(sx * 12, 8) * u, 3.5 * u, Color(0.93, 0.45, 0.4, 0.35), true, -1.0, true)
	match face:
		"worried":
			ci.draw_arc(head + Vector2(0, 14) * u, 5 * u, PI + 0.5, TAU - 0.5, 8, Color("7a2b22"), 2.5 * u, true)
		"cheer":
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, 10) * u, 6 * u, 5 * u, 12), Color("7a2b22"))
		_:
			ci.draw_arc(head + Vector2(0, 7) * u, 6 * u, 0.4, PI - 0.4, 8, Color("7a2b22"), 2.5 * u, true)


static func _umbrella(ci: CanvasItem, feet: Vector2, u: float) -> void:
	var c := feet + Vector2(0, -66) * u
	var dome := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		dome.append(c + Vector2(cos(a) * 42, sin(a) * 40) * u)
	# Scalloped hem.
	for i in range(6, -1, -1):
		var x := -42.0 + i * 14.0
		dome.append(c + Vector2(x, 4 + (4 if i % 2 == 1 else 0)) * u)
	ci.draw_colored_polygon(dome, UMBRELLA)
	for k in 3:
		var a := PI + PI * (k + 1) / 4.0
		ci.draw_line(c, c + Vector2(cos(a) * 42, sin(a) * 40) * u, UMBRELLA.lightened(0.18), 3 * u, true)
	ci.draw_line(c + Vector2(0, -40) * u, c + Vector2(0, -50) * u, INK, 4 * u, true)
	ci.draw_line(c, c + Vector2(0, 34) * u, INK, 4 * u, true)
	ci.draw_arc(c + Vector2(-6, 34) * u, 6 * u, 0, PI, 8, INK, 4 * u, true)
	DrawKit.outline(ci, dome, INK, 3 * u)
	var f := UIKit.font(true)
	ci.draw_string_outline(f, c + Vector2(-10, -6) * u, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * u), int(6 * u), INK)
	ci.draw_string(f, c + Vector2(-10, -6) * u, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * u), Color.WHITE)


## The khalasi: cap, waistcoat, a towel over the shoulder. `arm` 0..1 raises
## the right arm (banging the bus / waving), `face`: happy | worried | cheer.
static func draw_khalasi(ci: CanvasItem, feet: Vector2, s: float, arm: float = 0.0, face: String = "happy", time: float = 0.0) -> void:
	var u := s / 100.0
	var skin := Color("c48a62")
	ci.draw_colored_polygon(DrawKit.ellipse(feet, 34 * u, 9 * u, 18), Color(0, 0, 0, 0.25))
	DrawKit.capsule(ci, feet + Vector2(-11, -4) * u, feet + Vector2(-11, -34) * u, 8 * u, Color("2f3a52"))
	DrawKit.capsule(ci, feet + Vector2(11, -4) * u, feet + Vector2(11, -34) * u, 8 * u, Color("2f3a52"))
	ci.draw_colored_polygon(DrawKit.ellipse(feet + Vector2(-13, -2) * u, 11 * u, 5 * u, 10), INK)
	ci.draw_colored_polygon(DrawKit.ellipse(feet + Vector2(13, -2) * u, 11 * u, 5 * u, 10), INK)
	# Shirt + waistcoat.
	var body := Rect2(feet + Vector2(-28, -88) * u, Vector2(56, 58) * u)
	ci.draw_colored_polygon(DrawKit.rounded_rect(body.grow(3 * u), 20 * u, 6), INK)
	ci.draw_colored_polygon(DrawKit.rounded_rect(body, 18 * u, 6), Color("f4f1ea"))
	ci.draw_colored_polygon(PackedVector2Array([body.position + Vector2(0, 14 * u), body.position + Vector2(20, 0) * u, body.position + Vector2(22, 58) * u, body.position + Vector2(0, 58) * u]), Color("1d7fe0"))
	ci.draw_colored_polygon(PackedVector2Array([body.position + Vector2(56, 14) * u, body.position + Vector2(36, 0) * u, body.position + Vector2(34, 58) * u, body.position + Vector2(56, 58) * u]), Color("1d7fe0"))
	# Towel on the shoulder.
	ci.draw_colored_polygon(PackedVector2Array([feet + Vector2(-26, -88) * u, feet + Vector2(-10, -90) * u, feet + Vector2(-16, -52) * u, feet + Vector2(-30, -56) * u]), Color("ffc300"))
	# Arms: left on hip, right raised by `arm`.
	DrawKit.capsule(ci, feet + Vector2(-30, -80) * u, feet + Vector2(-38, -54) * u, 7 * u, Color("f4f1ea"))
	ci.draw_circle(feet + Vector2(-38, -52) * u, 7 * u, skin, true, -1.0, true)
	var shoulder := feet + Vector2(30, -80) * u
	var ang := lerpf(PI * 0.42, -PI * 0.38, arm) + sin(time * 9.0) * 0.08 * arm
	var hand := shoulder + Vector2(cos(ang), sin(ang)) * 34 * u
	DrawKit.capsule(ci, shoulder, hand, 7 * u, Color("f4f1ea"))
	ci.draw_circle(hand, 8 * u, skin, true, -1.0, true)
	# Head.
	var head := feet + Vector2(0, -112) * u
	ci.draw_circle(head, 26 * u, INK, true, -1.0, true)
	ci.draw_circle(head, 24 * u, skin, true, -1.0, true)
	ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -12) * u, 24 * u, 12 * u, 18), HAIR)
	# Cap with a peak.
	ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, -16) * u, 24 * u, 13 * u, 20), Color("e63946"))
	ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(14, -10) * u, 18 * u, 5 * u, 14), Color("b02532"))
	ci.draw_circle(head + Vector2(-4, -22) * u, 4 * u, Color(1, 1, 1, 0.5), true, -1.0, true)
	# Moustache.
	ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-1, 8) * u, head + Vector2(-13, 12) * u, head + Vector2(-11, 7) * u, head + Vector2(0, 5) * u, head + Vector2(11, 7) * u, head + Vector2(13, 12) * u, head + Vector2(1, 8) * u]), HAIR)
	for sx in [-1.0, 1.0]:
		if face == "worried":
			ci.draw_line(head + Vector2(sx * 9 - 4, -6) * u, head + Vector2(sx * 9 + 4, -9 + sx * 3) * u, HAIR, 3 * u, true)
		ci.draw_circle(head + Vector2(sx * 9, 0) * u, 3.4 * u, HAIR, true, -1.0, true)
	match face:
		"worried":
			ci.draw_arc(head + Vector2(0, 20) * u, 6 * u, PI + 0.5, TAU - 0.5, 8, Color("7a2b22"), 3 * u, true)
		"cheer":
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, 16) * u, 9 * u, 7 * u, 14), Color("7a2b22"))
			ci.draw_colored_polygon(DrawKit.ellipse(head + Vector2(0, 19) * u, 5 * u, 3 * u, 10), Color("e8737a"))
		_:
			ci.draw_arc(head + Vector2(0, 13) * u, 7 * u, 0.4, PI - 0.4, 8, Color("7a2b22"), 3 * u, true)
