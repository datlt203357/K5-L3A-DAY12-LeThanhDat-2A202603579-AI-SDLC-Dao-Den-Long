extends Node3D

const Sim = preload("res://scripts/game_sim.gd")
const FONT_SIZE := 20
const MAT_GRASS := Color("#2f5d50")
const MAT_WOOD := Color("#6b4a2f")
const MAT_WARM := Color("#ffb347")
const MAT_MOTE := Color("#fff6c2")
const MAT_SHADE := Color("#120a1a")
const DEFAULT_KEYS := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S, "jump": KEY_SPACE, "dash": KEY_SHIFT, "interact": KEY_E, "pulse": KEY_Q, "pause": KEY_P}

var sim
var accumulator := 0.0
var world := Node3D.new()
var actor_nodes: Dictionary = {}
var camera: Camera3D
var hud: Label
var game_environment: Environment
var menu_layer: CanvasLayer
var menu_panel: PanelContainer
var colorblind := false
var large_text := false
var reduced_motion := false
var settings_path := "user://settings.json"
var leaderboard_path := "user://leaderboard.json"
var score_submitted := false
var result_handled := false
var awaiting_rebind := ""
var keybinds := DEFAULT_KEYS.duplicate()
var leaderboard_entries: Array = []
var mode := "game"
var process_started_ms := 0
var bench_started_ms := 0
var bench_load_ms := 0
var bench_duration_s := 30.0
var bench_elapsed_s := 0.0
var bench_warmup_s := 3.0
var bench_frames: Array[float] = []
var bench_peak_mb := 0.0
var bench_rss_started := false
var bench_rss_stop_path := ""
var bench_rss_value_path := ""
var bench_rss_process_id := -1
var bench_out := "bench.json"
var bench_tick_accumulator := 0.0
var game_total_score := 0
var nights_won := 0
var camera_yaw_deg := 0.0
var mouse_sensitivity := 0.15
var master_volume := 1.0

func _ready() -> void:
	process_started_ms = Time.get_ticks_msec()
	_load_settings()
	_load_leaderboard()
	if _export_leaderboard_if_requested():
		return
	var args := OS.get_cmdline_user_args()
	if args.has("--bench"):
		_start_benchmark(args)
	else:
		sim = Sim.new(1, 1)
	_build_world()
	_build_hud()
	_build_menu()
	_update_scene()
	var screenshot_index := args.find("--screenshot")
	if screenshot_index >= 0:
		_start_new_game()
		var screenshot_path := str(args[screenshot_index + 1]) if screenshot_index + 1 < args.size() else "docs/demo/gameplay.png"
		call_deferred("_capture_screenshot", screenshot_path)
	elif mode != "bench":
		_show_title_menu()

func _process(delta: float) -> void:
	if sim == null:
		return
	if mode == "bench":
		_process_benchmark(delta)
		_update_scene()
		return
	if mode == "game" and sim.state == "playing":
		accumulator += minf(delta, 0.1)
		while accumulator >= 1.0 / 60.0:
			sim.set_input(_read_input())
			sim.step()
			accumulator -= 1.0 / 60.0
			if sim.state != "playing":
				break
	_update_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mode == "game" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw_deg = wrapf(camera_yaw_deg - event.relative.x * mouse_sensitivity, -180.0, 180.0)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if awaiting_rebind != "":
			if event.keycode == KEY_ESCAPE:
				awaiting_rebind = ""
				_show_settings()
				return
			for action in keybinds:
				if action != awaiting_rebind and int(keybinds[action]) == event.keycode:
					hud.text = "Phím này đã được dùng. Hãy chọn phím khác."
					return
			keybinds[awaiting_rebind] = event.keycode
			awaiting_rebind = ""
			_save_settings()
			_show_settings()
			return
		if event.keycode == KEY_ESCAPE or event.keycode == int(keybinds.pause):
			if sim and sim.state in ["playing", "paused"]:
				sim.set_input({"pause": true})
				sim.step()
				sim.set_input({"pause": false})
				_toggle_pause()
		elif event.keycode == KEY_R and sim and sim.state in ["won", "lost", "paused"]:
			_replay_current_night()
		elif event.keycode == KEY_ENTER and mode == "result":
			_accept_result()
		elif event.keycode == KEY_ENTER and mode == "menu":
			_start_new_game()
		elif event.keycode == KEY_H:
			_show_leaderboard()
		elif event.keycode == KEY_O and mode == "settings":
			colorblind = not colorblind
			_save_settings()
			_show_settings()
		elif event.keycode == KEY_V and mode == "settings":
			reduced_motion = not reduced_motion
			_save_settings()
			_show_settings()
		elif event.keycode == KEY_EQUAL and mode == "settings":
			large_text = not large_text
			_save_settings()
			_show_settings()

func _read_input() -> Dictionary:
	var move := Vector2.ZERO
	move.x = float(Input.is_key_pressed(int(keybinds.move_right))) - float(Input.is_key_pressed(int(keybinds.move_left)))
	move.y = float(Input.is_key_pressed(int(keybinds.move_back))) - float(Input.is_key_pressed(int(keybinds.move_forward)))
	return {"move": move, "cam_yaw_deg": camera_yaw_deg, "jump": Input.is_key_pressed(int(keybinds.jump)), "interact": Input.is_key_pressed(int(keybinds.interact)), "pulse": Input.is_key_pressed(int(keybinds.pulse)), "dash": Input.is_key_pressed(int(keybinds.dash))}

func _build_world() -> void:
	add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	game_environment = environment
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#0e1430")
	sky_mat.sky_horizon_color = Color("#1b2350")
	sky_mat.ground_bottom_color = Color("#12384a")
	sky_mat.ground_horizon_color = Color("#12384a")
	sky.sky_material = sky_mat
	environment.sky = sky
	env.environment = environment
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 0.8
	world.add_child(sun)
	_create_islands()
	var avatar := _mesh_node("Mây", SphereMesh.new(), Color("#e8e2d0"), Vector3(0.65, 0.9, 0.65))
	world.add_child(avatar)
	actor_nodes["player"] = avatar
	var hat := _mesh_node("Nón lá", CylinderMesh.new(), Color("#c9b48a"), Vector3(0.85, 0.16, 0.85))
	avatar.add_child(hat)
	hat.position = Vector3(0, 0.85, 0)
	var lantern_pole := _mesh_node("Lantern", CylinderMesh.new(), MAT_WOOD, Vector3(0.3, 2.4, 0.3))
	world.add_child(lantern_pole)
	actor_nodes["lanterns"] = []
	for l in sim.lanterns:
		var group := Node3D.new()
		world.add_child(group)
		var pole := _mesh_node("Cột " + l.id, CylinderMesh.new(), MAT_WOOD, Vector3(0.35, 1.7, 0.35))
		group.add_child(pole)
		pole.position.y = 1.7
		var flame := _mesh_node("Lửa " + l.id, SphereMesh.new(), Color("#5b5f6e"), Vector3(0.85, 0.85, 0.85))
		group.add_child(flame)
		flame.position.y = 3.65
		var light := OmniLight3D.new()
		light.position.y = 3.7
		light.omni_range = 9.0
		light.light_color = MAT_WARM
		light.light_energy = 0.0
		group.add_child(light)
		var fuel_bar := _mesh_node("Dầu " + l.id, BoxMesh.new(), MAT_WARM, Vector3(0.85, 0.06, 0.08))
		fuel_bar.position = Vector3(0, 4.25, 0)
		group.add_child(fuel_bar)
		group.position = l.pos
		actor_nodes.lanterns.append({"root": group, "flame": flame, "light": light, "fuel_bar": fuel_bar})
	var player_light := OmniLight3D.new()
	player_light.position = Vector3(0, 2.2, 0)
	player_light.omni_range = 5.0
	player_light.light_color = MAT_WARM
	player_light.light_energy = 0.7
	avatar.add_child(player_light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 68
	world.add_child(camera)
	
func _create_islands() -> void:
	if sim.night == 1:
		_add_disc(Vector3.ZERO, 40.0, 0.0, MAT_GRASS)
	elif sim.night == 2:
		_add_disc(Vector3.ZERO, 28.0, 0.0, MAT_GRASS)
		_add_disc(Vector3(70, 0, 0), 28.0, 0.0, MAT_GRASS)
		var bridge := _mesh_node("Cầu tre", BoxMesh.new(), MAT_WOOD, Vector3(18, 0.4, 4))
		bridge.position = Vector3(35, 0, 0)
		world.add_child(bridge)
	else:
		_add_disc(Vector3.ZERO, 45.0, 0.0, MAT_GRASS)
		_add_disc(Vector3(0, 3, 0), 24.0, 0.0, Color("#426f5d"))
		_add_disc(Vector3(0, 6, 0), 8.0, 0.0, Color("#527b62"))
	for i in range(12):
		var cloud := _mesh_node("Mây đảo %d" % i, SphereMesh.new(), Color("#55768a", 0.55), Vector3(8, 1.4, 5))
		cloud.position = Vector3(cos(i * TAU / 12) * 43, -1.5, sin(i * TAU / 12) * 43)
		world.add_child(cloud)

func _add_disc(center: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.03
	mesh.height = 0.5
	var island := _mesh_node("Đảo", mesh, color, Vector3.ONE)
	island.position = center + Vector3(0, height - 0.25, 0)
	world.add_child(island)

func _mesh_node(label: String, mesh: Mesh, color: Color, scale_value: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.scale = scale_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	return node

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(18, 14)
	hud.add_theme_font_size_override("font_size", FONT_SIZE if not large_text else 25)
	hud.add_theme_color_override("font_color", Color("#f5f1e6"))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)

func _build_menu() -> void:
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.custom_minimum_size = Vector2(420, 250)
	menu_panel.visible = false
	menu_layer.add_child(menu_panel)
	var label := Label.new()
	label.name = "MenuText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	var box := VBoxContainer.new()
	box.name = "MenuBox"
	box.add_child(label)
	menu_panel.add_child(box)
	var name_field := LineEdit.new()
	name_field.name = "PlayerName"
	name_field.placeholder_text = "Tên người chơi (3–12 ký tự)"
	name_field.max_length = 12
	name_field.visible = false
	name_field.text_submitted.connect(func(_value: String) -> void: _accept_result())
	box.add_child(name_field)

func _toggle_pause() -> void:
	if sim.state == "paused":
		mode = "pause"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_pause_menu()
	else:
		mode = "game"
		menu_panel.visible = false

func _show_menu(text: String) -> void:
	menu_panel.get_node("MenuBox/MenuText").text = text
	menu_panel.get_node("MenuBox/PlayerName").visible = false
	_clear_menu_buttons()
	menu_panel.visible = true

func _clear_menu_buttons() -> void:
	var box: VBoxContainer = menu_panel.get_node("MenuBox")
	for child in box.get_children():
		if child.name not in ["MenuText", "PlayerName"]:
			box.remove_child(child)
			child.queue_free()

func _add_menu_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 38)
	button.add_theme_font_size_override("font_size", 18 if not large_text else 23)
	button.pressed.connect(callback)
	menu_panel.get_node("MenuBox").add_child(button)

func _show_pause_menu() -> void:
	_show_menu("TẠM DỪNG")
	_add_menu_button("Tiếp tục", func() -> void: _resume_game())
	_add_menu_button("Chơi lại đêm", func() -> void: _replay_current_night())
	_add_menu_button("Cài đặt", func() -> void: _show_settings())
	_add_menu_button("Bảng xếp hạng", func() -> void: _show_leaderboard())
	_add_menu_button("Về menu chính", func() -> void: _show_title_menu())

func _resume_game() -> void:
	if sim.state == "paused":
		sim.set_input({"pause": true})
		sim.step()
		sim.set_input({"pause": false})
	mode = "game"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu_panel.visible = false

func _show_settings() -> void:
	mode = "settings"
	var lines := ["CÀI ĐẶT & TRỢ NĂNG", "O — bảng màu: %s · V — giảm chuyển động: %s · = — chữ lớn: %s" % ["Bật" if colorblind else "Tắt", "Bật" if reduced_motion else "Tắt", "Bật" if large_text else "Tắt"], "Chọn hành động để gán phím; phím trùng sẽ bị từ chối."]
	_show_menu("\n".join(lines))
	_add_menu_button("Bảng màu dễ phân biệt: %s" % ("Bật" if colorblind else "Tắt"), func() -> void: _toggle_colorblind())
	_add_menu_button("Giảm chuyển động: %s" % ("Bật" if reduced_motion else "Tắt"), func() -> void: _toggle_motion())
	_add_menu_button("Cỡ chữ lớn: %s" % ("Bật" if large_text else "Tắt"), func() -> void: _toggle_large_text())
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.05
	sensitivity.max_value = 0.6
	sensitivity.step = 0.01
	sensitivity.value = mouse_sensitivity
	sensitivity.tooltip_text = "Độ nhạy chuột"
	sensitivity.value_changed.connect(func(value: float) -> void: mouse_sensitivity = value; _save_settings())
	menu_panel.get_node("MenuBox").add_child(sensitivity)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = master_volume
	volume.tooltip_text = "Âm lượng"
	volume.value_changed.connect(func(value: float) -> void: master_volume = value; AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001))); _save_settings())
	menu_panel.get_node("MenuBox").add_child(volume)
	for action in DEFAULT_KEYS:
		_add_menu_button("%s: %s" % [_action_label(action), OS.get_keycode_string(int(keybinds[action]))], func() -> void: _begin_rebind(action))
	_add_menu_button("Khôi phục mặc định", func() -> void: _restore_keys())
	_add_menu_button("Quay lại", func() -> void: _show_pause_menu() if sim.state == "paused" else _show_title_menu())

func _toggle_colorblind() -> void:
	colorblind = not colorblind
	_save_settings()
	_show_settings()
	_update_scene()

func _toggle_motion() -> void:
	reduced_motion = not reduced_motion
	_save_settings()
	_show_settings()

func _toggle_large_text() -> void:
	large_text = not large_text
	_save_settings()
	_apply_accessibility()
	_show_settings()

func _apply_accessibility() -> void:
	if is_instance_valid(hud):
		hud.add_theme_font_size_override("font_size", 25 if large_text else FONT_SIZE)

func _action_label(action: String) -> String:
	return {"move_left": "Sang trái", "move_right": "Sang phải", "move_forward": "Tiến", "move_back": "Lùi", "jump": "Nhảy", "dash": "Lướt", "interact": "Tương tác", "pulse": "Tỏa sáng", "pause": "Tạm dừng"}.get(action, action)

func _begin_rebind(action: String) -> void:
	awaiting_rebind = action
	menu_panel.get_node("MenuBox/MenuText").text = "Nhấn phím mới cho: %s\nEscape để hủy." % _action_label(action)

func _restore_keys() -> void:
	keybinds = DEFAULT_KEYS.duplicate()
	_save_settings()
	_show_settings()

func _show_title_menu() -> void:
	mode = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_menu("ĐẢO ĐÈN LỒNG\nĐêm nay, hãy mang ánh sáng trở về.")
	_add_menu_button("Bắt đầu", func() -> void: _start_new_game())
	_add_menu_button("Bảng xếp hạng", func() -> void: _show_leaderboard())
	_add_menu_button("Cài đặt", func() -> void: _show_settings())

func _start_new_game() -> void:
	game_total_score = 0
	nights_won = 0
	camera_yaw_deg = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_night(1)

func _replay_current_night() -> void:
	if sim.state == "won":
		game_total_score = maxi(0, game_total_score - sim.score)
		nights_won = maxi(0, nights_won - 1)
	_start_night(sim.night)

func _show_leaderboard() -> void:
	mode = "leaderboard"
	var lines := ["BẢNG XẾP HẠNG"]
	for index in range(leaderboard_entries.size()):
		var row: Dictionary = leaderboard_entries[index]
		lines.append("%d. %s — %d điểm (%d đêm)" % [index + 1, row.name, row.score, row.nights_won])
	if leaderboard_entries.is_empty():
		lines.append("Chưa có kết quả được lưu.")
	_show_menu("\n".join(lines))
	_add_menu_button("Quay lại", func() -> void: _show_title_menu())

func _update_scene() -> void:
	var p: Vector3 = sim.player.pos
	var avatar: Node3D = actor_nodes.player
	avatar.position = p + Vector3.UP * 1.0
	var yaw := deg_to_rad(0.0 if reduced_motion else camera_yaw_deg)
	var camera_offset := Vector3(sin(yaw) * 13.0, 9.0, cos(yaw) * 13.0)
	camera.position = p + camera_offset
	camera.look_at(p + Vector3(0, 0.8, 0))
	for i in range(sim.lanterns.size()):
		var l: Dictionary = sim.lanterns[i]
		var vis: Dictionary = actor_nodes.lanterns[i]
		vis.root.position = l.pos
		vis.flame.material_override.albedo_color = MAT_WARM if l.lit else Color("#5b5f6e")
		vis.flame.scale = Vector3(0.85, 0.85, 0.85) if l.lit else Vector3(0.85, 0.68, 0.85)
		vis.light.light_energy = 1.2 if l.lit else 0.0
		vis.light.omni_range = 9.0 if l.lit else 0.0
		vis.fuel_bar.visible = l.lit and (float(l.fuel) >= 30.0 or reduced_motion or sim.sim_tick % 60 < 30)
		var fill := clampf(float(l.fuel) / 100.0, 0.0, 1.0)
		vis.fuel_bar.scale.x = 0.85 * fill
		vis.fuel_bar.position.x = -0.85 * (1.0 - fill) * 0.5
	game_environment.ambient_light_energy = 0.15 + 0.55 * float(_lit_count()) / float(sim.lanterns.size())
	for kind in ["motes", "shades", "drifters", "charms"]:
		_sync_entities(kind)
	var wind_note := "\n⚠ Gió sắp thổi" if sim.night == 3 and sim.sim_tick % 1800 >= 1680 and not sim.wind_active else ("\nGió mạnh!" if sim.wind_active else "")
	var alert_note := "\n⚠ 10 giây cuối" if sim.time_left <= 10.0 else ""
	var weak_note := "\n⚠ Đèn sắp cạn dầu" if _has_weak_lantern() else ""
	hud.text = "%s\n🔥 %d    Đèn %d/%d    Điểm %d\nĐom đóm %d/%d    ⏱ %02d:%02d%s%s%s" % [Sim.NIGHT_NAMES[sim.night - 1], sim.player.flames, _lit_count(), sim.lanterns.size(), sim.score, sim.player.carried, sim.player.capacity, int(sim.time_left) / 60, int(sim.time_left) % 60, alert_note, weak_note, wind_note]
	var timer_flash: bool = not reduced_motion and sim.time_left <= 30.0 and int(sim.sim_tick / 30) % 2 == 0
	hud.add_theme_color_override("font_color", Color("#ff5a5f") if timer_flash else Color("#f5f1e6"))
	if sim.state in ["won", "lost"] and not result_handled:
		_handle_night_result()

func _capture_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var output_path := ProjectSettings.globalize_path(path if path.begins_with("res://") else "res://" + path)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(output_path)
	if result != OK:
		printerr("Cannot save screenshot: " + output_path)
		get_tree().quit(1)
		return
	print("SCREENSHOT_OK: " + output_path)
	await RenderingServer.frame_post_draw
	get_tree().quit()

func _sync_entities(kind: String) -> void:
	var data: Array = sim.get(kind)
	if not actor_nodes.has(kind):
		actor_nodes[kind] = {}
	var nodes: Dictionary = actor_nodes[kind]
	var active := {}
	for entity in data:
		var id := str(entity.id)
		if kind == "charms" and not entity.available:
			continue
		if kind == "drifters" and entity.state == "removed":
			continue
		active[id] = true
		if not nodes.has(id):
			var color := MAT_MOTE if kind == "motes" or kind == "charms" else (Color("#8fa3b8") if kind == "drifters" else MAT_SHADE)
			var mesh := SphereMesh.new()
			var size := Vector3.ONE * (0.38 if kind == "motes" else (1.1 if kind == "shades" else 0.8))
			var node := _mesh_node(id, mesh, color, size)
			world.add_child(node)
			nodes[id] = node
		var n: Node3D = nodes[id]
		n.position = entity.pos + (Vector3.UP * 0.5 if kind == "motes" else Vector3.ZERO)
		if kind == "shades" and entity.state == "stunned":
			n.material_override.albedo_color = Color("#3a3450")
		elif kind == "shades":
			n.material_override.albedo_color = Color("#00b3ff" if colorblind else "#7a3cff")
	for old_id in nodes.keys():
		if not active.has(old_id):
			nodes[old_id].queue_free()
			nodes.erase(old_id)

func _lit_count() -> int:
	var total := 0
	for l in sim.lanterns:
		if l.lit:
			total += 1
	return total

func _has_weak_lantern() -> bool:
	for l in sim.lanterns:
		if l.lit and l.fuel < 30.0:
			return true
	return false

func _handle_night_result() -> void:
	result_handled = true
	mode = "result"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if sim.state == "won":
		game_total_score += sim.score
		nights_won += 1
		if sim.night < 3:
			_show_menu("BÌNH MINH — %s hoàn thành!\nĐiểm Đêm: %d · Tổng điểm: %d" % [Sim.NIGHT_NAMES[sim.night - 1], sim.score, game_total_score])
			_add_menu_button("Đêm tiếp theo", func() -> void: _accept_result())
			_add_menu_button("Chơi lại đêm này", func() -> void: _replay_current_night())
		else:
			_show_final_result("ĐÃ QUA BA ĐÊM!")
	else:
		_show_final_result("ĐÊM TỐI — %s" % ("hết Ngọn Lửa" if sim.player.flames <= 0 else "đèn chưa giữ được tới bình minh"))

func _show_final_result(title: String) -> void:
	_show_menu("%s\nTổng điểm: %d · Số đêm thắng: %d\nNhập tên để lưu bảng xếp hạng." % [title, game_total_score, nights_won])
	mode = "result"
	var name_field: LineEdit = menu_panel.get_node("MenuBox/PlayerName")
	name_field.visible = true
	name_field.text = ""
	name_field.grab_focus()
	_add_menu_button("Lưu điểm", func() -> void: _accept_result())
	_add_menu_button("Menu chính", func() -> void: _show_title_menu())

func _accept_result() -> void:
	if sim.state == "won" and sim.night < 3:
		_start_night(sim.night + 1)
		return
	var name_field: LineEdit = menu_panel.get_node("MenuBox/PlayerName")
	var player_name := name_field.text.strip_edges()
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_]{3,12}$")
	if regex.search(player_name) == null:
		menu_panel.get_node("MenuBox/MenuText").text += "\nTên không hợp lệ: cần 3–12 ký tự A–Z, a–z, 0–9 hoặc _."
		return
	_submit_score(player_name)
	_show_leaderboard()

func _start_night(number: int) -> void:
	if is_instance_valid(world):
		world.queue_free()
		world = Node3D.new()
		actor_nodes.clear()
		sim = Sim.new(number, sim.seed_value)
		_build_world()
		score_submitted = false
		result_handled = false
		accumulator = 0.0
		menu_panel.visible = false
		mode = "game"
		_update_scene()

func _start_benchmark(args: PackedStringArray) -> void:
	var opts := _args_to_dict(args)
	var seed_value := int(opts.get("seed", 42))
	bench_duration_s = float(opts.get("duration", 30))
	bench_out = str(opts.get("out", "bench.json"))
	var scenario := {"random_motes": false, "random_shades": false, "random_drifters": false, "wind_enabled": false}
	scenario["motes"] = []
	scenario["shades"] = []
	scenario["lanterns"] = [{"id": "L1", "lit": true, "fuel": 100}, {"id": "L2", "lit": true, "fuel": 100}, {"id": "L3", "lit": true, "fuel": 100}]
	for i in range(100):
		var angle := TAU * i / 100.0
		scenario.motes.append([cos(angle) * 34.0, 0, sin(angle) * 34.0])
	for i in range(200):
		var angle := TAU * i / 200.0
		var radius := 18.0 + float((i * 17) % 2000) / 100.0
		scenario.shades.append({"id": "S%d" % (i + 1), "pos": [cos(angle) * radius, 0, sin(angle) * radius], "state": "wander"})
	sim = Sim.new(1, seed_value, scenario)
	mode = "bench"
	bench_started_ms = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _process_benchmark(delta: float) -> void:
	var elapsed := float(Time.get_ticks_msec() - bench_started_ms) / 1000.0
	if bench_load_ms == 0:
		bench_load_ms = Time.get_ticks_msec() - process_started_ms
	var angle := TAU * fmod(elapsed, 15.0) / 15.0
	camera.position = Vector3(cos(angle) * 30.0, 15.0, sin(angle) * 30.0)
	camera.look_at(Vector3.ZERO)
	bench_tick_accumulator += delta
	while bench_tick_accumulator >= 1.0 / 60.0:
		sim.sim_tick += 1
		sim._move_shades()
		bench_tick_accumulator -= 1.0 / 60.0
	if elapsed >= bench_warmup_s:
		if not bench_rss_started:
			_start_rss_monitor()
		bench_elapsed_s += delta
		bench_frames.append(delta * 1000.0)
	if bench_elapsed_s >= bench_duration_s:
		_finish_rss_monitor()
		_write_benchmark()
		get_tree().quit()

func _start_rss_monitor() -> void:
	bench_rss_started = true
	if OS.get_name() != "Windows":
		bench_peak_mb = _read_rss_mb()
		return
	bench_rss_stop_path = ProjectSettings.globalize_path("user://bench-rss-stop.tmp")
	bench_rss_value_path = ProjectSettings.globalize_path("user://bench-rss-peak.tmp")
	var stop_file := FileAccess.open("user://bench-rss-stop.tmp", FileAccess.WRITE)
	if stop_file == null:
		bench_peak_mb = _read_rss_mb()
		return
	stop_file.close()
	DirAccess.remove_absolute(bench_rss_stop_path)
	var monitor_script := ProjectSettings.globalize_path("res://scripts/rss_monitor.ps1")
	bench_rss_process_id = OS.create_process("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", monitor_script, "-TargetPid", str(OS.get_process_id()), "-OutputPath", bench_rss_value_path, "-StopPath", bench_rss_stop_path], false)
	if bench_rss_process_id < 0:
		bench_peak_mb = _read_rss_mb()

func _finish_rss_monitor() -> void:
	if OS.get_name() == "Windows" and bench_rss_process_id > 0:
		var stop_file := FileAccess.open("user://bench-rss-stop.tmp", FileAccess.WRITE)
		if stop_file:
			stop_file.store_string("stop")
			stop_file.close()
		OS.delay_msec(120)
		if FileAccess.file_exists("user://bench-rss-peak.tmp"):
			var peak_text := FileAccess.get_file_as_string("user://bench-rss-peak.tmp").strip_edges()
			if peak_text.is_valid_int():
				bench_peak_mb = float(int(peak_text)) / 1048576.0
	if bench_peak_mb <= 0.0:
		bench_peak_mb = _read_rss_mb()

func _write_benchmark() -> void:
	var sorted := bench_frames.duplicate()
	sorted.sort()
	var sum_ms := 0.0
	for dt in bench_frames:
		sum_ms += dt
	var n := bench_frames.size()
	var p95_i := clampi(ceili(n * 0.95) - 1, 0, maxi(0, n - 1))
	var tail_count := maxi(1, ceili(n * 0.01))
	var tail_sum := 0.0
	for i in range(maxi(0, n - tail_count), n):
		tail_sum += sorted[i]
	var low_fps := 1000.0 / maxf(0.001, tail_sum / tail_count)
	var body := {"contract_version": "1.3", "avg_fps": 1000.0 * n / maxf(0.001, sum_ms), "p1_low_fps": low_fps, "frame_ms_p95": sorted[p95_i] if n > 0 else 0.0, "frames": n, "load_ms": bench_load_ms, "peak_mem_mb": bench_peak_mb, "vsync_off": DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "renderer": "Godot 4.7.2 / GL Compatibility", "os": OS.get_name()}
	var f := FileAccess.open(bench_out, FileAccess.WRITE)
	if f == null:
		printerr("Cannot open benchmark output: " + bench_out)
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(body, "\t"))
	f.close()

func _read_rss_mb() -> float:
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

func _args_to_dict(args: PackedStringArray) -> Dictionary:
	var result := {}
	var i := 0
	while i < args.size():
		var key := str(args[i]).trim_prefix("--")
		if key == "":
			i += 1
			continue
		if i + 1 >= args.size() or str(args[i + 1]).begins_with("--"):
			result[key] = true
			i += 1
		else:
			result[key] = args[i + 1]
			i += 2
	return result

func _load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if parsed is Dictionary:
			colorblind = bool(parsed.get("colorblind", false))
			large_text = bool(parsed.get("large_text", false))
			reduced_motion = bool(parsed.get("reduced_motion", false))
			mouse_sensitivity = float(parsed.get("mouse_sensitivity", 0.15))
			master_volume = float(parsed.get("master_volume", 1.0))
			var saved_keys: Dictionary = parsed.get("keybinds", {})
			for action in keybinds:
				if saved_keys.has(action):
					keybinds[action] = int(saved_keys[action])

func _save_settings() -> void:
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"colorblind": colorblind, "large_text": large_text, "reduced_motion": reduced_motion, "mouse_sensitivity": mouse_sensitivity, "master_volume": master_volume, "keybinds": keybinds}))
		f.close()

func _load_leaderboard() -> void:
	if FileAccess.file_exists(leaderboard_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(leaderboard_path))
		if parsed is Dictionary:
			leaderboard_entries = parsed.get("entries", [])

func _submit_score(name: String) -> void:
	var subsecond_ms := int(fmod(Time.get_unix_time_from_system(), 1.0) * 1000.0)
	var row := {"name": name, "score": game_total_score, "nights_won": nights_won, "achieved_at": Time.get_datetime_string_from_system(true, true) + ".%03dZ" % subsecond_ms, "seed": sim.seed_value}
	leaderboard_entries.append(row)
	leaderboard_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) == int(b.score):
			return str(a.achieved_at) < str(b.achieved_at)
		return int(a.score) > int(b.score))
	if leaderboard_entries.size() > 10:
		leaderboard_entries.resize(10)
	var f := FileAccess.open(leaderboard_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"entries": leaderboard_entries}, "\t"))
		f.close()

func _export_leaderboard_if_requested() -> bool:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--export-leaderboard")
	if i < 0:
		return false
	var out := args[i + 1] if i + 1 < args.size() else "out.json"
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"entries": leaderboard_entries}, "\t"))
		file.close()
	get_tree().quit()
	return true
