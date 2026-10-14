extends SceneTree
## Renders the engine's startup image (assets/app_icon/splash.png) from the
## real loading screen's first frame, minus the tip text and percentage, so
## the hand-off from Godot's splash to the loading screen is seamless.
##   godot --path . --script res://tools/make_splash.gd
## Rendered offscreen at 1080x1920, so any monitor works. Re-run it after
## changing the loading screen, logo or the morning theme.

const OUT := "res://assets/app_icon/splash.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.get_node("SaveManager").set_save_path("user://splash_save.json")
	var vp := SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var boot: Control = load("res://scenes/main/boot.tscn").instantiate()
	vp.add_child(boot)
	for i in 3:
		await process_frame
	for key in ["_pct", "_tip"]:
		var n: Control = boot.get(key)
		if n:
			n.visible = false
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT)
	var top := img.get_pixel(540, 4)
	print("wrote %s (%dx%d), top colour %s" % [OUT, img.get_width(), img.get_height(), top.to_html(false)])
	quit()
