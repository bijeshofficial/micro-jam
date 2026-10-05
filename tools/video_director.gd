extends Node
## Plays a scripted, bot-driven run of the real game for promo videos and
## App Store previews: Home > a normal level > a big round lot with a Crane
## rescue > end card. Captions, tap rings and the end card are drawn on an
## overlay above the game. Driven by tools/record_video.gd.
##
## Every wait is in game time (timers), so under Movie Maker mode the video is
## smooth and the same length no matter how fast the machine renders.

const ART := "res://docs/store/art/"
const NAVY := Color("17213F")
const TITLE_FONT := preload("res://assets/fonts/TitanOne-Regular.ttf")

var cut := "promo"   # "promo" (Shorts / Reels / Play promo) or "appstore"
var S: Node
var SM: Node
var overlay: CanvasLayer
var caption: Label
var caption_box: Panel
var _caption_tween: Tween


func run() -> void:
	S = get_node("/root/SaveManager")
	SM = get_node("/root/ScreenManager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	S.set_save_path("user://video_save.json")
	get_node("/root/GameManager").pause_on_focus_loss = false
	_build_overlay()

	var short := cut == "appstore"   # App Store previews: 30 s max

	# 1. Home: the route map, then PLAY (the App Store cut opens in the level).
	_fresh(42)
	if short:
		# No wipe: the first frame is the App Store poster frame.
		get_tree().change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	else:
		SM.hub_tab = "home"
		get_tree().change_scene_to_file("res://scenes/main/hub.tscn")
		await _wait(0.3)
		_say("Clear the bus park jam!", 1.6)
		await _wait(1.4)
		var hub = get_tree().current_scene
		var play_btn: Control = hub.home.play_button
		await _tap_at(play_btn.get_global_rect().get_center())
		SM.start_level()
	await _wait_level()

	# 2. A normal level, played to the win panel.
	await _wait(0.4)
	_say("Tap a bus. Fill it up!", 2.2)
	await _play(99, 0.48)
	await _fast_forward()
	await _wait_modal("win", 12.0)
	await _wait(1.0 if short else 1.4)
	_say("Win coins, unlock buses!", 1.4)
	await _wait(0.6)

	# 3. A big round lot from level 1000, with a Crane rescue.
	S.data["current_level"] = 1000
	S.data["game"]["route_seen_level"] = 1000
	var win = SM.find_modal("win")
	if win:
		await _tap_at(win.continue_button.get_global_rect().get_center())
	SM.start_level()
	await _wait_level()
	await _wait(0.4)
	_say("Bigger lots, bigger jams", 2.2)
	await _play(3 if short else 5, 0.45)
	await _wait(0.3)
	await _crane()
	await _wait(0.4)
	await _play(2 if short else 4, 0.45)
	await _wait(0.6)

	# 4. End card.
	await _end_card()


# --- Setup -------------------------------------------------------------------

func _fresh(level: int) -> void:
	S.data = S.defaults()
	S.data["coins"] = 1240
	S.data["current_level"] = level
	S.data["game"]["route_seen_level"] = level
	S.data["game"]["boosters"] = {"crane": 3, "extra_bay": 2, "shuffle": 4}
	S.data["settings"]["hints"] = false
	var steps := {}
	for k in ["tap", "blocked", "bays", "crane", "extra_bay", "shuffle", "twist_sleep", "twist_cones", "twist_covered", "twist_tunnel", "grant_crane", "grant_extra_bay", "grant_shuffle"]:
		steps[k] = true
	S.data["game"]["tutorial_steps"] = steps
	# All claimed already, so a win doesn't pop an achievement toast.
	for e in S.data["game"]["achievements"].values():
		e["claimed"] = true


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 120
	add_child(overlay)
	caption_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(NAVY, 0.88)
	sb.set_corner_radius_all(54)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.set_border_width_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	caption_box.add_theme_stylebox_override("panel", sb)
	caption_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_box.visible = false
	overlay.add_child(caption_box)
	caption = Label.new()
	caption.add_theme_font_override("font", TITLE_FONT)
	caption.add_theme_font_size_override("font_size", 74)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", NAVY)
	caption.add_theme_constant_override("outline_size", 18)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption_box.add_child(caption)


# --- Overlay effects ---------------------------------------------------------

## Pops a caption ribbon in over the top bar, holds it, then fades it out.
func _say(text: String, hold: float) -> void:
	var vp := _vp()
	caption.text = text
	caption_box.size = Vector2(vp.x - 80, 170)
	caption_box.position = Vector2(40, 34 + _top_inset())
	caption_box.pivot_offset = caption_box.size * 0.5
	caption_box.visible = true
	caption_box.modulate.a = 1.0
	if _caption_tween:
		_caption_tween.kill()
	var tw := caption_box.create_tween()
	_caption_tween = tw
	tw.tween_property(caption_box, "scale", Vector2.ONE, 0.28).from(Vector2(0.6, 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(caption_box, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: caption_box.visible = false)


func _top_inset() -> float:
	# Taller (19.5:9) frames get extra sky above the game's top bar.
	return maxf(0.0, (_vp().y - 1920.0) * 0.25)


## A soft touch ring where the "finger" taps, then a short beat.
func _tap_at(p: Vector2) -> void:
	var ring := TapRing.new()
	ring.position = p
	overlay.add_child(ring)
	await _wait(0.12)


func _bus_point(g, id: int) -> Vector2:
	return g.view.get_global_transform_with_canvas() * g.view.lot_center(id)


# --- Bot ---------------------------------------------------------------------

## Taps up to `count` buses, picking the solver's best move each time.
func _play(count: int, pace: float) -> void:
	var g = get_tree().current_scene
	var taps := 0
	var guard := 0.0
	while taps < count and guard < 60.0 and g.state != 3 and not g.park.is_won():
		if not g.is_playing():
			await _wait(0.1)
			guard += 0.1
			continue
		var id := _pick(g)
		if id < 0 or g.view.is_bus_busy(id):
			await _wait(0.08)
			guard += 0.08
			continue
		await _tap_at(_bus_point(g, id))
		g.tap_bus(id)
		taps += 1
		await _wait(pace)


## Once the lot is empty the last passengers are still boarding: play that
## tail at double speed so the video doesn't sit on an empty lot.
func _fast_forward() -> void:
	var g = get_tree().current_scene
	Engine.time_scale = 2.0
	var t := 0.0
	while g.view.time_left() > 0.25 and t < 8.0:
		await _wait(0.05)
		t += 0.05
	Engine.time_scale = 1.0


func _pick(g) -> int:
	var id: int = ParkSolver.hint(g.park.to_dict(), 30000)
	if id >= 0:
		return id
	for s in g.level_data.get("solution", []):
		if g.park.bus(int(s))["state"] == "lot" and g.park.can_exit(int(s)):
			return int(s)
	var ex: Array = g.park.exitable()
	return int(ex[0]) if not ex.is_empty() else -1


## Lifts a boxed-in bus of the colour the line wants with the Crane.
func _crane() -> void:
	var g = get_tree().current_scene
	var front: int = g.park.front_color()
	var target := -1
	for id in g.park.lot_buses():
		if bool(g.park.blocker(id)["blocked"]):
			if int(g.park.bus(id)["color"]) == front:
				target = id
				break
			if target < 0:
				target = id
	if target < 0:
		return
	_say("Boxed in? Call the Crane!", 2.4)
	await _wait(0.5)
	await _tap_at(g.booster_buttons["crane"].get_global_rect().get_center())
	g.use_booster("crane")
	await _wait(0.7)
	await _tap_at(_bus_point(g, target))
	g.tap_bus(target)
	await _wait(1.6)


func _end_card() -> void:
	var vp := _vp()
	var card := Control.new()
	card.size = vp
	card.modulate.a = 0.0
	overlay.add_child(card)
	var bg := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color("5FA8EA"))
	grad.gradient.set_color(1, Color("CFE6F7"))
	grad.fill_to = Vector2(0, 1)
	bg.texture = grad
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = vp
	card.add_child(bg)
	var logo := _art("logo_micro_jam.png", Vector2(vp.x * 0.86, 560))
	logo.position = Vector2((vp.x - logo.size.x) * 0.5, vp.y * 0.2)
	card.add_child(logo)
	var buses := _art("bus_trio.png", Vector2(vp.x * 0.9, 520))
	buses.position = Vector2((vp.x - buses.size.x) * 0.5, vp.y * 0.47)
	card.add_child(buses)
	var line := Label.new()
	line.text = "Play free today!" if cut == "promo" else "Clear the jam!"
	line.add_theme_font_override("font", TITLE_FONT)
	line.add_theme_font_size_override("font_size", 96)
	line.add_theme_color_override("font_color", Color("FFC300"))
	line.add_theme_color_override("font_outline_color", NAVY)
	line.add_theme_constant_override("outline_size", 26)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.size = Vector2(vp.x, 140)
	line.position = Vector2(0, vp.y * 0.78)
	line.pivot_offset = line.size * 0.5
	card.add_child(line)
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.35)
	tw.tween_property(line, "scale", Vector2.ONE, 0.4).from(Vector2(0.5, 0.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_node("/root/AudioManager").play("level_complete")
	await _wait(2.6 if cut == "appstore" else 3.0)


## Loads a PNG from docs/store/art (not imported, so read from disk).
func _art(file: String, box: Vector2) -> TextureRect:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ART + file))
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = box
	return t


# --- Waits (game time) -------------------------------------------------------

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _wait_level() -> void:
	await _wait(0.3)
	var t := 0.0
	while (SM.is_busy() or not get_tree().current_scene.has_method("is_playing") or not get_tree().current_scene.is_playing()) and t < 12.0:
		await _wait(0.05)
		t += 0.05


func _wait_modal(key: String, limit: float) -> void:
	var t := 0.0
	while SM.find_modal(key) == null and t < limit:
		await _wait(0.1)
		t += 0.1


class TapRing extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t > 0.5:
			queue_free()

	func _draw() -> void:
		var k := clampf(t / 0.5, 0.0, 1.0)
		var a := 1.0 - k
		draw_circle(Vector2.ZERO, 34.0 * (1.0 - k * 0.4), Color(1, 1, 1, 0.55 * a))
		draw_arc(Vector2.ZERO, 40.0 + 70.0 * k, 0, TAU, 48, Color(1, 1, 1, 0.9 * a), 8.0, true)
