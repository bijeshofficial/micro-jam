extends Node
## Booster inventory: Crane, Extra Bay and Shuffle Queue.

signal changed(id: String, count: int)

const IDS := ["crane", "extra_bay", "shuffle"]
const NAMES := {"crane": "Crane", "extra_bay": "Extra Bay", "shuffle": "Shuffle"}
const ICONS := {"crane": "crane", "extra_bay": "bay_plus", "shuffle": "shuffle"}
const DESCRIPTIONS := {
	"crane": "Lift any bus straight out to a free bay, even when it's boxed in.",
	"extra_bay": "Open a 6th loading bay for this level.",
	"shuffle": "Re-order the waiting passengers so every bus can still be filled.",
}


func count(id: String) -> int:
	return int(SaveManager.game()["boosters"].get(id, 0))


func grant(id: String, n: int = 1, save: bool = true) -> void:
	if not IDS.has(id) or n <= 0:
		return
	SaveManager.game()["boosters"][id] = count(id) + n
	changed.emit(id, count(id))
	if save:
		SaveManager.save_game()


## Uses one from the inventory. Returns false when there are none.
func consume(id: String) -> bool:
	if count(id) <= 0:
		return false
	SaveManager.game()["boosters"][id] = count(id) - 1
	SaveManager.add_game_stat("boosters_used")
	changed.emit(id, count(id))
	SaveManager.save_game()
	return true


func price(id: String) -> int:
	return GameData.price(id)


func buy(id: String) -> bool:
	if not CurrencyManager.spend(price(id)):
		return false
	grant(id, 1)
	return true


## One-time tutorial grant (L6 Crane, L8 Extra Bay, L12 Shuffle).
func grant_tutorial(id: String) -> int:
	var key := "grant_" + id
	if ProgressionManager.tutorial_done(key):
		return 0
	var n := int(GameData.economy()["tutorial_grants"].get(id, 1))
	grant(id, n, false)
	ProgressionManager.mark_tutorial(key)
	return n


func display_name(id: String) -> String:
	return NAMES.get(id, id)


func icon(id: String) -> String:
	return ICONS.get(id, "star")


func description(id: String) -> String:
	return DESCRIPTIONS.get(id, "")
