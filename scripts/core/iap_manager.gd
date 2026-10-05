extends Node
## Real-money coin packs.
##
## Only offered on the platforms in data/economy.json "store_platforms".
## That is iOS only: there is no Google Play merchant account (Nepal), so
## Android never shows prices or paid products.
##
## There is no real store backend yet (StoreKit on iOS), so release builds
## hide the coin packs everywhere and the mock can never hand out free
## coins. Debug builds show the mock "TEST PURCHASE" flow on iOS, or on
## desktop with -- --store. A StoreKit adapter replaces buy()'s body and
## makes has_real_backend() true.

signal purchased(product_id: String)

## Tests skip the confirmation popup.
var auto_confirm := false
## Tests force the store on (desktop has no store platform).
var store_override := false


func platform() -> String:
	if OS.has_feature("ios"):
		return "ios"
	if OS.has_feature("android"):
		return "android"
	return "desktop"


func has_real_backend() -> bool:
	return false


## Whether the Shop shows real-money coin packs on this build.
func store_enabled() -> bool:
	return store_allowed(platform(), OS.is_debug_build(), has_real_backend(), store_override or "--store" in OS.get_cmdline_user_args())


static func store_allowed(plat: String, debug: bool, real_backend: bool, forced: bool) -> bool:
	if forced and debug:
		return true
	var plats: Array = GameData.economy().get("store_platforms", ["ios"])
	if not plats.has(plat):
		return false
	return real_backend or debug


func product(product_id: String) -> Dictionary:
	return GameData.coin_pack(product_id)


func buy(product_id: String, on_done: Callable) -> void:
	var p := product(product_id)
	if p.is_empty() or not store_enabled():
		on_done.call(false)
		return
	if auto_confirm:
		_finish(product_id, true, on_done)
		return
	var popup := GamePopup.create({
		"title": "TEST PURCHASE",
		"art": "coin_pile",
		"body": "%s: %d coins\n%s (test only, nothing is charged)" % [p["name"], int(p["coins"]), p.get("price_label", "")],
		"buttons": [
			{"text": "Cancel", "kind": "neutral", "cb": func() -> void: _finish(product_id, false, on_done)},
			{"text": "Confirm", "kind": "primary", "cb": func() -> void: _finish(product_id, true, on_done)},
		],
		"on_back": func() -> void: _finish(product_id, false, on_done),
	})
	ScreenManager.push_modal(popup)


func _finish(product_id: String, ok: bool, on_done: Callable) -> void:
	if ok:
		grant(product_id)
	on_done.call(ok)


func grant(product_id: String) -> void:
	var p := product(product_id)
	if p.is_empty():
		return
	CurrencyManager.add_coins(int(p["coins"]))
	purchased.emit(product_id)
