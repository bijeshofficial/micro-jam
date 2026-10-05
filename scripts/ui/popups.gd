class_name Popups
extends RefCounted
## Builders for the standard popups, all using GamePopup.


static func show(spec: Dictionary) -> GamePopup:
	var p := GamePopup.create(spec)
	ScreenManager.push_modal(p)
	return p


static func confirm(title: String, body: String, yes_text: String, on_yes: Callable, yes_kind: String = "primary", no_text: String = "Cancel") -> GamePopup:
	return show({
		"id": "confirm",
		"title": title,
		"body": body,
		"buttons": [
			{"id": "no", "text": no_text, "kind": "neutral"},
			{"id": "yes", "text": yes_text, "kind": yes_kind, "cb": on_yes},
		],
	})


static func reward(title: String, body: String, icon: String = "coin_pile", on_close: Callable = Callable()) -> GamePopup:
	AudioManager.play("reward")
	HapticsManager.medium()
	return show({
		"id": "reward",
		"title": title,
		"art": icon,
		"body": body,
		"body_size": 54,
		"body_heavy": true,
		"buttons": [{"id": "ok", "text": "Nice!", "kind": "primary", "icon": "check", "cb": on_close}],
		"on_back": on_close,
	})


## Lives popup: count, countdown, refill for coins, +1 via rewarded ad.
static func lives(out_of_lives: bool = false, on_refilled: Callable = Callable()) -> GamePopup:
	var full := LivesManager.is_full()
	var body := "Lives are full. Go clear some jams!" if full else "Next life in %s" % LivesManager.countdown_text()
	if out_of_lives and not full:
		body = "You're out of lives.\nNext life in %s" % LivesManager.countdown_text()
	var price := LivesManager.refill_price()
	var p := show({
		"id": "out_of_lives" if out_of_lives else "lives",
		"title": "Out of lives" if out_of_lives else "Lives: %d / %d" % [LivesManager.lives(), LivesManager.max_lives()],
		"art": "heart",
		"art_color": UIKit.HEART,
		"body": body,
		"closable": true,
		"vertical": true,
		"buttons": [
			{"id": "refill", "text": "Refill all  %d" % price, "kind": "gold", "icon": "coin", "disabled": full or not CurrencyManager.can_afford(price), "close": false, "cb": func() -> void:
				if LivesManager.buy_refill():
					AudioManager.play("heart")
					VFXManager.toast("Lives refilled!")
					ScreenManager.close_modal(ScreenManager.find_modal("out_of_lives" if out_of_lives else "lives"))
					if on_refilled.is_valid():
						on_refilled.call()
				else:
					VFXManager.toast("Not enough coins")},
			{"id": "ad", "text": "+1 life  (Watch ad)", "kind": "secondary", "icon": "ad", "disabled": full, "close": false, "cb": func() -> void:
				AdManager.show_rewarded("life", func(ok: bool) -> void:
					if ok:
						LivesManager.add_lives(1)
						AudioManager.play("heart")
						VFXManager.toast("+1 life")
						ScreenManager.close_modal(ScreenManager.find_modal("out_of_lives" if out_of_lives else "lives"))
						if on_refilled.is_valid():
							on_refilled.call()
					else:
						VFXManager.toast("Ad not available right now"))},
			{"id": "wait", "text": "Wait", "kind": "neutral"},
		],
	})
	# Keep the countdown ticking while the popup is open.
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	p.add_child(t)
	t.timeout.connect(func() -> void:
		if p.body_label:
			if LivesManager.is_full():
				p.body_label.text = "Lives are full. Go clear some jams!"
			else:
				p.body_label.text = ("You're out of lives.\n" if out_of_lives else "") + "Next life in %s" % LivesManager.countdown_text())
	return p


## Booster at zero: buy with coins or watch an ad for one.
## `on_cancel` runs when the player backs out (close, back button) or the
## free ad fails, so a caller that closed its own popup can bring it back.
static func buy_booster(id: String, on_got: Callable = Callable(), on_cancel: Callable = Callable()) -> GamePopup:
	var price := BoosterManager.price(id)
	var icon := BoosterManager.icon(id)
	var desc := BoosterManager.description(id)
	return show({
		"id": "buy_booster",
		"title": BoosterManager.display_name(id),
		"art": icon,
		"art_color": UIKit.TEAL,
		"body": desc,
		"closable": true,
		"vertical": true,
		"buttons": [
			{"id": "buy", "text": "Buy 1  %d" % price, "kind": "gold", "icon": "coin", "disabled": not CurrencyManager.can_afford(price), "cb": func() -> void:
				if BoosterManager.buy(id):
					AudioManager.play("coin_pickup")
					if on_got.is_valid():
						on_got.call()},
			{"id": "ad", "text": "Get 1 free  (Watch ad)", "kind": "secondary", "icon": "ad", "cb": func() -> void:
				AdManager.show_rewarded("booster_" + id, func(ok: bool) -> void:
					if ok:
						BoosterManager.grant(id, 1)
						VFXManager.toast("+1 %s" % BoosterManager.display_name(id))
						if on_got.is_valid():
							on_got.call()
					else:
						VFXManager.toast("Ad not available right now")
						if on_cancel.is_valid():
							on_cancel.call())},
		],
		"on_back": on_cancel,
	})


## Credits (from Settings): fonts, tools and the people behind the game.
static func credits() -> GamePopup:
	return show({
		"id": "credits",
		"title": "CREDITS",
		"art": "bus",
		"art_color": UIKit.SECONDARY,
		"body": "Micro Jam by Neuron Nest\n\nMade with Godot Engine\nFonts: Titan One by Rodrigo Fuenzalida, Baloo 2 by Ek Type (SIL Open Font License)\nArt and sounds made in code\n\nAll towns, buses and people are fictional.",
		"body_size": 40,
		"closable": true,
		"buttons": [{"id": "ok", "text": "Close", "kind": "primary", "icon": "check"}],
	})


# --- Daily -------------------------------------------------------------------

const TASK_ICONS := {"win_levels": "trophy", "send_buses": "bus", "board": "profile", "booster": "crane", "clean_win": "star", "daily_jam": "calendar"}


## Daily Tasks: three easy tasks with progress bars and CLAIM buttons, plus
## a bonus chest when all three are claimed.
static func daily_tasks() -> GamePopup:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(830, 0)
	var p := show({"id": "daily_tasks", "title": "DAILY TASKS", "content": box, "closable": true, "width": 960})
	_fill_tasks(box)
	var footer := UIKit.label("New tasks in " + DailyManager.reset_text(), 36, UIKit.INK_SOFT)
	(box.get_parent() as Control).add_child(footer)
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	p.add_child(t)
	t.timeout.connect(func() -> void: footer.text = "New tasks in " + DailyManager.reset_text())
	return p


static func _fill_tasks(box: VBoxContainer) -> void:
	for ch in box.get_children():
		ch.queue_free()
	var list := DailyManager.tasks()
	for i in list.size():
		var t: Dictionary = list[i]
		var card := UIKit.card("green" if bool(t["claimed"]) else "blue", 20, 30)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		row.add_child(UIKit.disk(String(TASK_ICONS.get(String(t["id"]), "star")), 104, UIKit.GOLD, UIKit.GOLD_EDGE))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 8)
		row.add_child(col)
		var lbl := UIKit.text(String(t["text"]), 38)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(380, 0)
		col.add_child(lbl)
		col.add_child(UIKit.progress_bar(float(t["progress"]) / float(t["target"]), UIKit.GOLD, 40, "%d / %d" % [int(t["progress"]), int(t["target"])]))
		var btn: GameButton
		if bool(t["claimed"]):
			btn = UIKit.button("", "primary", "check", 40, Vector2(170, 112))
			btn.disabled = true
		elif bool(t["done"]):
			btn = UIKit.button("CLAIM", "gold", "", 36, Vector2(170, 112))
			btn.pressed.connect(_claim_task.bind(i, box))
			UIKit.pulse(btn, 1.06, 0.9)
		else:
			btn = UIKit.button(_reward_short(t["reward"]), "secondary", _reward_icon(t["reward"]), 34, Vector2(170, 112))
			btn.disabled = true
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)
		box.add_child(card)
	# Bonus chest.
	var chest := UIKit.card("gold" if DailyManager.chest_ready() else "purple", 20, 30)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 18)
	chest.add_child(crow)
	var ic := UIKit.icon("chest", 104)
	crow.add_child(ic)
	var ccol := VBoxContainer.new()
	ccol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(ccol)
	ccol.add_child(UIKit.text("Bonus chest", 40))
	var sub := UIKit.text("Claim all 3 tasks: " + AchievementManager.reward_text(DailyManager.chest_reward()), 30, HORIZONTAL_ALIGNMENT_LEFT, UIKit.TEXT_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(380, 0)
	ccol.add_child(sub)
	var cb: GameButton
	if DailyManager.chest_claimed():
		cb = UIKit.button("", "primary", "check", 40, Vector2(170, 112))
		cb.disabled = true
	elif DailyManager.chest_ready():
		cb = UIKit.button("OPEN", "primary", "", 38, Vector2(170, 112))
		cb.pressed.connect(_claim_chest.bind(box))
		UIKit.pulse(cb, 1.08, 0.8)
	else:
		var claimed := 0
		for t in list:
			if bool(t["claimed"]):
				claimed += 1
		cb = UIKit.button("%d / %d" % [claimed, list.size()], "neutral", "", 36, Vector2(170, 112))
		cb.disabled = true
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(cb)
	box.add_child(chest)


static func _reward_short(r: Dictionary) -> String:
	if r.has("coins"):
		return "+%d" % int(r["coins"])
	for k in r.keys():
		return "+%d" % int(r[k])
	return ""


static func _reward_icon(r: Dictionary) -> String:
	if r.has("coins"):
		return "coin"
	for k in r.keys():
		return BoosterManager.icon(String(k))
	return ""


static func _claim_task(i: int, box: VBoxContainer) -> void:
	var r := DailyManager.claim_task(i)
	if r.is_empty():
		return
	AudioManager.play("reward")
	HapticsManager.medium()
	VFXManager.toast(AchievementManager.reward_text(r) + "!")
	_fill_tasks(box)


static func _claim_chest(box: VBoxContainer) -> void:
	var r := DailyManager.claim_chest()
	if r.is_empty():
		return
	_fill_tasks(box)
	reward("Bonus chest!", AchievementManager.reward_text(r), "chest")


## The Daily Jam card: today's special level, streak and reward.
static func daily_jam() -> GamePopup:
	var done := DailyManager.challenge_done_today()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	var streak_card := UIKit.card("purple", 18, 28)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	streak_card.add_child(sh)
	sh.add_child(UIKit.icon("flame", 72))
	var n := DailyManager.streak()
	sh.add_child(UIKit.text("%d day%s" % [n, "" if n == 1 else "s"], 42))
	row.add_child(streak_card)
	var reward_card := UIKit.card("gold", 18, 28)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 10)
	reward_card.add_child(rh)
	rh.add_child(UIKit.icon("coin", 72))
	rh.add_child(UIKit.text("+%d" % DailyManager.challenge_reward(), 46))
	row.add_child(reward_card)
	var buttons: Array
	if done:
		buttons = [{"id": "wait", "text": "Next jam in " + DailyManager.reset_text(), "kind": "neutral", "disabled": true}]
	else:
		buttons = [{"id": "play", "text": "PLAY", "kind": "primary", "icon": "play", "size": 60, "cb": ScreenManager.start_daily}]
	return show({
		"id": "daily_jam",
		"title": "DAILY JAM",
		"art": "calendar",
		"art_color": UIKit.PURPLE,
		"body": "Cleared! Come back tomorrow to keep your streak going." if done else "One special jam every day. Free to play: no lives needed! Clear it on days in a row for bigger rewards.",
		"content": box,
		"closable": true,
		"buttons": buttons,
	})
