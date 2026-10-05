class_name WeatherFX
extends Control
## Rain streaks or snowflakes over the play area (theme weather).

var kind := "rain"

var _t := 0.0
var _drops: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		_drops.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var W := size.x
	var H := size.y
	for d in _drops:
		var v: Vector3 = d
		if kind == "snow":
			var y := fposmod(v.y * H + _t * 110.0 * v.z, H + 20.0) - 10.0
			var x := fposmod(v.x * W + sin(_t * v.z + v.x * 10.0) * 30.0, W)
			draw_circle(Vector2(x, y), 4.0 * v.z, Color(1, 1, 1, 0.75), true, -1.0, true)
		else:
			var y := fposmod(v.y * H + _t * 1300.0 * v.z, H + 60.0) - 30.0
			var x := fposmod(v.x * W - y * 0.18, W)
			draw_line(Vector2(x, y), Vector2(x - 6, y + 34 * v.z), Color(0.85, 0.9, 1.0, 0.35), 3.0, true)
