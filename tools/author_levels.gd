extends SceneTree
## Curates levels 3-20 from hand-picked parameters and freezes them into
## data/levels_authored.json (levels 1-2 are hand-placed and kept as is).
##   godot --headless --path . --script res://tools/author_levels.gd
## Each entry fixes the lot size, bus count, colours, interleave window,
## tier, twists and tutorial; the seed is fixed so output never changes.

const OUT := "res://data/levels_authored.json"

## [level, w, h, buses, colors, big, window, tier, twists, tutorial]
const TABLE := [
	[3, 4, 5, 5, 2, 0.0, 2, "normal", [], "bays"],
	[4, 5, 5, 5, 3, 0.0, 1, "normal", [], ""],
	[5, 5, 5, 6, 3, 0.1, 2, "hard", [], ""],
	[6, 5, 6, 6, 3, 0.2, 1, "normal", [], "crane"],
	[7, 5, 6, 7, 3, 0.2, 2, "normal", [], ""],
	[8, 5, 6, 7, 3, 0.2, 2, "normal", [], "extra_bay"],
	[9, 5, 6, 8, 3, 0.2, 2, "normal", [], ""],
	[10, 5, 6, 9, 4, 0.2, 3, "super", [], ""],
	[11, 5, 6, 7, 3, 0.2, 1, "easy", [], ""],
	[12, 5, 6, 8, 4, 0.2, 2, "normal", [], "shuffle"],
	[13, 6, 6, 9, 4, 0.2, 2, "normal", [], ""],
	[14, 6, 6, 10, 4, 0.25, 2, "normal", [], ""],
	[15, 6, 7, 11, 4, 0.25, 2, "hard", ["sleep"], ""],
	[16, 6, 6, 9, 4, 0.2, 2, "easy", [], ""],
	[17, 6, 7, 11, 4, 0.25, 2, "normal", ["sleep"], ""],
	[18, 6, 7, 11, 5, 0.25, 2, "normal", [], ""],
	[19, 6, 7, 12, 5, 0.25, 2, "normal", ["sleep"], ""],
	[20, 6, 7, 13, 5, 0.25, 3, "super", [], ""],
]


func _initialize() -> void:
	GameData.preload_all()
	var keep: Array = []
	for l in GameData.authored_levels():
		if int(l["level"]) <= 2:
			keep.append(_norm(l))
	for row in TABLE:
		var p := {
			"level": row[0], "w": row[1], "h": row[2], "buses": row[3], "colors": row[4],
			"big": row[5], "window": row[6], "tier": row[7], "twists": row[8], "bays": 5,
		}
		var lvl := LevelGenerator.generate_with(p, 7000 + int(row[0]))
		if lvl.is_empty():
			push_error("could not author level %d" % row[0])
			quit(1)
			return
		if String(row[9]) != "":
			lvl["tutorial"] = row[9]
		for k in ["verified", "solver_nodes", "dead_ends"]:
			lvl.erase(k)
		lvl["fail_rate"] = snappedf(float(lvl["fail_rate"]), 0.01)
		keep.append(lvl)
		print("L%d  %dx%d  buses %d  colours %d  fail %.2f  bays %d" % [row[0], row[1], row[2], (lvl["buses"] as Array).size(), row[4], lvl["fail_rate"], lvl["plan_bays"]])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(_pretty(keep))
	f.close()
	print("wrote %d levels" % keep.size())
	quit(0)


## JSON numbers come back as floats; whole numbers go back to ints.
func _norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return int(f) if is_equal_approx(f, roundf(f)) else f
		TYPE_DICTIONARY:
			var d: Dictionary = (v as Dictionary).duplicate()
			for k in d.keys():
				d[k] = _norm(d[k])
			return d
		TYPE_ARRAY:
			var a: Array = (v as Array).duplicate()
			for i in a.size():
				a[i] = _norm(a[i])
			return a
	return v


## One level per line block: compact arrays, readable structure.
func _pretty(levels: Array) -> String:
	var parts := PackedStringArray()
	for l in levels:
		var d: Dictionary = l
		var lines := PackedStringArray()
		var head := {}
		for k in d.keys():
			if k != "buses":
				head[k] = d[k]
		var bus_lines := PackedStringArray()
		for b in d["buses"]:
			var bb: Dictionary = (b as Dictionary).duplicate()
			for k in ["state", "boarded"]:
				if bb.has(k) and (k != "state" or bb[k] == "lot"):
					bb.erase(k)
			if bb.has("sleep") and not bool(bb["sleep"]):
				bb.erase("sleep")
			bus_lines.append("\t\t\t\t" + JSON.stringify(bb))
		var head_json := JSON.stringify(head)
		lines.append("\t\t" + head_json.substr(0, head_json.length() - 1) + ",\n\t\t\t\"buses\": [\n" + ",\n".join(bus_lines) + "\n\t\t\t]}")
		parts.append("\n".join(lines))
	return "{\n\t\"levels\": [\n" + ",\n".join(parts) + "\n\t]\n}\n"
