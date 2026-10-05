extends SceneTree
## Builds res://assets/ui/game_theme.tres, the project-wide Theme:
## Titan One everywhere, outlined labels, chunky 3D buttons (thick darker
## bottom edge, pressed state sinks), rounded panels and invisible scrollbars.
##   godot --headless --path . --script res://tools/build_theme.gd

const OUT := "res://assets/ui/game_theme.tres"


func _initialize() -> void:
	var th := Theme.new()
	var font: FontFile = load("res://assets/fonts/TitanOne-Regular.ttf")
	th.default_font = font
	th.default_font_size = 44
	var ink := Color("1f2a48")
	var outline := Color("17213f")
	# Labels: clean dark text by default. Outlined white game text is opted
	# into per label (UIKit.title); a default outline smudges dark body text.
	th.set_color("font_color", "Label", ink)
	th.set_constant("outline_size", "Label", 0)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	th.set_constant("shadow_offset_y", "Label", 0)
	# Buttons: chunky green with a darker bottom lip; pressed sinks 8 px.
	var normal := _btn(Color("2ec27e"), Color("168a52"), 12, 0)
	var hover := _btn(Color("3fd38f"), Color("168a52"), 12, 0)
	var pressed := _btn(Color("27ad70"), Color("168a52"), 4, 8)
	var disabled := _btn(Color("c4cbd8"), Color("8590a6"), 12, 0)
	for st in [["normal", normal], ["hover", hover], ["pressed", pressed], ["hover_pressed", pressed], ["disabled", disabled], ["focus", StyleBoxEmpty.new()]]:
		th.set_stylebox(st[0], "Button", st[1])
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color(1, 1, 1, 0.9))
	th.set_color("font_outline_color", "Button", Color("0b5a33"))
	th.set_constant("outline_size", "Button", 10)
	th.set_font_size("font_size", "Button", 48)
	# Panels: white card with a blue frame.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color.WHITE
	panel.set_corner_radius_all(40)
	panel.border_color = Color("1d5fb8")
	panel.set_border_width_all(8)
	panel.border_width_bottom = 16
	panel.shadow_color = Color(0.03, 0.05, 0.15, 0.3)
	panel.shadow_size = 12
	panel.shadow_offset = Vector2(0, 8)
	panel.set_content_margin_all(32)
	panel.anti_aliasing = true
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Panel", panel)
	# Text fields.
	var le := StyleBoxFlat.new()
	le.bg_color = Color("f2f6fc")
	le.set_corner_radius_all(22)
	le.border_color = Color("93a6c4")
	le.set_border_width_all(4)
	le.set_content_margin_all(16)
	th.set_stylebox("normal", "LineEdit", le)
	th.set_color("font_color", "LineEdit", ink)
	# Scrollbars are never shown (swipe to scroll).
	for sb in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", sb, StyleBoxEmpty.new())
		th.set_stylebox("grabber", sb, StyleBoxEmpty.new())
		th.set_stylebox("grabber_highlight", sb, StyleBoxEmpty.new())
		th.set_stylebox("grabber_pressed", sb, StyleBoxEmpty.new())
	th.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	# Tooltips.
	var tip := panel.duplicate()
	tip.set_content_margin_all(16)
	th.set_stylebox("panel", "TooltipPanel", tip)
	var err := ResourceSaver.save(th, OUT)
	print("theme saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _btn(fill: Color, edge: Color, lip: int, sink: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(36)
	s.border_color = edge
	s.set_border_width_all(5)
	s.border_width_bottom = lip
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 18 + sink
	s.content_margin_bottom = 18
	s.expand_margin_top = -sink
	s.shadow_color = Color(0.03, 0.05, 0.15, 0.3)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 6)
	s.anti_aliasing = true
	return s
