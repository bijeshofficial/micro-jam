extends SceneTree
## Headless smoke test for Micro Jam.
##   godot --headless --path . --script res://tests/smoke_test.gd
## Uses its own save file (user://smoke_test_save.json), never the player's.
## Exits 0 when every check passes, 1 otherwise, and prints
## "SMOKE TEST PASSED" on success.
##
## Only pure-logic classes (Park, ParkSolver, LevelGenerator, GameData) are
## referenced by name: UI/gameplay classes compile before the autoloads exist
## in --script mode, so they are reached through scene instances instead.

const TEST_SAVE := "user://smoke_test_save.json"
const HUB := "res://scenes/main/hub.tscn"
const GAMEPLAY := "res://scenes/gameplay/gameplay.tscn"
const POPUPS := "res://scripts/ui/popups.gd"
const ST_PLAYING := 1
const ST_FAILING := 2
const ST_WON := 3
const ST_FAILED := 4

var failures: Array[String] = []
var checks := 0

var S: Node
var CM: Node
var PM: Node
var LM: Node
var BM: Node
var ACH: Node
var AD: Node
var AU: Node
var HM: Node
var SM: Node
var GM: Node
var IAP: Node
var VFX: Node
var POOL: Node


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	await process_frame
	S = root.get_node_or_null("SaveManager")
	if S == null:
		_fail("autoloads are not available")
		_finish()
		return
	CM = root.get_node("CurrencyManager")
	PM = root.get_node("ProgressionManager")
	LM = root.get_node("LivesManager")
	BM = root.get_node("BoosterManager")
	ACH = root.get_node("AchievementManager")
	AD = root.get_node("AdManager")
	AU = root.get_node("AudioManager")
	HM = root.get_node("HapticsManager")
	SM = root.get_node("ScreenManager")
	GM = root.get_node("GameManager")
	IAP = root.get_node("IAPManager")
	VFX = root.get_node("VFXManager")
	POOL = root.get_node("PoolManager")

	S.set_save_path(TEST_SAVE)
	_remove_test_files()
	S.load_game()
	AD.mock_duration = 0.05
	AD.mock_fail_rate = 0.0

	_test_path_clear_all_directions()
	_test_boarding_and_win()
	_test_fail_and_warning()
	_test_twists()
	_test_boosters_logic()
	_test_solver_and_levels()
	_test_lives_logic()
	await _test_level1_by_input()
	await _test_tutorial_not_repeated()
	await _test_failure_costs_life()
	await _test_rescue_and_boosters_in_level()
	await _test_cones_clear_in_view()
	await _test_resume()
	await _test_leave_costs_life()
	await _test_hub_and_back()
	await _test_ads()
	await _test_shop_iap_achievements()
	await _test_modal_stack()
	_test_daily_tasks()
	await _test_daily_jam()
	_test_save_load()
	_test_corrupt_and_migration()
	_test_layout_aspects()
	_test_hooks()
	_finish()


# --- Rules: path-clear checks ------------------------------------------------

func _park(w: int, h: int, buses: Array, queue: Array = [], extra: Dictionary = {}) -> Park:
	var list: Array = []
	for i in buses.size():
		var b: Dictionary = (buses[i] as Dictionary).duplicate()
		b["id"] = i
		list.append(b)
	var d := {"w": w, "h": h, "buses": list, "queue": queue}
	d.merge(extra, true)
	return Park.from_level(d)


## Every direction x both lengths: clear path exits; one blocker in the path
## blocks (and the event names it); a bus at the edge facing out exits.
func _test_path_clear_all_directions() -> void:
	var names := ["up", "right", "down", "left"]
	for length in [2, 3]:
		for dir in 4:
			# A 7x7 lot, the bus in the middle.
			var vertical: bool = dir == Park.UP or dir == Park.DOWN
			var x := 3 if vertical else 2
			var y := 2 if vertical else 3
			var cap := Park.capacity_for(length)
			var p := _park(7, 7, [{"x": x, "y": y, "len": length, "dir": dir, "color": 0}], _repeat(0, cap))
			var path := p.path(0)
			_check(not path.is_empty(), "%s len%d: has a path to the edge" % [names[dir], length])
			var last: Vector2i = path[path.size() - 1]
			_check(last.x == 0 or last.y == 0 or last.x == 6 or last.y == 6, "%s len%d: path ends at the lot edge" % [names[dir], length])
			_check(p.can_exit(0), "%s len%d: clear path can exit" % [names[dir], length])
			# Put a 2-cell blocker across the far end of the path.
			var far: Vector2i = path[path.size() - 1]
			var blk := {"x": far.x, "y": far.y, "len": 2, "dir": Park.RIGHT if vertical else Park.DOWN, "color": 1}
			if vertical and far.x == 6:
				blk["x"] = 5
			if not vertical and far.y == 6:
				blk["y"] = 5
			var p2 := _park(7, 7, [{"x": x, "y": y, "len": length, "dir": dir, "color": 0}, blk], _repeat(0, cap) + _repeat(1, 4))
			_check(not p2.can_exit(0), "%s len%d: a bus in the path blocks" % [names[dir], length])
			var ev := p2.tap(0)
			_check(ev.size() == 1 and ev[0]["type"] == "blocked" and int(ev[0]["blocker"]) == 1, "%s len%d: blocked tap bumps the blocker, no state change" % [names[dir], length])
			_check(p2.bus(0)["state"] == "lot" and p2.bays_used() == 0, "%s len%d: blocked tap costs nothing" % [names[dir], length])
			# A blocker beside the path (not in it) doesn't block.
			var side := {"x": x + (2 if vertical else 0), "y": y + (0 if vertical else 2), "len": 2, "dir": Park.DOWN if vertical else Park.RIGHT, "color": 1}
			var p3 := _park(7, 7, [{"x": x, "y": y, "len": length, "dir": dir, "color": 0}, side], _repeat(0, cap) + _repeat(1, 4))
			_check(p3.can_exit(0), "%s len%d: a bus beside the path doesn't block" % [names[dir], length])
	# Facing out from the edge: empty path, exits.
	var e := _park(4, 4, [{"x": 0, "y": 0, "len": 3, "dir": Park.UP, "color": 0}], _repeat(0, 6))
	_check(e.path(0).is_empty() and e.can_exit(0), "a bus at the edge facing out exits at once")
	# Footprints.
	_check(Park.cells_of(1, 1, 3, Park.RIGHT) == [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], "horizontal footprint")
	_check(Park.front_of(1, 1, 3, Park.DOWN) == Vector2i(1, 3) and Park.front_of(1, 1, 3, Park.LEFT) == Vector2i(1, 1), "front cells")


func _repeat(v: int, n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append(v)
	return a


func _test_boarding_and_win() -> void:
	var p := _park(4, 4, [{"x": 0, "y": 0, "len": 2, "dir": Park.UP, "color": 0}, {"x": 2, "y": 0, "len": 3, "dir": Park.UP, "color": 1}], [1, 0, 0, 0, 0, 1, 1, 1, 1, 1])
	var ev := p.tap(0)
	_check(ev[0]["type"] == "exit" and int(ev[0]["bay"]) == 0, "exit takes the first free bay")
	# Same colour in two bays: the bus that arrived first boards first.
	var ar := _park(4, 4, [{"x": 0, "y": 0, "len": 2, "dir": Park.UP, "color": 0}, {"x": 1, "y": 0, "len": 2, "dir": Park.UP, "color": 0}, {"x": 2, "y": 0, "len": 2, "dir": Park.UP, "color": 1}], [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1])
	ar.add_bay()
	ar.tap(1)
	ar.tap(0)
	_check(int(ar.bays[5]) == 1 and int(ar.bays[0]) == 0, "setup: later bus took the leftmost bay")
	ar.tap(2)
	_check(ar.bus(1)["state"] == "gone" and int(ar.bus(0)["boarded"]) == 4, "passengers board the earliest-arrived matching bus first")
	_check(p.qpos == 0, "front passenger (blue) doesn't board a red bus")
	ev = p.tap(1)
	var boards := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "board")
	_check(boards.size() == 10 and p.qpos == 10, "queue boards automatically, in order, into matching bays (%d)" % boards.size())
	var departs := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "depart")
	_check(departs.size() == 2, "full buses depart (micro 4 seats, bus 6 seats)")
	_check(ev[ev.size() - 1]["type"] == "won" and p.is_won(), "win when every bus left and the queue is empty")
	_check(p.bays_used() == 0 and p.free_bay() == 2, "departed buses free their bays; the next bus takes the longest-free bay")
	# Round trip.
	var q := _park(4, 4, [{"x": 0, "y": 0, "len": 2, "dir": Park.UP, "color": 0}], [0, 0, 0, 0])
	var d := q.to_dict()
	_check(Park.from_level(d).to_dict() == d, "park serialises and restores exactly")


func _test_fail_and_warning() -> void:
	# Five red buses at the top edge, the queue wants green first.
	var buses: Array = []
	for i in 6:
		buses.append({"x": i, "y": 0, "len": 2, "dir": Park.UP, "color": 0 if i < 5 else 3})
	var queue: Array = [3, 3, 3, 3] + _repeat(0, 20)
	var p := _park(6, 4, buses, queue)
	for i in 4:
		p.tap(i)
	_check(p.is_warning() and not p.is_failed(), "warning when only one bay is left and nobody fits")
	var ev := p.tap(4)
	_check(ev[ev.size() - 1]["type"] == "failed" and p.is_failed(), "FAIL: all 5 bays taken and the front passenger matches none")
	_check(p.tap(5).is_empty(), "no more taps after failing")
	var full := p.duplicate_park()
	full.queue[full.qpos] = 0
	_check(not full.is_failed(), "not failed when the front passenger fits a bay")


func _test_twists() -> void:
	# Sleeping driver: first tap wakes, second drives.
	var s := _park(3, 3, [{"x": 0, "y": 0, "len": 2, "dir": Park.UP, "color": 0, "sleep": true}], [0, 0, 0, 0])
	var e1 := s.tap(0)
	_check(e1.size() == 1 and e1[0]["type"] == "wake" and s.bus(0)["state"] == "lot", "sleeping driver: first tap only wakes")
	var e2 := s.tap(0)
	_check(e2[0]["type"] == "exit", "sleeping driver: second tap drives")
	# Cones block until 3 buses have left.
	var buses: Array = [{"x": 0, "y": 2, "len": 2, "dir": Park.UP, "color": 0}]
	for i in 3:
		buses.append({"x": 2 + i, "y": 0, "len": 2, "dir": Park.UP, "color": 1})
	var c := _park(5, 4, buses, _repeat(1, 12) + _repeat(0, 4), {"cones": [[0, 1]], "cone_clear": 3})
	_check(not c.can_exit(0) and c.tap(0)[0]["type"] == "blocked", "cone blocks the path")
	c.tap(1)
	c.tap(2)
	var e3 := c.tap(3)
	_check(e3.any(func(e: Dictionary) -> bool: return e["type"] == "cones_clear") and c.cones.is_empty(), "cones vanish after 3 buses leave")
	_check(c.can_exit(0), "path clear once the cones are gone")
	# Covered passengers: hidden except at the front.
	var cv := _park(3, 3, [{"x": 0, "y": 0, "len": 2, "dir": Park.UP, "color": 0}], [0, 0, 0, 0], {"covered": [0, 2]})
	_check(not cv.is_covered(0) and cv.is_covered(2) and not cv.is_covered(1), "umbrellas hide colour until the front")
	# Tunnel: the next bus rolls out when the spot bus leaves.
	var t := {"edge": "left", "pos": 1, "order": [0, 1], "next": 0}
	var tl := _park(5, 3, [
		{"x": 0, "y": 1, "len": 2, "dir": Park.RIGHT, "color": 0, "state": "lot"},
		{"x": 0, "y": 0, "len": 3, "dir": Park.RIGHT, "color": 1, "state": "tunnel"}], _repeat(0, 4) + _repeat(1, 6), {"tunnel": t})
	_check(tl.tunnel_waiting() == [1], "tunnel holds the next bus")
	var e4 := tl.tap(0)
	_check(e4.any(func(e: Dictionary) -> bool: return e["type"] == "tunnel_out" and int(e["bus"]) == 1), "next tunnel bus rolls out")
	_check(tl.bus(1)["state"] == "lot" and tl.bus_at(Vector2i(0, 1)) == 1 and tl.bus_at(Vector2i(2, 1)) == 1, "tunnel bus sits on the spot (%s)" % [tl.cells(1)])
	tl.tap(1)
	_check(tl.is_won(), "tunnel level can be finished")


func _test_boosters_logic() -> void:
	# Crane ignores blockers.
	var p := _park(3, 4, [{"x": 0, "y": 2, "len": 2, "dir": Park.UP, "color": 0}, {"x": 0, "y": 0, "len": 2, "dir": Park.RIGHT, "color": 1}], _repeat(0, 4) + _repeat(1, 4))
	_check(not p.can_exit(0), "crane test: bus is boxed in")
	var ev := p.crane(0)
	_check(not ev.is_empty() and ev[0]["type"] == "exit" and ev[0]["via"] == "crane", "CRANE lifts a blocked bus to a bay")
	_check(p.bus(0)["state"] == "gone", "craned bus fills and leaves")
	# Extra bay rescues a failed park.
	var buses: Array = []
	for i in 6:
		buses.append({"x": i, "y": 0, "len": 2, "dir": Park.UP, "color": 0 if i < 5 else 3})
	var f := _park(6, 4, buses, [3, 3, 3, 3] + _repeat(0, 20))
	for i in 5:
		f.tap(i)
	_check(f.is_failed(), "setup: failed")
	var g := f.duplicate_park()
	g.add_bay()
	_check(g.bays.size() == 6 and not g.is_failed(), "EXTRA BAY: a 6th bay ends the fail state")
	var ev2 := g.tap(5)
	_check(ev2.any(func(e: Dictionary) -> bool: return e["type"] == "won"), "EXTRA BAY: level can be won")
	# Shuffle keeps counts and makes it solvable again.
	var h := f.duplicate_park()
	var before := _counts(h.queue, h.qpos)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_check(h.shuffle_queue(rng), "SHUFFLE QUEUE runs")
	_check(_counts(h.queue, h.qpos) == before, "SHUFFLE keeps the passenger counts")
	var ev3 := h.resolve()
	_check(not h.is_failed() and not ev3.is_empty(), "SHUFFLE rescues a failed park (front now fits a bay)")
	_check(bool(ParkSolver.solve(h.to_dict(), 5000)["solvable"]), "SHUFFLE result is solvable")


func _counts(q: PackedInt32Array, from: int) -> Dictionary:
	var c := {}
	for i in range(from, q.size()):
		c[q[i]] = int(c.get(q[i], 0)) + 1
	return c


# --- Solver, levels ----------------------------------------------------------

func _test_solver_and_levels() -> void:
	for n in range(1, 21):
		var l := LevelGenerator.generate(n)
		var r := ParkSolver.solve(l, 20000)
		_check(bool(r["solvable"]), "authored level %d solvable" % n)
		_check(ParkSolver.lazy_ok(l, l["solution"]), "authored level %d: stored solution works" % n)
	var a := LevelGenerator.generate(37)
	var b := LevelGenerator.generate(37)
	_check(JSON.stringify(a) == JSON.stringify(b), "generation is deterministic per level number")
	_check(JSON.stringify(a) != JSON.stringify(LevelGenerator.generate(38)), "different levels differ")
	_check(LevelGenerator.tier_for(25) == "hard" and LevelGenerator.tier_for(30) == "super" and LevelGenerator.tier_for(31) == "easy", "sawtooth rhythm: HARD every 5th, SUPER every 10th, easy after")
	var small := (LevelGenerator.generate(12)["buses"] as Array).size()
	var big := (LevelGenerator.generate(212)["buses"] as Array).size()
	_check(big > small + 8, "difficulty ramps: more buses later (%d vs %d)" % [small, big])
	_check(PM.coin_reward(24) == 10 and PM.coin_reward(25) == 15 and PM.coin_reward(30) == 20, "coin rewards 10 / 15 HARD / 20 SUPER")
	for n in [52, 84, 133]:
		var l := LevelGenerator.generate(n)
		_check(int(l["w"]) * int(l["h"]) >= 42 and bool(l.get("verified", false)), "level %d generated, verified by the solver" % n)


func _test_lives_logic() -> void:
	S.data = S.defaults()
	LM.time_offset = 0.0
	_check(LM.lives() == 5, "lives start at 5")
	LM.lose_life()
	LM.lose_life()
	_check(LM.lives() == 3, "lose_life works")
	LM.time_offset = 1800.0 + 5.0
	LM.tick()
	_check(LM.lives() == 4, "+1 life after 30 minutes")
	LM.time_offset = 1800.0 * 10.0
	LM.tick()
	_check(LM.lives() == 5, "lives clamp at 5 after a long time away")
	LM.time_offset = 0.0
	LM.lose_life()
	S.game()["last_life_time"] = LM.now() + 99999.0
	LM.tick()
	_check(LM.lives() == 4, "clock set backwards grants nothing")
	_check(not LM.level_costs_life(3) and LM.level_costs_life(20), "tutorial levels never cost lives")
	S.data = S.defaults()


# --- Gameplay with real input ------------------------------------------------

func _fresh(level: int) -> void:
	S.data = S.defaults()
	S.data["current_level"] = level
	S.save_game()


func _open_level(level: int) -> Node:
	SM.close_all_modals()
	paused = false
	S.data["current_level"] = level
	change_scene_to_file(GAMEPLAY)
	await _wait(0.2)
	var g := current_scene
	# Twist intro cards appear just after the state turns PLAYING: keep
	# dismissing them until the level has been playable for a moment.
	var waited := 0.0
	var clear_for := 0.0
	while waited < 4.0 and clear_for < 0.4:
		await _wait(0.1)
		waited += 0.1
		var top: Control = SM.top_modal()
		if top and top.has_method("press") and String(top.get_meta("popup_id", "")).begins_with("twist_"):
			top.press("ok")
			clear_for = 0.0
		elif g.state == ST_PLAYING and top == null:
			clear_for += 0.1
		else:
			clear_for = 0.0
	return g


## A real tap: touch press + release pushed through the viewport.
func _touch(pos: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.position = pos
	down.pressed = true
	root.push_input(down, true)
	var up := InputEventScreenTouch.new()
	up.position = pos
	up.pressed = false
	root.push_input(up, true)


func _bus_screen_pos(g: Node, id: int) -> Vector2:
	var bv = g.view.bus_visual(id)
	return g.view.position + bv.position - Vector2(0, g.view.cell * 0.1)


func _test_level1_by_input() -> void:
	_fresh(1)
	var g := await _open_level(1)
	_check(g.state == ST_PLAYING, "level 1 starts")
	_check(g.tutorial.step == "tap" and g.tutorial.forced.map(func(v: Variant) -> int: return int(v)) == [0, 1, 2], "level 1 forced tutorial taps")
	# A tap on the wrong bus is ignored during the forced tutorial.
	_touch(_bus_screen_pos(g, 2))
	await _wait(0.1)
	_check(g.park.bus(2)["state"] == "lot", "tutorial ignores the wrong bus")
	for id in [0, 1, 2]:
		while g.view.is_bus_busy(id) or not g.is_playing():
			await _wait(0.05)
			if g.state == ST_WON:
				break
		_touch(_bus_screen_pos(g, id))
		await _wait(0.15)
		_check(g.park.bus(id)["state"] != "lot", "touch drove bus %d out" % id)
	var waited := 0.0
	while SM.find_modal("win") == null and waited < 12.0:
		await _wait(0.2)
		waited += 0.2
	_check(g.state == ST_WON, "level 1 won by touch input")
	_check(SM.find_modal("win") != null, "win screen shows")
	_check(PM.current_level() == 2, "progress advanced to level 2")
	_check(CM.get_coins() == 10, "won 10 coins (%d)" % CM.get_coins())
	_check(SaveManager_stat("buses_sent") == 3 and SaveManager_stat("passengers_boarded") == 12, "stats counted buses and passengers")
	_check(ProgressionManager_tut("tap"), "tap tutorial marked done")
	var win: Control = SM.find_modal("win")
	await _wait(1.2)
	win.continue_pressed.emit()
	await _wait(1.2)
	_check(current_scene.level == 2, "CONTINUE goes straight into level 2")


func SaveManager_stat(k: String) -> int:
	return S.game_stat(k)


func ProgressionManager_tut(k: String) -> bool:
	return PM.tutorial_done(k)


func _test_tutorial_not_repeated() -> void:
	S.data["game"]["tutorial_steps"]["tap"] = true
	var g := await _open_level(1)
	_check(g.tutorial.step == "", "finished tutorial doesn't repeat")
	_check(g.tutorial.allows_tap(2), "any bus can be tapped after the tutorial")


## Plays wrong colours on purpose until all bays are full.
func _force_fail(g: Node) -> void:
	var guard := 0
	while not g.park.is_failed() and guard < 60:
		guard += 1
		var ex: Array = g.park.exitable()
		if ex.is_empty():
			break
		var front: int = g.park.front_color()
		var pick: int = -1
		for id in ex:
			if int(g.park.bus(id)["color"]) != front and not g.view.is_bus_busy(id):
				pick = id
				break
		if pick < 0:
			for id in ex:
				if not g.view.is_bus_busy(id):
					pick = id
					break
		if pick < 0:
			await _wait(0.1)
			continue
		g.tap_bus(pick)
		await _wait(0.02)


func _test_failure_costs_life() -> void:
	_fresh(24)
	var g := await _open_level(24)
	await _force_fail(g)
	_check(g.park.is_failed() and g.state == ST_FAILING, "level 24 forced into failure")
	var waited := 0.0
	while SM.find_modal("out_of_bays") == null and waited < 8.0:
		await _wait(0.2)
		waited += 0.2
	var pop: Control = SM.find_modal("out_of_bays")
	_check(pop != null, "out-of-bays popup offers a rescue")
	var lives_before: int = LM.lives()
	pop.press("give_up")
	await _wait(0.3)
	_check(LM.lives() == lives_before - 1, "a failed level costs 1 life")
	_check(SM.find_modal("failed") != null, "level failed popup")
	_check(S.game()["in_progress_level"] == null, "failed level clears the resume slot")
	# 0 lives: playing is blocked and the lives popup offers a refill.
	S.game()["lives"] = 0
	_check(not LM.can_play(24), "0 lives blocks levels 9+")
	_check(LM.can_play(3), "tutorial levels stay playable at 0 lives")
	SM.close_all_modals()
	load(POPUPS).lives(true)
	await _wait(0.1)
	var lp: Control = SM.find_modal("out_of_lives")
	_check(lp != null and lp.button("ad") != null and lp.button("refill") != null and lp.button("wait") != null, "out-of-lives popup: wait / refill / ad")
	lp.press("ad")
	await _wait(0.4)
	_check(LM.lives() == 1, "watching the mock ad gives +1 life")
	SM.close_all_modals()


func _test_rescue_and_boosters_in_level() -> void:
	_fresh(24)
	S.game()["boosters"] = {"crane": 2, "extra_bay": 1, "shuffle": 1}
	var g := await _open_level(24)
	await _force_fail(g)
	var waited := 0.0
	while SM.find_modal("out_of_bays") == null and waited < 8.0:
		await _wait(0.2)
		waited += 0.2
	var pop: Control = SM.find_modal("out_of_bays")
	pop.press("extra_bay")
	await _wait(0.3)
	waited = 0.0
	while not g.view.idle() and waited < 6.0:
		await _wait(0.2)
		waited += 0.2
	await _wait(0.2)
	_check(g.park.bays.size() == 6 and g.state == ST_PLAYING, "EXTRA BAY from the rescue popup: back to playing with 6 bays")
	_check(BM.count("extra_bay") == 0, "extra bay consumed")
	_check(not g.use_booster("extra_bay"), "only one extra bay per level")
	# Crane: select mode, tap a blocked bus.
	var blocked := -1
	for id in g.park.lot_buses():
		if bool(g.park.blocker(id)["blocked"]):
			blocked = id
			break
	if g.park.free_bay() >= 0 and blocked >= 0:
		g.use_booster("crane")
		_check(g.crane_mode, "crane mode on")
		g.tap_bus(blocked)
		_check(g.park.bus(blocked)["state"] != "lot" and BM.count("crane") == 1, "CRANE lifted a blocked bus")
		_check(g.used_crane, "crane use recorded (Crane-free achievement)")
	# Shuffle queue.
	waited = 0.0
	while not g.view.idle() and waited < 8.0:
		await _wait(0.2)
		waited += 0.2
	if g.park.waiting_count() >= 2 and g.state == ST_PLAYING:
		var before := _counts(g.park.queue, g.park.qpos)
		g.use_booster("shuffle")
		await _wait(0.1)
		_check(BM.count("shuffle") == 0, "SHUFFLE consumed")
		_check(_counts(g.park.queue, g.park.qpos).size() <= before.size(), "SHUFFLE kept the passenger colours")
	# Booster at 0 opens the buy popup.
	SM.close_all_modals()
	S.game()["boosters"]["extra_bay"] = 0
	g.extra_used = false
	g.state = ST_PLAYING
	CM.add_coins(500)
	g.use_booster("extra_bay")
	await _wait(0.1)
	var bp: Control = SM.find_modal("buy_booster")
	_check(bp != null, "booster at 0 opens buy / watch-ad popup (state %d)" % g.state)
	if bp:
		var coins_before: int = CM.get_coins()
		bp.press("buy")
		await _wait(0.1)
		_check(CM.get_coins() == coins_before - BM.price("extra_bay"), "bought a booster with coins")
	SM.close_all_modals()


## Cones vanish on screen after 3 buses leave (animation callback path).
func _test_cones_clear_in_view() -> void:
	var lvl_n := -1
	for n in range(30, 80):
		if (LevelGenerator.generate(n).get("twists", []) as Array).has("cones"):
			lvl_n = n
			break
	_check(lvl_n > 0, "found a level with cones (%d)" % lvl_n)
	_fresh(lvl_n)
	var g := await _open_level(lvl_n)
	_check(not g.view.cone_scale.is_empty(), "cones drawn at the start")
	for id in g.level_data["solution"]:
		if g.park.exits >= 3:
			break
		if bool(g.park.bus(int(id))["sleep"]):
			g.tap_bus(int(id))
			await _wait(0.4)
		g.tap_bus(int(id))
		await _wait(0.4)
	await _wait(1.2)
	_check(g.park.cones.is_empty() and g.view.cone_scale.is_empty(), "cones cleared in the rules and on screen (L%d exits %d, cones %s, drawn %s, state %d)" % [lvl_n, g.park.exits, g.park.cones, g.view.cone_scale, g.state])
	g.state = ST_FAILED
	S.game()["in_progress_level"] = null


func _test_resume() -> void:
	_fresh(21)
	var g := await _open_level(21)
	var id: int = int(g.level_data["solution"][0])
	if bool(g.park.bus(id)["sleep"]):
		g.tap_bus(id)
		await _wait(0.4)
	g.tap_bus(id)
	await _wait(0.7)
	var snap: Dictionary = g.park.to_dict()
	_check(S.game()["in_progress_level"] != null, "board saved after a move (debounced) (state %d moves %d playing %s modal %s)" % [g.state, g.moves, g.is_playing(), SM.top_modal()])
	# Simulate the app being killed: reload the save file from disk.
	S.load_game()
	change_scene_to_file(HUB)
	await _wait(0.4)
	var g2 := await _open_level(21)
	_check(JSON.stringify(g2.park.to_dict()["buses"]) == JSON.stringify(snap["buses"]), "resume restores the buses exactly")
	_check(g2.park.qpos == int(snap["qpos"]) and g2.moves == 1, "resume restores the queue and move count")
	_check(LM.lives() == 5, "resuming costs no life")


func _test_leave_costs_life() -> void:
	var g: Node = current_scene
	var before: int = LM.lives()
	g.leave_level("home")
	await _wait(0.1)
	var c: Control = SM.find_modal("confirm")
	_check(c != null, "leaving after a move asks first")
	c.press("yes")
	await _wait(0.9)
	_check(LM.lives() == before - 1, "leaving after a move costs 1 life")
	_check(current_scene.scene_file_path == HUB, "back at the hub")


func _test_hub_and_back() -> void:
	SM.close_all_modals()
	SM.hub_tab = "home"
	change_scene_to_file(HUB)
	await _wait(0.6)
	var hub := current_scene
	_check(hub.current == 1, "hub opens on Home")
	hub.select_tab(0)
	await _wait(0.3)
	_check(hub.current == 0, "tab switch to Shop")
	GM.handle_back()
	await _wait(0.3)
	_check(hub.current == 1, "back from Shop returns Home")
	GM.handle_back()
	await _wait(0.1)
	_check(SM.find_modal("confirm") != null, "back on Home asks to quit")
	SM.close_all_modals()
	# Two taps from launch: Home PLAY starts the level.
	S.game()["lives"] = 5
	hub.home.play_button.pressed.emit()
	await _wait(1.0)
	_check(current_scene.scene_file_path == GAMEPLAY, "PLAY opens the level")
	var g := current_scene
	await _wait(1.0)
	GM.handle_back()
	await _wait(0.1)
	_check(SM.find_modal("pause") != null and paused, "back in a level opens Pause (game paused)")
	SM.close_all_modals()
	await _wait(0.1)
	_check(not paused, "closing pause resumes")
	g.state = ST_FAILED


func _test_ads() -> void:
	AD.reset_session_state()
	var got := [0]
	AD.mock_fail_rate = 0.0
	AD.show_rewarded("test", func(ok: bool) -> void: got[0] = 1 if ok else -1)
	await _wait(0.4)
	_check(got[0] == 1, "rewarded ad success path calls back true")
	AD.mock_fail_rate = 1.0
	AD.show_rewarded("test", func(ok: bool) -> void: got[0] = 1 if ok else -1)
	await _wait(0.4)
	_check(got[0] == -1, "rewarded ad failure path calls back false")
	AD.mock_fail_rate = 0.0
	for i in 5:
		AD.on_run_finished()
	_check(not AD.can_show_interstitial(), "no ads between levels (interstitials are off)")
	_check(AD.pick_provider(true, false) == "admob" and AD.pick_provider(false, true) == "mock" and AD.pick_provider(false, false) == "none", "ad backend: AdMob on phones, fake ad only in debug builds, none otherwise")
	_check(AD.ad_unit_id(false) == "" and AD.ad_unit_id(true) == "", "no ad unit on desktop")
	var keep_kind: String = AD.kind
	AD.kind = "none"
	var res := [0]
	AD.show_rewarded("test", func(ok: bool) -> void: res[0] = 1 if ok else -1)
	_check(res[0] == -1 and not AD.is_rewarded_ready(), "release build without AdMob: no fake reward")
	AD.kind = keep_kind


func _test_shop_iap_achievements() -> void:
	S.data = S.defaults()
	IAP.auto_confirm = true
	_check(not IAP.store_allowed("android", false, false, false) and not IAP.store_allowed("android", true, false, false), "no real-money store on Android")
	_check(not IAP.store_allowed("ios", false, false, false), "release iOS without StoreKit: no fake purchases")
	_check(IAP.store_allowed("ios", false, true, false) and IAP.store_allowed("ios", true, false, false), "iOS store with StoreKit (or in debug builds)")
	_check(not IAP.store_enabled(), "desktop: coin packs hidden")
	IAP.store_override = true
	var ok := [false]
	IAP.buy("coins_small", func(r: bool) -> void: ok[0] = r)
	_check(ok[0] and CM.get_coins() == 500, "mock IAP grants coins")
	_check(PM.buy_cosmetic("horn_pompom") and PM.selected_cosmetic("horn") == "horn_pompom", "buy + select a horn")
	_check(CM.get_coins() == 460, "cosmetic cost charged")
	_check(not PM.buy_cosmetic("theme_snow"), "can't buy what you can't afford")
	S.add_game_stat("buses_sent", 1)
	ACH.refresh()
	_check(ACH.can_claim("first_departure"), "First Departure achievement claimable")
	var r: Dictionary = ACH.claim("first_departure")
	_check(int(r.get("coins", 0)) == 20 and CM.get_coins() == 480, "achievement reward claimed")
	_check(not ACH.can_claim("first_departure"), "no double claims")
	S.set_game_stat("crane_free_wins", 20)
	ACH.refresh()
	_check(ACH.can_claim("crane_free"), "Crane-free achievement tracks wins")
	_check(ACH.definitions().size() >= 10, "10-12 achievements")


# --- Modal stack: only the top popup shows -------------------------------------

func _test_modal_stack() -> void:
	SM.close_all_modals()
	paused = false
	change_scene_to_file(HUB)
	await _wait(0.5)
	var pops = load(POPUPS)
	var a: Control = pops.show({"id": "stack_a", "title": "A", "body": "a", "closable": true})
	var b: Control = pops.show({"id": "stack_b", "title": "B", "body": "b", "closable": true})
	_check(not a.visible and b.visible and SM.top_modal() == b, "popup B on top of A: A hidden, B shown")
	GM.handle_back()
	await _wait(0.1)
	_check(SM.find_modal("stack_b") == null and SM.find_modal("stack_a") == a, "back closes only the top popup")
	_check(a.visible, "closing B shows A again")
	_check(a.get_meta("ribbon") != null and (a.get_meta("ribbon") as Control).is_inside_tree(), "A comes back as it was (not rebuilt)")
	# Overlay flag: kept visible together with the popup under it.
	var c := Control.new()
	c.set_meta("modal_overlay", true)
	c.set_meta("popup_id", "stack_c")
	SM.push_modal(c)
	_check(a.visible and c.visible, "an overlay modal keeps the popup below visible")
	var d: Control = pops.show({"id": "stack_d", "title": "D", "body": "d"})
	_check(d.visible and not c.visible and not a.visible, "a real popup over an overlay hides both below")
	d.queue_free()
	await _wait(0.1)
	_check(a.visible and c.visible and SM.top_modal() == c, "a popup freed directly restores the stack")
	SM.close_all_modals()
	await _wait(0.1)
	# The real chain: Settings -> Credits.
	current_scene.open_settings()
	await _wait(0.2)
	var settings: Control = SM.find_modal("settings")
	pops.credits()
	await _wait(0.2)
	var credits: Control = SM.find_modal("credits")
	_check(settings != null and credits != null and not settings.visible and credits.visible, "Settings -> Credits: only Credits shows")
	credits.press("ok")
	await _wait(0.1)
	_check(settings.visible and SM.top_modal() == settings, "closing Credits shows Settings again")
	SM.close_all_modals()
	# Rescue popup -> buy booster -> cancel brings the rescue back.
	_fresh(24)
	S.game()["boosters"] = {"crane": 0, "extra_bay": 0, "shuffle": 0}
	var g := await _open_level(24)
	await _force_fail(g)
	var waited := 0.0
	while SM.find_modal("out_of_bays") == null and waited < 8.0:
		await _wait(0.2)
		waited += 0.2
	var oob: Control = SM.find_modal("out_of_bays")
	if oob:
		oob.press("extra_bay")
		await _wait(0.2)
		var buy: Control = SM.find_modal("buy_booster")
		_check(buy != null and buy.visible and SM.find_modal("out_of_bays") == null, "rescue -> buy booster popup")
		GM.handle_back()
		await _wait(0.5)
		var back: Control = SM.find_modal("out_of_bays")
		_check(back != null and back.visible and g.state == ST_FAILING, "cancelling the purchase brings the rescue back")
	else:
		_check(false, "rescue popup appeared for the buy-cancel test")
	g.state = ST_FAILED
	SM.close_all_modals()
	S.game()["in_progress_level"] = null


# --- Daily tasks and the Daily Jam ---------------------------------------------

func _test_daily_tasks() -> void:
	var DM := root.get_node("DailyManager")
	S.data = S.defaults()
	DM.date_override = "2026-10-02"
	DM.refresh()
	var tasks: Array = DM.tasks()
	_check(tasks.size() == 3, "3 daily tasks a day")
	var ids: String = str(tasks.map(func(t: Dictionary) -> String: return String(t["id"])))
	S.game()["daily"]["date"] = ""
	DM.refresh()
	_check(str(DM.tasks().map(func(t: Dictionary) -> String: return String(t["id"]))) == ids, "same date, same tasks")
	_check(not DM.can_claim(0) and DM.claimable_count() == 0, "fresh tasks aren't claimable")
	for t in DM.tasks():
		_check(int(t["target"]) <= 60, "daily task '%s' is easy (target %d)" % [t["text"], int(t["target"])])
		S.add_game_stat(String(DM._def(String(t["id"]))["stat"]), int(t["target"]))
	_check(DM.claimable_count() == 3, "doing the tasks makes them claimable")
	var coins: int = CM.get_coins()
	var boosters: int = BM.count("crane") + BM.count("extra_bay") + BM.count("shuffle")
	for i in 3:
		_check(not DM.claim_task(i).is_empty(), "claim daily task %d" % i)
	_check(CM.get_coins() > coins or BM.count("crane") + BM.count("extra_bay") + BM.count("shuffle") > boosters, "task rewards granted")
	_check(DM.claim_task(0).is_empty(), "no double claims")
	_check(DM.chest_ready(), "bonus chest opens when all 3 are claimed")
	_check(not DM.claim_chest().is_empty() and DM.chest_claimed(), "bonus chest claimed")
	DM.date_override = "2026-10-03"
	DM.refresh()
	_check(DM.claimable_count() == 0 and not DM.chest_claimed() and not bool(DM.tasks()[0]["done"]), "a new day brings fresh tasks")
	# Streaks: count while the last jam was today or yesterday.
	S.game()["daily"]["challenge_date"] = "2026-10-02"
	S.game()["daily"]["streak"] = 3
	_check(DM.streak() == 3, "streak still alive the next day")
	DM.date_override = "2026-10-05"
	_check(DM.streak() == 0, "streak resets after a missed day")


func _test_daily_jam() -> void:
	var DM := root.get_node("DailyManager")
	S.data = S.defaults()
	DM.date_override = "2026-10-04"
	DM.refresh()
	S.game()["lives"] = 0
	S.game()["tutorial_steps"] = {"twist_sleep": true, "twist_cones": true, "twist_covered": true, "twist_tunnel": true}
	var a: Dictionary = DM.challenge_level()
	_check(JSON.stringify(a) == JSON.stringify(DM.challenge_level()) and (a["buses"] as Array).size() >= 10, "Daily Jam level is fixed for the day")
	SM.play_mode = "daily"
	var g := await _open_level(30)
	_check(g.is_daily and g.level_label.text == "Daily Jam", "Daily Jam opens with 0 lives")
	_check(not g.costs_life(), "Daily Jam never costs lives")
	var reward: int = DM.challenge_reward()
	var coins: int = CM.get_coins()
	for id in g.level_data["solution"]:
		var guard := 0
		while g.park.bus(int(id))["state"] == "lot" and guard < 60 and g.state != ST_WON:
			guard += 1
			if g.is_playing() and not g.view.is_bus_busy(int(id)):
				g.tap_bus(int(id))
			await _wait(0.15)
	var waited := 0.0
	while SM.find_modal("win") == null and waited < 20.0:
		await _wait(0.2)
		waited += 0.2
	_check(g.state == ST_WON and SM.find_modal("win") != null, "Daily Jam won")
	_check(DM.challenge_done_today() and DM.streak() == 1, "Daily Jam recorded with a streak")
	_check(CM.get_coins() == coins + reward, "Daily Jam reward paid (%d)" % reward)
	_check(PM.current_level() == 30, "Daily Jam doesn't move the level on")
	_check(S.game()["in_progress_daily"] == null and S.game()["in_progress_level"] == null, "Daily Jam doesn't touch the level resume slot")
	SM.close_all_modals()
	SM.play_mode = "level"
	DM.date_override = ""


func _test_save_load() -> void:
	S.data = S.defaults()
	CM.add_coins(123)
	S.data["current_level"] = 42
	S.set_setting("music", false)
	S.game()["profile"]["name"] = "Saathi"
	S.save_game()
	S.data = {}
	S.load_game()
	_check(CM.get_coins() == 123 and int(S.data["current_level"]) == 42, "coins and level survive save/load")
	_check(not S.get_setting("music") and String(S.game()["profile"]["name"]) == "Saathi", "settings and profile survive save/load")
	_check(not FileAccess.file_exists(TEST_SAVE.get_basename() + ".tmp"), "atomic write leaves no temp file")
	S.set_setting("music", true)


func _test_corrupt_and_migration() -> void:
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	S.load_game()
	_check(int(S.data["current_level"]) == 1, "corrupt save starts from defaults")
	_check(FileAccess.file_exists(S.corrupt_path()), "corrupt save backed up")
	var old := {"coins": 7, "lives": 2, "boosters": {"crane": 9}}
	var m: Dictionary = S._merge(S.defaults(), S.migrate(old))
	_check(int(m["game"]["lives"]) == 2 and int(m["game"]["boosters"]["crane"]) == 9 and m.has("statistics"), "v0 save migrates and merges over defaults")


func _test_layout_aspects() -> void:
	for h in [1920.0, 2400.0]:
		for lvl in [1, 60, 200, 900]:
			var p := Park.from_level(LevelGenerator.generate(lvl))
			var view = load("res://scripts/gameplay/park_view.gd").new()
			view.park = p
			view.width = 1080.0
			view.top = 176.0 + (60.0 if h > 2000.0 else 0.0)
			view.bottom = h - 300.0 - (40.0 if h > 2000.0 else 0.0)
			view._layout()
			var ok: bool = view.cell >= 60.0 and view.ring.position.x >= 0.0 and view.ring.end.x <= 1080.0 and view.ring.end.y <= view.bottom + 4.0 and view.ring.position.y >= view.bays_top + view.bay_h - 1.0
			_check(ok, "layout fits at 1080x%d for level %d (cell %.0f)" % [int(h), lvl, view.cell])
			view.free()


func _test_hooks() -> void:
	var log: Array = AU.played_log
	for id in ["button_click", "drive", "hop", "door", "depart", "level_complete", "coin_pickup", "failure"]:
		_check(log.has(id), "audio hook '%s' fired" % id)
	_check(HM.fired_count > 0, "haptics fired")
	_check(VFX.shake_count > 0 and VFX.sparkle_count > 0, "screen shake and particles fired")
	_check(POOL.created_count > 0, "pooled objects were used")


# --- Helpers -----------------------------------------------------------------

func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		_fail(what)


func _fail(what: String) -> void:
	failures.append(what)
	print("FAIL: ", what)


func _remove_test_files() -> void:
	for p in [TEST_SAVE, TEST_SAVE.get_basename() + ".corrupt.json", TEST_SAVE.get_basename() + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _finish() -> void:
	SM.close_all_modals()
	paused = false
	change_scene_to_file("res://tests/empty.tscn")
	await _wait(0.3)
	_remove_test_files()
	if failures.is_empty():
		print("SMOKE TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("SMOKE TEST FAILED: %d of %d checks" % [failures.size(), checks])
		quit(1)
