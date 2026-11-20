extends SceneTree

const Sim = preload("res://scripts/game_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var opts := {}
	var i := 0
	while i + 1 < args.size():
		opts[str(args[i]).trim_prefix("--")] = args[i + 1]
		i += 2
	var count := clampi(int(opts.get("nights", 10)), 1, 100)
	var base_seed := int(opts.get("seed", 7))
	var out := str(opts.get("out", "soak.json"))
	var started := Time.get_ticks_msec()
	var mem_start := 0.0
	var results: Array[String] = []
	var crashes := 0
	for index in range(count):
		var which_night := index % 3 + 1
		var sim = Sim.new(which_night, base_seed + index)
		if index == 0:
			mem_start = _rss_mb()
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + index
		var direction := Vector2.ZERO
		for t in range(21600):
			if t % 30 == 0:
				direction = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).limit_length(1.0)
			sim.set_input({"move": direction, "jump": rng.randf() < 0.05, "dash": rng.randf() < 0.03, "pulse": rng.randf() < 0.02, "interact": rng.randf() < 0.10})
			sim.step()
			if sim.state in ["won", "lost"]:
				break
		if sim.state == "playing":
			crashes += 1
		results.append("won" if sim.state == "won" else "lost")
		sim = null
	var mem_end := _rss_mb()
	var body := {"nights": count, "crashes": crashes, "results": results, "mem_start_mb": mem_start, "mem_end_mb": mem_end, "duration_s": float(Time.get_ticks_msec() - started) / 1000.0}
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		printerr("Cannot open soak output: " + out)
		quit(1)
		return
	f.store_string(JSON.stringify(body, "\t"))
	f.close()
	print(JSON.stringify(body))
	quit(0 if crashes == 0 else 1)

func _rss_mb() -> float:
	var output: Array = []
	var code := 1
	if OS.get_name() == "Windows":
		code = OS.execute("powershell.exe", ["-NoProfile", "-Command", "(Get-Process -Id %d).WorkingSet64" % OS.get_process_id()], output, true)
	else:
		code = OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], output, true)
	if code != 0 or output.is_empty():
		return 0.0
	var value := int(str(output[0]).strip_edges())
	return float(value) / (1048576.0 if OS.get_name() == "Windows" else 1024.0)
