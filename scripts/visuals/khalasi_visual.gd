class_name KhalasiVisual
extends Node2D
## The bus conductor mascot. Idles with a bob; bangs the side of a leaving
## bus and shouts its destination; cheers on a win; worries when the bays
## are nearly full.

var unit := 1.0
var face := "happy"

var _t := 0.0
var _arm := 0.0
var _arm_tween: Tween
var _bubble_text := ""
var _bubble_a := 0.0
var _bubble_tween: Tween
var _jump := 0.0
var _worried := false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 3.0 * unit
	var feet := Vector2(0, -bob * 0.3 - _jump)
	PeopleArt.draw_khalasi(self, feet, 150.0 * unit, _arm, face, _t)
	if _bubble_a > 0.01 and _bubble_text != "":
		_draw_bubble(feet + Vector2(40, -230) * unit)


func _draw_bubble(anchor: Vector2) -> void:
	var f := UIKit.font(true)
	var fs := int(40 * unit)
	var tw := f.get_string_size(_bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(anchor - Vector2(10, 40) * unit, Vector2(tw + 44 * unit, 74 * unit))
	var a := _bubble_a
	var tail := PackedVector2Array([r.position + Vector2(20, r.size.y - 4) * Vector2(unit, 1), r.position + Vector2(52 * unit, r.size.y - 4), r.position + Vector2(4 * unit, r.size.y + 30 * unit)])
	draw_colored_polygon(DrawKit.rounded_rect(r.grow(4), 30 * unit, 6), Color(0.12, 0.14, 0.26, a))
	draw_colored_polygon(tail, Color(0.12, 0.14, 0.26, a))
	draw_colored_polygon(DrawKit.rounded_rect(r, 26 * unit, 6), Color(1, 1, 1, a))
	draw_string(f, r.position + Vector2(22 * unit, r.size.y * 0.5 + fs * 0.36), _bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.85, 0.15, 0.22, a))


func _set_arm(v: float) -> void:
	_arm = v


## Bangs the bus twice ("dhak dhak") and shouts `text`.
func bang(text: String) -> void:
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	for k in 2:
		_arm_tween.tween_method(_set_arm, 0.2, 1.0, 0.08)
		_arm_tween.tween_method(_set_arm, 1.0, 0.2, 0.1)
	_arm_tween.tween_method(_set_arm, 0.2, 0.0, 0.2)
	shout(text)


func shout(text: String, hold: float = 1.0) -> void:
	_bubble_text = text
	if _bubble_tween:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(self, "_bubble_a", 1.0, 0.1)
	_bubble_tween.tween_interval(hold)
	_bubble_tween.tween_property(self, "_bubble_a", 0.0, 0.25)


func cheer(dur: float = 1.6) -> void:
	face = "cheer"
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.tween_method(_set_arm, _arm, 1.0, 0.12)
	var jt := create_tween().set_loops(3)
	jt.tween_property(self, "_jump", 34.0 * unit, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jt.tween_property(self, "_jump", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_arm_tween.tween_interval(dur)
	_arm_tween.tween_callback(func() -> void: face = "worried" if _worried else "happy")
	_arm_tween.tween_method(_set_arm, 1.0, 0.0, 0.2)


func set_worried(on: bool) -> void:
	_worried = on
	face = "worried" if on else "happy"


func wave() -> void:
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	for k in 3:
		_arm_tween.tween_method(_set_arm, 0.6, 1.0, 0.12)
		_arm_tween.tween_method(_set_arm, 1.0, 0.6, 0.12)
	_arm_tween.tween_method(_set_arm, 0.6, 0.0, 0.2)
