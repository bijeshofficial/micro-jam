class_name BottomNav
extends Control
## Shop | Home | Profile dock. The selected tab widens into a raised glossy
## gold tile with a big icon and its name; the others show a large icon
## only. Widths animate when switching. Red dots mark things to claim.

signal tab_selected(index: int)

const TABS := [["shop", "Shop"], ["home", "Home"], ["profile", "Profile"]]
## Dock height without the safe-area inset.
const HEIGHT := 200.0
const LIFT := 34.0
const SELECTED_SHARE := 0.42

var current := 1
var _share: Array = [0.29, SELECTED_SHARE, 0.29]
var _icons: Array[IconView] = []
var _labels: Array[Label] = []
var _dots: Array[Control] = []
var _tween: Tween
var _press := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in TABS.size():
		var ic := UIKit.icon(TABS[i][0], 100, Color.WHITE)
		ic.shadow = true
		ic.shadow_color = Color("0d1544")
		add_child(ic)
		_icons.append(ic)
		var l := UIKit.title(TABS[i][1], 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, Color("7a3a00"))
		add_child(l)
		_labels.append(l)
		var dot := UIKit.red_dot(40)
		dot.visible = false
		add_child(dot)
		_dots.append(dot)
	resized.connect(_layout)
	select(current, false)


func set_dot(index: int, on: bool) -> void:
	_dots[index].visible = on


func has_dot(index: int) -> bool:
	return _dots[index].visible


func select(index: int, animate: bool = true) -> void:
	current = index
	var target: Array = []
	for i in TABS.size():
		target.append(SELECTED_SHARE if i == index else (1.0 - SELECTED_SHARE) * 0.5)
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		var from := _share.duplicate()
		_tween = create_tween()
		_tween.tween_method(_blend.bind(from, target), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		UIKit.bounce(_icons[index], 1.25, 0.3)
	else:
		_share = target
		_layout()


func _blend(t: float, from: Array, target: Array) -> void:
	for i in _share.size():
		_share[i] = lerpf(float(from[i]), float(target[i]), t)
	_layout()


func _slot(i: int) -> Rect2:
	var x := 0.0
	for k in i:
		x += float(_share[k]) * size.x
	return Rect2(x, 0, float(_share[i]) * size.x, size.y)


func _layout() -> void:
	if _icons.is_empty():
		return
	for i in TABS.size():
		var r := _slot(i)
		var on := i == current
		var s := 118.0 if on else 100.0
		var cy := LIFT + 44.0 if on else LIFT + (HEIGHT - LIFT) * 0.5 - 6.0
		_icons[i].size = Vector2(s, s)
		_icons[i].position = Vector2(r.position.x + (r.size.x - s) * 0.5, cy - s * 0.5)
		_icons[i].pivot_offset = Vector2(s, s) * 0.5
		_labels[i].visible = on
		_labels[i].size = Vector2(r.size.x, 52)
		_labels[i].position = Vector2(r.position.x, LIFT + 96.0)
		_dots[i].position = Vector2(r.position.x + r.size.x * 0.5 + s * 0.28, cy - s * 0.58)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var bar := Rect2(0, LIFT, w, size.y - LIFT + 20.0)
	# Dock body: dark top frame, blue gradient, a light line under the frame.
	draw_rect(Rect2(0, LIFT - 8, w, 10), Color("0d1544"))
	draw_polygon(PackedVector2Array([bar.position, Vector2(w, bar.position.y), Vector2(w, bar.end.y), Vector2(0, bar.end.y)]),
		PackedColorArray([Color("3f72ff"), Color("3f72ff"), Color("1f3aa6"), Color("1f3aa6")]))
	draw_rect(Rect2(0, LIFT + 2, w, 4), Color(1, 1, 1, 0.3))
	# Dividers between the unselected tabs.
	for i in range(1, TABS.size()):
		if i != current and i - 1 != current:
			var x := _slot(i).position.x
			draw_line(Vector2(x, LIFT + 30), Vector2(x, size.y - 40), Color(0.05, 0.08, 0.3, 0.5), 4.0)
	# The selected tile, raised above the dock.
	var r := _slot(current).grow_individual(-10, 0, -10, 0)
	var tile := Rect2(r.position.x, 2.0, r.size.x, LIFT + 152.0)
	var press := 1.0 if _press == current else 0.0
	DrawKit.glossy_rrect(self, tile, 40, Color("ffcf3a"), Color("e08a00"), press, 6.0, 14.0, true)


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
	else:
		return
	var hit := -1
	for i in TABS.size():
		if _slot(i).has_point(pos):
			hit = i
	if pressed:
		_press = hit
		queue_redraw()
	elif _press >= 0:
		var was := _press
		_press = -1
		queue_redraw()
		if hit == was:
			AudioManager.play("button_click")
			HapticsManager.light()
			tab_selected.emit(hit)
	accept_event()
