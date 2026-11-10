extends SceneTree
## Records one short: run by make_shorts.py under Godot's Movie Maker.
##   -- --job=<job.json> --log=<frames.json>
## Uses a throwaway save, never the player's.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var job_path := ""
	var log_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--job="):
			job_path = a.substr(6)
		elif a.begins_with("--log="):
			log_path = a.substr(6)
	# Loaded at runtime: --script files can't name game classes directly.
	var director: Node = load("res://tools/shorts/shorts_director.gd").new()
	director.job = JSON.parse_string(FileAccess.get_file_as_string(job_path))
	director.log_path = log_path
	root.add_child(director)
	await director.run()
	quit(0)
