extends SceneTree

const Sim = preload("res://scripts/game_sim.gd")
var failures: Array[String] = []
var passed: Array[String] = []

func _initialize() -> void:
	_check_maps_and_durations()
	_check_determinism()
	_check_pickup_and_light()
	_check_relight_and_fuel_decay()
	_check_shade_drain()
	_check_collision_drop()
	_check_dawn_rule()
	_check_pause_ticks()
	_check_phase_2_and_score_regressions()
	_check_phase_2_feature_scenarios()
	_check_collision_id_order()
	var summary := {"suite": "contract_checks", "passed": passed.size(), "failed": failures.size(), "checks": passed, "failures": failures}
	print(JSON.stringify(summary, "\t"))
	var proof_path := ProjectSettings.globalize_path("res://docs/proof/phase-4/contract-checks.json")
	var f := FileAccess.open(proof_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(summary, "\t"))
		f.close()
	else:
		printerr("Could not save contract test evidence")
	quit(0 if failures.is_empty() else 1)

func _ok(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
	else:
		failures.append(label)

func _check_maps_and_durations() -> void:
	var n1 = Sim.new(1, 123)
	var n2 = Sim.new(2, 123)
	var n3 = Sim.new(3, 123)
	_ok(n1.lanterns.size() == 5 and n1.motes.size() == 20, "Night 1 map baseline")
	_ok(n2.lanterns.size() == 6 and n2.motes.size() == 20 and n2.charms.size() == 1, "Night 2 map baseline")
	_ok(n3.lanterns.size() == 7 and n3.motes.size() == 30 and n3.charms.size() == 2, "Night 3 map baseline")
	_ok(is_equal_approx(n1.time_left, 240.0) and is_equal_approx(n2.time_left, 270.0) and is_equal_approx(n3.time_left, 300.0), "Phase 3 night durations")

func _check_determinism() -> void:
	var a = Sim.new(1, 887)
	var b = Sim.new(1, 887)
	for i in range(180):
		var frame := {"move": Vector2(0.25, 0.75), "cam_yaw_deg": 35.0, "jump": i == 3}
		a.set_input(frame)
		b.set_input(frame)
		a.step()
		b.step()
	_ok(JSON.stringify(a.snapshot()) == JSON.stringify(b.snapshot()), "Same-seed simulation deterministic")

func _check_pickup_and_light() -> void:
	var pick_scenario := {"random_motes": false, "random_shades": false, "motes": [[0, 0, 0]]}
	var pickup = Sim.new(1, 1, pick_scenario)
	pickup.step()
	_ok(pickup.player.carried == 1 and pickup.events.any(func(e: Dictionary) -> bool: return e.name == "mote_picked"), "Mote pickup event and inventory")
	var light_scenario := {"random_motes": false, "random_shades": false, "player": {"pos": [0, 0, 25], "carried": 10}, "time_left_s": 100}
	var light = Sim.new(1, 1, light_scenario)
	light.set_input({"interact": true})
	light.step()
	_ok(light.lanterns[0].lit and light.player.carried == 0 and light.score == 150, "First light, deposit, and score")
	_ok(light.state == "playing", "Lighting every lamp does not win before dawn")

func _check_relight_and_fuel_decay() -> void:
	var relight_scenario := {"random_motes": false, "random_shades": false, "player": {"pos": [0, 0, 25], "carried": 5}, "lanterns": [{"id": "L1", "ever_lit": true}]}
	var relight = Sim.new(1, 1, relight_scenario)
	relight.set_input({"interact": true})
	relight.step()
	_ok(relight.lanterns[0].lit and relight.lanterns[0].relit_count == 1 and relight.score == 65, "Relight cost and score")
	var fuel_scenario := {"random_motes": false, "random_shades": false, "lanterns": [{"id": "L1", "lit": true, "fuel": 100}]}
	var fuel = Sim.new(1, 1, fuel_scenario)
	for _i in range(60):
		fuel.step()
	_ok(is_equal_approx(fuel.lanterns[0].fuel, 99.0), "Fuel decay is one unit per second")

func _check_shade_drain() -> void:
	var scenario := {"random_motes": false, "random_shades": false, "lanterns": [{"id": "L1", "lit": true, "fuel": 29}], "shades": [{"id": "S1", "pos": [1, 0, 21], "state": "wander"}]}
	var sim = Sim.new(2, 2, scenario)
	for _i in range(60):
		sim.step()
	var found_drain := false
	for s in sim.shades:
		if s.state == "drain":
			found_drain = true
	_ok(found_drain and sim.lanterns[0].fuel < 24.0, "Low-fuel shade drains a lantern")

func _check_collision_drop() -> void:
	var scenario := {"random_motes": false, "random_shades": false, "player": {"carried": 4}, "shades": [{"id": "S1", "pos": [0, 0, 0], "state": "chase"}]}
	var sim = Sim.new(1, 9, scenario)
	sim.step()
	_ok(sim.player.flames == 2 and sim.player.carried == 2 and sim.motes.size() == 2, "Shade hit loses a flame and drops half the carried motes")

func _check_dawn_rule() -> void:
	var lamps := [{"id": "L1", "lit": true}, {"id": "L2", "lit": true}, {"id": "L3", "lit": true}]
	var scenario := {"random_motes": false, "random_shades": false, "time_left_s": 1.0 / 60.0, "lanterns": lamps}
	var sim = Sim.new(1, 1, scenario)
	sim.step()
	_ok(sim.state == "won" and sim.events.any(func(e: Dictionary) -> bool: return e.name == "game_over" and e.data.reason == "dawn_survived"), "Win at dawn with 60 percent of lamps lit")
	var fatal_lamps := [{"id": "L1", "lit": true}, {"id": "L2", "lit": true}, {"id": "L3", "lit": true}]
	var fatal = Sim.new(1, 2, {"random_motes": false, "random_shades": false, "time_left_s": 1.0 / 60.0, "player": {"flames": 1}, "shades": [{"id": "S1", "pos": [0, 0, 0], "state": "chase"}], "lanterns": fatal_lamps})
	fatal.step()
	_ok(fatal.state == "lost" and fatal.events.any(func(e: Dictionary) -> bool: return e.name == "game_over" and e.data.reason == "no_flames"), "No-flames loss takes precedence at dawn")

func _check_pause_ticks() -> void:
	var sim = Sim.new(1, 1, {"random_motes": false, "random_shades": false})
	sim.set_input({"pause": true})
	sim.step()
	var paused_ok: bool = sim.state == "paused" and sim.tick == 1 and sim.sim_tick == 0
	sim.set_input({"pause": false})
	sim.step()
	sim.set_input({"pause": true})
	sim.step()
	_ok(paused_ok and sim.state == "playing" and sim.tick == 3 and sim.sim_tick == 1, "Paused ticks advance wall tick but freeze simulation")

func _check_phase_2_and_score_regressions() -> void:
	var n1 = Sim.new(1, 1, {"random_motes": false, "random_shades": false, "lanterns": [{"id": "L1", "lit": true, "fuel": 29}], "shades": [{"id": "S1", "pos": [0, 0, 23], "state": "wander"}]})
	for _i in range(60):
		n1.step()
	_ok(n1.shades[0].state == "drain" and n1.lanterns[0].fuel < 24.0, "Low-fuel drain applies on Night 1")
	var dawn = Sim.new(1, 4, {"random_motes": false, "random_shades": false, "time_left_s": 1.0 / 60.0, "lanterns": [{"id": "L1", "lit": true, "fuel": 100}, {"id": "L2", "lit": true, "fuel": 100}, {"id": "L3", "lit": true, "fuel": 100}]})
	dawn.step()
	_ok(dawn.state == "won" and dawn.score == 597, "Dawn score uses Phase 3 lantern fuel and flames on Night 1")
	var n2 = Sim.new(2, 5)
	var covers_island_a := false
	var covers_island_b := false
	for i in range(16):
		n2._last_spawned_shade = i
		var p: Vector3 = n2._shade_spawn_point()
		if i < 8 and p.x < 28:
			covers_island_a = true
		if i >= 8 and p.x > 42:
			covers_island_b = true
	_ok(covers_island_a and covers_island_b, "Night 2 shade spawn points cover both islands")
	var fall = Sim.new(1, 6, {"random_motes": false, "random_shades": false, "player": {"pos": [41, 0, 0]}})
	for _i in range(130):
		fall.step()
	_ok(fall.player.flames == 2 and fall.player.pos == Vector3.ZERO, "Fall respawn happens once after 60 ticks")

func _check_phase_2_feature_scenarios() -> void:
	var dash_scenario: Dictionary = _json_resource("res://tests/scenarios/dash.json")
	var dash_inputs: Dictionary = _json_resource("res://tests/inputs/dash.json")
	var dash = Sim.new(1, 7, dash_scenario)
	dash.set_input(dash_inputs.frames[0])
	dash.step()
	var dash_started: bool = dash.events.any(func(e: Dictionary) -> bool: return e.name == "dash")
	dash.set_input(dash_inputs.frames[1])
	dash.step()
	_ok(dash_started and dash.player.dash_cd == 89, "Dash scenario respects edge-trigger and cooldown")
	var charm = Sim.new(2, 8, _json_resource("res://tests/scenarios/charm.json"))
	charm.step()
	_ok(charm.charms.size() == 1 and charm.player.charm == 600 and charm.events.any(func(e: Dictionary) -> bool: return e.name == "charm_picked"), "Charm scenario replaces defaults and grants a 600-tick boost")
	var drifter = Sim.new(2, 9, _json_resource("res://tests/scenarios/drifter.json"))
	drifter.step()
	_ok(drifter.player.carried == 2 and drifter.drifters[0].stolen == 3 and drifter.drifters[0].state == "flee", "Drifter scenario steals up to three motes")
	var dropped = Sim.new(2, 11, {"random_motes": false, "random_shades": false, "player": {"carried": 3}, "drifters": [{"id": "D1", "pos": [0, 0, 1], "state": "flee", "stolen": 2}]})
	dropped.set_input({"pulse": true})
	dropped.step()
	_ok(dropped.motes.size() == 2 and dropped.drifters[0].stolen == 0, "Pulse makes a fleeing drifter drop stolen motes")
	var wind = Sim.new(3, 10, _json_resource("res://tests/scenarios/wind.json"))
	for _i in range(1800):
		wind.step()
	_ok(wind.wind_active, "Wind scenario starts a gust at 30 seconds")

func _json_resource(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _check_collision_id_order() -> void:
	var scenario := {"random_motes": false, "random_shades": false, "player": {"carried": 0}, "shades": [{"id": "S2", "pos": [0, 0, 0], "state": "chase"}, {"id": "S1", "pos": [0, 0, 0], "state": "chase"}]}
	var sim = Sim.new(1, 12, scenario)
	sim.step()
	_ok(sim.shades[0].state == "chase" and sim.shades[1].state == "recoil", "Shade contact resolves in ascending ID order")
