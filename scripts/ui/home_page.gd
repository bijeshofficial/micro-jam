class_name HomePage
extends Control
## Home: the full-screen route map, a big ticket PLAY button floating above
## the dock, and side buttons for the Daily Jam and Daily Tasks.
## One tap from here into the level (PLAY or the glowing current stop).

var play_button: TicketButton
var map: RouteMap
var daily_button: SideButton
var tasks_button: SideButton
var locate_button: GameButton
var _badge_holder: CenterContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var top_pad := float(get_meta("top_pad", 150.0))
	var bottom_pad := float(get_meta("bottom_pad", 200.0))
	map = RouteMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.top_pad = top_pad
	map.bottom_pad = bottom_pad + 250.0
	map.play_requested.connect(_on_play)
	add_child(map)

	# Side buttons under the top bar.
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 18)
	side.position = Vector2(20, top_pad + 10)
	add_child(side)
	daily_button = SideButton.new()
	daily_button.setup("calendar", "Daily Jam", UIKit.PURPLE, UIKit.PURPLE_EDGE)
	daily_button.pressed.connect(func() -> void: Popups.daily_jam())
	side.add_child(daily_button)
	tasks_button = SideButton.new()
	tasks_button.setup("tasks", "Tasks", UIKit.TEAL, UIKit.TEAL_EDGE)
	tasks_button.pressed.connect(func() -> void: Popups.daily_tasks())
	side.add_child(tasks_button)

	# Recentre on the bus when scrolled away.
	locate_button = UIKit.button("", "secondary", "target", 44, Vector2(110, 110))
	locate_button.position = Vector2(get_viewport_rect().size.x - 136, top_pad + 20)
	locate_button.pressed.connect(func() -> void: map.center_on(float(ProgressionManager.current_level())))
	add_child(locate_button)

	# PLAY ticket floating above the dock.
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 110
	bottom.offset_right = -110
	bottom.offset_top = -(bottom_pad + 270.0)
	bottom.offset_bottom = -(bottom_pad + 16.0)
	add_child(bottom)
	_badge_holder = CenterContainer.new()
	_badge_holder.custom_minimum_size = Vector2(0, 48)
	bottom.add_child(_badge_holder)
	play_button = TicketButton.new()
	play_button.setup("PLAY", "gold", "", 78, Vector2(0, 200))
	play_button.pressed.connect(_on_play)
	bottom.add_child(play_button)
	UIKit.pulse(play_button, 1.04, 1.3)
	refresh(true)


func _process(_delta: float) -> void:
	if locate_button:
		locate_button.visible = not map.is_centered()


func refresh(animate: bool = false) -> void:
	var level := ProgressionManager.current_level()
	play_button.set_label("LEVEL %d" % level)
	for ch in _badge_holder.get_children():
		ch.queue_free()
	var badge := UIKit.tier_badge(ProgressionManager.tier_for(level), 34)
	if badge:
		_badge_holder.add_child(badge)
	map.refresh(animate)
	refresh_badges()


func refresh_badges() -> void:
	if daily_button == null:
		return
	daily_button.set_badge("" if DailyManager.challenge_done_today() else "!", DailyManager.challenge_done_today())
	var n := DailyManager.claimable_count()
	tasks_button.set_badge(str(n) if n > 0 else "", DailyManager.all_claimed() and DailyManager.chest_claimed())


func _on_play() -> void:
	var level := ProgressionManager.current_level()
	if not LivesManager.can_play(level):
		Popups.lives(true)
		return
	ScreenManager.start_level()
