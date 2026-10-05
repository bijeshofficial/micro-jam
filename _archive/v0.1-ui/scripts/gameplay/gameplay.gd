class_name Gameplay
extends Node2D
## One level: tap buses to drive them out to the loading bays.
## Owns the Park (rules), the ParkView (visuals + animation), the HUD,
## boosters, the in-progress save, idle hints, lives and the win / fail flow.

enum State { INTRO, PLAYING, FAILING, WON, FAILED }

const ParkViewScript := preload("res://scripts/gameplay/park_view.gd")
const WinPanelScript := preload("res://scripts/ui/win_panel.gd")
const SAVE_DELAY := 0.4

var level := 1
var level_data: Dictionary = {}
var park: Park
var view: ParkView
var moves := 0
var boosters_used := false
var used_crane := false
var extra_used := false
var revive_used := false
var crane_mode := false
var state := State.INTRO
var resumed := false
var tutorial: TutorialDirector
var booster_buttons: Dictionary = {}
var hud: CanvasLayer
var backdrop: ParkBackdrop
var level_label: Label
var pause_button: GameButton
var restart_button: GameButton
var camera: Camera2D
var crane_banner: PanelContainer

var _save_timer := -1.0
var _idle := 0.0
var _hint_shown := false
var _hint_task := -1
var _hint_mutex := Mutex.new()
var _hint_result := -1
var _pending_booster := ""
var _crane_free := false
var _summary: Dictionary = {}
var _new_achievement := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	VFXManager.toast_anchor = "bottom"
	AudioManager.set_ambient("park")
	_rng.randomize()
	level = ProgressionManager.current_level()
	level_data = ProgressionManager.get_level(level)
	var vp := get_viewport_rect().size
	var insets := GameManager.get_safe_insets()

	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()
	VFXManager.register_camera(camera)

	var top := insets.x + 176.0
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	backdrop = ParkBackdrop.new()
	backdrop.theme_id = ProgressionManager.selected_cosmetic("theme")
	backdrop.horizon = (top + 2.0) / vp.y
	backdrop.weather = false
	backdrop.town = false
	backdrop.bunting = false
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(backdrop)

	if not _try_resume():
		park = Park.from_level(level_data)
	view = ParkViewScript.new()
	add_child(view)
	view.build(park, {"width": vp.x, "top": top, "bottom": vp.y - insets.y - 300.0}, level)
	view.timeline_done.connect(_on_timeline_done)

	# Rain or snow over the park, below the HUD.
	var kind := String(ParkTheme.get_theme(backdrop.theme_id)["weather"])
	if kind == "rain" or kind == "snow":
		var wx := CanvasLayer.new()
		wx.layer = 5
		add_child(wx)
		var wfx := WeatherFX.new()
		wfx.kind = kind
		wfx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wx.add_child(wfx)

	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_build_top_bar(insets)
	_build_booster_bar(vp, insets)
	_build_crane_banner(vp)

	tutorial = TutorialDirector.new()
	add_child(tutorial)
	tutorial.setup(self, hud, level_data, moves)

	GameManager.app_paused.connect(_on_app_paused)
	ProgressionManager.prefetch(level + 1)
	AdManager.banner_opportunity("gameplay")
	view.play_intro()
	_after(view.intro_time(), _on_intro_done)


func _on_intro_done() -> void:
	if state != State.INTRO:
		return
	state = State.PLAYING
	var twists: Array = level_data.get("twists", [])
	_show_twist_cards(twists.duplicate(), _on_cards_done)


func _on_cards_done() -> void:
	tutorial.start()
	if resumed:
		VFXManager.toast("Welcome back! The buses waited for you.")
	if park.is_failed():
		_fail()
	elif park.is_warning():
		view.set_warning(true)


func _show_twist_cards(list: Array, done: Callable) -> void:
	while not list.is_empty() and ProgressionManager.tutorial_done("twist_" + String(list[0])):
		list.pop_front()
	if list.is_empty():
		done.call()
		return
	var id: String = list.pop_front()
	TutorialDirector.twist_card(id, func() -> void:
		ProgressionManager.mark_tutorial("twist_" + id)
		_show_twist_cards(list, done))


# --- HUD ---------------------------------------------------------------------

func _build_top_bar(insets: Vector2) -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(30, insets.x + 22)
	bar.size = Vector2(get_viewport_rect().size.x - 60, 140)
	bar.add_theme_constant_override("separation", 20)
	hud.add_child(bar)
	pause_button = UIKit.button("", "secondary", "pause", 54, Vector2(130, 130))
	pause_button.pressed.connect(open_pause)
	bar.add_child(pause_button)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 2)
	bar.add_child(mid)
	level_label = UIKit.title("Level %d" % level, 74)
	mid.add_child(level_label)
	var badge := UIKit.tier_badge(String(level_data.get("tier", "normal")), 30)
	if badge:
		var holder := CenterContainer.new()
		holder.add_child(badge)
		mid.add_child(holder)
	restart_button = UIKit.button("", "secondary", "retry", 54, Vector2(130, 130))
	restart_button.pressed.connect(func() -> void: leave_level("restart"))
	bar.add_child(restart_button)


func _build_booster_bar(vp: Vector2, insets: Vector2) -> void:
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = Vector2(0, vp.y - insets.y - 300)
	strip.size = Vector2(vp.x, 300 + insets.y)
	strip.draw.connect(func() -> void:
		var tray := Rect2(30, 34, strip.size.x - 60, 256)
		strip.draw_colored_polygon(DrawKit.rounded_rect(tray.grow(6), 76, 8), Color(0.08, 0.1, 0.24, 0.35))
		DrawKit.gradient_fill(strip, DrawKit.rounded_rect(tray, 70, 8), Color("2d4f9e"), Color("1c2f66"))
		DrawKit.outline(strip, DrawKit.rounded_rect(tray.grow(-6), 64, 8), Color(1, 1, 1, 0.2), 3.0))
	hud.add_child(strip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 56)
	row.position = Vector2(0, vp.y - insets.y - 284)
	row.size = Vector2(vp.x, 260)
	hud.add_child(row)
	for id in BoosterManager.IDS:
		var b := BoosterButton.new()
		b.setup(id)
		b.pressed.connect(use_booster.bind(id, false))
		row.add_child(b)
		booster_buttons[id] = b


func _build_crane_banner(vp: Vector2) -> void:
	crane_banner = PanelContainer.new()
	var sb := UIKit.card_box(Color("fff4c2"), 22, UIKit.GOLD)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	crane_banner.add_theme_stylebox_override("panel", sb)
	crane_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	crane_banner.add_child(row)
	row.add_child(UIKit.icon("crane", 64, UIKit.INK))
	row.add_child(UIKit.label("Tap any bus to lift it out", 42, UIKit.INK))
	crane_banner.visible = false
	hud.add_child(crane_banner)
	crane_banner.position = Vector2(80, vp.y - GameManager.get_safe_insets().y - 420)


## Tutorial text sits just above the booster bar.
func hint_text_y() -> float:
	return get_viewport_rect().size.y - GameManager.get_safe_insets().y - 430.0


func is_playing() -> bool:
	return state == State.PLAYING and not ScreenManager.has_modal() and not AdManager.is_showing() and not ScreenManager.is_busy()


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var p: Vector2 = get_canvas_transform().affine_inverse() * event.position
		handle_tap(view.to_local(p))


## View-space tap (tests call this too).
func handle_tap(p: Vector2) -> void:
	if not is_playing():
		return
	var id := view.bus_at(p)
	if id >= 0:
		tap_bus(id)


func tap_bus(id: int) -> void:
	if not is_playing() or id < 0 or id >= park.buses.size() or view.is_bus_busy(id):
		return
	if park.bus(id)["state"] != "lot":
		return
	_idle = 0.0
	_clear_hint()
	if not tutorial.allows_tap(id):
		return
	if crane_mode:
		_crane_lift(id)
		return
	var events := park.tap(id)
	if events.is_empty():
		return
	var kind := String(events[0]["type"])
	if kind == "exit" or kind == "wake":
		moves += 1
	_after_events(events)
	tutorial.on_tap(id, events)


## Plays events, updates stats, the warning and the win/fail status.
func _after_events(events: Array) -> void:
	view.play(events)
	var boarded := 0
	for e in events:
		match String(e["type"]):
			"board":
				boarded += 1
			"depart":
				SaveManager.add_game_stat("buses_sent")
			"won":
				_win()
			"failed":
				_fail()
	if boarded > 0:
		SaveManager.add_game_stat("passengers_boarded", boarded)
	if state == State.PLAYING:
		var warn := park.is_warning()
		if warn and view.warning < 0.01:
			_after(view.time_left(), _announce_warning)
		view.set_warning(warn)
	_queue_save()


func _announce_warning() -> void:
	if state == State.PLAYING and park.is_warning():
		AudioManager.play("warning")
		HapticsManager.medium()
		VFXManager.toast("Last bay! Pick your next bus carefully.")


# --- Boosters ----------------------------------------------------------------

## Uses a booster. `free` skips the inventory (rescue on early levels / ad).
func use_booster(id: String, free: bool = false) -> bool:
	if state != State.PLAYING and state != State.FAILING:
		return false
	if AdManager.is_showing() or ScreenManager.is_busy():
		return false
	if tutorial.blocks_boosters():
		VFXManager.toast("Follow the hand first!")
		return false
	match id:
		"crane":
			if crane_mode:
				_set_crane_mode(false)
				return false
			if park.free_bay() < 0:
				VFXManager.toast("No free bay for the crane")
				return false
		"extra_bay":
			if extra_used:
				VFXManager.toast("Only one extra bay per level")
				return false
		"shuffle":
			if park.waiting_count() < 2:
				VFXManager.toast("Nobody left to shuffle")
				return false
	if not free and BoosterManager.count(id) <= 0:
		Popups.buy_booster(id, use_booster.bind(id, false))
		return false
	if id == "crane":
		_set_crane_mode(true, free)
		return true
	if not view.idle():
		# Let the buses settle first; the booster fires right after.
		_pending_booster = id + (":free" if free else "")
		return true
	return _apply_booster(id, free)


func _apply_booster(id: String, free: bool) -> bool:
	if free:
		SaveManager.add_game_stat("boosters_used")
	elif not BoosterManager.consume(id):
		return false
	boosters_used = true
	_idle = 0.0
	_clear_hint()
	match id:
		"extra_bay":
			extra_used = true
			park.add_bay()
			view.add_bay_visual()
			HapticsManager.medium()
			VFXManager.toast("Bay %d is open!" % park.bays.size())
		"shuffle":
			if not park.shuffle_queue(_rng):
				if not free:
					BoosterManager.grant(id, 1)
				VFXManager.toast("Couldn't shuffle. Booster refunded.")
				return false
			view.shuffle_queue_visual()
			view.queue_t = view.clock + 0.4
			HapticsManager.medium()
	if state == State.FAILING:
		state = State.PLAYING
		view.khalasi.set_worried(false)
	tutorial.on_booster(id)
	_after_events(park.resolve())
	return true


func _on_timeline_done() -> void:
	if _pending_booster == "":
		return
	var parts := _pending_booster.split(":")
	_pending_booster = ""
	if state == State.PLAYING or state == State.FAILING:
		_apply_booster(parts[0], parts.size() > 1)


func _set_crane_mode(on: bool, free: bool = false) -> void:
	crane_mode = on
	_crane_free = free
	if crane_banner == null:
		return
	crane_banner.visible = on
	if on:
		UIKit.pop_in(crane_banner)
		booster_buttons["crane"].start_pulse()
		for bid in park.lot_buses():
			view.highlight_bus(bid, true)
		AudioManager.play("select")
	else:
		booster_buttons["crane"].stop_pulse()
		view.clear_highlights()


func _crane_lift(id: int) -> void:
	var free := _crane_free
	_set_crane_mode(false)
	if park.free_bay() < 0:
		VFXManager.toast("No free bay for the crane")
		return
	if free:
		SaveManager.add_game_stat("boosters_used")
	elif not BoosterManager.consume("crane"):
		return
	boosters_used = true
	used_crane = true
	SaveManager.add_game_stat("cranes_used")
	moves += 1
	if state == State.FAILING:
		state = State.PLAYING
	tutorial.on_booster("crane")
	_after_events(park.crane(id))


# --- Fail / rescue / leaving -------------------------------------------------

func free_fixes() -> bool:
	return not LivesManager.level_costs_life(level)


func _fail() -> void:
	if state == State.WON or state == State.FAILED:
		return
	state = State.FAILING
	_set_crane_mode(false)
	_after(view.time_left() + 0.35, show_out_of_bays)


func show_out_of_bays() -> void:
	if state != State.FAILING or ScreenManager.find_modal("out_of_bays") or ScreenManager.find_modal("pause"):
		return
	AudioManager.play("failure")
	HapticsManager.heavy()
	view.khalasi.set_worried(true)
	var free := free_fixes()
	var tag := func(id: String) -> String:
		return "free" if free else (str(BoosterManager.count(id)) if BoosterManager.count(id) > 0 else "+")
	var buttons: Array = [
		{"id": "extra_bay", "text": "Extra Bay", "icon": "bay_plus", "kind": "secondary", "badge": tag.call("extra_bay"), "disabled": extra_used, "cb": use_booster.bind("extra_bay", free)},
		{"id": "shuffle", "text": "Shuffle Queue", "icon": "shuffle", "kind": "secondary", "badge": tag.call("shuffle"), "cb": use_booster.bind("shuffle", free)},
	]
	if not revive_used and not free:
		buttons.append({"id": "revive", "text": "Free rescue  (Watch ad)", "icon": "ad", "kind": "purple", "cb": _revive})
	buttons.append({"id": "give_up", "text": "Give up  (-1 life)" if not free else "Start over", "kind": "danger", "cb": give_up})
	Popups.show({
		"id": "out_of_bays",
		"title": "Out of bays!",
		"art": "bay_plus",
		"art_color": UIKit.DANGER,
		"body": "Every bay is taken and the next passenger fits none of them. A booster can save the day." if not free else "Every bay is taken. Here's a free fix!",
		"vertical": true,
		"buttons": buttons,
		"on_back": func() -> void: pass,
	})


## Rewarded revive (once per level): a free Extra Bay, or a free Shuffle
## Queue if the extra bay is already open.
func _revive() -> void:
	AdManager.show_rewarded_revive(_on_revive_ad)


func _on_revive_ad(ok: bool) -> void:
	if not ok:
		VFXManager.toast("Ad not available right now")
		_after(0.3, show_out_of_bays)
		return
	revive_used = true
	use_booster("shuffle" if extra_used else "extra_bay", true)


func give_up() -> void:
	if state == State.WON or state == State.FAILED:
		return
	state = State.FAILED
	var cost := LivesManager.level_costs_life(level)
	if cost:
		LivesManager.lose_life()
	SaveManager.add_game_stat("levels_failed")
	_clear_progress()
	AudioManager.play("failure")
	HapticsManager.heavy()
	AdManager.on_run_finished()
	Popups.show({
		"id": "failed",
		"title": "Level failed",
		"art": "heart",
		"art_color": UIKit.HEART,
		"body": ("You lost a life. %d left." % LivesManager.lives()) if cost else "No lives lost on the early levels. Try again!",
		"buttons": [
			{"id": "home", "text": "Home", "kind": "neutral", "icon": "home", "cb": _go_home},
			{"id": "retry", "text": "Retry", "kind": "primary", "icon": "retry", "cb": retry},
		],
		"on_back": _go_home,
	})


func retry() -> void:
	if not LivesManager.can_play(level):
		Popups.lives(true, retry)
		return
	ScreenManager.change_screen(ScreenManager.GAMEPLAY, level)


## Restart or Home. After at least one move this costs a life (levels 9+).
func leave_level(to: String) -> void:
	if state == State.WON or state == State.FAILED:
		return
	if moves > 0 and LivesManager.level_costs_life(level):
		Popups.confirm("Leave level?" if to == "home" else "Restart level?", "Leaving will cost 1 life.", "Leave" if to == "home" else "Restart", _leave_now.bind(to, true), "danger")
	elif to == "restart":
		Popups.confirm("Restart level?", "Start this level again from the beginning?", "Restart", _leave_now.bind(to, false), "danger")
	else:
		_leave_now(to, false)


func _leave_now(to: String, costs_life: bool) -> void:
	if state == State.WON or state == State.FAILED:
		return
	state = State.FAILED
	if costs_life:
		LivesManager.lose_life()
		AdManager.on_run_finished()
	_clear_progress()
	if to == "restart":
		retry()
	else:
		ScreenManager.go_hub("home")


func open_pause() -> void:
	if state == State.WON or state == State.FAILED:
		return
	if ScreenManager.find_modal("pause"):
		return
	_set_crane_mode(false)
	var oob := ScreenManager.find_modal("out_of_bays")
	if oob:
		ScreenManager.close_modal(oob)
	get_tree().paused = true
	var p := Popups.show({
		"id": "pause",
		"title": "Paused",
		"vertical": true,
		"buttons": [
			{"id": "resume", "text": "Resume", "kind": "primary", "icon": "play"},
			{"id": "restart", "text": "Restart", "kind": "neutral", "icon": "retry", "cb": leave_level.bind("restart")},
			{"id": "home", "text": "Home", "kind": "neutral", "icon": "home", "cb": leave_level.bind("home")},
			{"id": "settings", "text": "Settings", "kind": "neutral", "icon": "gear", "close": false, "cb": _open_settings},
		],
	})
	p.tree_exited.connect(_on_pause_closed)


func _open_settings() -> void:
	ScreenManager.push_modal(load("res://scenes/ui/settings.tscn").instantiate())


func _on_pause_closed() -> void:
	if is_inside_tree() and ScreenManager.find_modal("pause") == null:
		get_tree().paused = false
		if state == State.FAILING:
			_after(0.1, show_out_of_bays)


func on_back() -> void:
	if crane_mode:
		_set_crane_mode(false)
		return
	if state == State.PLAYING or state == State.INTRO or state == State.FAILING:
		open_pause()


func _on_app_paused() -> void:
	_save_progress()
	if (state == State.PLAYING or state == State.FAILING) and ScreenManager.find_modal("pause") == null and not AdManager.is_showing():
		open_pause()


# --- Win ---------------------------------------------------------------------

func _win() -> void:
	state = State.WON
	_set_crane_mode(false)
	_clear_hint()
	var claimable_before := AchievementManager.claimable_count()
	var full_house := park.max_bays_used >= Park.DEFAULT_BAYS
	_summary = ProgressionManager.complete_level(level, boosters_used, used_crane, full_house)
	AchievementManager.refresh()
	_new_achievement = AchievementManager.claimable_count() > claimable_before
	AdManager.on_run_finished()
	tutorial.on_win()
	_after(view.time_left() + 0.5, _celebrate)


func _celebrate() -> void:
	var t := view.celebrate()
	var vp := get_viewport_rect().size
	VFXManager.confetti(hud, vp.x)
	VFXManager.shake(9.0, 0.25)
	AudioManager.play("level_complete")
	AudioManager.horn()
	HapticsManager.heavy()
	var cheers: Array = GameData.meta().get("cheers", ["JAM CLEAR!"])
	VFXManager.popup_text(hud, String(cheers[level % cheers.size()]), Vector2(vp.x * 0.5, vp.y * 0.45), UIKit.GOLD, 120, 80, 1.3)
	_after(maxf(t, 1.3), _show_win_panel)


func _show_win_panel() -> void:
	var panel: WinPanel = WinPanelScript.new()
	panel.setup(level, _summary)
	panel.continue_pressed.connect(continue_next)
	panel.home_pressed.connect(_go_home)
	ScreenManager.push_modal(panel)
	if _new_achievement:
		VFXManager.toast("Achievement unlocked! Claim it in your Profile.")
	if _summary.get("milestone", false):
		_after(1.3, _milestone_gift)


func _go_home() -> void:
	ScreenManager.go_hub("home")


func _milestone_gift() -> void:
	Popups.show({
		"id": "gift",
		"title": "Depot gift!",
		"art": "gift",
		"art_color": UIKit.PINK,
		"body": "Every 10 levels the depot sends you a present.",
		"buttons": [{"id": "open", "text": "Open", "kind": "primary", "icon": "gift", "cb": _open_gift}],
	})


func _open_gift() -> void:
	var g := ProgressionManager.claim_milestone(level)
	if not g.is_empty():
		Popups.reward("Depot gift", "+%d coins\n+1 %s" % [int(g["coins"]), BoosterManager.display_name(g["booster"])], "gift")


func continue_next() -> void:
	var next := ProgressionManager.current_level()
	if not LivesManager.can_play(next):
		Popups.lives(true, continue_next)
		return
	if level > LivesManager.free_levels() and AdManager.can_show_interstitial():
		AdManager.show_interstitial(ScreenManager.start_level)
	else:
		ScreenManager.start_level()


# --- In-progress save --------------------------------------------------------

func _try_resume() -> bool:
	var ip: Variant = SaveManager.game().get("in_progress_level")
	if typeof(ip) != TYPE_DICTIONARY or int(ip.get("level", -1)) != level:
		return false
	if typeof(ip.get("park")) != TYPE_DICTIONARY:
		return false
	park = Park.from_level(ip["park"])
	moves = int(ip.get("moves", 0))
	boosters_used = bool(ip.get("boosters_used", false))
	used_crane = bool(ip.get("used_crane", false))
	extra_used = bool(ip.get("extra_used", false))
	revive_used = bool(ip.get("revive_used", false))
	resumed = moves > 0
	return true


func _in_progress() -> Dictionary:
	return {
		"level": level,
		"park": park.to_dict(),
		"moves": moves,
		"boosters_used": boosters_used,
		"used_crane": used_crane,
		"extra_used": extra_used,
		"revive_used": revive_used,
	}


func _queue_save() -> void:
	_save_timer = SAVE_DELAY


func _save_progress() -> void:
	_save_timer = -1.0
	if state == State.WON or state == State.FAILED or park == null:
		return
	SaveManager.game()["in_progress_level"] = _in_progress()
	SaveManager.save_game()


func _clear_progress() -> void:
	_save_timer = -1.0
	SaveManager.game()["in_progress_level"] = null
	SaveManager.save_game()


# --- Frame / hints -----------------------------------------------------------

func _process(delta: float) -> void:
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_progress()
	_poll_hint()
	if is_playing() and view.idle() and SaveManager.get_setting("hints") and not tutorial.is_active() and not _hint_shown and not crane_mode:
		_idle += delta
		if _idle >= float(GameData.difficulty()["hint"]["idle_seconds"]):
			request_hint()


func request_hint() -> void:
	if _hint_task >= 0:
		return
	_hint_shown = true
	var budget := int(GameData.difficulty()["hint"]["node_budget"])
	_hint_task = WorkerThreadPool.add_task(_hint_worker.bind(park.to_dict(), budget))


func _hint_worker(copy: Dictionary, budget: int) -> void:
	var id := ParkSolver.hint(copy, budget)
	_hint_mutex.lock()
	_hint_result = id
	_hint_mutex.unlock()


func _poll_hint() -> void:
	if _hint_task < 0 or not WorkerThreadPool.is_task_completed(_hint_task):
		return
	WorkerThreadPool.wait_for_task_completion(_hint_task)
	_hint_task = -1
	_hint_mutex.lock()
	var id := _hint_result
	_hint_mutex.unlock()
	if id >= 0 and is_playing() and park.bus(id)["state"] == "lot":
		tutorial.point_at_bus(id)
		view.highlight_bus(id, true)


func _clear_hint() -> void:
	if _hint_shown:
		view.clear_highlights()
		tutorial.hide_hand()
	_hint_shown = false


## The bus the idle hint is pointing at, or -1 (tests).
func hint_bus() -> int:
	return _hint_result if _hint_shown and _hint_task < 0 else -1


func _exit_tree() -> void:
	if _hint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1
	if _save_timer > 0.0:
		_save_progress()
	if get_tree():
		get_tree().paused = false


## Runs `fn` after `sec` seconds on a tween owned by this node, so it never
## fires after the node is gone (unlike a SceneTree timer).
func _after(sec: float, fn: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(0.0, sec))
	tw.tween_callback(fn)
