extends SceneTree
## Records a gameplay video with Godot's Movie Maker (frame-perfect, with the
## game's own sound). Use tools/make_videos.sh, which also encodes the MP4s.
##
##   godot --path . --screen 1 --resolution 1080x1920 --write-movie /tmp/raw.avi \
##         --fixed-fps 60 --script res://tools/record_video.gd -- --cut=promo
##
## Uses a throwaway save, never the player's.

var cut := "promo"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cut="):
			cut = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# Loaded at runtime: --script files can't name game classes directly.
	var director: Node = load("res://tools/video_director.gd").new()
	director.cut = cut
	root.add_child(director)
	await director.run()
	quit(0)
