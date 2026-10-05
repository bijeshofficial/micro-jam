extends SceneTree
## Store screenshots and Canva art, rendered from the real game.
##
##   Google Play phone screenshots (1080x1920):
##     godot --path . --always-on-top --screen 1 --resolution 1080x1920 --script res://tools/store_shots.gd -- --set=android
##   App Store 6.5" iPhone screenshots (1242x2688):
##     godot --path . --always-on-top --screen 1 --resolution 932x2018 --script res://tools/store_shots.gd -- --set=ios-6.5 --target=1242x2688
##     (A 2688 px tall window doesn't fit on a monitor, so the game renders at
##     the same 19.5:9 aspect and the PNG is scaled up to 1242x2688.)
##   Icon, feature graphic and transparent cut-outs for Canva:
##     godot --path . --always-on-top --script res://tools/store_shots.gd -- --art
##
## The window must not be clamped by the monitor: use a scale-1 screen
## (--screen N) so the PNGs come out at exactly the requested size.
## Uses a throwaway save, never the player's.

const OUT := "res://docs/store/"

var set_name := "android"
var target := Vector2i.ZERO
var art_only := false
var S: Node
var SM: Node
var dir := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			set_name = a.substr(6)
		elif a.begins_with("--target="):
			var p := a.substr(9).split("x")
			target = Vector2i(int(p[0]), int(p[1]))
		elif a == "--art":
			art_only = true
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = root.get_node("SaveManager")
	SM = root.get_node("ScreenManager")
	S.set_save_path("user://store_shots_save.json")
	root.get_node("GameManager").pause_on_focus_loss = false
	root.get_node("AudioManager").set_ad_mute(true)
	root.get_node("AdManager").mock_duration = 0.05

	if art_only:
		# Loaded at runtime: --script files can't name game classes directly.
		var art: Node = load("res://tools/store_art.gd").new()
		root.add_child(art)
		await art.export_all(OUT)
		_done()
		return

	dir = ProjectSettings.globalize_path(OUT + "screenshots/" + set_name)
	DirAccess.make_dir_recursive_absolute(dir)
	print("rendering %s at %s" % [set_name, str(root.size)])

	# 1. Home: the route map and the ticket PLAY button.
	_fresh(37)
	SM.hub_tab = "home"
	await _scene("res://scenes/main/hub.tscn", 1.2)
	await _shot("01_home_route_map")

	# 2. The jam: buses heading to the bays, passengers hopping on.
	var g := await _level(42, "theme_morning")
	await _tap_solution(g, 3, 0.35)
	await _wait(0.55)
	await _shot("02_clear_the_jam")

	# 3. Twists: cones, umbrellas and a bump.
	g = await _level(57, "theme_festival")
	await _tap_solution(g, 2, 0.4)
	await _wait(0.5)
	for id in g.park.lot_buses():
		if bool(g.park.blocker(id)["blocked"]) and not bool(g.park.bus(id)["sleep"]):
			g.tap_bus(id)
			break
	await _wait(0.13)
	await _shot("03_bump_and_twists")

	# 4. The crane lifts a boxed-in bus.
	g = await _level(64, "theme_morning")
	await _tap_solution(g, 1, 0.3)
	await _wait(0.6)
	var boxed := -1
	for id in g.park.lot_buses():
		if bool(g.park.blocker(id)["blocked"]):
			boxed = id
	if boxed >= 0:
		g.use_booster("crane", true)
		await _wait(0.2)
		g.tap_bus(boxed)
		await _wait(0.62)
	await _shot("04_crane_booster")

	# 5. Night bus park with the tunnel.
	g = await _level(80, "theme_night")
	await _tap_solution(g, 2, 0.4)
	await _wait(0.7)
	await _shot("05_night_bus_park")

	# 6. Level complete.
	g = await _level(9, "theme_morning")
	for id in g.level_data["solution"]:
		var guard := 0
		while (g.view.is_bus_busy(int(id)) or not g.is_playing()) and guard < 80:
			guard += 1
			await _wait(0.1)
		if g.park.bus(int(id))["state"] == "lot":
			g.tap_bus(int(id))
		await _wait(0.3)
	var waited := 0.0
	while SM.find_modal("win") == null and waited < 15.0:
		await _wait(0.2)
		waited += 0.2
	await _wait(1.9)
	await _shot("06_jam_cleared")
	SM.close_all_modals()

	# 7. Shop: bus liveries and horns at the ticket counter.
	_fresh(37)
	SM.hub_tab = "shop"
	await _scene("res://scenes/main/hub.tscn", 0.9)
	var shop = current_scene.shop
	var first: Control = shop.cosmetic_buttons.values()[0]
	shop.scroll.scroll_vertical = int(first.get_global_rect().position.y - root.get_visible_rect().size.y * 0.42)
	await _wait(0.4)
	await _shot("07_bus_liveries")

	# 8. Daily Tasks over the route map (two done, one to go).
	_fresh(37)
	SM.hub_tab = "home"
	await _scene("res://scenes/main/hub.tscn", 1.0)
	var dm := root.get_node("DailyManager")
	dm.refresh()
	var tasks: Array = dm.tasks()
	for i in 2:
		S.add_game_stat(String(dm._def(String(tasks[i]["id"]))["stat"]), int(tasks[i]["target"]))
	dm.claim_task(0)
	load("res://scripts/ui/popups.gd").daily_tasks()
	await _wait(0.7)
	await _shot("08_daily_tasks")
	_done()


func _fresh(level: int) -> void:
	S.data = S.defaults()
	S.data["coins"] = 1240
	S.data["current_level"] = level
	S.data["tutorial_done"] = true
	S.data["unlocked_items"] = ["livery_mountain", "horn_pompom", "outfit_rain", "theme_festival", "theme_night"]
	S.data["selected_items"] = {"livery": "livery_mountain"}
	S.game()["route_seen_level"] = level
	S.game()["boosters"] = {"crane": 3, "extra_bay": 2, "shuffle": 4}
	var steps := {}
	for k in ["tap", "blocked", "bays", "crane", "extra_bay", "shuffle", "twist_sleep", "twist_cones", "twist_covered", "twist_tunnel", "grant_crane", "grant_extra_bay", "grant_shuffle"]:
		steps[k] = true
	S.game()["tutorial_steps"] = steps


func _level(level: int, theme: String) -> Node:
	_fresh(level)
	S.data["selected_items"]["theme"] = theme
	await _scene("res://scenes/gameplay/gameplay.tscn", 1.3)
	SM.close_all_modals()
	paused = false
	return current_scene


## Taps the first `n` buses of the stored solution that can leave now.
func _tap_solution(g: Node, n: int, gap: float) -> void:
	var done := 0
	for id in g.level_data["solution"]:
		if done >= n:
			break
		var b: Dictionary = g.park.bus(int(id))
		if b["state"] != "lot":
			continue
		if bool(b["sleep"]):
			g.tap_bus(int(id))
			await _wait(0.35)
		if g.park.can_exit(int(id)):
			g.tap_bus(int(id))
			done += 1
			await _wait(gap)


func _scene(path: String, wait: float) -> void:
	SM.close_all_modals()
	paused = false
	change_scene_to_file(path)
	await _wait(wait)


var _last_hash := 0
var stale_shots: Array = []


## Saves the current frame. If it is identical to the previous shot the
## window has stopped rendering (covered by another window): retry, then
## report it so a bad set is never mistaken for a good one.
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var tries := 0
	while hash(img.get_data()) == _last_hash and tries < 10:
		tries += 1
		await _wait(0.3)
		img = root.get_texture().get_image()
	if hash(img.get_data()) == _last_hash:
		stale_shots.append(name)
		push_error("store_shots: %s is identical to the previous shot (window not rendering?)" % name)
	_last_hash = hash(img.get_data())
	img.convert(Image.FORMAT_RGB8)
	if target != Vector2i.ZERO and img.get_size() != target:
		img.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(dir.path_join(name + ".png"))
	print("  ", name, "  ", img.get_size())


func _done() -> void:
	SM.close_all_modals()
	paused = false
	change_scene_to_file("res://tests/empty.tscn")
	await _wait(0.3)
	if stale_shots.is_empty():
		print("store renders done")
	else:
		print("STALE SHOTS, re-run with the window visible: ", stale_shots)
	quit(0)


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
