class_name HomePage
extends Control
## Home: the MICRO JAM logo, the route map (each level is a bus stop) and a
## big ticket-shaped PLAY button. One tap from here into the level.

var play_button: TicketButton
var map: RouteMap
var _badge_holder: CenterContainer
var _logo: Control
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_logo = Control.new()
	_logo.custom_minimum_size = Vector2(0, 290)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.draw.connect(func() -> void: GameLogo.draw(_logo, Vector2(_logo.size.x * 0.5, -10), 0.95, _t))
	v.add_child(_logo)
	map = RouteMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.clip_contents = true
	v.add_child(map)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 110)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 24)
	v.add_child(pad)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	pad.add_child(stack)
	_badge_holder = CenterContainer.new()
	_badge_holder.custom_minimum_size = Vector2(0, 50)
	stack.add_child(_badge_holder)
	play_button = TicketButton.new()
	play_button.setup("PLAY", "gold", "", 76, Vector2(0, 210))
	play_button.pressed.connect(_on_play)
	stack.add_child(play_button)
	UIKit.pulse(play_button, 1.04, 1.3)
	refresh(true)


func _process(delta: float) -> void:
	_t += delta
	_logo.queue_redraw()


func refresh(animate: bool = false) -> void:
	var level := ProgressionManager.current_level()
	play_button.set_label("PLAY  %d" % level)
	for ch in _badge_holder.get_children():
		ch.queue_free()
	var badge := UIKit.tier_badge(ProgressionManager.tier_for(level), 34)
	if badge:
		_badge_holder.add_child(badge)
	map.refresh(animate)


func _on_play() -> void:
	var level := ProgressionManager.current_level()
	if not LivesManager.can_play(level):
		Popups.lives(true)
		return
	ScreenManager.start_level()
