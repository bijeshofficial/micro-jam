class_name CraneHook
extends Node2D
## The CRANE booster: a yellow boom at the top of the screen, a cable and a
## hook. While `attached`, it follows the lifted bus.

var target: BusVisual
var attached := false

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if attached and is_instance_valid(target):
		position = target.position - Vector2(0, BusArt.body_height(target.cell) + 20 + target.lift * target.cell * 0.6)
	queue_redraw()


func _draw() -> void:
	var top := -position.y - 40.0
	# Boom.
	draw_rect(Rect2(-160, top, 320, 46), Color("1f2433"))
	draw_rect(Rect2(-154, top + 6, 308, 34), Color("ffc300"))
	for k in 6:
		draw_line(Vector2(-150 + k * 52, top + 6), Vector2(-124 + k * 52, top + 40), Color("1f2433"), 5.0)
	# Cable and hook.
	draw_line(Vector2(0, top + 40), Vector2(0, -18), Color("1f2433"), 6.0, true)
	draw_rect(Rect2(-18, -26, 36, 16), Color("4a5263"))
	draw_arc(Vector2(0, 2), 16, -PI * 0.1, PI * 1.25, 14, Color("4a5263"), 8.0, true)
