class_name ProfilePage
extends Control
## Profile: avatar, editable name, level, stats and achievements.

signal changed

var list: VBoxContainer
var avatar: AvatarView
var name_edit: LineEdit
var claim_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 30
	add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 32)
	pad.add_theme_constant_override("margin_top", int(float(get_meta("top_pad", 150.0))))
	pad.add_theme_constant_override("margin_bottom", int(float(get_meta("bottom_pad", 200.0))) + 50)
	scroll.add_child(pad)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 24)
	pad.add_child(list)
	build()
	AchievementManager.claimed.connect(_on_claimed)


func _on_claimed(_id: String) -> void:
	build()


func build() -> void:
	for ch in list.get_children():
		ch.queue_free()
	claim_buttons.clear()
	AchievementManager.refresh()
	list.add_child(UIKit.spacer(10))
	list.add_child(_header())
	list.add_child(_stats())
	var rib := UIKit.ribbon("ACHIEVEMENTS", 700, UIKit.PURPLE, UIKit.PURPLE_EDGE, 50)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(rib)
	for a in AchievementManager.definitions():
		list.add_child(_achievement_card(a))


func _card(kind: String = "blue") -> PanelContainer:
	return UIKit.card(kind, 22, 32)


## The driver's licence card: photo, editable name, licence number and class.
func _header() -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 120
	sb.content_margin_bottom = 40
	card.add_theme_stylebox_override("panel", sb)
	card.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, card.size)
		card.draw_colored_polygon(DrawKit.rounded_rect(Rect2(r.position + Vector2(0, 14), r.size), 40, 8), Color(0.03, 0.05, 0.15, 0.3))
		card.draw_colored_polygon(DrawKit.rounded_rect(r, 40, 8), Color("17213f"))
		DrawKit.gradient_fill(card, DrawKit.rounded_rect(r.grow(-6), 34, 8), Color("fffdf5"), Color("e9f2ff"))
		# Guilloche-like wavy lines in the background.
		for k in 6:
			var pts := PackedVector2Array()
			for i in 41:
				var x := r.size.x * i / 40.0
				pts.append(Vector2(x, 160 + k * 46 + sin(i * 0.5 + k) * 10))
			card.draw_polyline(pts, Color(0.11, 0.5, 0.88, 0.08), 3.0, true)
		# Blue header band.
		var band := Rect2(6, 6, r.size.x - 12, 92)
		card.draw_colored_polygon(DrawKit.rounded_rect(band, 34, 8), UIKit.SECONDARY)
		card.draw_rect(Rect2(6, 60, r.size.x - 12, 38), UIKit.SECONDARY)
		var f := UIKit.font(true)
		card.draw_string_outline(f, Vector2(36, 70), "DRIVING LICENCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 10, Color("0a3670"))
		card.draw_string(f, Vector2(36, 70), "DRIVING LICENCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color.WHITE)
		var sub := "MICRO JAM TRANSPORT"
		var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		card.draw_string(f, Vector2(r.size.x - sw - 36, 66), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.85))
		# A hologram-ish seal.
		var sc := Vector2(r.size.x - 90, r.size.y - 80)
		for k in 3:
			card.draw_circle(sc, 46.0 - k * 12.0, Color(UIKit.GOLD, 0.35 + k * 0.2), true, -1.0, true)
		card.draw_colored_polygon(DrawKit.star(sc, 24, 10, 5), Color("fff6dc")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	card.add_child(row)
	var ab := Button.new()
	ab.flat = true
	ab.focus_mode = Control.FOCUS_NONE
	ab.custom_minimum_size = Vector2(230, 270)
	for st in ["normal", "hover", "pressed", "focus"]:
		ab.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var photo := Control.new()
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.draw.connect(func() -> void:
		var pr := Rect2(Vector2.ZERO, photo.size)
		photo.draw_colored_polygon(DrawKit.rounded_rect(pr, 20, 6), Color("17213f"))
		photo.draw_colored_polygon(DrawKit.rounded_rect(pr.grow(-6), 16, 6), Color("cfe6f7")))
	ab.add_child(photo)
	avatar = AvatarView.new()
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar.offset_left = 18
	avatar.offset_right = -18
	avatar.offset_top = 30
	avatar.offset_bottom = -42
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.index = int(SaveManager.game()["profile"]["avatar"])
	ab.add_child(avatar)
	var edit_bg := Control.new()
	edit_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit_bg.position = Vector2(160, 200)
	edit_bg.size = Vector2(76, 76)
	edit_bg.draw.connect(func() -> void: DrawKit.glossy_circle(edit_bg, Vector2(38, 38), 38, UIKit.PRIMARY, UIKit.PRIMARY_EDGE, 4.0, 5.0))
	ab.add_child(edit_bg)
	var edit := UIKit.icon("pencil", 52, Color.WHITE)
	edit.position = Vector2(172, 210)
	ab.add_child(edit)
	ab.pressed.connect(_pick_avatar)
	row.add_child(ab)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	col.add_child(UIKit.label("NAME", 30, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT))
	name_edit = LineEdit.new()
	name_edit.text = String(SaveManager.game()["profile"]["name"])
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(200, 96)
	name_edit.add_theme_font_override("font", UIKit.font(true))
	name_edit.add_theme_font_size_override("font_size", 46)
	name_edit.add_theme_color_override("font_color", UIKit.INK)
	name_edit.add_theme_stylebox_override("normal", UIKit.box(Color(1, 1, 1, 0.7), 22, UIKit.NEUTRAL_EDGE, 4, 16))
	name_edit.add_theme_stylebox_override("focus", UIKit.box(Color.WHITE, 22, UIKit.PRIMARY, 4, 16))
	name_edit.text_submitted.connect(func(_t: String) -> void: name_edit.release_focus())
	name_edit.focus_exited.connect(func() -> void: set_player_name(name_edit.text))
	col.add_child(name_edit)
	col.add_child(UIKit.label("LICENCE NO.  MJ-%05d" % (absi(hash(String(SaveManager.game()["profile"]["name"]))) % 100000), 32, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT))
	var cls := HBoxContainer.new()
	cls.add_theme_constant_override("separation", 14)
	cls.add_child(UIKit.label("CLASS", 32, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT))
	cls.add_child(UIKit.title("Level %d" % ProgressionManager.current_level(), 48, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, Color("8a4a00")))
	col.add_child(cls)
	return card


func set_player_name(value: String) -> void:
	var clean := value.strip_edges()
	if clean == "":
		clean = "Driver"
	SaveManager.game()["profile"]["name"] = clean
	SaveManager.save_game()
	if name_edit and name_edit.text != clean:
		name_edit.text = clean


func set_avatar(idx: int) -> void:
	SaveManager.game()["profile"]["avatar"] = idx
	SaveManager.save_game()
	if avatar:
		avatar.index = idx
	changed.emit()


func _pick_avatar() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var popup: GamePopup
	for i in GameData.avatars().size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 170)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var av := AvatarView.new()
		av.index = i
		av.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(av)
		b.pressed.connect(func() -> void:
			AudioManager.play("button_click")
			set_avatar(i)
			if popup:
				popup.close())
		grid.add_child(b)
	popup = Popups.show({"id": "avatars", "title": "Choose your avatar", "content": grid, "closable": true})


func _stats() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var secs := SaveManager.stat("play_time_sec")
	var play := "%dh %02dm" % [secs / 3600, (secs / 60) % 60] if secs >= 3600 else "%dm" % (secs / 60)
	var rows := [
		["Levels", str(SaveManager.game_stat("levels_completed")), "map", "blue"],
		["Buses sent", str(SaveManager.game_stat("buses_sent")), "bus", "red"],
		["Passengers", str(SaveManager.game_stat("passengers_boarded")), "profile", "green"],
		["Daily Jams", str(SaveManager.game_stat("daily_jams")), "calendar", "purple"],
		["Clean streak", str(SaveManager.game_stat("best_no_booster_streak")), "star", "gold"],
		["Play time", play, "clock", "teal"],
	]
	for r in rows:
		var c := _card(String(r[3]))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		c.add_child(hb)
		var ic := UIKit.icon(r[2], 80, Color.WHITE)
		ic.shadow = true
		ic.accent = (UIKit.CARDS[r[3]] as Array)[1]
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(v)
		v.add_child(UIKit.text(r[1], 52))
		var cap := UIKit.text(r[0], 30, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1, 0.92))
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.custom_minimum_size = Vector2(180, 0)
		v.add_child(cap)
		grid.add_child(c)
	return grid


func _achievement_card(a: Dictionary) -> Control:
	var id: String = a["id"]
	var complete := AchievementManager.is_complete(id)
	var claimed := AchievementManager.is_claimed(id)
	var card := _card("gold" if complete and not claimed else ("green" if claimed else "blue"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	row.add_child(UIKit.disk("trophy", 104, UIKit.GOLD if complete else Color("8fa8e6"), UIKit.GOLD_EDGE if complete else Color("3d4f9a")))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	col.add_child(UIKit.text(a["title"], 42))
	var desc := UIKit.text(String(a["desc"]), 30, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1, 0.94))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	col.add_child(desc)
	var prog := AchievementManager.progress(id)
	var tgt := AchievementManager.target(id)
	col.add_child(UIKit.progress_bar(float(prog) / float(tgt), UIKit.PRIMARY if not complete else Color("ffd84a"), 40, "%d / %d" % [prog, tgt]))
	col.add_child(UIKit.text("Reward: " + AchievementManager.reward_text(a.get("reward", {})), 28, HORIZONTAL_ALIGNMENT_LEFT, Color("ffe58a")))
	var btn: GameButton
	if claimed:
		btn = UIKit.button("", "primary", "check", 40, Vector2(150, 110))
		btn.disabled = true
	else:
		btn = UIKit.button("CLAIM", "primary" if complete else "neutral", "", 34, Vector2(180, 110))
		btn.disabled = not complete
		btn.pressed.connect(func() -> void: claim(id))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	claim_buttons[id] = btn
	return card


func claim(id: String) -> void:
	var reward := AchievementManager.claim(id)
	if reward.is_empty():
		return
	Popups.reward(AchievementManager.definition(id)["title"], AchievementManager.reward_text(reward), "trophy")
	changed.emit()
