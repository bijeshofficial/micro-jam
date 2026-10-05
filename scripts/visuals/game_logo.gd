class_name GameLogo
extends RefCounted
## The MICRO JAM title: chunky outlined letters with a little bounce, a
## microbus parked under the word.


static func draw(ci: CanvasItem, top_center: Vector2, s: float = 1.0, time: float = 0.0) -> void:
	var f := UIKit.font(true)
	_word(ci, f, "MICRO", top_center + Vector2(0, 110) * s, int(118 * s), Color("ffc300"), time, 0)
	_word(ci, f, "JAM", top_center + Vector2(0, 236) * s, int(150 * s), Color("e63946"), time, 5)


static func _word(ci: CanvasItem, f: Font, word: String, base: Vector2, fs: int, col: Color, time: float, phase: int) -> void:
	var widths: Array = []
	var total := 0.0
	for ch in word:
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w + fs * 0.02
	var x := base.x - total * 0.5
	for i in word.length():
		var ch := word[i]
		var bob := sin(time * 3.0 + (i + phase) * 0.7) * fs * 0.04
		var rot := (0.06 if (i + phase) % 2 == 0 else -0.05)
		var pos := Vector2(x + float(widths[i]) * 0.5, base.y + bob)
		ci.draw_set_transform(pos, rot)
		var o := Vector2(-float(widths[i]) * 0.5, 0)
		ci.draw_string_outline(f, o + Vector2(0, fs * 0.1), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.3), Color("17213f"))
		ci.draw_string_outline(f, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.26), Color("17213f"))
		ci.draw_string(f, o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		# Glossy top highlight: the letter again, clipped by a lighter colour offset.
		ci.draw_string(f, o + Vector2(0, -fs * 0.03), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.lightened(0.35), 0.35))
		ci.draw_set_transform(Vector2.ZERO)
		x += float(widths[i]) + fs * 0.02
