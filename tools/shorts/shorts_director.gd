extends Node
## Performs one short video as a scripted take of the real game under Movie
## Maker. The game rules decide everything; the director only taps buses, adds
## the headline, labels, timer, stamps and end card, and hides the game's HUD.
## Formats: pick (only one bus works), cascade (one tap clears every bay),
## mystery (guess the colour), stuck (everything blocked, then the Crane).
##
## Loading and rebuilding scenes shows nothing worth watching, so the director
## logs which frames to keep and make_shorts.py cuts the rest.

const FPS := 60
const NAVY := Color("17213F")
const LOT_LEVEL := 900   # level slot used for hand-built lots (never saved)
const ART := "res://docs/store/art/"
const SEEN := ["tap", "blocked", "bays", "crane", "extra_bay", "shuffle", "twist_sleep", "twist_cones", "twist_covered", "twist_tunnel", "twist_mystery", "twist_padlock", "twist_taxi", "grant_crane", "grant_extra_bay", "grant_shuffle"]

var job: Dictionary = {}
var log_path := ""
var S: Node
var SM: Node
var PM: Node
var g: Node = null
var overlay: CanvasLayer
var band: Control
var head_label: Label
var sub_label: Label
var timer_bar: ColorRect
var tags: Array[Control] = []

var _frame := 0
var _keep: Array = []
var _keep_from := -1
var _rewinding: Array[ImageTexture] = []
var _capturing := false
var _capture_tick := 0


func _process(_delta: float) -> void:
	_frame += 1
	# The game's own tips ("Last bay!") would talk over the headline.
	var toast: Control = get_node("/root/VFXManager")._toast
	if toast:
		toast.visible = false
	if _capturing:
		_capture_tick += 1
		if _capture_tick % 2 == 0:
			var img := get_viewport().get_texture().get_image()
			img.resize(432, 768, Image.INTERPOLATE_BILINEAR)
			_rewinding.append(ImageTexture.create_from_image(img))


func run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	S = get_node("/root/SaveManager")
	SM = get_node("/root/ScreenManager")
	PM = get_node("/root/ProgressionManager")
	S.set_save_path("user://shorts_save.json")
	get_node("/root/GameManager").pause_on_focus_loss = false
	overlay = CanvasLayer.new()
	overlay.layer = 120
	add_child(overlay)
	_build_band()
	match String(job["kind"]):
		"pick":
			await _pick()
		"cascade":
			await _cascade()
		"mystery":
			await _mystery()
		"stuck":
			await _stuck()
	await _end_card()
	_keep_stop()
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"keep": _keep, "fps": FPS, "total": _frame}))
	f.close()


# --- Formats -----------------------------------------------------------------

## One free bay, three numbered buses. The wrong one ends the level, the clip
## rewinds, then the right one saves it.
func _pick() -> void:
	var opts: Array = []
	for o in job["options"]:
		opts.append(int(o))
	var right := int(job["right"])
	var wrong := int(job["wrong"])
	await _open_state(int(job["level"]), job["start"])
	_keep_start()
	_say(job["hook"], job["sub"])
	_number_buses(opts)
	_next_marker()
	await _countdown(2.7)
	_clear_tags()
	_capturing = true
	var wrong_no := opts.find(wrong) + 1
	_say("BUS %d?" % wrong_no, "")
	for id in job["fail_path"]:
		await _wait_free(int(id))
		await _tap(int(id))
		await _wait(0.42)
	await _wait(g.view.time_left() + 0.1)
	g.state = 4   # stops the game's rescue popup: this take rewinds instead
	g.view.khalasi.set_worried(true)
	get_node("/root/AudioManager").play("failure")
	get_node("/root/VFXManager").shake(9.0, 0.25)
	_say("BUS %d LOSES THE LEVEL" % wrong_no, "No bay left for the next passenger")
	await _stamp("OUT OF BAYS!", Color("ff4d5e"), 0.75)
	_capturing = false
	await _rewind()
	_keep_stop()
	await _open_state(int(job["level"]), job["start"])
	_keep_start()
	var right_no := opts.find(right) + 1
	_say("BUS %d WAS THE ONE" % right_no, "")
	_number_buses([right], [right_no])
	await _wait(0.45)
	_clear_tags()
	Engine.time_scale = 1.35
	await _tap(right)
	# Let the right bus fill and leave, and any chain behind it: that's the payoff.
	await _count_departures(int(job.get("right_departs", 1)), g.view.buses.size())
	g.view.set_warning(false)
	Engine.time_scale = 1.0
	await _stamp("SAVED!", Color("ffd84a"), 0.8)


## Parks a bus in every bay on purpose, then one tap makes them all leave.
func _cascade() -> void:
	await _open_level(int(job["level"]))
	_keep_start()
	_say(job["hook"], job["sub"])
	Engine.time_scale = 1.25
	for id in job["path"]:
		await _wait_free(int(id))
		await _tap(int(id))
		await _wait(0.3)
	await _wait(minf(g.view.time_left(), 0.8))
	Engine.time_scale = 1.0
	_say("LAST BAY. ONE TAP.", "Watch all of them")
	var trigger := int(job["trigger"])
	g.view.highlight_bus(trigger, true)
	await _wait(1.0)
	g.view.clear_highlights()
	var before: int = g.view.buses.size()
	await _tap(trigger)
	Engine.time_scale = 1.3
	var total := int(job["departs"])
	await _count_departures(total, before)
	Engine.time_scale = 1.0
	await _stamp("%d BUSES. ONE TAP." % total, Color("ffd84a"), 0.9)


## Waits for `total` buses to leave, counting them on screen with rising horns.
func _count_departures(total: int, before: int) -> void:
	var seen := 0
	var guard := 0.0
	while seen < total and guard < 9.0:
		await _wait(0.05)
		guard += 0.05
		var gone: int = before - g.view.buses.size()
		if gone > seen:
			seen = gone
			if total > 1:
				get_node("/root/AudioManager").horn(1.0 + 0.1 * seen)
				_pop_count("%d" % seen)
	await _wait(0.42 if total > 1 else 0.1)   # the last number clears before the stamp


## A grey bus and a question. The way clears and its colour pops in.
func _mystery() -> void:
	await _open_level(int(job["level"]))
	var pairs: Array = job["pairs"]
	_keep_start()
	_say(job["hook"], job["sub"])
	if pairs.size() == 1:
		await _zoom_to(int(pairs[0]["mystery"]), 1.45, 0.4)
	for i in pairs.size():
		var pair: Dictionary = pairs[i]
		var m := int(pair["mystery"])
		var name_upper := String(GameData.color_name(int(pair["color"]))).to_upper()
		g.view.highlight_bus(m, true)
		_question_tag(m)
		if pairs.size() > 1:
			_say("SECRET BUS %d OF %d" % [i + 1, pairs.size()], "Guess the colour")
		await _countdown(2.4 if pairs.size() == 1 else 1.3)
		g.view.clear_highlights()
		await _tap(int(pair["blocker"]))
		await _wait(0.6)
		_clear_tags()
		_say("IT WAS %s!" % name_upper, "Did you get it?" if pairs.size() == 1 else "")
		await _stamp(name_upper + "!", GameData.bus_color(int(pair["color"])).lightened(0.15), 0.7 if pairs.size() > 1 else 0.9)
	if bool(job.get("wanted", false)):
		var m := int(pairs[0]["mystery"])
		_say("AND THE LINE NEEDED IT", "Go on then")
		await _zoom_out(0.25)
		await _tap(m)
		await _wait(1.5)
		await _stamp("LUCKY!", Color("ffd84a"), 0.7)
	if pairs.size() > 1:
		_say("HOW MANY DID YOU GET?", "Be honest")
		await _wait(1.0)
	await _zoom_out(0.2)


## Every bus blocks another. They bump, then the Crane breaks the loop and the
## rest drive out. `rings` > 1: a second, smaller loop is still stuck after that.
func _stuck() -> void:
	var built := _build_stuck(String(job["layout"]))
	PM._cache[LOT_LEVEL] = built["level"]
	await _open_level(LOT_LEVEL, 130.0, true)
	_keep_start()
	_say(job["hook"], job["sub"])
	for id in built["bump"]:
		await _tap(int(id))
		await _wait(0.28)
	await _wait(0.1)
	_say("NO BUS CAN MOVE", "So now what?")
	await _countdown(1.3)
	var rounds: Array = built["rounds"]
	for r in rounds.size():
		var round_data: Dictionary = rounds[r]
		_say(("CALL THE CRANE" if r == 0 else "STILL STUCK?! CRANE AGAIN"), "")
		var btn: Control = g.booster_buttons["crane"]
		await _ring_at(btn.get_global_rect().get_center())
		g.use_booster("crane", true)
		await _wait(0.45)
		var lift := int(round_data["lift"])
		await _tap(lift)
		await _wait(1.25)
		_say("ONE LIFT FREES THEM" if r == 0 else "THAT DID IT", "")
		var order: Array = round_data["order"]
		Engine.time_scale = 1.6 if order.size() < 8 else 2.2
		for id in order:
			await _wait_free(int(id))
			await _tap(int(id))
			await _wait(0.24 if order.size() < 8 else 0.14)
		if r < rounds.size() - 1:
			await _wait(0.3)
		Engine.time_scale = 1.0
	# The last passengers board fast, then the game's own win moment: confetti and a cheer.
	Engine.time_scale = 2.6
	var t := 0.0
	while g.view.time_left() > 0.15 and t < 5.0:
		await _wait(0.05)
		t += 0.05
	Engine.time_scale = 1.0
	await _wait(1.5)


# --- Hand-built lots ---------------------------------------------------------

## A pinwheel: buses run clockwise round a square, each blocked by the next.
func _pinwheel(o: int, size: int, lens: Array, colors: Array, buses: Array) -> Array:
	# Each side owns its start corner and runs `size - 1` cells.
	var ids: Array = []
	var add := func(x: int, y: int, length: int, dir: int) -> int:
		var id := buses.size()
		buses.append({"id": id, "x": x, "y": y, "len": length, "dir": dir, "color": int(colors[id % colors.size()]), "sleep": false, "state": "lot"})
		ids.append(id)
		return id
	var end := o + size - 1
	var pos := o
	for l in lens:   # top, running right
		add.call(pos, o, int(l), Park.RIGHT)
		pos += int(l)
	pos = o
	for l in lens:   # right, running down
		add.call(end, pos, int(l), Park.DOWN)
		pos += int(l)
	pos = end
	for l in lens:   # bottom, running left
		add.call(pos - int(l) + 1, end, int(l), Park.LEFT)
		pos -= int(l)
	pos = end
	for l in lens:   # left, running up
		add.call(o, pos - int(l) + 1, int(l), Park.UP)
		pos -= int(l)
	return ids


func _build_stuck(layout: String) -> Dictionary:
	var buses: Array = []
	var w := 6
	var h := 6
	var shape := "round"
	var lifts: Array = []
	var bump: Array = []
	var palette := [0, 1, 2, 3, 4, 5, 6, 7]
	match layout:
		"small":
			var ring := _pinwheel(1, 4, [3], [0, 1, 2, 3], buses)
			buses.append({"id": buses.size(), "x": 2, "y": 2, "len": 2, "dir": Park.UP, "color": 7, "sleep": false, "state": "lot"})
			buses.append({"id": buses.size(), "x": 3, "y": 2, "len": 2, "dir": Park.DOWN, "color": 6, "sleep": false, "state": "lot"})
			lifts = [ring[1]]
			bump = ring
		"big":
			w = 9
			h = 9
			var ring := _pinwheel(1, 7, [3, 3], [0, 1, 2, 3, 4, 5, 6, 7], buses)
			var inner := [[3, 3, 2, Park.UP, 5], [5, 3, 2, Park.UP, 2], [4, 3, 1, Park.UP, 7], [4, 4, 1, Park.UP, 0], [3, 5, 1, Park.LEFT, 6], [4, 5, 1, Park.DOWN, 1], [5, 5, 1, Park.RIGHT, 3]]
			for it in inner:
				buses.append({"id": buses.size(), "x": it[0], "y": it[1], "len": it[2], "dir": it[3], "color": it[4], "sleep": false, "state": "lot"})
			lifts = [ring[2]]
			bump = [ring[1], ring[3], ring[5], ring[7]]
		"double":
			w = 10
			h = 10
			shape = "rect"
			var outer := _pinwheel(0, 10, [3, 3, 3], palette, buses)
			var inner_ring := _pinwheel(2, 6, [3, 2], [6, 7, 0, 1, 2, 3, 4, 5], buses)
			buses.append({"id": buses.size(), "x": 4, "y": 4, "len": 1, "dir": Park.UP, "color": 2, "sleep": false, "state": "lot"})
			buses.append({"id": buses.size(), "x": 5, "y": 4, "len": 1, "dir": Park.RIGHT, "color": 5, "sleep": false, "state": "lot"})
			buses.append({"id": buses.size(), "x": 4, "y": 5, "len": 1, "dir": Park.LEFT, "color": 0, "sleep": false, "state": "lot"})
			buses.append({"id": buses.size(), "x": 5, "y": 5, "len": 1, "dir": Park.DOWN, "color": 3, "sleep": false, "state": "lot"})
			lifts = [outer[3], inner_ring[2]]
			bump = [outer[2], outer[5], outer[8]]
	var base := {
		"level": LOT_LEVEL, "tier": "normal", "w": w, "h": h, "bay_count": 5, "buses": buses, "queue": [], "covered": [], "cones": [],
		"cone_clear": 3, "tunnel": {}, "shape": shape, "holes": LotShape.holes(w, h, shape), "twists": [], "solution": [],
	}
	# Work out the exit order with the real rules, then line passengers up to match.
	var sim := Park.from_level(base)
	assert(sim.exitable().is_empty(), "stuck lot %s has a bus that can move" % layout)
	var rounds: Array = []
	var all_order: Array = []
	for lift in lifts:
		sim.buses[int(lift)]["state"] = "gone"
		sim._rebuild_grid()
		var order: Array = sim.feasible_exit_order()
		for id in order:
			sim.buses[int(id)]["state"] = "gone"
		sim._rebuild_grid()
		rounds.append({"lift": lift, "order": order})
		all_order.append(lift)
		all_order.append_array(order)
	assert(sim.lot_buses().is_empty(), "stuck lot %s can't be cleared" % layout)
	var queue: Array = []
	for id in all_order:
		for i in Park.capacity_for(int(buses[int(id)]["len"])):
			queue.append(int(buses[int(id)]["color"]))
	base["queue"] = queue
	base["solution"] = all_order
	return {"level": base, "rounds": rounds, "bump": bump}


# --- Game control ------------------------------------------------------------

func _fresh(level: int) -> void:
	S.data = S.defaults()
	S.data["coins"] = 1240
	S.data["current_level"] = level
	S.data["game"]["route_seen_level"] = level
	S.data["game"]["boosters"] = {"crane": 3, "extra_bay": 2, "shuffle": 4}
	S.data["settings"]["hints"] = false
	S.data["selected_items"]["theme"] = String(job.get("theme", "theme_morning"))
	if not (S.data["unlocked_items"] as Array).has(S.data["selected_items"]["theme"]):
		S.data["unlocked_items"].append(S.data["selected_items"]["theme"])
	var steps := {}
	for k in SEEN:
		steps[k] = true
	S.data["game"]["tutorial_steps"] = steps
	for e in S.data["game"]["achievements"].values():
		e["claimed"] = true


## Opens a level at its start. `bottom`: space to leave under the lot (Shorts
## apps cover the bottom of the screen with captions and buttons).
func _open_level(level: int, bottom: float = 30.0, boosters: bool = false) -> void:
	_fresh(level)
	await _open_scene(bottom, boosters)


func _open_state(level: int, state: Dictionary) -> void:
	_fresh(level)
	S.data["game"]["in_progress_level"] = {"level": level, "date": "", "park": state, "moves": 0,
		"boosters_used": false, "used_crane": false, "extra_used": false, "revive_used": false}
	await _open_scene(30.0, false)


func _open_scene(bottom: float, boosters: bool) -> void:
	# Room for the headline up top, and the app's captions at the bottom.
	get_node("/root/GameManager").debug_safe_insets = Vector2(124.0, bottom)
	Engine.time_scale = 1.0
	SM.close_all_modals()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	g = get_tree().current_scene
	var t := 0.0
	while (g == null or not g.is_playing()) and t < 8.0:
		await _wait(0.05)
		t += 0.05
		g = get_tree().current_scene
	# Game HUD off: the clip has its own headline.
	g.pause_button.get_parent().visible = false
	(g.booster_buttons["crane"] as Control).get_parent().visible = boosters
	g.crane_banner.position.y = 5000.0
	await _wait(1.0)   # the buses finish landing (cut from the video)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _wait_free(id: int) -> void:
	var t := 0.0
	while (g.view.is_bus_busy(id) or not g.is_playing()) and t < 3.0:
		await _wait(0.03)
		t += 0.03
		if g.state != 1:
			return


func _point(id: int) -> Vector2:
	var bv: BusVisual = g.view.bus_visual(id)
	var local: Vector2 = bv.position if bv else g.view.lot_center(id)
	return g.view.get_global_transform_with_canvas() * local


func _tap(id: int) -> void:
	await _ring_at(_point(id))
	g.tap_bus(id)


func _ring_at(p: Vector2) -> void:
	var ring := TapRing.new()
	ring.position = p
	overlay.add_child(ring)
	await _wait(0.1)


func _zoom_to(id: int, zoom: float, dur: float) -> void:
	var cam: Camera2D = g.camera
	var vp := get_viewport().get_visible_rect().size
	var c: Vector2 = _point(id)
	var to := (c - vp * 0.5 / zoom)
	to.x = clampf(to.x, 0.0, vp.x - vp.x / zoom)
	to.y = clampf(to.y, 120.0, vp.y - vp.y / zoom)
	var tw := cam.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cam, "zoom", Vector2(zoom, zoom), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "position", to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait(dur)


func _zoom_out(dur: float) -> void:
	var cam: Camera2D = g.camera
	var tw := cam.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cam, "zoom", Vector2.ONE, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "position", Vector2.ZERO, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait(dur)


func _keep_start() -> void:
	_keep_from = _frame


func _keep_stop() -> void:
	if _keep_from >= 0:
		_keep.append([_keep_from, _frame])
	_keep_from = -1


# --- Overlay -----------------------------------------------------------------

func _build_band() -> void:
	band = Control.new()
	band.size = Vector2(1000, 118)
	band.position = Vector2(40, 96)
	band.pivot_offset = band.size * 0.5
	band.visible = false
	band.draw.connect(func() -> void:
		DrawKit.glossy_rrect(band, Rect2(Vector2.ZERO, band.size), 44, Color("ffcf3a"), Color("d98200"), 0.0, 6.0, 12.0, true))
	overlay.add_child(band)
	head_label = UIKit.title("", 70, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	head_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	head_label.offset_bottom = -12
	head_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(head_label)
	sub_label = UIKit.title("", 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	sub_label.position = Vector2(40, 218)
	sub_label.size = Vector2(1000, 54)
	overlay.add_child(sub_label)
	timer_bar = ColorRect.new()
	timer_bar.color = Color("ff4d5e")
	timer_bar.position = Vector2(140, 270)
	timer_bar.size = Vector2(800, 12)
	timer_bar.visible = false
	overlay.add_child(timer_bar)


func _say(head: String, sub: String) -> void:
	head_label.text = head
	var fs := 72
	var font: Font = head_label.get_theme_font("font")
	while fs > 40 and font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 930.0:
		fs -= 2
	head_label.add_theme_font_size_override("font_size", fs)
	sub_label.text = sub
	band.visible = true
	var tw := band.create_tween()
	tw.tween_property(band, "scale", Vector2.ONE, 0.2).from(Vector2(0.86, 0.86)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A draining bar and a tick each beat: time to guess.
func _countdown(sec: float) -> void:
	timer_bar.visible = true
	timer_bar.size.x = 800.0
	timer_bar.position.x = 140.0
	var tw := timer_bar.create_tween()
	tw.tween_property(timer_bar, "size:x", 0.0, sec)
	tw.parallel().tween_property(timer_bar, "position:x", 540.0, sec)
	var ticks := int(round(sec / 0.6))
	for i in ticks:
		get_node("/root/AudioManager").play("select", 1.0 + 0.04 * i)
		await _wait(sec / float(ticks))
	timer_bar.visible = false


func _stamp(text: String, col: Color, hold: float) -> void:
	var l: Label = UIKit.title(text, 120, col, HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	var fs := 120
	var font: Font = l.get_theme_font("font")
	while fs > 60 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 960.0:
		fs -= 4
	l.add_theme_font_size_override("font_size", fs)
	l.size = Vector2(1080, 180)
	l.position = Vector2(0, 840)
	l.pivot_offset = l.size * 0.5
	overlay.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.24).from(Vector2(0.3, 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(hold)
	l.queue_free()


## A quick count for each bus that leaves in a chain.
func _pop_count(text: String) -> void:
	var l: Label = UIKit.title(text, 170, Color("ffd84a"), HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	l.size = Vector2(1080, 220)
	l.position = Vector2(0, 930)
	l.pivot_offset = l.size * 0.5
	overlay.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).from(Vector2(0.4, 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.22)
	tw.tween_property(l, "modulate:a", 0.0, 0.14)
	tw.tween_callback(l.queue_free)


func _number_buses(ids: Array, numbers: Array = []) -> void:
	_clear_tags()
	for i in ids.size():
		var tag := Control.new()
		tag.size = Vector2(92, 92)
		var short_bus: bool = int(g.park.bus(int(ids[i]))["len"]) == 1
		tag.position = _point(int(ids[i])) - tag.size * 0.5 - Vector2(0, 66 if short_bus else 34)
		tag.pivot_offset = tag.size * 0.5
		tag.draw.connect(func() -> void:
			DrawKit.glossy_circle(tag, tag.size * 0.5, 44.0, Color("ffcf3a"), Color("c26a00"), 5.0, 6.0))
		var n := UIKit.title(str(int(numbers[i]) if not numbers.is_empty() else i + 1), 58, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, NAVY)
		n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		n.offset_bottom = -6
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_child(n)
		overlay.add_child(tag)
		tags.append(tag)
		var tw := tag.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(tag, "scale", Vector2.ONE, 0.22).from(Vector2.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tag.scale = Vector2.ZERO


## A bouncing "?" above the secret bus.
func _question_tag(id: int) -> void:
	var tag := Control.new()
	tag.size = Vector2(100, 100)
	tag.position = _point(id) - Vector2(50, 150)
	tag.pivot_offset = tag.size * 0.5
	tag.draw.connect(func() -> void:
		DrawKit.glossy_circle(tag, tag.size * 0.5, 48.0, Color("ffcf3a"), Color("c26a00"), 5.0, 6.0))
	var n: Label = UIKit.title("?", 66, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	n.offset_bottom = -6
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(n)
	overlay.add_child(tag)
	tags.append(tag)
	var tw := tag.create_tween().set_loops()
	tw.tween_property(tag, "position:y", tag.position.y + 22.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tag, "position:y", tag.position.y, 0.3).set_trans(Tween.TRANS_SINE)


## "NEXT" over the first passenger: the colour rule, without explaining it.
func _next_marker() -> void:
	if g.view.queue_nodes.is_empty():
		return
	var pv: Node2D = g.view.queue_nodes[0]
	var l: Label = UIKit.title("NEXT", 34, Color("ffd84a"), HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	l.size = Vector2(140, 44)
	l.position = g.view.get_global_transform_with_canvas() * pv.position - Vector2(70, 128)
	overlay.add_child(l)
	tags.append(l)


func _clear_tags() -> void:
	for t in tags:
		if is_instance_valid(t):
			t.queue_free()
	tags.clear()


## Plays the frames captured since the wrong tap backwards, fast.
func _rewind() -> void:
	var rect := TextureRect.new()
	rect.size = Vector2(1080, 1920)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.modulate = Color(0.78, 0.86, 1.0)
	overlay.add_child(rect)
	var label: Label = UIKit.title("REWIND", 110, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	label.size = Vector2(1080, 170)
	label.position = Vector2(0, 860)
	overlay.add_child(label)
	band.visible = false
	sub_label.text = ""
	get_node("/root/AudioManager").play("wipe", 0.7)
	var frames := _rewinding.size()
	var show_frames := 42
	for i in show_frames:
		var k := clampi(frames - 1 - int(float(i) / float(show_frames) * float(frames)), 0, frames - 1)
		rect.texture = _rewinding[k]
		await get_tree().process_frame
	rect.queue_free()
	label.queue_free()
	_rewinding.clear()


func _end_card() -> void:
	Engine.time_scale = 1.0
	var card := Control.new()
	card.size = Vector2(1080, 1920)
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
	bg.size = card.size
	card.add_child(bg)
	card.add_child(_art("logo_micro_jam.png", Vector2(930, 520), 300))
	card.add_child(_art("bus_trio.png", Vector2(960, 470), 810))
	var line: Label = UIKit.title("FREE TO PLAY", 92, Color("ffd84a"), HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	line.size = Vector2(1080, 130)
	line.position = Vector2(0, 1290)
	card.add_child(line)
	var search: Label = UIKit.title("Search MICRO JAM", 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, NAVY)
	search.size = Vector2(1080, 80)
	search.position = Vector2(0, 1420)
	card.add_child(search)
	band.visible = false
	sub_label.text = ""
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	await _wait(1.4)


func _art(file: String, box: Vector2, y: float) -> TextureRect:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ART + file))
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = box
	t.position = Vector2((1080.0 - box.x) * 0.5, y)
	return t


class TapRing extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t > 0.45:
			queue_free()

	func _draw() -> void:
		var k := clampf(t / 0.45, 0.0, 1.0)
		var a := 1.0 - k
		draw_circle(Vector2.ZERO, 36.0 * (1.0 - k * 0.4), Color(1, 1, 1, 0.6 * a))
		draw_arc(Vector2.ZERO, 42.0 + 70.0 * k, 0, TAU, 48, Color(1, 1, 1, 0.95 * a), 9.0, true)
