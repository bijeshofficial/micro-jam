extends Node
## Canva art for the store, rendered offscreen from the game's own drawing
## code: transparent cut-outs (logo, buses, conductor, passengers) and a
## draft Play feature graphic (1024x500). App icons: tools/import_icon.py.
## Driven by tools/store_shots.gd -- --art.


## Renders a node tree into an offscreen viewport and saves it.
func _render(size: Vector2i, build: Callable, path: String, transparent: bool) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	build.call(vp)
	for i in 6:
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	if not transparent:
		img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(path))
	print("  ", path.get_file(), "  ", img.get_size())
	vp.queue_free()
	await get_tree().process_frame


func _drawer(vp: SubViewport, fn: Callable) -> Node2D:
	var n := Node2D.new()
	n.draw.connect(fn.bind(n))
	vp.add_child(n)
	return n


func export_all(out: String) -> void:
	var art := out + "art/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(art))
	print("rendering Canva art")
	# Transparent cut-outs.
	await _render(Vector2i(1400, 760), func(vp: SubViewport) -> void:
		_drawer(vp, func(n: Node2D) -> void: GameLogo.draw(n, Vector2(700, 40), 2.4, 0.0)), art + "logo_micro_jam.png", true)
	await _render(Vector2i(1500, 760), func(vp: SubViewport) -> void:
		_drawer(vp, func(n: Node2D) -> void:
			BusArt.draw_bus(n, Vector2(750, 400), 420, 3, Park.RIGHT, Color("e63946"), {"name": "Mero Gadi", "livery": "stripes", "arrow": false})), art + "bus_hero_red.png", true)
	await _render(Vector2i(1600, 900), func(vp: SubViewport) -> void:
		_drawer(vp, func(n: Node2D) -> void:
			BusArt.draw_bus(n, Vector2(520, 280), 230, 3, Park.RIGHT, Color("1d7fe0"), {"name": "Sathi", "livery": "zigzag", "arrow": false})
			BusArt.draw_bus(n, Vector2(1080, 420), 230, 2, Park.LEFT, Color("ffc300"), {"name": "Ramailo", "livery": "flowers", "arrow": false})
			BusArt.draw_bus(n, Vector2(700, 660), 230, 3, Park.RIGHT, Color("e63946"), {"name": "Mero Gadi", "livery": "stripes", "arrow": false})), art + "bus_trio.png", true)
	await _render(Vector2i(700, 1000), func(vp: SubViewport) -> void:
		_drawer(vp, func(n: Node2D) -> void: PeopleArt.draw_khalasi(n, Vector2(330, 960), 600, 1.0, "cheer", 0.0)), art + "khalasi_conductor.png", true)
	await _render(Vector2i(1500, 520), func(vp: SubViewport) -> void:
		_drawer(vp, func(n: Node2D) -> void:
			for i in 6:
				PeopleArt.draw_passenger(n, Vector2(150 + i * 240, 490), 400, GameData.bus_color([0, 1, 2, 3, 6, 7][i]), i * 7 + 3, "everyday", i == 4)), art + "passengers.png", true)
	# Play feature graphic. The app icons come from the designed artwork:
	# python3 tools/import_icon.py <folder> (see docs/store/README.md).
	await _render(Vector2i(1024, 500), _build_feature, art + "feature_graphic_1024x500.png", false)


func _build_feature(vp: SubViewport) -> void:
	var bd := ParkBackdrop.new()
	bd.theme_id = "theme_morning"
	bd.horizon = 0.66
	bd.town = false
	bd.size = Vector2(1024, 500)
	vp.add_child(bd)
	_drawer(vp, func(n: Node2D) -> void:
		n.draw_rect(Rect2(0, 330, 1024, 170), Color("8e97ab"))
		for k in 7:
			n.draw_rect(Rect2(30 + k * 150, 420, 80, 10), Color(1, 1, 1, 0.8))
		GameLogo.draw(n, Vector2(270, -10), 0.95, 0.0)
		BusArt.draw_bus(n, Vector2(640, 250), 100, 3, Park.RIGHT, Color("1d7fe0"), {"name": "Sathi", "livery": "zigzag", "arrow": false})
		BusArt.draw_bus(n, Vector2(700, 395), 115, 3, Park.LEFT, Color("e63946"), {"name": "Mero Gadi", "livery": "stripes", "arrow": false})
		BusArt.draw_bus(n, Vector2(470, 330), 100, 2, Park.RIGHT, Color("ffc300"), {"name": "Ramailo", "livery": "flowers", "arrow": false})
		for i in 5:
			PeopleArt.draw_passenger(n, Vector2(60 + i * 58, 480), 115, GameData.bus_color([0, 1, 2, 3, 6][i]), i * 7 + 3)
		PeopleArt.draw_khalasi(n, Vector2(925, 480), 160, 1.0, "cheer", 0.0))
