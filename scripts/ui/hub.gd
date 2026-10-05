class_name Hub
extends Control
## Hub screen: top bar (lives, coins, settings), three pages (Shop | Home |
## Profile) that slide horizontally, and the bottom navigation. Swipe
## left/right or tap a tab. Back: other tab -> Home; Home -> quit prompt.

const TAB_NAMES := ["shop", "home", "profile"]

var current := 1
var pages: Array[Control] = []
var home: HomePage
var shop: ShopPage
var profile: ProfilePage
var nav: BottomNav
var coin_chip: CoinChip
var lives_chip: LivesChip
var backdrop: GameBackdrop
## Heights of the floating top bar and bottom dock (pages pad by these).
var top_h := 0.0
var nav_h := 0.0

var _page_area: Control
var _swipe_start := Vector2.ZERO
var _swipe_time := 0
var _swiping := false


func _ready() -> void:
	VFXManager.toast_anchor = "top"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = GameBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	top_h = UIKit.safe_top() + 150.0
	nav_h = BottomNav.HEIGHT + UIKit.safe_bottom()

	# Pages fill the whole screen; the bars float on top.
	_page_area = Control.new()
	_page_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_area.clip_contents = true
	_page_area.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_page_area)
	shop = ShopPage.new()
	home = HomePage.new()
	profile = ProfilePage.new()
	pages = [shop, home, profile]
	for p in pages:
		p.set_meta("top_pad", top_h)
		p.set_meta("bottom_pad", nav_h)
		_page_area.add_child(p)
	_page_area.resized.connect(_place_pages)

	# Top bar: a soft dark fade so the pills read over the map.
	var shade := Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = top_h + 40.0
	shade.draw.connect(func() -> void:
		var h := shade.size.y
		shade.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(shade.size.x, 0), Vector2(shade.size.x, h), Vector2(0, h)]),
			PackedColorArray([Color(0.04, 0.07, 0.25, 0.55), Color(0.04, 0.07, 0.25, 0.55), Color(0.04, 0.07, 0.25, 0.0), Color(0.04, 0.07, 0.25, 0.0)])))
	add_child(shade)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_top", int(UIKit.safe_top()) + 22)
	top.add_theme_constant_override("margin_left", 26)
	top.add_theme_constant_override("margin_right", 26)
	add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	top.add_child(bar)
	lives_chip = LivesChip.new()
	bar.add_child(lives_chip)
	bar.add_child(UIKit.hspacer())
	coin_chip = CoinChip.new()
	coin_chip.plus_pressed.connect(func() -> void: select_tab(0))
	bar.add_child(coin_chip)
	var gear := UIKit.button("", "secondary", "gear", 50, Vector2(108, 108))
	gear.pressed.connect(open_settings)
	bar.add_child(gear)

	nav = BottomNav.new()
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -nav_h
	nav.tab_selected.connect(select_tab)
	add_child(nav)

	shop.changed.connect(_refresh_dots)
	profile.changed.connect(_refresh_dots)
	AchievementManager.claimable_changed.connect(_on_claimable_changed)
	ProgressionManager.cosmetic_changed.connect(_on_cosmetic_changed)
	SaveManager.progress_reset.connect(_rebuild)
	DailyManager.changed.connect(_refresh_dots)

	current = maxi(0, TAB_NAMES.find(ScreenManager.hub_tab))
	nav.select(current, false)
	_place_pages()
	_refresh_dots()
	AdManager.banner_opportunity("hub")
	# Prepare the next level while the player looks around.
	ProgressionManager.prefetch(ProgressionManager.current_level())
	AudioManager.set_ambient("hub")


func _on_claimable_changed(_n: int) -> void:
	_refresh_dots()


func _on_cosmetic_changed(_c: String, _i: String) -> void:
	home.refresh()


func _rebuild() -> void:
	home.refresh()
	shop.build()
	profile.build()
	_refresh_dots()


func _refresh_dots() -> void:
	nav.set_dot(0, ShopPage.daily_available())
	nav.set_dot(1, DailyManager.claimable_count() > 0 or not DailyManager.challenge_done_today())
	nav.set_dot(2, AchievementManager.claimable_count() > 0)
	if home:
		home.refresh_badges()


func _place_pages(animate: bool = false) -> void:
	var w := _page_area.size.x
	for i in pages.size():
		var p := pages[i]
		p.size = _page_area.size
		var target := Vector2((i - current) * w, 0)
		if animate:
			var tw := p.create_tween()
			tw.tween_property(p, "position", target, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			p.position = target


func select_tab(index: int) -> void:
	index = clampi(index, 0, pages.size() - 1)
	if index == current:
		return
	current = index
	ScreenManager.hub_tab = TAB_NAMES[index]
	nav.select(index)
	_place_pages(true)
	match index:
		0:
			shop._refresh_buttons()
		1:
			home.refresh()
		2:
			profile.build()
	_refresh_dots()


func open_settings() -> void:
	ScreenManager.push_modal(load("res://scenes/ui/settings.tscn").instantiate())


## Horizontal swipe between tabs (does not consume the event, so vertical
## scrolling and button taps keep working).
func _input(event: InputEvent) -> void:
	if ScreenManager.has_modal() or ScreenManager.is_busy():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
			_swipe_time = Time.get_ticks_msec()
			_swiping = true
		elif _swiping:
			_swiping = false
			var d: Vector2 = event.position - _swipe_start
			var dt := Time.get_ticks_msec() - _swipe_time
			if absf(d.x) > 170.0 and absf(d.x) > absf(d.y) * 1.6 and dt < 700:
				select_tab(current + (1 if d.x < 0 else -1))


func on_back() -> void:
	if current != 1:
		select_tab(1)
		return
	Popups.confirm("Leave the bus park?", "Your progress is saved.", "Quit", GameManager.quit_game, "danger", "Stay")
