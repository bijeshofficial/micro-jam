class_name TutorialDirector
extends Node
## The first levels teach by doing: an animated hand and one short line.
##   L1 "tap":       forced taps; only the bus under the hand responds.
##   L2 "blocked":   a blocked bus bumps back; the hand shows a free one
##                   if the player idles.
##   L3 "bays":      text only, until the first full bus leaves.
##   L6 "crane":     a round lot with four buses boxing each other in (a
##                   pinwheel). The free buses go first; once nothing can
##                   move, the hand shows the Crane, then a boxed-in bus.
##   L8 "extra_bay" / L12 "shuffle": free charges and the booster pulses
##                   until it is used.
## Each step is saved once complete and never repeats. Twists get a
## one-screen intro card.

const TEXTS := {
	"crane": "Boxed in? Lift any bus out with the Crane!",
	"extra_bay": "Need more room? Open an extra bay!",
	"shuffle": "Wrong colours first? Shuffle the queue!",
}

var game: Node            # Gameplay
var step := ""
var forced: Array = []
var hand: IconView
var text_panel: PanelContainer
var text_label: Label

var crane_targets: Array = []   # L6: buses the Crane may lift
var _crane_prompted := false
var _idle := 0.0
var _hand_tween: Tween
var _hand_shown := false
var _bumped := false


func setup(gameplay: Node, layer: CanvasLayer, level: Dictionary, moves_done: int = 0) -> void:
	game = gameplay
	text_panel = PanelContainer.new()
	var sb := UIKit.card_box(Color.WHITE, 26, UIKit.SECONDARY)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	text_panel.add_theme_stylebox_override("panel", sb)
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.visible = false
	layer.add_child(text_panel)
	text_label = UIKit.label("", 46, UIKit.INK)
	text_panel.add_child(text_label)
	hand = UIKit.icon("hand", 150, Color.WHITE)
	hand.shadow = true
	hand.size = Vector2(150, 150)
	hand.pivot_offset = hand.size * 0.5
	hand.visible = false
	hand.z_index = 30
	layer.add_child(hand)
	var id := String(level.get("tutorial", ""))
	if id != "" and not ProgressionManager.tutorial_done(id):
		step = id
		if id == "tap":
			forced = (level.get("forced", []) as Array).duplicate()
			forced = forced.slice(mini(moves_done, forced.size()))
		if id == "crane":
			for t in level.get("crane_targets", []):
				crane_targets.append(int(t))


## Called once the buses have landed.
func start() -> void:
	match step:
		"tap":
			_show_forced()
		"blocked":
			say("Blocked? Clear the way first!")
		"bays":
			say("Buses wait in a bay until they're full.")
		"crane", "extra_bay", "shuffle":
			var n := BoosterManager.grant_tutorial(step)
			if n > 0:
				VFXManager.toast("%d free %s!" % [n, BoosterManager.display_name(step)])
			if _crane_lesson():
				say("Send out the buses that can move!")
				return
			say(TEXTS[step])
			game.booster_buttons[step].start_pulse()


func is_active() -> bool:
	return step == "tap" or step == "blocked" or _crane_lesson()


## L6's hand-made pinwheel level (other levels' crane step just pulses).
func _crane_lesson() -> bool:
	return step == "crane" and not crane_targets.is_empty()


func blocks_boosters() -> bool:
	if _crane_lesson() and not game.park.exitable().is_empty():
		return true
	return step == "tap" and not forced.is_empty()


## Message shown when a booster is tapped while blocks_boosters() is true.
func blocked_booster_text() -> String:
	return "Send the free buses out first!" if _crane_lesson() else "Follow the hand first!"


## L6: Crane mode is on: show which bus to lift.
func on_crane_mode(on: bool) -> void:
	if not _crane_lesson():
		return
	if on:
		# The lesson's own line replaces the game's crane banner here.
		if game.crane_banner:
			game.crane_banner.visible = false
		say("Tap a boxed-in bus to lift it out!")
		point_at_bus(int(crane_targets[0]))
	else:
		hide_hand()


## L1: only the bus under the hand responds. L6 in Crane mode: only the
## four boxed-in buses can be lifted (lifting a free one would waste it).
func allows_tap(id: int) -> bool:
	if _crane_lesson() and game.crane_mode and not crane_targets.has(id):
		VFXManager.toast("Lift one of the boxed-in buses!")
		return false
	if step != "tap" or forced.is_empty():
		return true
	if id != int(forced[0]):
		var bv: BusVisual = game.view.bus_visual(int(forced[0]))
		if bv:
			bv.squash(Vector2(1.1, 0.9))
		return false
	return true


func on_tap(_id: int, events: Array) -> void:
	_idle = 0.0
	hide_hand()
	var kind := String(events[0]["type"]) if not events.is_empty() else ""
	match step:
		"tap":
			if kind == "exit" and not forced.is_empty():
				forced.pop_front()
				if forced.is_empty():
					say("Full buses leave. Clear the jam!")
					complete()
					_after(2.5, hide_text)
				else:
					_after(0.6, _show_forced)
		"blocked":
			if kind == "blocked":
				_bumped = true
				say("Bump! Move the bus in the way first.")
			elif kind == "exit" and _bumped:
				hide_text()
				complete()
	for e in events:
		if String(e["type"]) == "depart" and step == "bays":
			_after(1.0, hide_text)
			complete()


func on_booster(id: String) -> void:
	if step == id:
		game.booster_buttons[id].stop_pulse()
		hide_text()
		complete()


func on_win() -> void:
	hide_hand()
	hide_text()
	for id in ["crane", "extra_bay", "shuffle"]:
		if game.booster_buttons.has(id):
			game.booster_buttons[id].stop_pulse()
	if step != "":
		complete()


func complete() -> void:
	if step != "":
		ProgressionManager.mark_tutorial(step)
	step = ""


func _process(delta: float) -> void:
	# L6: once nothing can drive out, show the Crane.
	if _crane_lesson() and not _crane_prompted and not game.crane_mode and game.is_playing() and game.view.idle() and game.park.exitable().is_empty():
		_crane_prompted = true
		say(TEXTS["crane"])
		game.booster_buttons["crane"].start_pulse()
		point_at_control(game.booster_buttons["crane"])
	if step == "blocked" and not _hand_shown and game.is_playing() and game.view.idle():
		_idle += delta
		if _idle >= 4.0:
			var id := ParkSolver.hint(game.park.to_dict(), 3000)
			if id >= 0:
				point_at_bus(id)


func _show_forced() -> void:
	if forced.is_empty() or not is_instance_valid(game):
		return
	var lines := ["Tap the bus to drive it out!", "Blue passengers need a blue bus!", "Last one! Tap it."]
	say(lines[clampi(game.moves, 0, lines.size() - 1)])
	point_at_bus(int(forced[0]))


func say(text: String) -> void:
	text_label.text = text
	text_panel.visible = true
	text_panel.reset_size()
	var vp := game.get_viewport().get_visible_rect().size
	text_panel.position = Vector2((vp.x - text_panel.size.x) * 0.5, game.hint_text_y())
	text_panel.modulate.a = 0.0
	UIKit.pop_in(text_panel)


func hide_text() -> void:
	if text_panel.visible:
		var tw := text_panel.create_tween()
		tw.tween_property(text_panel, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func() -> void: text_panel.visible = false)


func point_at_bus(id: int) -> void:
	var bv: BusVisual = game.view.bus_visual(id)
	if bv == null:
		return
	var p: Vector2 = game.view.position + bv.position + Vector2(-10, -10)
	_hand_shown = true
	hand.visible = true
	if _hand_tween:
		_hand_tween.kill()
	hand.scale = Vector2.ONE
	hand.position = p
	_hand_tween = hand.create_tween().set_loops()
	_hand_tween.tween_property(hand, "position", p + Vector2(18, 36), 0.35).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(hand, "scale", Vector2(0.9, 0.9), 0.08)
	_hand_tween.tween_property(hand, "scale", Vector2.ONE, 0.12)
	_hand_tween.tween_property(hand, "position", p, 0.35).set_trans(Tween.TRANS_SINE)


## Buttons sit on the bottom row, so the hand hangs above them, upside
## down, with the finger pointing down at the button (below it, it would be
## off screen on phones with a gesture bar).
func point_at_control(c: Control) -> void:
	var r := c.get_global_rect()
	# Fingertip of the hand icon, in its 150 px box, once flipped vertically.
	var tip := Vector2(hand.size.x * 0.42, hand.size.y * (1.0 - 0.1))
	var target := Vector2(r.get_center().x, r.position.y + r.size.y * 0.18)
	var p := target - tip - Vector2(0, 30)
	_hand_shown = true
	hand.visible = true
	if _hand_tween:
		_hand_tween.kill()
	hand.scale = Vector2(1, -1)
	hand.position = p
	# Keep the hint text clear of the hand: lift it above if they overlap.
	if text_panel.visible and text_panel.position.y + text_panel.size.y > p.y - 10.0:
		text_panel.position.y = p.y - text_panel.size.y - 16.0
	_hand_tween = hand.create_tween().set_loops()
	_hand_tween.tween_property(hand, "position", p + Vector2(0, 30), 0.35).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(hand, "scale", Vector2(0.9, -0.9), 0.08)
	_hand_tween.tween_property(hand, "scale", Vector2(1, -1), 0.12)
	_hand_tween.tween_property(hand, "position", p, 0.35).set_trans(Tween.TRANS_SINE)


func hide_hand() -> void:
	_hand_shown = false
	if _hand_tween:
		_hand_tween.kill()
		_hand_tween = null
	if hand:
		hand.visible = false
		hand.scale = Vector2.ONE


## One-screen intro card for twists this player hasn't seen yet.
static func twist_card(twist_id: String, on_close: Callable) -> GamePopup:
	var info: Dictionary = GameData.difficulty()["twists"].get(twist_id, {})
	return Popups.show({
		"id": "twist_" + twist_id,
		"title": String(info.get("title", "New twist")),
		"art": func(c: Control) -> void: draw_twist_art(c, twist_id),
		"art_size": 320,
		"body": String(info.get("text", "")),
		"buttons": [{"id": "ok", "text": "Got it", "kind": "primary", "icon": "check", "cb": on_close}],
		"on_back": on_close,
	})


static func draw_twist_art(c: Control, twist_id: String) -> void:
	var mid := c.size * 0.5 + Vector2(0, 30)
	match twist_id:
		"sleep":
			BusArt.draw_bus(c, mid, 130, 2, Park.RIGHT, GameData.bus_color(1), {"sleep": true, "time": Time.get_ticks_msec() / 1000.0, "name": "Sathi"})
			c.queue_redraw()
		"cones":
			BusArt.draw_bus(c, mid + Vector2(-110, 0), 110, 2, Park.RIGHT, GameData.bus_color(0), {})
			var p := mid + Vector2(150, 40)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-34, 0), p + Vector2(34, 0), p + Vector2(10, -90), p + Vector2(-10, -90)]), Color("ff7f11"))
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-24, -32), p + Vector2(24, -32), p + Vector2(18, -54), p + Vector2(-18, -54)]), Color.WHITE)
			c.draw_rect(Rect2(p + Vector2(-46, -6), Vector2(92, 16)), Color("d35400"))
		"covered":
			PeopleArt.draw_passenger(c, mid + Vector2(-90, 90), 200, GameData.bus_color(3), 1, "everyday", true)
			PeopleArt.draw_passenger(c, mid + Vector2(90, 90), 200, GameData.bus_color(3), 2, "everyday", false)
			c.draw_line(mid + Vector2(-20, 0), mid + Vector2(20, 0), UIKit.INK_SOFT, 8, true)
		"taxi":
			BusArt.draw_bus(c, mid + Vector2(-150, 0), 120, 2, Park.RIGHT, GameData.bus_color(1), {})
			BusArt.draw_bus(c, mid + Vector2(70, 0), 120, 1, Park.RIGHT, GameData.bus_color(2), {})
			BusArt.draw_bus(c, mid + Vector2(200, 0), 120, 1, Park.UP, GameData.bus_color(0), {})
		"mystery":
			BusArt.draw_bus(c, mid + Vector2(-120, 0), 120, 2, Park.RIGHT, Color.WHITE, {"mystery": true})
			c.draw_line(mid + Vector2(10, 0), mid + Vector2(60, 0), UIKit.INK_SOFT, 8, true)
			BusArt.draw_bus(c, mid + Vector2(160, 0), 120, 2, Park.RIGHT, GameData.bus_color(2), {})
		"padlock":
			BusArt.draw_bus(c, mid + Vector2(-120, 0), 120, 2, Park.RIGHT, GameData.bus_color(1), {"lock": GameData.bus_color(0)})
			BusArt.draw_bus(c, mid + Vector2(150, -10), 100, 2, Park.UP, GameData.bus_color(0), {"seats": 4, "boarded": 4, "seat_color": GameData.bus_color(0)})
		"tunnel":
			var r := Rect2(mid + Vector2(-260, -90), Vector2(110, 180))
			c.draw_colored_polygon(DrawKit.rounded_rect(r.grow(10), 30, 6), Color("6b6f7a"))
			c.draw_colored_polygon(DrawKit.rounded_rect(r, 26, 6), Color("141821"))
			BusArt.draw_bus(c, mid + Vector2(10, 0), 110, 3, Park.RIGHT, GameData.bus_color(5), {})


## Runs `fn` after `sec` seconds on a tween owned by this node.
func _after(sec: float, fn: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(fn)
