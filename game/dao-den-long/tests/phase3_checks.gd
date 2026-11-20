extends SceneTree

const Sim = preload("res://scripts/game_sim.gd")
var passed: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	_check_relight_and_refuel()
	_check_capacity_and_no_early_win()
	_check_low_fuel_drain()
	_check_lantern_out()
	_check_dawn_and_score()
	var result := {"suite": "phase3_checks", "contract_version": "1.3", "passed": passed.size(), "failed": failures.size(), "checks": passed, "failures": failures}
	print(JSON.stringify(result, "\t"))
	var output_path := ProjectSettings.globalize_path("res://docs/proof/phase-3/phase3-checks.json")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	else:
		printerr("Could not write Phase 3 proof output")
		quit(1)
		return
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
	else:
		failures.append(label)

func _check_relight_and_refuel() -> void:
	var relight := Sim.new(1, 301, {"random_motes": false, "random_shades": false, "player": {"pos": [0, 0, 25], "carried": 5}, "lanterns": [{"id": "L1", "ever_lit": true}]})
	relight.set_input({"interact": true})
	relight.step()
	_check(relight.lanterns[0].lit and relight.lanterns[0].fuel == 100.0 and relight.lanterns[0].relit_count == 1, "Relight restores fuel to 100 with 5 motes")
	_check(relight.score == 65, "Relight awards 40 plus 5 per mote")
	var refuel := Sim.new(1, 302, {"random_motes": false, "random_shades": false, "player": {"pos": [0, 0, 25], "carried": 2}, "lanterns": [{"id": "L1", "lit": true, "fuel": 50}]})
	refuel.set_input({"interact": true})
	refuel.step()
	_check(refuel.player.carried == 0 and refuel.lanterns[0].fuel >= 69.9 and refuel.score == 10, "Refuel consumes only carried motes and awards deposit points")

func _check_capacity_and_no_early_win() -> void:
	var light := Sim.new(1, 303, {"random_motes": false, "random_shades": false, "player": {"pos": [0, 0, 25], "carried": 10}, "time_left_s": 100})
	light.set_input({"interact": true})
	light.step()
	_check(light.player.capacity == 12 and light.player.successful_lights == 1, "Successful light increases carrying capacity by two")
	var all_lit := Sim.new(1, 304, {"random_motes": false, "random_shades": false, "time_left_s": 100, "lanterns": [{"id": "L1", "lit": true}, {"id": "L2", "lit": true}, {"id": "L3", "lit": true}, {"id": "L4", "lit": true}, {"id": "L5", "lit": true}]})
	all_lit.step()
	_check(all_lit.state == "playing", "All lanterns lit does not end a night before dawn")

func _check_low_fuel_drain() -> void:
	var sim := Sim.new(1, 305, {"random_motes": false, "random_shades": false, "lanterns": [{"id": "L1", "lit": true, "fuel": 29}], "shades": [{"id": "S1", "pos": [0, 0, 26], "state": "drain", "target_lantern_id": "L1"}]})
	sim.step()
	_check(is_equal_approx(sim.lanterns[0].fuel, 28.9), "Low-fuel shade adds 5 fuel drain per second")

func _check_lantern_out() -> void:
	var sim := Sim.new(1, 306, {"random_motes": false, "random_shades": false, "lanterns": [{"id": "L1", "lit": true, "fuel": 1.0 / 60.0}]})
	sim.step()
	_check(not sim.lanterns[0].lit and sim.lanterns[0].fuel == 0.0 and sim.lanterns[0].deposited == 0, "Lantern turns off and resets deposited fuel at zero")
	_check(sim.events.any(func(event: Dictionary) -> bool: return event.name == "lantern_out"), "Lantern-out event is emitted")

func _check_dawn_and_score() -> void:
	var lamps := [{"id": "L1", "lit": true}, {"id": "L2", "lit": true}, {"id": "L3", "lit": true}]
	var win := Sim.new(1, 307, {"random_motes": false, "random_shades": false, "time_left_s": 1.0 / 60.0, "lanterns": lamps})
	win.step()
	_check(win.state == "won" and win.score == 597, "Dawn win threshold and Phase 3 fuel/flame score")
	var lose := Sim.new(1, 308, {"random_motes": false, "random_shades": false, "time_left_s": 1.0 / 60.0, "player": {"flames": 0}, "lanterns": lamps})
	lose.step()
	_check(lose.state == "lost" and lose.events.any(func(event: Dictionary) -> bool: return event.name == "game_over" and event.data.reason == "no_flames"), "No-flames loss takes priority at dawn")
