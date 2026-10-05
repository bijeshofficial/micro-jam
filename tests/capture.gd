extends SceneTree
## Renders screens to PNG for visual review (needs a window, not --headless).
##   godot --path . --resolution 540x960 --always-on-top --script res://tests/capture.gd -- --out=/tmp/shots [--set=boot|hub|play|action|popups|themes]
## Uses a throwaway save file, never the player's.

var out_dir := "user://captures"
var which := "all"
var S: Node
var SM: Node
var PM: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--set="):
			which = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _fresh(level: int, coins: int = 640) -> void:
	S.data = S.defaults()
	S.data["coins"] = coins
	S.data["current_level"] = level
	S.data["game"]["route_seen_level"] = level
	var steps := {}
	for k in ["tap", "blocked", "bays", "crane", "extra_bay", "shuffle", "twist_sleep", "twist_cones", "twist_covered", "twist_tunnel", "grant_crane", "grant_extra_bay", "grant_shuffle"]:
		steps[k] = true
	S.data["game"]["tutorial_steps"] = steps


func _want(set_name: String) -> bool:
	return which == "all" or which.split(",").has(set_name)


func _run() -> void:
	await process_frame
	S = root.get_node("SaveManager")
	SM = root.get_node("ScreenManager")
	PM = root.get_node("ProgressionManager")
	S.set_save_path("user://capture_save.json")
	root.get_node("GameManager").pause_on_focus_loss = false
	root.get_node("AudioManager").set_ad_mute(true)
	root.get_node("AdManager").mock_duration = 0.05

	if _want("boot"):
		_fresh(1)
		change_scene_to_file("res://scenes/main/boot.tscn")
		await _wait(0.6)
		await _save("00_boot")
		await _wait(0.5)
		await _save("01_boot_late")
		await _wait(1.0)
		await _wait_transition(0.12)
		await _save("01b_wipe")
		await _wait(1.0)

	if _want("hub"):
		_fresh(37)
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 0.9)
		await _save("02_home")
		current_scene.select_tab(0)
		await _wait(0.5)
		await _save("03_shop")
		var shop = current_scene.shop
		shop.scroll.scroll_vertical = 1300
		await _wait(0.3)
		await _save("04_shop_more")
		shop.scroll.scroll_vertical = 2600
		await _wait(0.3)
		await _save("05_shop_cosmetics")
		shop.scroll.scroll_vertical = 4200
		await _wait(0.3)
		await _save("05b_shop_themes")
		current_scene.select_tab(2)
		await _wait(0.5)
		await _save("06_profile")
		current_scene.select_tab(1)
		await _wait(0.5)
		var pops = load("res://scripts/ui/popups.gd")
		S.add_game_stat("buses_sent", 12)
		pops.daily_tasks()
		await _wait(0.6)
		await _save("06b_daily_tasks")
		SM.close_all_modals()
		pops.daily_jam()
		await _wait(0.6)
		await _save("06c_daily_jam")
		SM.close_all_modals()
		_fresh(12)
		S.data["game"]["route_seen_level"] = 10
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 0.5)
		await _save("07_home_token_driving")

	if _want("play"):
		for spec in [[1, "10_level1"], [2, "11_level2"], [15, "12_level15"], [30, "13_level30"], [57, "14_level57"], [80, "15_level80"], [200, "16_level200"]]:
			_fresh(int(spec[0]))
			if int(spec[0]) <= 2:
				S.data["game"]["tutorial_steps"] = {}
			await _scene("res://scenes/gameplay/gameplay.tscn", 1.4)
			await _save(String(spec[1]))
			var pop = SM.top_modal()
			if pop:
				SM.close_all_modals()

	if _want("action"):
		_fresh(24)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.2)
		var g = current_scene
		var sol: Array = g.level_data.get("solution", [])
		var tapped := 0
		for id in sol:
			if g.park.bus(int(id))["state"] == "lot" and g.park.can_exit(int(id)):
				g.tap_bus(int(id))
				tapped += 1
				if tapped == 1:
					await _wait(0.25)
					await _save("20_bus_driving")
				if tapped >= 3:
					break
				await _wait(0.15)
		await _wait(0.5)
		await _save("21_boarding")
		# A blocked bump.
		for id in g.park.lot_buses():
			if bool(g.park.blocker(id)["blocked"]) and not bool(g.park.bus(id)["sleep"]):
				g.tap_bus(id)
				break
		await _wait(0.12)
		await _save("22_bump")
		await _wait(1.5)
		g.use_booster("crane", true)
		await _wait(0.4)
		await _save("23_crane_mode")
		var target: int = g.park.lot_buses()[0]
		g.tap_bus(target)
		await _wait(0.55)
		await _save("24_crane_lift")
		await _wait(2.0)
		# Force the out-of-bays popup.
		_fresh(24)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.2)
		g = current_scene
		var guard := 0
		while not g.park.is_failed() and guard < 40:
			guard += 1
			var ex: Array = g.park.exitable()
			if ex.is_empty():
				break
			var front: int = g.park.front_color()
			var pick: int = -1
			for id in ex:
				if int(g.park.bus(id)["color"]) != front:
					pick = id
					break
			if pick < 0:
				pick = ex[0]
			g.tap_bus(pick)
			await _wait(0.05)
		await _wait(3.0)
		await _save("25_out_of_bays")
		SM.close_all_modals()
		# Win panel.
		_fresh(3)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.0)
		g = current_scene
		for id in g.level_data["solution"]:
			while g.view.is_bus_busy(int(id)) or not g.is_playing():
				await _wait(0.1)
			if g.park.bus(int(id))["state"] == "lot":
				g.tap_bus(int(id))
			await _wait(0.2)
		await _wait(2.4)
		await _save("26_celebrate")
		await _wait(1.6)
		await _save("27_win_panel")
		SM.close_all_modals()

	if _want("win"):
		_fresh(9)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.0)
		var gw = current_scene
		for id in gw.level_data["solution"]:
			while gw.view.is_bus_busy(int(id)) or not gw.is_playing():
				await _wait(0.1)
				if gw.state == 3:
					break
			if gw.park.bus(int(id))["state"] == "lot":
				gw.tap_bus(int(id))
			await _wait(0.3)
		var waited := 0.0
		while SM.find_modal("win") == null and waited < 15.0:
			await _wait(0.2)
			waited += 0.2
		await _wait(0.5)
		await _save("28_win_panel")
		await _wait(1.2)
		await _save("29_win_coins")
		SM.close_all_modals()

	if _want("big"):
		for spec in [[200, "60_diamond"], [250, "61_plus"], [400, "62_octagon"], [1000, "63_round"], [800, "64_rect_42"], [500, "65_rect_40"]]:
			_fresh(int(spec[0]))
			await _scene("res://scenes/gameplay/gameplay.tscn", 1.5)
			SM.close_all_modals()
			await _wait(0.2)
			await _save(String(spec[1]))
		# Some buses heading out of a round lot.
		_fresh(1000)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.4)
		var gb = current_scene
		var n := 0
		for id in gb.level_data["solution"]:
			if n >= 3:
				break
			if gb.park.bus(int(id))["state"] == "lot" and gb.park.can_exit(int(id)):
				gb.tap_bus(int(id))
				n += 1
				await _wait(0.2)
		await _wait(0.25)
		await _save("66_round_action")

	if _want("stack"):
		# Pause -> Settings -> Credits: only the top popup should show.
		_fresh(24)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.2)
		current_scene.open_pause()
		await _wait(0.5)
		await _save("50_pause")
		SM.find_modal("pause").press("settings")
		await _wait(0.5)
		await _save("51_pause_settings")
		load("res://scripts/ui/popups.gd").credits()
		await _wait(0.5)
		await _save("52_settings_credits")
		SM.find_modal("credits").press("ok")
		await _wait(0.4)
		await _save("53_back_to_settings")
		SM.close_all_modals()
		paused = false
		# Win -> depot gift chest -> reward over the win panel.
		_fresh(10)
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.0)
		var gs = current_scene
		for id in gs.level_data["solution"]:
			var guard := 0
			while gs.park.bus(int(id))["state"] == "lot" and guard < 80 and gs.state != 3:
				guard += 1
				if gs.is_playing() and not gs.view.is_bus_busy(int(id)):
					gs.tap_bus(int(id))
				await _wait(0.15)
		var w := 0.0
		while SM.find_modal("gift") == null and w < 20.0:
			await _wait(0.2)
			w += 0.2
		await _wait(0.6)
		await _save("54_win_then_gift")
		SM.find_modal("gift").press("open")
		await _wait(0.6)
		await _save("55_gift_reward")
		SM.find_modal("reward").press("ok")
		await _wait(0.5)
		await _save("56_back_to_win")
		SM.close_all_modals()

	if _want("popups"):
		_fresh(30)
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 0.6)
		current_scene.open_settings()
		await _wait(0.5)
		await _save("30_settings")
		SM.close_all_modals()
		load("res://scripts/ui/popups.gd").lives(true)
		await _wait(0.5)
		await _save("31_out_of_lives")
		SM.close_all_modals()
		load("res://scripts/ui/popups.gd").reward("Full House", "80 coins + 1 Extra Bay", "trophy")
		await _wait(0.5)
		await _save("31b_reward")
		SM.close_all_modals()
		load("res://scripts/ui/popups.gd").credits()
		await _wait(0.5)
		await _save("31c_credits")
		SM.close_all_modals()
		load("res://scripts/ui/popups.gd").daily_jam()
		await _wait(0.5)
		await _save("31d_daily_jam")
		SM.close_all_modals()
		load("res://scripts/ui/popups.gd").buy_booster("crane")
		await _wait(0.5)
		await _save("32_buy_booster")
		SM.close_all_modals()
		_fresh(50)
		S.data["game"]["tutorial_steps"].erase("twist_covered")
		await _scene("res://scenes/gameplay/gameplay.tscn", 1.4)
		await _save("33_twist_card")
		SM.close_all_modals()
		current_scene.open_pause()
		await _wait(0.5)
		await _save("34_pause")
		SM.close_all_modals()
		paused = false

	if _want("themes"):
		for th in ["theme_rain", "theme_festival", "theme_night", "theme_snow"]:
			_fresh(42)
			S.data["selected_items"]["theme"] = th
			S.data["unlocked_items"].append(th)
			await _scene("res://scenes/gameplay/gameplay.tscn", 1.2)
			await _save("40_" + th)
		_fresh(42)
		S.data["selected_items"]["theme"] = "theme_night"
		S.data["unlocked_items"].append("theme_night")
		SM.hub_tab = "home"
		await _scene("res://scenes/main/hub.tscn", 0.8)
		await _save("45_home_night")
	print("captures in ", ProjectSettings.globalize_path(out_dir))
	quit(0)


func _scene(path: String, wait: float) -> void:
	SM.close_all_modals()
	paused = false
	change_scene_to_file(path)
	await _wait(wait)


func _wait_transition(t: float) -> void:
	await _wait(t)


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _save(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
