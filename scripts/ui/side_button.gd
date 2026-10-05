class_name SideButton
extends Button
## Square glossy tile with a big icon and a short name underneath (Home side
## buttons: Daily Jam, Tasks). Shows a red count badge or a green check.

var base := UIKit.PURPLE
var edge := UIKit.PURPLE_EDGE
var _icon: IconView
var _label: Label
var _badge := ""
var _check := false
var _press := 0.0


func setup(icon_name: String, caption: String, col: Color, col_edge: Color) -> void:
	base = col
	edge = col_edge
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(150, 170)
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_icon = UIKit.icon(icon_name, 84, Color.WHITE)
	_icon.shadow = true
	_icon.shadow_color = edge.darkened(0.5)
	_icon.accent = base
	add_child(_icon)
	_label = UIKit.title(caption, 32)
	add_child(_label)
	button_down.connect(func() -> void:
		_press = 1.0
		queue_redraw()
		_layout())
	button_up.connect(func() -> void:
		_press = 0.0
		queue_redraw()
		_layout()
		UIKit.bounce(self, 1.08))
	pressed.connect(func() -> void:
		AudioManager.play("button_click")
		HapticsManager.light())
	resized.connect(_layout)


func set_badge(text: String, check: bool = false) -> void:
	_badge = text
	_check = check
	queue_redraw()


func _layout() -> void:
	pivot_offset = size * 0.5
	_icon.size = Vector2(84, 84)
	_icon.position = Vector2((size.x - 84) * 0.5, 14 + _press * 8)
	_label.size = Vector2(size.x + 30, 44)
	_label.position = Vector2(-15, size.y - 50)


func _draw() -> void:
	DrawKit.glossy_rrect(self, Rect2(Vector2(10, 0), Vector2(size.x - 20, size.y - 44)), 30, base, edge, _press, 5.0, 10.0, true)
	var bc := Vector2(size.x - 16, 10)
	if _check:
		draw_circle(bc, 24, Color("0b5a32"), true, -1.0, true)
		draw_circle(bc, 20, UIKit.PRIMARY, true, -1.0, true)
		draw_polyline(PackedVector2Array([bc + Vector2(-9, 0), bc + Vector2(-2, 7), bc + Vector2(10, -7)]), Color.WHITE, 5.0, true)
	elif _badge != "":
		draw_circle(bc, 24, Color.WHITE, true, -1.0, true)
		draw_circle(bc, 20, UIKit.HEART, true, -1.0, true)
		var f := UIKit.font(true)
		var w := f.get_string_size(_badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(f, bc + Vector2(-w * 0.5, 10), _badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
