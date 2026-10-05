extends SceneTree
## A real relaunch: one process plays a move and quits, a second process
## loads the save and checks everything came back.
##   godot --headless --path . --script res://tests/relaunch_check.gd -- --phase=write
##   godot --headless --path . --script res://tests/relaunch_check.gd -- --phase=verify
## Uses user://relaunch_save.json, never the player's save.

const SAVE := "user://relaunch_save.json"
const EXPECT := "user://relaunch_expect.json"
const LEVEL := 33

var S: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = root.get_node("SaveManager")
	S.set_save_path(SAVE)
	var phase := "write"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = a.substr(8)
	if phase == "write":
		await _write()
	else:
		await _verify()


func _write() -> void:
	S.data = S.defaults()
	S.data["coins"] = 777
	S.data["current_level"] = LEVEL
	S.data["unlocked_items"] = ["livery_mountain"]
	S.data["selected_items"] = {"livery": "livery_mountain"}
	S.game()["lives"] = 3
	S.game()["boosters"] = {"crane": 4, "extra_bay": 2, "shuffle": 0}
	for k in ["twist_sleep", "twist_cones", "twist_covered", "twist_tunnel"]:
		S.game()["tutorial_steps"][k] = true
	S.set_setting("haptics", false)
	S.save_game()
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await _wait(1.4)
	var g := current_scene
	for id in g.level_data["solution"]:
		if g.park.bus(int(id))["state"] == "lot" and g.park.can_exit(int(id)):
			g.tap_bus(int(id))
			break
	await _wait(0.8)
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"park": g.park.to_dict(), "moves": g.moves}))
	f.close()
	print("RELAUNCH WRITE DONE")
	root.get_node("GameManager").quit_game()


func _verify() -> void:
	var bad: Array = []
	S.load_game()
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	if int(S.data["coins"]) != 777:
		bad.append("coins %d" % int(S.data["coins"]))
	if int(S.data["current_level"]) != LEVEL:
		bad.append("level")
	if int(S.game()["lives"]) != 3:
		bad.append("lives %d" % int(S.game()["lives"]))
	if int(S.game()["boosters"]["crane"]) != 4:
		bad.append("boosters")
	if String(S.data["selected_items"].get("livery", "")) != "livery_mountain":
		bad.append("cosmetic")
	if S.get_setting("haptics"):
		bad.append("settings")
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await _wait(1.4)
	var g := current_scene
	if _canon(g.park.to_dict()["buses"]) != _canon(expect["park"]["buses"]):
		bad.append("resumed buses differ")
	if g.park.qpos != int(expect["park"]["qpos"]) or g.moves != int(expect["moves"]):
		bad.append("resumed queue/moves differ")
	for b in bad:
		print("FAIL: ", b)
	for p in [SAVE, EXPECT]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	change_scene_to_file("res://tests/empty.tscn")
	await _wait(0.2)
	print("RELAUNCH CHECK PASSED" if bad.is_empty() else "RELAUNCH CHECK FAILED")
	quit(0 if bad.is_empty() else 1)


## Same text for ints and whole floats (JSON has no ints).
func _canon(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)))


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
