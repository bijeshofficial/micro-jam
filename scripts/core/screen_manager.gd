extends Node
## Screen changes with a bus wipe (a microbus pulls a curtain across, the
## scene swaps, a second bus pushes it off: ~0.45 s), plus a stack of modal
## overlays.

signal screen_changed(path: String)

const BOOT := "res://scenes/main/boot.tscn"
const HUB := "res://scenes/main/hub.tscn"
const GAMEPLAY := "res://scenes/gameplay/gameplay.tscn"

var current_path := ""
## Tab the hub opens on ("shop", "home", "profile").
var hub_tab := "home"
## Scenes loaded by the loading screen (path -> PackedScene).
var preloaded: Dictionary = {}

var _modal_layer: CanvasLayer
var _wipe: BusWipe
var _modals: Array[Control] = []
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 60
	add_child(_modal_layer)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_wipe = BusWipe.new()
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_wipe)


func _exit_tree() -> void:
	preloaded.clear()


func is_busy() -> bool:
	return _busy


## Swaps the scene behind the wipe. If `wait_level` > 0 the curtain stays
## down until that level has finished generating in the background (max 3 s).
func change_screen(path: String, wait_level: int = 0) -> void:
	if _busy:
		return
	_busy = true
	_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	AudioManager.play("wipe")
	var down := create_tween()
	down.tween_property(_wipe, "phase", 1.0, 0.22).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await down.finished
	close_all_modals()
	get_tree().paused = false
	if wait_level > 0:
		ProgressionManager.prefetch(wait_level)
		var waited := 0.0
		while not ProgressionManager.has_level(wait_level) and ProgressionManager.is_generating(wait_level) and waited < 3.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
	if preloaded.has(path):
		get_tree().change_scene_to_packed(preloaded[path])
	else:
		get_tree().change_scene_to_file(path)
	current_path = path
	await get_tree().process_frame
	await get_tree().process_frame
	screen_changed.emit(path)
	var up := create_tween()
	up.tween_property(_wipe, "phase", 2.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await up.finished
	_wipe.phase = 0.0
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func go_hub(tab: String = "home") -> void:
	hub_tab = tab
	change_screen(HUB)


## "level" (the next level) or "daily" (today's Daily Jam).
var play_mode := "level"


## Opens the current level (lives are checked by the caller).
func start_level() -> void:
	play_mode = "level"
	change_screen(GAMEPLAY, ProgressionManager.current_level())


## Opens today's Daily Jam (free to play, no lives).
func start_daily() -> void:
	play_mode = "daily"
	change_screen(GAMEPLAY)


## Shows a modal on top of the stack. Only the top modal is visible: the
## ones below are hidden (not rebuilt) and come back exactly as they were
## when the top one closes. A modal with the meta "modal_overlay" = true
## (a speech box, a small notice) keeps the modal below it visible too.
func push_modal(node: Control) -> Control:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	_modal_layer.add_child(node)
	_modals.append(node)
	node.tree_exited.connect(_on_modal_exited.bind(node))
	_restack()
	return node


func close_modal(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	_modals.erase(node)
	node.queue_free()
	_restack()


## Walks the stack from the top down: each modal is shown while every one
## above it is an overlay; everything below the first real modal is hidden.
## Hidden Controls get no input, and the back button only reaches the top.
func _restack() -> void:
	var show := true
	for i in range(_modals.size() - 1, -1, -1):
		var m := _modals[i]
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			continue
		m.visible = show
		if show and not bool(m.get_meta("modal_overlay", false)):
			show = false


func close_all_modals() -> void:
	for m in _modals.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	_modals.clear()


func top_modal() -> Control:
	for i in range(_modals.size() - 1, -1, -1):
		var m := _modals[i]
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			return m
	return null


func has_modal() -> bool:
	return top_modal() != null


func modal_count() -> int:
	var n := 0
	for m in _modals:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			n += 1
	return n


## Finds an open modal by its popup id (GamePopup.id) or script path.
func find_modal(key: String) -> Control:
	for m in _modals:
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			continue
		if m.has_meta("popup_id") and String(m.get_meta("popup_id")) == key:
			return m
		if m.get_script() and (m.get_script() as Script).resource_path == key:
			return m
	return null


## Back button on the top modal: its on_back() if it has one, else close it.
func handle_back_on_modal() -> bool:
	var top := top_modal()
	if top == null:
		return false
	if top.has_method("on_back"):
		top.call("on_back")
	else:
		close_modal(top)
	return true


## Also covers modals freed directly (queue_free) instead of via close_modal.
func _on_modal_exited(node: Control) -> void:
	_modals.erase(node)
	_restack()
