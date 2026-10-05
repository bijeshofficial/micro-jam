class_name BootScreen
extends Control
## Loading screen: a microbus climbs a winding mountain road; how far it has
## driven IS the progress bar (threaded scene loads + save load). Stays at
## least 1.2 s so it never flashes, with rotating tips.

const MIN_TIME := 1.2
const LOAD := ["res://scenes/main/hub.tscn", "res://scenes/gameplay/gameplay.tscn"]
const PRELOAD_SCRIPTS := ["res://scripts/ui/hub.gd", "res://scripts/gameplay/gameplay.gd", "res://scripts/gameplay/park_view.gd"]
const BUS_SCENE := preload("res://scenes/components/bus_visual.tscn")

var progress := 0.0
var _elapsed := 0.0
var _done := false
var _road: Control
var _bus: BusVisual
var _tip: Label
var _tips: Array = []
var _tip_i := 0
var _logo: Control
var _pct: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.set_ambient("hub")
	var bd := ParkBackdrop.new()
	bd.theme_id = ProgressionManager.selected_cosmetic("theme")
	bd.horizon = 0.5
	bd.town = false
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bd)
	var vp := get_viewport_rect().size
	_logo = Control.new()
	_logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.draw.connect(func() -> void: GameLogo.draw(_logo, Vector2(vp.x * 0.5, vp.y * 0.08), 1.15, _elapsed))
	add_child(_logo)
	_road = Control.new()
	_road.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_road.draw.connect(_draw_road)
	add_child(_road)
	var layer := Node2D.new()
	add_child(layer)
	_bus = BUS_SCENE.instantiate()
	_bus.setup(0, 2, Park.RIGHT, Color("e63946"), 120.0, "stripes", "Mero Gadi")
	layer.add_child(_bus)
	_bus.position = road_point(0.0)
	_pct = UIKit.title("0%", 54)
	_pct.size = Vector2(300, 70)
	add_child(_pct)
	_tips = GameData.tips()
	_tip_i = randi() % _tips.size()
	_tip = UIKit.title(_tips[_tip_i], 40)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(vp.x - 120, 0)
	_tip.position = Vector2(60, vp.y * 0.82)
	_tip.size = Vector2(vp.x - 120, 140)
	add_child(_tip)
	# Compile the screens' scripts here first: compiling GDScript on the
	# loader thread leaks a couple of objects in Godot 4.7.
	for sp in PRELOAD_SCRIPTS:
		load(sp)
	for p in LOAD:
		ResourceLoader.load_threaded_request(p)
	var tips := Timer.new()
	tips.wait_time = 2.2
	tips.autostart = true
	add_child(tips)
	tips.timeout.connect(_next_tip)


func _next_tip() -> void:
	_tip_i = (_tip_i + 1) % _tips.size()
	_tip.text = _tips[_tip_i]
	UIKit.bounce(_tip, 1.06)


## Point on the winding road at progress t (0..1).
func road_point(t: float) -> Vector2:
	var vp := get_viewport_rect().size
	var x := lerpf(-60.0, vp.x + 60.0, t)
	var y := vp.y * 0.66 - t * vp.y * 0.12 + sin(t * TAU * 1.5) * 70.0
	return Vector2(x, y)


func _draw_road() -> void:
	var pts := PackedVector2Array()
	for i in 61:
		pts.append(road_point(float(i) / 60.0) + Vector2(0, 30))
	_road.draw_polyline(pts, Color("5d5850"), 120.0, true)
	_road.draw_polyline(pts, Color("b9b2a6"), 100.0, true)
	# Driven part glows gold (the progress bar).
	var done := PackedVector2Array()
	var n := int(progress * 60.0)
	for i in n + 1:
		done.append(road_point(float(i) / 60.0) + Vector2(0, 30))
	if done.size() >= 2:
		_road.draw_polyline(done, Color("ffc300"), 20.0, true)
	for i in range(n, 60, 2):
		_road.draw_line(pts[i], pts[i + 1], Color(1, 1, 1, 0.8), 8.0, true)
	# Bus-stop flag at the end of the road.
	var end := road_point(1.0) + Vector2(-110, -40)
	_road.draw_line(end, end + Vector2(0, 90), Color("4a5263"), 8.0)
	_road.draw_circle(end, 34, Color("17213f"), true, -1.0, true)
	_road.draw_circle(end, 28, UIKit.PRIMARY, true, -1.0, true)


func _process(delta: float) -> void:
	_logo.queue_redraw()
	if _done:
		return
	_elapsed += delta
	var real := 0.0
	for p in LOAD:
		var arr := []
		var st := ResourceLoader.load_threaded_get_status(p, arr)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			real += 1.0
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not arr.is_empty():
			real += float(arr[0])
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			real += 1.0
	# The save is loaded by the SaveManager autoload before this scene exists.
	real = (real + 1.0) / (LOAD.size() + 1.0)
	var shown := minf(real, _elapsed / MIN_TIME)
	progress = maxf(progress, shown)
	var p := road_point(progress)
	var ahead := road_point(minf(1.0, progress + 0.02))
	_bus.position = p
	_bus.rotation = clampf((ahead - p).angle(), -0.35, 0.35) * 0.6
	_pct.text = "%d%%" % int(progress * 100.0)
	_pct.position = p + Vector2(-150, -190)
	_road.queue_redraw()
	if progress >= 1.0 and _elapsed >= MIN_TIME + 0.25:
		_done = true
		AudioManager.horn()
		for path in LOAD:
			var res := ResourceLoader.load_threaded_get(path)
			if res is PackedScene:
				ScreenManager.preloaded[path] = res
		ScreenManager.go_hub("home")
