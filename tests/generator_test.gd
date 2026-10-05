extends SceneTree
## Generator test: every level 21-400 is generated, then solved by the
## bounded solver within its node budget. Also checks determinism and that
## difficulty follows the rhythm (SUPER HARD > normal > easy on average).
##   godot --headless --path . --script res://tests/generator_test.gd [-- --from=21 --to=400]
## Exit code 0 on success.

const BUDGET := 20000


func _initialize() -> void:
	var from := 21
	var to := 400
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = int(a.substr(7))
		elif a.begins_with("--to="):
			to = int(a.substr(5))
	GameData.preload_all()
	var bad: Array = []
	var by_tier := {"easy": [], "normal": [], "hard": [], "super": []}
	var max_nodes := 0
	var total_ms := 0
	var twists := {}
	for n in range(from, to + 1):
		var t0 := Time.get_ticks_msec()
		var lvl := LevelGenerator.generate(n)
		total_ms += Time.get_ticks_msec() - t0
		if lvl.is_empty():
			bad.append("L%d: generation failed" % n)
			continue
		var r := ParkSolver.solve(lvl, BUDGET)
		max_nodes = maxi(max_nodes, int(r["nodes"]))
		if not bool(r["solvable"]):
			bad.append("L%d: solver %s (nodes %d)" % [n, "ran out of budget" if bool(r["aborted"]) else "found no solution", int(r["nodes"])])
		if not ParkSolver.lazy_ok(lvl, lvl["solution"]):
			bad.append("L%d: stored solution fails" % n)
		var cells := int(lvl["w"]) * int(lvl["h"])
		if cells > 120 or int(lvl["w"]) > 10 or int(lvl["h"]) > 12:
			bad.append("L%d: lot too big" % n)
		(by_tier[String(lvl["tier"])] as Array).append(float(lvl["fail_rate"]))
		for t in lvl.get("twists", []):
			twists[t] = int(twists.get(t, 0)) + 1
		if n % 50 == 0:
			print("... L%d ok (%d buses, %dx%d)" % [n, (lvl["buses"] as Array).size(), lvl["w"], lvl["h"]])
	# Determinism on a sample.
	for n in [from, (from + to) / 2, to]:
		if JSON.stringify(LevelGenerator.generate(n)) != JSON.stringify(LevelGenerator.generate(n)):
			bad.append("L%d: not deterministic" % n)
	var avg := func(a: Array) -> float:
		var s := 0.0
		for v in a:
			s += float(v)
		return s / maxf(1.0, a.size())
	var e: float = avg.call(by_tier["easy"])
	var m: float = avg.call(by_tier["normal"])
	var h: float = avg.call(by_tier["hard"])
	var s: float = avg.call(by_tier["super"])
	print("avg fail rate  easy %.2f  normal %.2f  hard %.2f  super %.2f" % [e, m, h, s])
	print("twists seen: ", twists)
	print("max solver nodes %d (budget %d), avg generation %.0f ms" % [max_nodes, BUDGET, float(total_ms) / float(to - from + 1)])
	if not (s > m and m > e):
		bad.append("difficulty rhythm not reflected (easy %.2f normal %.2f super %.2f)" % [e, m, s])
	for b in bad:
		print("FAIL: ", b)
	if bad.is_empty():
		print("GENERATOR TEST PASSED (levels %d-%d)" % [from, to])
		quit(0)
	else:
		print("GENERATOR TEST FAILED (%d problems)" % bad.size())
		quit(1)
