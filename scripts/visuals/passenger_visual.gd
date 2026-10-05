class_name PassengerVisual
extends Node2D
## One waiting passenger (pooled). Position = feet. Walks forward in the
## queue with a little bob, hops in an arc into a bus, and folds away an
## umbrella when it reaches the front.

var color := Color.RED
var variant := 0
var outfit := "everyday"
var covered := false:
	set(v):
		covered = v
		queue_redraw()
var face := "happy":
	set(v):
		face = v
		queue_redraw()
var height := 104.0
var qi := -1

var _walk: Tween
var _bob := 0.0


func setup(index: int, col: Color, outfit_style: String, is_covered: bool, size: float) -> void:
	qi = index
	color = col
	variant = index * 7 + 3
	outfit = outfit_style
	covered = is_covered
	height = size
	face = "happy"
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	z_index = 0
	if _walk:
		_walk.kill()
	queue_redraw()


func _draw() -> void:
	PeopleArt.draw_passenger(self, Vector2(0, -_bob), height, color, variant, outfit, covered, face)


func _set_bob(v: float) -> void:
	_bob = v
	queue_redraw()


## Walks to `to` with a couple of bouncy steps.
func walk_to(to: Vector2, dur: float = 0.22, delay: float = 0.0) -> void:
	if _walk:
		_walk.kill()
	_walk = create_tween()
	if delay > 0.0:
		_walk.tween_interval(delay)
	_walk.tween_property(self, "position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_walk.parallel().tween_method(_step_bob, 0.0, 1.0, dur)
	_walk.tween_callback(_set_bob.bind(0.0))


func _step_bob(t: float) -> void:
	_set_bob(absf(sin(t * PI * 2.0)) * 10.0)


## Hop arc into a bus; calls `on_land` when it lands, then returns to the pool.
func hop_to(to: Vector2, dur: float, on_land: Callable) -> void:
	if _walk:
		_walk.kill()
	z_index = 20
	var from := position
	_walk = create_tween()
	_walk.tween_property(self, "scale", Vector2(1.15, 0.8), 0.06)
	_walk.tween_property(self, "scale", Vector2(0.9, 1.12), 0.05)
	_walk.tween_method(func(t: float) -> void:
		var x := lerpf(from.x, to.x, t)
		var y := lerpf(from.y, to.y, t) - 170.0 * 4.0 * t * (1.0 - t)
		position = Vector2(x, y)
		scale = Vector2.ONE * lerpf(1.0, 0.45, t * t), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk.tween_callback(func() -> void:
		if on_land.is_valid():
			on_land.call()
		PoolManager.release(self))


## Umbrella folds away (front of the queue).
func reveal() -> void:
	if not covered:
		return
	covered = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 0.85), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
