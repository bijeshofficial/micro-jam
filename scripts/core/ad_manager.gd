extends Node
## Rewarded ads only: an ad plays only when the player taps "Watch ad" (free
## life, booster, double coins, daily coins, rescue). There are no
## interstitials (ads between levels).
##
## Every request gets its own callback, so each reward is handled by the
## code that asked for it. The backend is picked at startup:
## - "admob": the AdMob plugin on a phone. It runs Google's consent form
##   first, then preloads rewarded ads. IDs live in data/ads.json.
## - "mock":  a clearly labelled TEST AD overlay, ONLY in debug builds.
## - "none":  a release build without AdMob. Ads are unavailable and the
##   player gets a friendly "no ad right now", never a free fake reward.

signal ad_started(placement: String)
signal ad_finished(placement: String, rewarded: bool)

const CONFIG := "res://data/ads.json"

## Set > 0 to test failure paths (or launch with -- --ad-fail).
@export var mock_fail_rate: float = 0.0
## How long the mock overlay stays up.
@export var mock_duration: float = 1.0

var interstitials_shown := 0
var provider: AdProvider
## "admob" | "mock" | "none"
var kind := "none"

var _showing := false
var _pending: Dictionary = {}     # placement -> on_done
var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--ad-fail" in OS.get_cmdline_user_args():
		mock_fail_rate = 1.0
	# Only build the AdMob backend where its native library exists (a phone
	# build with the plugin); elsewhere it would just be dead weight.
	var native := (OS.has_feature("android") or OS.has_feature("ios")) and Engine.has_singleton("PoingGodotAdMob") and ad_unit_id() != ""
	kind = pick_provider(native, OS.is_debug_build())
	provider = AdMobProvider.new() if kind == "admob" else AdProvider.new()
	provider.finished.connect(_on_provider_finished)
	provider.initialize.call_deferred()   # consent (UMP) first, then the SDK


## The simulated ad exists for development only.
static func pick_provider(admob_available: bool, debug_build: bool) -> String:
	if admob_available:
		return "admob"
	return "mock" if debug_build else "none"


func config() -> Dictionary:
	return GameData.load_json(CONFIG)


## Rewarded ad unit for this platform: Google's public TEST unit in debug
## builds and the live unit only in release builds, so you never see (or
## tap) your own live ads while developing. "" on desktop.
func ad_unit_id(release: bool = not OS.is_debug_build()) -> String:
	var plat := _platform()
	if plat == "":
		return ""
	return String(config().get("ad_units" if release else "test_ad_units", {}).get(plat, ""))


func app_id() -> String:
	return String(config().get("app_ids", {}).get(_platform(), ""))


func _platform() -> String:
	if OS.has_feature("ios"):
		return "ios"
	if OS.has_feature("android"):
		return "android"
	return ""


func is_showing() -> bool:
	return _showing


func is_rewarded_ready(_placement: String = "") -> bool:
	return not _showing and kind != "none"


## Settings shows "Ad privacy options" when consent applies (EEA/UK...).
func privacy_options_required() -> bool:
	return provider != null and provider.privacy_options_required()


func show_privacy_options(on_done: Callable = Callable()) -> void:
	provider.show_privacy_options(on_done)


func show_rewarded(placement: String, on_done: Callable) -> void:
	if _showing or kind == "none":
		on_done.call(false)
		return
	ad_started.emit(placement)
	_begin()
	if kind == "mock":
		await _show_mock_overlay("REWARDED TEST AD\n" + placement.replace("_", " "))
		_finish(placement, randf() >= mock_fail_rate, on_done)
		return
	_pending[placement] = on_done
	provider.show_rewarded(placement)


func _on_provider_finished(placement: String, rewarded: bool) -> void:
	var cb: Callable = _pending.get(placement, Callable())
	_pending.erase(placement)
	_finish(placement, rewarded, cb)


## Pause the game and mute it while an ad is on screen.
func _begin() -> void:
	_showing = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	AudioManager.set_ad_mute(true)


func _finish(placement: String, rewarded: bool, on_done: Callable) -> void:
	AudioManager.set_ad_mute(false)
	get_tree().paused = _was_paused
	_showing = false
	ad_finished.emit(placement, rewarded)
	if on_done.is_valid():
		on_done.call(rewarded)


func show_rewarded_revive(on_done: Callable) -> void:
	show_rewarded("revive", on_done)


func show_rewarded_double_reward(on_done: Callable) -> void:
	show_rewarded("double_reward", on_done)


func show_rewarded_bonus(on_done: Callable) -> void:
	show_rewarded("bonus", on_done)


func on_run_finished() -> void:
	pass  # kept for the old interstitial cap; nothing is shown between levels


## Interstitials (ads between levels) are off: data/ads.json "interstitials".
func can_show_interstitial() -> bool:
	return bool(config().get("interstitials", false)) and not _showing


func show_interstitial(on_closed: Callable) -> void:
	on_closed.call()


func banner_opportunity(_screen_name: String) -> void:
	pass  # hook only: no banners


## Test helper.
func reset_session_state() -> void:
	interstitials_shown = 0


## DEBUG BUILDS ONLY: a labelled fake ad with a short countdown.
func _show_mock_overlay(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("1f2530")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	var label := UIKit.label(text, 64, Color("f4efe6"))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(label)
	var counter := UIKit.label("", 120, UIKit.GOLD)
	counter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	counter.position.y -= 420
	counter.custom_minimum_size = Vector2(300, 160)
	counter.position.x -= 150
	layer.add_child(counter)

	var remaining := mock_duration
	while remaining > 0.0:
		counter.text = str(ceili(remaining))
		var step := minf(remaining, 0.25)
		await get_tree().create_timer(step, true).timeout
		remaining -= step

	layer.queue_free()
