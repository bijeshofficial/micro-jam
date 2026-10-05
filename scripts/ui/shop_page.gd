class_name ShopPage
extends Control
## Shop tab, styled as a bus-park ticket counter: free daily gift, coin
## packs (mock IAP), booster bundles, lives refill and cosmetics (bus
## liveries, horn sounds, passenger outfits, bus park themes).

signal changed

var list: VBoxContainer
var scroll: ScrollContainer
var cosmetic_buttons: Dictionary = {}   # id -> GameButton
var daily_button: GameButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	scroll = ScrollContainer.new()
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
	list.add_theme_constant_override("separation", 26)
	pad.add_child(list)
	build()
	CurrencyManager.coins_changed.connect(_on_coins_changed)


func _on_coins_changed(_t: int, _d: int) -> void:
	_refresh_buttons()


func build() -> void:
	for ch in list.get_children():
		ch.queue_free()
	cosmetic_buttons.clear()
	list.add_child(_counter_header())
	list.add_child(_daily_card())
	# Real-money coin packs: App Store only (see IAPManager.store_enabled).
	if IAPManager.store_enabled():
		_section("Coins")
		var packs := HBoxContainer.new()
		packs.add_theme_constant_override("separation", 18)
		list.add_child(packs)
		for p in GameData.economy()["coin_packs"]:
			packs.add_child(_coin_pack_card(p))
	_section("Boosters")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	list.add_child(grid)
	for b in GameData.economy()["bundles"]:
		grid.add_child(_bundle_card(b))
	list.add_child(_lives_card())
	for cat in GameData.cosmetic_categories():
		_section(cat["name"])
		var cg := GridContainer.new()
		cg.columns = 3
		cg.add_theme_constant_override("h_separation", 16)
		cg.add_theme_constant_override("v_separation", 16)
		list.add_child(cg)
		for item in GameData.cosmetics(cat["id"]):
			cg.add_child(_cosmetic_card(item))
	_refresh_buttons()


func _section(title: String) -> void:
	list.add_child(UIKit.spacer(6))
	var rib := UIKit.ribbon(title, 640, UIKit.SECONDARY, UIKit.SECONDARY_EDGE, 46)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(rib)


## The ticket counter window: awning, sign, a clerk waving behind the glass.
func _counter_header() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 380)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clerk := KhalasiVisual.new()
	clerk.unit = 0.9
	c.add_child(clerk)
	c.resized.connect(func() -> void: clerk.position = Vector2(c.size.x * 0.5 + 150, 330))
	c.draw.connect(func() -> void:
		var w := c.size.x
		var booth := Rect2(40, 60, w - 80, 300)
		c.draw_colored_polygon(DrawKit.rounded_rect(booth.grow(8), 30, 6), Color("17213f"))
		DrawKit.gradient_fill(c, DrawKit.rounded_rect(booth, 26, 6), Color("2f8fe8"), Color("1d5fb8"))
		var glass := Rect2(booth.position + Vector2(40, 110), Vector2(booth.size.x - 80, 170))
		c.draw_colored_polygon(DrawKit.rounded_rect(glass.grow(6), 18, 4), Color("17213f"))
		DrawKit.gradient_fill(c, DrawKit.rounded_rect(glass, 14, 4), Color("dff1ff"), Color("a9d3f2"))
		c.draw_line(glass.position + Vector2(30, 20), glass.position + Vector2(90, 20), Color(1, 1, 1, 0.8), 6.0)
		# Awning with scallops.
		var aw := Rect2(10, 20, w - 20, 70)
		var n := 10
		for k in n:
			var x0 := aw.position.x + aw.size.x * k / n
			var x1 := aw.position.x + aw.size.x * (k + 1) / n
			var col := Color("e63946") if k % 2 == 0 else Color("fff6dc")
			c.draw_rect(Rect2(x0, aw.position.y, x1 - x0, aw.size.y), col)
			c.draw_circle(Vector2((x0 + x1) * 0.5, aw.end.y), (x1 - x0) * 0.5, col, true, -1.0, true)
		c.draw_rect(Rect2(aw.position.x, aw.position.y - 8, aw.size.x, 12), Color("17213f"))
		# Sign.
		var board := Rect2(w * 0.5 - 200, 100, 400, 70)
		c.draw_colored_polygon(DrawKit.rounded_rect(board.grow(5), 16, 4), Color("17213f"))
		c.draw_colored_polygon(DrawKit.rounded_rect(board, 12, 4), UIKit.GOLD)
		var f := UIKit.font(true)
		var text := "TICKETS"
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		c.draw_string(f, Vector2(w * 0.5 - tw * 0.5, board.position.y + 54), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color("17213f"))
		# Counter ledge.
		c.draw_rect(Rect2(booth.position.x - 20, booth.end.y - 30, booth.size.x + 40, 34), Color("17213f"))
		c.draw_rect(Rect2(booth.position.x - 14, booth.end.y - 26, booth.size.x + 28, 24), UIKit.GOLD)
		# A ticket roll on the counter.
		var tr := Vector2(booth.position.x + 120, booth.end.y - 50)
		c.draw_circle(tr, 30, Color("17213f"), true, -1.0, true)
		c.draw_circle(tr, 25, Color("fff6dc"), true, -1.0, true)
		c.draw_rect(Rect2(tr.x + 10, tr.y + 8, 80, 22), Color("ffd84d")))
	return c


func _card(kind: String = "blue") -> PanelContainer:
	var p := UIKit.card(kind, 22, 32)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _daily_card() -> Control:
	var card := _card("purple")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	row.add_child(UIKit.disk("gift", 130, UIKit.PINK, UIKit.PINK_EDGE))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.text("Free daily coins", 44))
	var sub := UIKit.text("Watch a short ad for %d coins" % int(GameData.economy()["daily_free_coins"]), 32, HORIZONTAL_ALIGNMENT_LEFT, UIKit.TEXT_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	row.add_child(col)
	daily_button = UIKit.button("Watch", "gold", "ad", 38, Vector2(230, 130))
	daily_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	daily_button.pressed.connect(claim_daily)
	row.add_child(daily_button)
	return card


static func daily_available() -> bool:
	return String(SaveManager.game().get("daily_free_claimed_date", "")) != GameManager.today()


func claim_daily() -> void:
	if not daily_available():
		VFXManager.toast("Come back tomorrow for more")
		return
	AdManager.show_rewarded("daily_gift", func(ok: bool) -> void:
		if not ok:
			VFXManager.toast("Ad not available right now")
			return
		SaveManager.game()["daily_free_claimed_date"] = GameManager.today()
		CurrencyManager.add_coins(int(GameData.economy()["daily_free_coins"]))
		Popups.reward("Daily gift", "+%d coins" % int(GameData.economy()["daily_free_coins"]))
		_refresh_buttons()
		changed.emit())


func _coin_pack_card(p: Dictionary) -> Control:
	var card := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var art := CenterContainer.new()
	art.add_child(UIKit.icon("coin_pile", 130))
	v.add_child(art)
	v.add_child(UIKit.title("+%d" % int(p["coins"]), 52, Color("ffd84a"), HORIZONTAL_ALIGNMENT_CENTER, UIKit.OUTLINE))
	var name_l := UIKit.text(p["name"], 30, HORIZONTAL_ALIGNMENT_CENTER, UIKit.TEXT_SOFT)
	v.add_child(name_l)
	var b := UIKit.button(String(p.get("price_label", "")), "primary", "", 38, Vector2(0, 120))
	b.pressed.connect(func() -> void:
		IAPManager.buy(p["id"], func(ok: bool) -> void:
			if ok:
				Popups.reward("Test purchase", "+%d coins" % int(p["coins"]))))
	v.add_child(b)
	if p.has("ribbon"):
		var holder := VBoxContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_theme_constant_override("separation", -26)
		var ribbon := CenterContainer.new()
		ribbon.z_index = 2
		ribbon.add_child(UIKit.badge(String(p["ribbon"]), UIKit.DANGER, 28))
		holder.add_child(ribbon)
		holder.add_child(card)
		return holder
	return card


func _bundle_card(b: Dictionary) -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var grant: Dictionary = b["grant"]
	var icon: String = "gift" if grant.size() > 1 else BoosterManager.icon(String(grant.keys()[0]))
	row.add_child(UIKit.disk(icon, 110, UIKit.GOLD, UIKit.GOLD_EDGE))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.text(b["name"], 36))
	var btn := UIKit.button(str(int(b["price"])), "gold", "coin", 36, Vector2(0, 110))
	btn.pressed.connect(func() -> void: buy_bundle(b["id"]))
	btn.set_meta("price", int(b["price"]))
	col.add_child(btn)
	row.add_child(col)
	return card


func buy_bundle(id: String) -> bool:
	var b := GameData.bundle(id)
	if b.is_empty() or not CurrencyManager.spend(int(b["price"])):
		VFXManager.toast("Not enough coins")
		return false
	for k in (b["grant"] as Dictionary).keys():
		BoosterManager.grant(k, int(b["grant"][k]), false)
	SaveManager.save_game()
	AudioManager.play("reward")
	VFXManager.toast("%s added" % b["name"])
	return true


func _lives_card() -> Control:
	var card := _card("red")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	row.add_child(UIKit.disk("heart", 110, Color("ff8a9a"), UIKit.DANGER_EDGE))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.text("Refill lives", 44))
	col.add_child(UIKit.text("Back to %d lives now" % LivesManager.max_lives(), 32, HORIZONTAL_ALIGNMENT_LEFT, Color("ffe1e4")))
	row.add_child(col)
	var btn := UIKit.button(str(LivesManager.refill_price()), "gold", "coin", 36, Vector2(230, 120))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void:
		if LivesManager.is_full():
			VFXManager.toast("Lives are already full")
		elif LivesManager.buy_refill():
			AudioManager.play("heart")
			VFXManager.toast("Lives refilled!")
		else:
			VFXManager.toast("Not enough coins"))
	row.add_child(btn)
	return card


func _cosmetic_card(item: Dictionary) -> Control:
	var card := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var prev := Control.new()
	prev.custom_minimum_size = Vector2(0, 190)
	prev.clip_contents = true
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev.draw.connect(func() -> void: UIKit.draw_inset(prev, Rect2(Vector2.ZERO, prev.size), 22))
	v.add_child(prev)
	match String(item["category"]):
		"livery":
			prev.draw.connect(func() -> void:
				BusArt.draw_bus(prev, prev.size * 0.5 + Vector2(0, 16), 78, 3, Park.RIGHT, Color("1d7fe0"), {"livery": String(item["style"]), "name": "Sathi"}))
		"horn":
			prev.draw.connect(func() -> void:
				BusArt.draw_bus(prev, prev.size * 0.5 + Vector2(-24, 20), 70, 2, Park.RIGHT, Color("ffc300"), {"arrow": false}))
			var play := UIKit.button("", "secondary", "horn", 30, Vector2(84, 84))
			play.position = Vector2(150, 10)
			play.pressed.connect(func() -> void: AudioManager.play(String(item["sound"])))
			prev.add_child(play)
			prev.mouse_filter = Control.MOUSE_FILTER_PASS
		"outfit":
			prev.draw.connect(func() -> void:
				PeopleArt.draw_passenger(prev, Vector2(prev.size.x * 0.5 - 50, prev.size.y - 14), 150, Color("e63946"), 1, String(item["style"]))
				PeopleArt.draw_passenger(prev, Vector2(prev.size.x * 0.5 + 50, prev.size.y - 14), 150, Color("2ec27e"), 2, String(item["style"])))
		"theme":
			var bd := ParkBackdrop.new()
			bd.theme_id = item["id"]
			bd.horizon = 0.7
			bd.town = false
			bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			prev.add_child(bd)
	var name_l := UIKit.text(item["name"], 32, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(0, 76)
	v.add_child(name_l)
	var btn := UIKit.button("", "gold", "", 32, Vector2(0, 100))
	btn.pressed.connect(func() -> void: press_cosmetic(item["id"]))
	v.add_child(btn)
	cosmetic_buttons[item["id"]] = btn
	return card


func press_cosmetic(id: String) -> void:
	var item := GameData.cosmetic(id)
	if ProgressionManager.is_owned(id):
		ProgressionManager.select_cosmetic(id)
		AudioManager.play("success")
	elif CurrencyManager.can_afford(int(item["price"])):
		Popups.confirm("Buy %s?" % item["name"], "%d coins" % int(item["price"]), "Buy", func() -> void:
			if ProgressionManager.buy_cosmetic(id):
				AudioManager.play("reward")
				VFXManager.toast("%s unlocked!" % item["name"])
				_refresh_buttons()
				changed.emit())
		return
	else:
		VFXManager.toast("Not enough coins")
	_refresh_buttons()
	changed.emit()


func _refresh_buttons() -> void:
	if daily_button:
		var avail := daily_available()
		daily_button.set_label("Watch" if avail else "Tomorrow")
		daily_button.set_kind("gold" if avail else "neutral")
	for id in cosmetic_buttons.keys():
		var b: GameButton = cosmetic_buttons[id]
		var item := GameData.cosmetic(id)
		var sel: bool = ProgressionManager.selected_cosmetic(String(item["category"])) == String(id)
		if sel:
			b.set_label("Selected")
			b.set_kind("primary")
		elif ProgressionManager.is_owned(id):
			b.set_label("Select")
			b.set_kind("neutral")
		else:
			b.set_label("%d" % int(item["price"]))
			b.set_kind("gold" if CurrencyManager.can_afford(int(item["price"])) else "neutral")
