class_name GameSim
extends RefCounted

const HZ := 60
const DAY_SECONDS := [300, 330, 360]
const NIGHT3_SECONDS := [240, 270, 300]
const LANTERNS := [
	[Vector3(0, 0, 25), Vector3(23.8, 0, 7.7), Vector3(14.7, 0, -20.2), Vector3(-14.7, 0, -20.2), Vector3(-23.8, 0, 7.7)],
	[Vector3(0, 0, 20), Vector3(17, 0, -10), Vector3(-17, 0, -10), Vector3(70, 0, 20), Vector3(87, 0, -10), Vector3(53, 0, -10)],
	[Vector3(0, 6, 6), Vector3(18, 3, 10), Vector3(-18, 3, 10), Vector3(35, 0, -10), Vector3(-35, 0, -10), Vector3(20, 0, -35), Vector3(-20, 0, -35)]
]
const LANTERN_IDS := ["L1", "L2", "L3", "L4", "L5", "L6", "L7"]
const NIGHT_NAMES := ["Đêm 1 — Đảo Bến", "Đêm 2 — Đảo Cau", "Đêm 3 — Đảo Chuông"]

var rng := RandomNumberGenerator.new()
var night := 1
var seed_value := 1
var tick := 0
var sim_tick := 0
var state := "playing"
var score := 0
var time_left := 300.0
var player := {"pos": Vector3.ZERO, "vel": Vector3.ZERO, "carried": 0, "flames": 3, "capacity": 10, "successful_lights": 0, "invuln": 0, "dash_cd": 0, "pulse_cd": 0, "charm": 0, "grounded": true, "face": Vector3.FORWARD, "fall_wait": 0}
var lanterns: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var shades: Array[Dictionary] = []
var drifters: Array[Dictionary] = []
var charms: Array[Dictionary] = []
var events: Array[Dictionary] = []
var random_motes := true
var random_shades := true
var random_drifters := true
var wind_enabled := true
var wind_active := false
var wind_dir := 0.0
var input_state := {"move": Vector2.ZERO, "cam_yaw_deg": 0.0, "jump": false, "interact": false, "pulse": false, "dash": false, "pause": false}
var _prev_buttons := {"jump": false, "interact": false, "pulse": false, "dash": false, "pause": false}
var _last_spawned_shade := 0
var _last_spawned_drifter := 0
var _fuel_fraction := 0
var _wind_rng := 0
var _last_fuel_event_tick := 0

func _init(p_night: int = 1, p_seed: int = 1, scenario: Dictionary = {}) -> void:
	night = clampi(p_night, 1, 3)
	seed_value = p_seed
	rng.seed = p_seed
	_wind_rng = p_seed ^ 0x5A17
	var duration: float = NIGHT3_SECONDS[night - 1]
	time_left = float(scenario.get("time_left_s", duration))
	_setup_world(scenario)

func _setup_world(scenario: Dictionary) -> void:
	lanterns.clear()
	for i in range(LANTERNS[night - 1].size()):
		lanterns.append({"id": LANTERN_IDS[i], "pos": LANTERNS[night - 1][i], "lit": false, "deposited": 0, "fuel": 0, "ever_lit": false, "relit_count": 0, "_fuel_units": 0, "_drain_ticks": 0})
	player.pos = Vector3.ZERO
	var ps: Dictionary = scenario.get("player", {})
	player.pos = _v3(ps.get("pos", [0, 0, 0]))
	player.carried = int(ps.get("carried", 0))
	player.flames = int(ps.get("flames", 3))
	player.successful_lights = int(ps.get("successful_lights", 0))
	player.capacity = 10 if night == 1 else mini(20, 10 + 2 * int(player.successful_lights))
	player.invuln = int(ps.get("invuln_ticks", 0))
	player.dash_cd = int(ps.get("dash_cd_ticks", 0))
	player.pulse_cd = int(ps.get("pulse_cd_ticks", 0))
	player.charm = int(ps.get("charm_ticks", 0))
	random_motes = bool(scenario.get("random_motes", true))
	random_shades = bool(scenario.get("random_shades", true))
	random_drifters = bool(scenario.get("random_drifters", true))
	wind_enabled = bool(scenario.get("wind_enabled", true))
	motes.clear()
	shades.clear()
	drifters.clear()
	charms.clear()
	if random_motes:
		var points := _mote_points()
		if night == 1:
			points = points.slice(0, 20)
		elif night == 2:
			points = points.slice(0, 10) + points.slice(12, 22)
		for p in points:
			motes.append({"id": "M%d" % (motes.size() + 1), "pos": p, "kind": "random", "ttl": -1})
	if random_shades:
		_spawn_shade_defaults()
	if night == 2:
		charms.append({"id": "C1", "pos": Vector3(35, 0, 0), "available": true, "respawn": 0})
	elif night == 3:
		charms.append({"id": "C1", "pos": Vector3(30, 0, 25), "available": true, "respawn": 0})
		charms.append({"id": "C2", "pos": Vector3(-30, 0, 25), "available": true, "respawn": 0})
	if scenario.has("motes"):
		motes.clear()
	for raw in scenario.get("motes", []):
		var pos: Vector3 = _v3(raw.get("pos", raw) if raw is Dictionary else raw)
		motes.append({"id": "M%d" % (motes.size() + 1), "pos": pos, "kind": "random", "ttl": -1})
	if scenario.has("shades"):
		shades.clear()
		_last_spawned_shade = 0
	for raw in scenario.get("shades", []):
		var shade_id := str(raw.get("id", "S%d" % (shades.size() + 1)))
		shades.append({"id": shade_id, "pos": _v3(raw.get("pos", [0, 0, 0])), "state": str(raw.get("state", "wander")), "state_ticks_left": int(raw.get("state_ticks_left", 0)), "target_lantern_id": str(raw.get("target_lantern_id", "")), "recoil": Vector3.ZERO, "spawn_tick": 0})
		if shade_id.begins_with("S") and shade_id.trim_prefix("S").is_valid_int():
			_last_spawned_shade = maxi(_last_spawned_shade, int(shade_id.trim_prefix("S")))
	for raw in scenario.get("drifters", []):
		drifters.append({"id": str(raw.get("id", "D%d" % (drifters.size() + 1))), "pos": _v3(raw.get("pos", [0, 0, 0])), "state": str(raw.get("state", "idle")), "stolen": int(raw.get("stolen", 0)), "age": 0})
	if scenario.has("charms"):
		charms.clear()
	for raw in scenario.get("charms", []):
		charms.append({"id": str(raw.get("id", "C%d" % (charms.size() + 1))), "pos": _v3(raw.get("pos", [0, 0, 0])), "available": bool(raw.get("available", true)), "respawn": 0})
	for update in scenario.get("lanterns", []):
		var i := _lantern_index(str(update.get("id", "")))
		if i < 0:
			continue
		if update.has("pos"):
			lanterns[i].pos = _v3(update.pos)
		if update.has("deposited"):
			lanterns[i].deposited = int(update.deposited)
		if update.has("lit"):
			lanterns[i].lit = bool(update.lit)
			lanterns[i].fuel = float(update.get("fuel", 100.0 if update.lit else 0.0))
			lanterns[i]._fuel_units = roundi(float(lanterns[i].fuel) * HZ)
			lanterns[i].ever_lit = bool(update.get("ever_lit", update.lit))
		if update.has("fuel"):
			lanterns[i].fuel = float(update.fuel)
			lanterns[i]._fuel_units = roundi(float(update.fuel) * HZ)
		if update.has("ever_lit"):
			lanterns[i].ever_lit = bool(update.ever_lit)
		if update.has("relit_count"):
			lanterns[i].relit_count = int(update.relit_count)

func _mote_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if night == 1:
		for radius in [12.0, 33.0]:
			var count := 8 if radius == 12.0 else 16
			for i in range(count):
				var angle := TAU * i / count
				result.append(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
	elif night == 2:
		for center_x in [0.0, 70.0]:
			for radius in [10.0, 22.0]:
				var count := 4 if radius == 10.0 else 8
				for i in range(count):
					var a := TAU * i / count
					result.append(Vector3(center_x + cos(a) * radius, 0, sin(a) * radius))
	else:
		for i in range(18):
			var a := TAU * i / 18.0
			result.append(Vector3(cos(a) * 34, 0, sin(a) * 34))
		for i in range(8):
			var a := deg_to_rad(20.0 + i * 20.0)
			result.append(Vector3(cos(a) * 18, 3, sin(a) * 18))
		for a in [45.0, 135.0, 225.0, 315.0]:
			result.append(Vector3(cos(deg_to_rad(a)) * 5, 6, sin(deg_to_rad(a)) * 5))
	return result

func _spawn_shade_defaults() -> void:
	_last_spawned_shade = 0

func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _lantern_index(id: String) -> int:
	for i in range(lanterns.size()):
		if lanterns[i].id == id:
			return i
	return -1

func _event(name: String, data: Dictionary = {}) -> void:
	events.append({"type": "event", "tick": tick, "name": name, "data": data})

func set_input(input: Dictionary) -> void:
	for key in input:
		if key == "tick":
			continue
		if key == "move" and input[key] is Array and input[key].size() == 2:
			input_state[key] = Vector2(float(input[key][0]), float(input[key][1]))
		else:
			input_state[key] = input[key]

func step() -> void:
	tick += 1
	events.clear()
	if bool(input_state.pause) and not bool(_prev_buttons.pause):
		state = "paused" if state == "playing" else ("playing" if state == "paused" else state)
		_event("paused" if state == "paused" else "resumed")
	if state == "paused":
		_prev_buttons = {"jump": bool(input_state.jump), "interact": bool(input_state.interact), "pulse": bool(input_state.pulse), "dash": bool(input_state.dash), "pause": bool(input_state.pause)}
		return
	if state != "playing":
		return
	sim_tick += 1
	time_left = maxf(0.0, time_left - 1.0 / HZ)
	for key in ["invuln", "dash_cd", "pulse_cd", "charm"]:
		player[key] = maxi(0, int(player[key]) - 1)
	_update_fuel()
	if int(player.fall_wait) > 0:
		player.fall_wait = int(player.fall_wait) - 1
		player.pos = Vector3(0, -10, 0)
		player.vel = Vector3.ZERO
		if int(player.fall_wait) == 0:
			player.pos = Vector3.ZERO
			player.invuln = 90
			player.grounded = true
		_prev_buttons = {"jump": bool(input_state.jump), "interact": bool(input_state.interact), "pulse": bool(input_state.pulse), "dash": bool(input_state.dash), "pause": bool(input_state.pause)}
		return
	for mote in motes:
		if int(mote.ttl) > 0:
			mote.ttl = int(mote.ttl) - 1
	var input_move: Vector2 = input_state.move
	if input_move.length() > 1.0:
		input_move = input_move.normalized()
	var yaw := deg_to_rad(float(input_state.cam_yaw_deg))
	var world_move := Vector2(input_move.x * cos(yaw) + input_move.y * sin(yaw), -input_move.x * sin(yaw) + input_move.y * cos(yaw))
	if night == 3 and wind_enabled:
		var wind_phase := sim_tick % 1800
		wind_active = sim_tick >= 1800 and wind_phase < 300
		if sim_tick >= 1800 and wind_phase == 0:
			wind_dir = float((seed_value * 1103515245 + sim_tick) % 360)
	else:
		wind_active = false
	if world_move.length_squared() > 0.0:
		player.face = Vector3(world_move.x, 0, world_move.y).normalized()
	var speed := 7.2 if int(player.charm) > 0 else 6.0
	var dash_now := bool(input_state.dash) and not bool(_prev_buttons.dash) and int(player.dash_cd) == 0
	if dash_now:
		var facing: Vector3 = player.face
		player.vel.x = facing.x * 14.0
		player.vel.z = facing.z * 14.0
		player.dash_cd = 0 if int(player.charm) > 0 else 90
		player["dash_ticks"] = 12
		_event("dash")
	var pad_launching := int(player.get("pad_launch_ticks", 0)) > 0
	if pad_launching:
		player.vel.x = float(player.launch_vel.x)
		player.vel.z = float(player.launch_vel.z)
		player.pad_launch_ticks = int(player.pad_launch_ticks) - 1
	if int(player.get("dash_ticks", 0)) > 0:
		player.dash_ticks = int(player.dash_ticks) - 1
	elif not pad_launching:
		player.vel.x = move_toward(float(player.vel.x), world_move.x * speed, 60.0 / HZ)
		player.vel.z = move_toward(float(player.vel.z), world_move.y * speed, 60.0 / HZ)
	if bool(input_state.jump) and not bool(_prev_buttons.jump) and bool(player.grounded):
		player.vel.y = 7.0
		player.grounded = false
	if int(player.get("dash_ticks", 0)) <= 0:
		player.vel.y = float(player.vel.y) - 20.0 / HZ
	player.pos += Vector3(player.vel.x, player.vel.y, player.vel.z) / HZ
	if wind_active:
		player.pos += Vector3(cos(deg_to_rad(wind_dir)), 0, sin(deg_to_rad(wind_dir))) * 2.0 / HZ
	var floor_y: Variant = _ground_height(player.pos)
	if floor_y != null and float(player.pos.y) <= float(floor_y):
		player.pos.y = float(floor_y)
		player.vel.y = 0.0
		player.grounded = true
	else:
		player.grounded = false
	_check_jump_pads()
	_check_fall()
	if int(player.fall_wait) > 0:
		_prev_buttons = {"jump": bool(input_state.jump), "interact": bool(input_state.interact), "pulse": bool(input_state.pulse), "dash": bool(input_state.dash), "pause": bool(input_state.pause)}
		return
	_pickups()
	if bool(input_state.interact) and not bool(_prev_buttons.interact):
		_interact()
	if bool(input_state.pulse) and not bool(_prev_buttons.pulse):
		_pulse()
	_move_shades()
	_move_drifters()
	_collisions()
	_spawns()
	_check_result()
	_prev_buttons = {"jump": bool(input_state.jump), "interact": bool(input_state.interact), "pulse": bool(input_state.pulse), "dash": bool(input_state.dash), "pause": bool(input_state.pause)}

func _check_fall() -> void:
	if float(player.pos.y) < -10.0:
		player.flames = maxi(0, int(player.flames) - 1)
		var lost := int(player.carried)
		player.carried = 0
		player["fall_wait"] = 60
		_event("player_hit", {"by": "fall", "flames": player.flames, "dropped": lost, "lost": lost})
		player.pos = Vector3(0, -10, 0)
		player.vel = Vector3.ZERO
		player.invuln = 90
		if player.flames == 0:
			_end("lost", "no_flames")

func _ground_height(pos: Vector3) -> Variant:
	var radius := Vector2(pos.x, pos.z).length()
	if night == 1:
		return 0.0 if radius <= 40.0 else null
	if night == 2:
		if Vector2(pos.x, pos.z).length() <= 28.0 or Vector2(pos.x - 70.0, pos.z).length() <= 28.0:
			return 0.0
		if pos.x >= 26.0 and pos.x <= 44.0 and absf(pos.z) <= 2.0:
			return 0.0
		return null
	if radius > 45.0:
		return null
	if pos.z > 0 and radius >= 12.0 and radius <= 24.0:
		return 3.0
	for ramp_angle in [30.0, 150.0]:
		var angle := deg_to_rad(ramp_angle)
		var radial := Vector2(cos(angle), sin(angle))
		var point := Vector2(pos.x, pos.z)
		var along := point.dot(radial)
		var across := absf(point.x * radial.y - point.y * radial.x)
		if along >= 24.0 and along <= 30.0 and across <= 1.5:
			return (30.0 - along) * 0.5
	if radius <= 8.0:
		return 6.0
	return 0.0

func _check_jump_pads() -> void:
	if int(player.get("pad_launch_ticks", 0)) > 0 or not bool(player.grounded):
		return
	if night == 2:
		var pads := [Vector3(20, 0, 18), Vector3(50, 0, -18)]
		for i in range(pads.size()):
			if _xz(player.pos, pads[i]) <= 1.0:
				var target_x := 70.0 if i == 0 else 0.0
				var direction := Vector3(target_x - player.pos.x, 0, -player.pos.z).normalized()
				player.vel = direction * 24.0 + Vector3.UP * 14.0
				player["launch_vel"] = direction * 24.0
				player.pad_launch_ticks = 84
				player.grounded = false
				return
	elif night == 3 and _xz(player.pos, Vector3(0, 3, 13)) <= 1.0 and player.pos.y >= 2.5:
		player.vel = Vector3(0, 12.0, -8.0)
		player["launch_vel"] = Vector3(0, 0, -8.0)
		player.pad_launch_ticks = 53
		player.grounded = false

func _pickups() -> void:
	if int(player.fall_wait) > 0:
		return
	for i in range(motes.size() - 1, -1, -1):
		var m: Dictionary = motes[i]
		if int(m.ttl) == 0:
			motes.remove_at(i)
			continue
		var p: Vector3 = m.pos
		if int(player.carried) < int(player.capacity) and _xz(player.pos, p) <= 1.0 and absf(player.pos.y - p.y) <= 1.5:
			player.carried = int(player.carried) + 1
			_event("mote_picked", {"carried": player.carried})
			motes.remove_at(i)
	for charm in charms:
		if charm.available and _xz(player.pos, charm.pos) <= 1.0 and absf(player.pos.y - charm.pos.y) <= 1.5:
			charm.available = false
			charm.respawn = 2700
			player.charm = 600
			_event("charm_picked", {"charm_id": charm.id, "charm_ticks": player.charm})

func _interact() -> void:
	var chosen := -1
	var best := 2.0
	for i in range(lanterns.size()):
		var l: Dictionary = lanterns[i]
		var eligible: bool = (not l.lit) or (float(l.fuel) < 100.0)
		if not eligible:
			continue
		var d := _xz(player.pos, l.pos)
		if d <= best and (d < best or chosen < 0 or str(l.id) < str(lanterns[chosen].id)):
			best = d
			chosen = i
	if chosen < 0:
		return
	var l: Dictionary = lanterns[chosen]
	var used := 0
	var was_unlit: bool = not bool(l.lit)
	if not l.lit:
		var cost := 5 if l.ever_lit else 10
		used = mini(int(player.carried), cost - int(l.deposited))
		l.deposited = int(l.deposited) + used
		if used <= 0:
			return
		if l.deposited < cost:
			player.carried = int(player.carried) - used
			_add_score(used * 5)
			_event("deposit", {"lantern_id": l.id, "amount": used, "deposited": l.deposited})
			return
		l.lit = true
		l.ever_lit = true
		l.fuel = 100.0
		l._fuel_units = 6000
		if cost == 5:
			l.relit_count = int(l.relit_count) + 1
			_add_score(40)
		else:
			_add_score(100)
		_event("lantern_lit", {"lantern_id": l.id, "relight": cost == 5})
	else:
		used = mini(int(player.carried), ceili((100.0 - float(l.fuel)) / 10.0))
		if used <= 0:
			return
		l._fuel_units = mini(6000, int(l._fuel_units) + used * 600)
		l.fuel = float(l._fuel_units) / HZ
		_event("refuel", {"lantern_id": l.id, "amount": used, "fuel": snappedf(l.fuel, 0.1)})
	player.carried = int(player.carried) - used
	_add_score(used * 5)
	if was_unlit:
		player.successful_lights = int(player.successful_lights) + 1
	player.capacity = mini(20, 10 + 2 * int(player.successful_lights))
	if l.fuel >= 30.0:
		for shade in shades:
			if shade.state == "drain" and shade.target_lantern_id == l.id:
				shade.state = "wander"

func _update_fuel() -> void:
	for l in lanterns:
		if not l.lit:
			continue
		var draining := 0
		for s in shades:
			if s.state == "drain" and s.target_lantern_id == l.id:
				draining += 1
		l._fuel_units -= 1 + draining * 5
		l.fuel = maxf(0.0, float(l._fuel_units) / HZ)
		if draining > 0 and sim_tick % 60 == 0:
			for s in shades:
				if s.state == "drain" and s.target_lantern_id == l.id:
					_event("fuel_drain", {"lantern_id": l.id, "shade_id": s.id, "fuel": snappedf(l.fuel, 0.1)})
		if l._fuel_units <= 0:
			l.lit = false
			l.deposited = 0
			l.fuel = 0.0
			_event("lantern_out", {"lantern_id": l.id})

func _pulse() -> void:
	if int(player.pulse_cd) > 0 or int(player.carried) < 3:
		return
	player.carried = int(player.carried) - 3
	player.pulse_cd = 180
	var center: Vector3 = player.pos + Vector3.UP * 0.8
	var hit: Array[String] = []
	for s in shades:
		if center.distance_to(s.pos) <= 5.0:
			var was_drain: bool = str(s.state) == "drain"
			s.state = "stunned"
			s.state_ticks_left = 120
			var away: Vector3 = s.pos - player.pos
			away.y = 0
			if away.length_squared() == 0:
				away = Vector3.RIGHT
			s.recoil = away.normalized() * (4.0 / 15.0)
			s["push_ticks"] = 15
			hit.append(str(s.id))
			_add_score(15 if was_drain else 5)
	for d in drifters:
		if center.distance_to(d.pos + Vector3.UP * 0.5) > 5.0:
			continue
		if d.state == "chase":
			d.state = "flee"
			d.age = 0
		elif d.state == "flee" and int(d.stolen) > 0:
			var amount := int(d.stolen)
			d.stolen = 0
			d.state = "flee_drop"
			d.age = 0
			for i in range(amount):
				var angle := TAU * i / maxi(1, amount)
				motes.append({"id": "DRIFTER_DROP_%s_%d" % [d.id, i], "pos": d.pos + Vector3(cos(angle), 0, sin(angle)), "kind": "dropped", "ttl": 480})
	_event("pulse", {"stunned_ids": hit})

func _move_shades() -> void:
	for s in shades:
		if s.state == "stunned":
			if int(s.get("push_ticks", 0)) > 0:
				s.pos += s.recoil
				s.push_ticks = int(s.push_ticks) - 1
			s.state_ticks_left = maxi(0, int(s.state_ticks_left) - 1)
			if int(s.state_ticks_left) == 0:
				s.state = "wander"
			continue
		if s.state == "recoil":
			s.pos += s.recoil
			s.state_ticks_left = maxi(0, int(s.state_ticks_left) - 1)
			if int(s.state_ticks_left) == 0:
				s.state = "wander"
			continue
		if s.state == "spawning":
			s.state = "wander"
		var dist := _xz(s.pos, player.pos)
		if s.state == "drain":
			var target_i := _lantern_index(str(s.target_lantern_id))
			if dist <= 6.0:
				s.state = "chase"
			elif target_i < 0 or not lanterns[target_i].lit or lanterns[target_i].fuel >= 30.0 or _xz(s.pos, lanterns[target_i].pos) > 2.0:
				s.state = "wander"
			else:
				continue
		if s.state == "chase":
			if dist > 18.0:
				s.state = "wander"
			else:
				var direction: Vector3 = player.pos - s.pos
				direction.y = 0
				if direction.length_squared() > 0:
					s.pos += direction.normalized() * (4.5 if night == 3 else 4.0) / HZ
				_enforce_safe_zones(s)
				continue
		if s.state == "wander":
			if dist <= 12.0:
				s.state = "chase"
				continue
			var phase := float(int(str(s.id).trim_prefix("S"))) * 1.7 + float(sim_tick) / 120.0
			s.pos.x += cos(phase) * 0.7 / HZ
			s.pos.z += sin(phase) * 0.7 / HZ
			var target := _weak_lantern(s.pos)
			if target >= 0:
				s.target_lantern_id = lanterns[target].id
				var dv: Vector3 = lanterns[target].pos - s.pos
				dv.y = 0
				if lanterns[target].lit and dv.length() <= 2.0:
					s.state = "drain"
				else:
					s.pos += dv.normalized() * (4.5 if night == 3 else 4.0) / HZ
				continue
			var dark_target := _nearest_dark_lantern(s.pos)
			if dark_target >= 0:
				var dark_direction: Vector3 = lanterns[dark_target].pos - s.pos
				dark_direction.y = 0
				if dark_direction.length_squared() > 0:
					s.pos += dark_direction.normalized() * (4.5 if night == 3 else 4.0) / HZ
				continue
		_enforce_safe_zones(s)

func _enforce_safe_zones(shade: Dictionary) -> void:
	for l in lanterns:
		if l.lit and l.fuel >= 30.0:
			var offset: Vector3 = shade.pos - l.pos
			offset.y = 0
			if offset.length() < 6.0:
				if offset.length_squared() == 0:
					offset = Vector3.RIGHT
				shade.pos = l.pos + offset.normalized() * 6.0

func _weak_lantern(pos: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in range(lanterns.size()):
		var l: Dictionary = lanterns[i]
		if not l.lit or l.fuel >= 30.0:
			continue
		var d := _xz(pos, l.pos)
		if d < best_d or (is_equal_approx(d, best_d) and (best < 0 or str(l.id) < str(lanterns[best].id))):
			best = i
			best_d = d
	return best

func _nearest_dark_lantern(pos: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in range(lanterns.size()):
		if lanterns[i].lit:
			continue
		var d := _xz(pos, lanterns[i].pos)
		if d < best_d:
			best = i
			best_d = d
	return best

func _move_drifters() -> void:
	for d in drifters:
		d.age = int(d.age) + 1
		if d.state == "removed":
			continue
		var delta: Vector3 = player.pos - d.pos
		delta.y = 0
		if d.state == "idle" and player.carried >= 5 and delta.length() <= 15.0:
			d.state = "chase"
		if d.state == "chase" and (player.carried < 5 or delta.length() > 15.0):
			d.state = "idle"
		if d.state == "chase" and delta.length() <= 1.2:
			var amount := mini(3, int(player.carried))
			player.carried = int(player.carried) - amount
			d.stolen = amount
			d.state = "flee"
			d.age = 0
			_event("drifter_steal", {"drifter_id": d.id, "amount": amount, "carried": player.carried})
		elif d.state == "chase" and delta.length_squared() > 0:
			d.pos += delta.normalized() * 7.0 / HZ
		elif d.state == "flee":
			if int(d.age) >= 240:
				d.state = "removed"
			else:
				var away: Vector3 = d.pos - player.pos
				away.y = 0
				if away.length_squared() > 0:
					d.pos += away.normalized() * 7.0 / HZ
		elif d.state == "idle":
			var wander_phase := float(int(str(d.id).trim_prefix("D"))) + float(sim_tick) / 180.0
			d.pos.x += cos(wander_phase) * 2.0 / HZ
			d.pos.z += sin(wander_phase) * 2.0 / HZ
		elif d.state == "flee_drop" and int(d.age) >= 120:
			d.state = "removed"

func _collisions() -> void:
	if int(player.invuln) > 0 or int(player.fall_wait) > 0:
		return
	var ordered_shades: Array = shades.duplicate()
	ordered_shades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for s in ordered_shades:
		if s.state == "stunned" or s.state == "spawning":
			continue
		if _xz(player.pos, s.pos) <= 1.0 and absf(player.pos.y - s.pos.y) <= 1.5:
			player.flames -= 1
			var dropped := int(floor(float(player.carried) / 2.0))
			player.carried -= dropped
			_drop_motes(dropped)
			player.invuln = 90
			s.state = "recoil"
			s.state_ticks_left = 60
			var away: Vector3 = s.pos - player.pos
			away.y = 0
			if away.length_squared() == 0:
				away = Vector3.RIGHT
			s.recoil = away.normalized() * (2.0 / 60.0)
			_event("player_hit", {"by": "shade", "flames": player.flames, "dropped": dropped})
			if player.flames <= 0:
				_end("lost", "no_flames")
			return
	for d in drifters:
		if d.state == "chase" and _xz(player.pos, d.pos) <= 1.2:
			var amount := mini(3, int(player.carried))
			player.carried -= amount
			d.stolen = amount
			d.state = "flee"
			d.age = 0
			_event("drifter_steal", {"drifter_id": d.id, "amount": amount, "carried": player.carried})
			return

func _drop_motes(amount: int) -> void:
	for i in range(amount):
		var angle := TAU * i / maxi(1, amount)
		var radius := 1.5 + 1.0 * float(i % 2)
		var drop_pos: Vector3 = player.pos + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		motes.append({"id": "DROPPED_%d_%d" % [sim_tick, i], "pos": drop_pos, "kind": "dropped", "ttl": 480})

func _spawns() -> void:
	if random_motes and sim_tick > 0 and sim_tick % 240 == 0 and motes.size() < 30:
		var points := _mote_points()
		for p in points:
			var occupied := false
			for m in motes:
				if _xz(m.pos, p) < 0.1:
					occupied = true
					break
			if not occupied:
				motes.append({"id": "M%d" % (motes.size() + sim_tick), "pos": p, "kind": "random", "ttl": -1})
				break
	if random_shades:
		var interval := 480 if night == 1 else (420 if night == 2 else 360)
		var cap := 6 if night == 1 else (8 if night == 2 else 10)
		var due := sim_tick == 300 or (sim_tick > 300 and (sim_tick - 300) % interval == 0)
		if due:
			var spawn_count := 2 if sim_tick == 300 else 1
			for _i in range(spawn_count):
				if shades.size() >= cap:
					break
				var p := _shade_spawn_point()
				_last_spawned_shade += 1
				var id := "S%d" % _last_spawned_shade
				shades.append({"id": id, "pos": p, "state": "spawning", "state_ticks_left": 0, "target_lantern_id": "", "recoil": Vector3.ZERO, "spawn_tick": sim_tick})
				_event("shade_spawned", {"id": id})
	var active_drifters := 0
	for drifter in drifters:
		if drifter.state != "removed":
			active_drifters += 1
	if night > 1 and random_drifters and sim_tick > 0 and sim_tick % 1200 == 0 and active_drifters < 2:
		_last_spawned_drifter += 1
		var id := "D%d" % _last_spawned_drifter
		drifters.append({"id": id, "pos": _shade_spawn_point(), "state": "idle", "stolen": 0, "age": 0})
	if night > 1:
		for charm in charms:
			if not charm.available:
				charm.respawn = maxi(0, int(charm.respawn) - 1)
				if charm.respawn == 0:
					charm.available = true

func _shade_spawn_point() -> Vector3:
	var radius := 37.0 if night == 1 else (26.0 if night == 2 else 43.0)
	var count := 12 if night == 1 else (16 if night == 2 else 16)
	for offset in range(count):
		var i := (offset + _last_spawned_shade) % count
		var angle := deg_to_rad(15.0 + 30.0 * i) if night == 1 else (deg_to_rad(22.5 + 45.0 * (i % 8)) if night == 2 else TAU * i / count)
		var island_x := 70.0 if night == 2 and i >= 8 else 0.0
		var pos := Vector3(island_x + cos(angle) * radius, 0, sin(angle) * radius)
		if _xz(pos, player.pos) >= 15.0:
			return pos
	return Vector3(radius, 0, 0)

func _check_result() -> void:
	if player.flames <= 0:
		_end("lost", "no_flames")
		return
	if time_left <= 0.0:
		var lit_count := 0
		for l in lanterns:
			if l.lit:
				lit_count += 1
		var required := ceili(lanterns.size() * 0.6)
		_end("won" if lit_count >= required else "lost", "dawn_survived" if lit_count >= required else "dawn")

func _end(result: String, reason: String) -> void:
	if state != "playing":
		return
	state = result
	if result == "won":
		for l in lanterns:
			if l.lit:
				_add_score(50 + int(floor(float(l.fuel))))
		_add_score(50 * player.flames)
	_event("game_over", {"result": result, "reason": reason})

func snapshot() -> Dictionary:
	var lout: Array[Dictionary] = []
	for l in lanterns:
		lout.append({"id": l.id, "pos": _arr(l.pos), "lit": l.lit, "deposited": l.deposited, "fuel": snappedf(float(l.fuel), 0.1), "ever_lit": l.ever_lit, "relit_count": l.relit_count})
	var mout: Array[Dictionary] = []
	for m in motes:
		mout.append({"id": m.id, "pos": _arr(m.pos), "kind": m.kind, "ttl_s": -1.0 if int(m.ttl) < 0 else float(m.ttl) / HZ})
	var sout: Array[Dictionary] = []
	for s in shades:
		sout.append({"id": s.id, "pos": _arr(s.pos), "state": s.state, "target_lantern_id": s.target_lantern_id})
	var dout: Array[Dictionary] = []
	for d in drifters:
		dout.append({"id": d.id, "pos": _arr(d.pos), "state": d.state, "stolen": d.stolen})
	var cout: Array[Dictionary] = []
	for c in charms:
		cout.append({"id": c.id, "available": c.available, "respawn_s": float(c.respawn) / HZ})
	return {"type": "snapshot", "tick": tick, "sim_tick": sim_tick, "night": night, "state": state, "time_left_s": snappedf(time_left, 0.001), "score": score, "wind": {"active": wind_active, "dir_deg": wind_dir}, "player": {"pos": _arr(player.pos), "vel": _arr(player.vel), "flames": player.flames, "carried": player.carried, "capacity": player.capacity, "grounded": player.grounded, "invuln": player.invuln > 0, "dash_cd_s": float(player.dash_cd) / HZ, "pulse_cd_s": float(player.pulse_cd) / HZ, "charm_s": float(player.charm) / HZ}, "lanterns": lout, "motes": mout, "motes_active": motes.size(), "shades": sout, "drifters": dout, "charms": cout}

func _arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

func _xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _add_score(points: int) -> void:
	score += points
