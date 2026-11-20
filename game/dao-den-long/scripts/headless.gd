extends SceneTree

const Sim = preload("res://scripts/game_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("Pass contract arguments after --")
		return
	var opts := _parse_args(args)
	if opts.has("error"):
		_fail(str(opts.error), 2)
		return
	for required in ["seed", "night", "ticks", "out"]:
		if not opts.has(required):
			_fail("Missing --" + required, 2)
			return
	if int(opts.get("night", 1)) < 1 or int(opts.get("night", 1)) > 3:
		_fail("--night must be 1, 2, or 3", 2)
		return
	var scenario := {}
	if opts.has("scenario"):
		var parsed: Variant = _read_json(str(opts.scenario))
		if parsed == null or not parsed is Dictionary:
			_fail("Invalid scenario JSON", 2)
			return
		scenario = parsed
		if not _valid_scenario(scenario):
			_fail("Invalid scenario structure", 2)
			return
	var frames: Array = []
	if opts.has("inputs"):
		var parsed: Variant = _read_json(str(opts.inputs))
		if parsed == null or not parsed is Dictionary or not parsed.get("frames", []) is Array:
			_fail("Invalid inputs JSON", 2)
			return
		frames = parsed.frames
		var last_tick := -1
		for frame in frames:
			if not frame is Dictionary or int(frame.get("tick", -1)) <= last_tick:
				_fail("Input frame ticks must be strictly increasing", 2)
				return
			last_tick = int(frame.tick)
			if frame.has("move"):
				if not frame.move is Array or frame.move.size() != 2 or not _is_number(frame.move[0]) or not _is_number(frame.move[1]) or absf(float(frame.move[0])) > 1.0 or absf(float(frame.move[1])) > 1.0:
					_fail("Input move must be a two-element vector in [-1,1]", 2)
					return
			for button in ["jump", "interact", "pulse", "dash", "pause"]:
				if frame.has(button) and not frame[button] is bool:
					_fail("Input button %s must be boolean" % button, 2)
					return
			if frame.has("cam_yaw_deg") and not (frame.cam_yaw_deg is float or frame.cam_yaw_deg is int):
				_fail("cam_yaw_deg must be a number", 2)
				return
	var sim = Sim.new(int(opts.get("night", 1)), int(opts.get("seed", 1)), scenario)
	var file := FileAccess.open(str(opts.out), FileAccess.WRITE)
	if file == null:
		_fail("Cannot open --out: " + str(opts.out))
		return
	var every := maxi(1, int(opts.get("snapshot-every", 10)))
	var tick_count := maxi(0, int(opts.get("ticks", 0)))
	var fi := 0
	file.store_line(JSON.stringify(sim.snapshot()))
	while sim.tick < tick_count and sim.state in ["playing", "paused"]:
		while fi < frames.size() and int(frames[fi].tick) == sim.tick:
			sim.set_input(frames[fi])
			fi += 1
		sim.step()
		for event in sim.events:
			file.store_line(JSON.stringify(event))
		if sim.tick > 0 and sim.tick % every == 0:
			file.store_line(JSON.stringify(sim.snapshot()))
	var end_state: String = sim.state
	file.store_line(JSON.stringify({"type": "end", "ticks": sim.tick, "state": end_state, "score": sim.score}))
	file.close()
	quit(0)

func _is_number(value: Variant) -> bool:
	return value is int or value is float

func _valid_vec3(value: Variant) -> bool:
	return value is Array and value.size() == 3 and _is_number(value[0]) and _is_number(value[1]) and _is_number(value[2])

func _valid_scenario(value: Dictionary) -> bool:
	for flag in ["random_motes", "random_shades", "random_drifters", "wind_enabled"]:
		if value.has(flag) and not value[flag] is bool:
			return false
	if value.has("time_left_s") and not _is_number(value.time_left_s):
		return false
	if value.has("player"):
		if not value.player is Dictionary:
			return false
		if value.player.has("pos") and not _valid_vec3(value.player.pos):
			return false
		for key in ["carried", "flames", "successful_lights", "invuln_ticks", "dash_cd_ticks", "pulse_cd_ticks", "charm_ticks"]:
			if value.player.has(key) and not _is_number(value.player[key]):
				return false
	for key in ["motes", "shades", "lanterns", "drifters", "charms"]:
		if value.has(key) and not value[key] is Array:
			return false
	for mote in value.get("motes", []):
		if mote is Dictionary:
			if not mote.has("pos") or not _valid_vec3(mote.pos):
				return false
		elif not _valid_vec3(mote):
			return false
	for key in ["shades", "drifters", "charms"]:
		for entity in value.get(key, []):
			if not entity is Dictionary or not entity.has("pos") or not _valid_vec3(entity.pos):
				return false
	for lantern in value.get("lanterns", []):
		if not lantern is Dictionary or not lantern.has("id"):
			return false
		if lantern.has("pos") and not _valid_vec3(lantern.pos):
			return false
		if lantern.has("lit") and not lantern.lit is bool:
			return false
		for key in ["deposited", "fuel", "relit_count"]:
			if lantern.has(key) and not _is_number(lantern[key]):
				return false
	return true

func _parse_args(args: PackedStringArray) -> Dictionary:
	var result := {}
	var i := 0
	while i < args.size():
		var key := str(args[i])
		if not key.begins_with("--"):
			return {"error": "Unexpected argument: " + key}
		if i + 1 >= args.size() or str(args[i + 1]).begins_with("--"):
			return {"error": "Missing value for " + key}
		result[key.trim_prefix("--")] = args[i + 1]
		i += 2
	for required in ["ticks", "out"]:
		if not result.has(required):
			return {"error": "Missing --" + required}
	return result

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed

func _fail(message: String, code: int = 1) -> void:
	printerr(message)
	quit(code)
