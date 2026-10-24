extends SceneTree

var failures: Array[String] = []
var skipped_tests: Array[String] = []
var passed_count: int = 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var packed := load("res://scenes/expedition_3d.tscn") as PackedScene
	_check(packed != null, "A cena 3D deve carregar como PackedScene")
	if packed == null:
		_finish()
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player := scene.get_node_or_null("LocalPlayer") as CharacterBody3D
	_check(player != null, "A cena deve criar o jogador local")
	_check(scene.get_node_or_null("CentralFloor") != null, "A cena deve criar a sala central")
	_check(scene.get_node_or_null("NorthRoomFloor") != null, "A cena deve criar a zona norte")
	_check(scene.get_node_or_null("EastRoomFloor") != null, "A cena deve criar a zona este")
	_check(scene.get_node_or_null("SouthRoomFloor") != null, "A cena deve criar a zona sul")
	_check(scene.get_node_or_null("DoorToNorth") != null, "A ligação norte deve ter porta")
	_check(scene.get_node_or_null("DoorToEast") != null, "A ligação este deve ter porta")
	_check(scene.get_node_or_null("DoorToSouth") != null, "A ligação sul deve ter porta")

	if player == null:
		_finish()
		return

	player.set_physics_process(false)
	_check(scene.has_node("LocalPlayer/PlayerCamera"), "O jogador deve ter câmara em primeira pessoa")

	await _test_door_passage(
		scene, player, "DoorToNorth", "norte",
		Vector3(0, 0.1, -3.2), 0.0,
		Vector3(0, 1.0, -3.5), Vector3(0, 1.0, -6.5),
		Vector3(0, 0.1, -3.5), Vector3(0, 0, -0.1)
	)
	await _test_door_passage(
		scene, player, "DoorToEast", "este",
		Vector3(3.2, 0.1, 0), -PI / 2.0,
		Vector3(3.5, 1.0, 0), Vector3(6.5, 1.0, 0),
		Vector3(3.5, 0.1, 0), Vector3(0.1, 0, 0)
	)
	await _test_door_passage(
		scene, player, "DoorToSouth", "sul",
		Vector3(0, 0.1, 3.2), PI,
		Vector3(0, 1.0, 3.5), Vector3(0, 1.0, 6.5),
		Vector3(0, 0.1, 3.5), Vector3(0, 0, 0.1)
	)

	await _test_connector_floor_support(scene, player)
	await _test_player_navigation(scene, player)
	await _test_outer_wall_collisions(player)
	await _test_keyboard_movement(player)
	await _test_mouse_look_and_capture(player)
	await _test_animation_asset()
	await _test_main_menu()
	await _test_multiplayer_replication_helpers(scene)
	await _test_multiplayer_connection()
	await _test_start_expedition_button()
	_finish()

func _test_connector_floor_support(scene: Node3D, player: CharacterBody3D) -> void:
	var connectors := [
		{"name": "norte", "point": Vector3(0, 1, -6)},
		{"name": "este", "point": Vector3(6, 1, 0)},
		{"name": "sul", "point": Vector3(0, 1, 6)}
	]
	for connector in connectors:
		var point: Vector3 = connector["point"]
		var hit := _raycast(scene, player, point, point + Vector3(0, -2, 0))
		_check(not hit.is_empty(), "A ligação " + str(connector["name"]) + " tem chão contínuo sob a passagem")

		player.position = Vector3(point.x, 2.0, point.z)
		player.velocity = Vector3.ZERO
		var physics_delta: float = 1.0 / float(Engine.physics_ticks_per_second)
		for step in range(60):
			await physics_frame
			player.velocity.y -= 18.0 * physics_delta
			player.move_and_slide()
		_check(player.is_on_floor() and player.position.y > -0.25, "O jogador mantém apoio físico no corredor " + str(connector["name"]))

func _test_player_navigation(scene: Node3D, player: CharacterBody3D) -> void:
	player.position = Vector3.ZERO
	await physics_frame
	var start_x: float = player.position.x
	_walk_steps(player, Vector3(0.1, 0, 0), 8)
	_check(player.position.x > start_x + 0.3, "O jogador consegue deslocar-se numa zona desimpedida")

	player.position = Vector3(-3.8, 0.1, 3.5)
	await physics_frame
	_walk_steps(player, Vector3(-0.1, 0, 0), 20)
	_check(player.position.x < -4.2 and player.position.x > -4.8, "A colisão da parede oeste impede o jogador de atravessar a parede")

func _test_outer_wall_collisions(player: CharacterBody3D) -> void:
	await _test_wall_collision(player, "parede oeste da zona norte", Vector3(-4.2, 0.1, -12), Vector3(-0.1, 0, 0), "x", -4.8, false)
	await _test_wall_collision(player, "parede este da zona norte", Vector3(4.2, 0.1, -12), Vector3(0.1, 0, 0), "x", 4.8, true)
	await _test_wall_collision(player, "parede de fundo da zona norte", Vector3(0, 0.1, -16.2), Vector3(0, 0, -0.1), "z", -16.8, false)
	await _test_wall_collision(player, "parede superior da zona este", Vector3(12, 0.1, -4.2), Vector3(0, 0, -0.1), "z", -4.8, false)
	await _test_wall_collision(player, "parede inferior da zona este", Vector3(12, 0.1, 4.2), Vector3(0, 0, 0.1), "z", 4.8, true)
	await _test_wall_collision(player, "parede de fundo da zona este", Vector3(16.2, 0.1, 0), Vector3(0.1, 0, 0), "x", 16.8, true)
	await _test_wall_collision(player, "parede oeste da zona sul", Vector3(-4.2, 0.1, 12), Vector3(-0.1, 0, 0), "x", -4.8, false)
	await _test_wall_collision(player, "parede este da zona sul", Vector3(4.2, 0.1, 12), Vector3(0.1, 0, 0), "x", 4.8, true)
	await _test_wall_collision(player, "parede de fundo da zona sul", Vector3(0, 0.1, 16.2), Vector3(0, 0, 0.1), "z", 16.8, true)

func _test_wall_collision(
	player: CharacterBody3D,
	wall_name: String,
	start: Vector3,
	motion: Vector3,
	axis: String,
	boundary: float,
	toward_positive: bool
) -> void:
	player.position = start
	await physics_frame
	_walk_steps(player, motion, 20)
	var start_value: float = start.x if axis == "x" else start.z
	var final_value: float = player.position.x if axis == "x" else player.position.z
	var moved_toward_wall: bool = final_value > start_value if toward_positive else final_value < start_value
	var stayed_inside: bool = final_value < boundary if toward_positive else final_value > boundary
	_check(moved_toward_wall and stayed_inside, "A colisão impede atravessar a " + wall_name)

func _test_keyboard_movement(player: CharacterBody3D) -> void:
	await _test_key_direction(player, KEY_W, "W", "z", false)
	await _test_key_direction(player, KEY_S, "S", "z", true)
	await _test_key_direction(player, KEY_A, "A", "x", false)
	await _test_key_direction(player, KEY_D, "D", "x", true)

func _test_key_direction(
	player: CharacterBody3D,
	key_code: Key,
	key_name: String,
	axis: String,
	toward_positive: bool
) -> void:
	player.set_physics_process(false)
	player.position = Vector3(0, 0.1, 0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await physics_frame
	player.set_physics_process(true)

	var key_event := InputEventKey.new()
	key_event.keycode = key_code
	key_event.physical_keycode = key_code
	key_event.pressed = true
	Input.parse_input_event(key_event)
	for step in range(12):
		await physics_frame

	key_event.pressed = false
	Input.parse_input_event(key_event)
	await physics_frame
	player.set_physics_process(false)

	var final_value: float = player.position.x if axis == "x" else player.position.z
	var moved_in_expected_direction: bool = final_value > 0.25 if toward_positive else final_value < -0.25
	_check(moved_in_expected_direction, "A tecla " + key_name + " move o jogador na direção esperada")

func _test_mouse_look_and_capture(player: CharacterBody3D) -> void:
	var camera := player.get_node_or_null("PlayerCamera") as Camera3D
	_check(camera != null, "A câmara está disponível para testar a rotação pelo rato")
	if camera == null:
		return

	player.set_physics_process(false)
	player.rotation = Vector3.ZERO
	player.set("pitch", 0.0)
	camera.rotation = Vector3.ZERO

	player.call("_apply_mouse_motion", Vector2(50, 50))
	_check(absf(player.rotation.y + 0.11) < 0.001, "O movimento horizontal do rato roda o jogador")
	_check(absf(float(player.get("pitch")) + 0.11) < 0.001, "O movimento vertical do rato altera a inclinação da vista")
	_check(absf(camera.rotation.x - float(player.get("pitch"))) < 0.001, "A câmara acompanha a inclinação do rato")

	player.call("_apply_mouse_motion", Vector2(0, 10000))
	_check(absf(float(player.get("pitch")) + 1.35) < 0.001, "A vista respeita o limite inferior de inclinação")
	player.call("_apply_mouse_motion", Vector2(0, -10000))
	_check(absf(float(player.get("pitch")) - 1.35) < 0.001, "A vista respeita o limite superior de inclinação")

	_skip("Captura/libertação do rato por eventos reais", "O runner Godot headless não fornece um dispositivo de rato capturável; este comportamento requer teste gráfico.")
	_skip("ESC e clique esquerdo para alternar captura do rato", "O estado Input.mouse_mode não é verificável de forma fiável neste runner headless.")

func _test_animation_asset() -> void:
	# O PRE-FLIGHT gera este GLB a partir da biblioteca CC0; localmente pode não existir.
	if not ResourceLoader.exists("res://assets/character_animated.glb"):
		_skip("Clips humanoides CC0", "O GLB animado é criado pelo passo de preparação do PRE-FLIGHT.")
		return
	var packed := load("res://assets/character_animated.glb") as PackedScene
	_check(packed != null, "O modelo humanoide com animações deve importar como PackedScene")
	if packed == null:
		return
	var model := packed.instantiate()
	root.add_child(model)
	await process_frame
	var animation_player := _find_animation_player_for_test(model)
	_check(animation_player != null, "O GLB combinado deve expor um AnimationPlayer")
	if animation_player != null:
		var names := animation_player.get_animation_list()
		_check(names.size() > 0, "O modelo combinado deve conter clips de animação")
		var has_walk := false
		var has_idle := false
		for animation_name in names:
			var normalized := String(animation_name).to_lower()
			has_walk = has_walk or normalized.contains("walk")
			has_idle = has_idle or normalized.contains("idle")
		var has_run := false
		for animation_name in names:
			has_run = has_run or String(animation_name).to_lower().contains("run")
		_check(has_walk, "O GLB deve conter uma animação de caminhada")
		_check(has_idle, "O GLB deve conter uma animação de repouso")
		_check(has_run, "O GLB deve conter uma animação de corrida")
		if has_walk:
			for animation_name in names:
				if String(animation_name).to_lower().contains("walk"):
					animation_player.play(String(animation_name))
					break
		_check(animation_player.is_playing(), "A animação de caminhada deve poder ser iniciada")
	model.queue_free()
	await process_frame

func _find_animation_player_for_test(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player_for_test(child)
		if found != null:
			return found
	return null

func _test_main_menu() -> void:
	var menu_scene := load("res://scenes/main.tscn") as PackedScene
	_check(menu_scene != null, "O menu principal deve carregar como PackedScene")
	if menu_scene == null:
		return
	var menu := menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	_check(menu.get("start_expedition_button") is Button, "O menu deve criar o botão para iniciar a expedição")
	_check(menu.get("host_button") is Button, "O menu deve criar o botão para criar sala")
	_check(menu.get("join_button") is Button, "O menu deve criar o botão para entrar numa sala")
	_check(menu.get("disconnect_button") is Button, "O menu deve criar o botão para desligar")
	_check(menu.get("status_label") is Label, "O menu deve apresentar o estado da ligação")
	_check(menu.get("players_label") is Label, "O menu deve apresentar a contagem de jogadores")
	menu.call("_host_game")
	await process_frame
	_check(menu.multiplayer.is_server(), "Criar sala deve iniciar um servidor ENet local")
	_check(not (menu.get("disconnect_button") as Button).disabled, "O botão desligar deve ficar ativo após criar sala")
	menu.call("_disconnect_game")
	await process_frame
	_check(menu.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Desligar deve repor o modo offline")
	_check((menu.get("host_button") as Button).disabled == false, "O botão criar sala deve reativar após desligar")
	menu.queue_free()
	await process_frame

func _test_start_expedition_button() -> void:
	var menu_scene := load("res://scenes/main.tscn") as PackedScene
	_check(menu_scene != null, "O menu está disponível para testar o botão iniciar")
	if menu_scene == null:
		return
	var menu := menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	var start_button := menu.get("start_expedition_button") as Button
	_check(start_button != null, "O botão iniciar está disponível")
	if start_button != null:
		start_button.pressed.emit()
		await process_frame
		await process_frame
		var current := current_scene
		_check(current != null and current.scene_file_path == "res://scenes/expedition_3d.tscn", "O botão iniciar abre a cena de expedição 3D")
	menu.queue_free()
	await process_frame

func _test_multiplayer_connection() -> void:
	var menu_scene := load("res://scenes/main.tscn") as PackedScene
	_check(menu_scene != null, "A cena do menu está disponível para o teste de rede")
	if menu_scene == null:
		return

	var host_root := Node.new()
	host_root.name = "TestHostRoot"
	root.add_child(host_root)
	var client_root := Node.new()
	client_root.name = "TestClientRoot"
	root.add_child(client_root)

	var host_api := MultiplayerAPI.create_default_interface()
	var client_api := MultiplayerAPI.create_default_interface()
	set_multiplayer(host_api, host_root.get_path())
	set_multiplayer(client_api, client_root.get_path())

	var host_menu := menu_scene.instantiate() as Control
	host_root.add_child(host_menu)
	await process_frame
	host_menu.call("_host_game")
	await process_frame
	_check(host_api.is_server(), "O anfitrião de teste inicia um servidor ENet real")

	var client_menu := menu_scene.instantiate() as Control
	client_root.add_child(client_menu)
	await process_frame
	var address_input := client_menu.get("address_input") as LineEdit
	address_input.text = "127.0.0.1"
	client_menu.call("_join_game")

	var connected := false
	for attempt in range(100):
		await create_timer(0.05).timeout
		if client_api.multiplayer_peer != null and client_api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and host_api.get_peers().size() == 1:
			connected = true
			break

	_check(connected, "Um cliente ENet local consegue ligar-se ao anfitrião")
	_check(host_api.get_peers().size() == 1, "O anfitrião reconhece o cliente ligado")
	var host_players_label := host_menu.get("players_label") as Label
	_check(host_players_label != null and host_players_label.text == "Jogadores ligados: 2", "O anfitrião atualiza a contagem para dois jogadores")
	var client_status_label := client_menu.get("status_label") as Label
	var client_status_ready := false
	for attempt in range(20):
		await process_frame
		if client_status_label != null and client_status_label.text.contains("Ligação ao anfitrião estabelecida."):
			client_status_ready = true
			break
	var client_status_text := client_status_label.text if client_status_label != null else "<sem etiqueta de estado>"
	_check(client_status_ready, "O cliente apresenta a ligação estabelecida (estado atual: %s)" % client_status_text)

	client_menu.call("_disconnect_game")
	var disconnected := false
	for attempt in range(40):
		await create_timer(0.05).timeout
		if host_api.get_peers().is_empty():
			disconnected = true
			break
	_check(disconnected, "O anfitrião deteta a saída do cliente")
	if host_players_label != null:
		_check(host_players_label.text == "Jogadores ligados: 1", "A contagem do anfitrião regressa a um após a saída do cliente")

	host_menu.call("_disconnect_game")
	await process_frame
	client_root.queue_free()
	host_root.queue_free()
	await process_frame

func _test_door_passage(
	scene: Node3D,
	player: CharacterBody3D,
	door_name: String,
	direction_name: String,
	player_position: Vector3,
	player_yaw: float,
	ray_from: Vector3,
	ray_to: Vector3,
	traversal_start: Vector3,
	traversal_motion: Vector3
) -> void:
	var door := scene.get_node_or_null(door_name) as Node3D
	if door == null:
		_check(false, "A porta " + direction_name + " existe para o teste de passagem")
		return

	player.position = player_position
	player.rotation.y = player_yaw
	await physics_frame
	player.call("_update_door_prompt")
	_check(player.get("nearby_door") == door, "O jogador identifica a porta " + direction_name + " pela colisão")

	var closed_hit := _raycast(scene, player, ray_from, ray_to)
	_check(_is_door_hit(closed_hit), "A porta " + direction_name + " bloqueia a passagem quando fechada")

	player.position = traversal_start
	_walk_steps(player, traversal_motion, 40)
	_check(not _crossed_doorway(direction_name, player.position), "O corpo do jogador não atravessa a porta " + direction_name + " fechada")

	var initial_yaw: float = door.rotation.y
	player.set("nearby_door", door)
	_press_interaction_key(player)
	await physics_frame
	await physics_frame
	_check(bool(door.get_meta("open", false)), "A tecla E abre a porta " + direction_name)
	var door_prompt := player.get("prompt") as Label
	_check(door_prompt != null and door_prompt.text == "[E] Fechar porta", "O aviso da porta " + direction_name + " muda para fechar")
	_check(absf(wrapf(door.rotation.y - initial_yaw, -PI, PI)) > 0.1, "A porta " + direction_name + " roda ao abrir")

	var open_hit := _raycast(scene, player, ray_from, ray_to)
	_check(open_hit.is_empty(), "A passagem " + direction_name + " fica desimpedida com a porta aberta")

	player.position = traversal_start
	_walk_steps(player, traversal_motion, 40)
	_check(_crossed_doorway(direction_name, player.position), "O corpo do jogador atravessa fisicamente a porta " + direction_name + " aberta")

	_walk_steps(player, -traversal_motion, 40)
	_check(_returned_to_central(direction_name, player.position), "O jogador regressa fisicamente à sala central pela porta " + direction_name)

	player.set("nearby_door", door)
	_press_interaction_key(player)
	await physics_frame
	await physics_frame
	_check(not bool(door.get_meta("open", true)), "A tecla E fecha a porta " + direction_name)
	_check(door_prompt != null and door_prompt.text == "[E] Abrir porta", "O aviso da porta " + direction_name + " muda para abrir")
	_check(absf(wrapf(door.rotation.y - initial_yaw, -PI, PI)) < 0.1, "A porta " + direction_name + " regressa à rotação inicial")

	var closed_again_hit := _raycast(scene, player, ray_from, ray_to)
	_check(_is_door_hit(closed_again_hit), "A passagem " + direction_name + " volta a ficar bloqueada ao fechar")

func _press_interaction_key(player: CharacterBody3D) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = true
	player.call("_unhandled_input", event)

func _walk_steps(player: CharacterBody3D, motion: Vector3, steps: int) -> void:
	for i in range(steps):
		var collision := player.move_and_collide(motion)
		if collision != null:
			break

func _crossed_doorway(direction_name: String, position: Vector3) -> bool:
	match direction_name:
		"norte":
			return position.z < -5.5
		"este":
			return position.x > 5.5
		"sul":
			return position.z > 5.5
	return false

func _returned_to_central(direction_name: String, position: Vector3) -> bool:
	match direction_name:
		"norte":
			return position.z > -5.5
		"este":
			return position.x < 5.5
		"sul":
			return position.z < 5.5
	return false

func _raycast(scene: Node3D, player: CharacterBody3D, ray_from: Vector3, ray_to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.exclude = [player.get_rid()]
	return scene.get_world_3d().direct_space_state.intersect_ray(query)

func _is_door_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	return collider is Node and (collider as Node).has_meta("is_door")

func _check(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("PASS | ", message)
	else:
		push_error("FAIL | " + message)
		failures.append(message)

func _skip(message: String, reason: String) -> void:
	skipped_tests.append(message)
	print("SKIP | ", message, " — ", reason)

func _finish() -> void:
	var summary := "TOTAL_PASS=%d TOTAL_FAIL=%d TOTAL_SKIP=%d" % [passed_count, failures.size(), skipped_tests.size()]
	if failures.is_empty():
		print(summary + " RESULTADO=PASS")
		quit(0)
	else:
		push_error(summary + " RESULTADO=FAIL")
		quit(1)

func _test_multiplayer_replication_helpers(scene: Node3D) -> void:
	var door := scene.get_node_or_null("DoorToNorth") as Node3D
	_check(door != null, "A porta existe para validar o estado sincronizável")
	if door == null:
		return
	scene.call("_add_remote_player", 42, Vector3(2, 0.1, 3), 0.5, 0.0)
	var avatar := scene.get_node_or_null("RemotePlayer_42") as Node3D
	_check(avatar != null, "Um jogador remoto cria uma representação visual")
	if avatar != null:
		var character_model := avatar.get_node_or_null("CharacterModel") as Node3D
		_check(character_model != null, "O avatar remoto carrega o modelo humanoide GLB")
		if character_model != null:
			var mesh_count := 0
			var skeleton_count := 0
			var stack: Array[Node] = [character_model]
			while not stack.is_empty():
				var current: Node = stack.pop_back()
				if current is MeshInstance3D:
					mesh_count += 1
				if current is Skeleton3D:
					skeleton_count += 1
					_check((current as Skeleton3D).get_bone_count() >= 60, "O modelo humanoide inclui esqueleto articulado")
				for child in current.get_children():
					stack.append(child)
			_check(mesh_count >= 3, "O modelo humanoide contém malhas 3D importadas")
			_check(skeleton_count >= 1, "O modelo humanoide contém um esqueleto")
		var animation_players := scene.get("_remote_animation_players") as Dictionary
		var animation_names := scene.get("_remote_animation_names") as Dictionary
		var animation_player := animation_players.get(avatar.get_instance_id()) as AnimationPlayer
		if animation_player != null:
			scene.call("_animate_remote_avatar", 42, avatar, 0.05, 0.0)
			_check(animation_player.current_animation.to_lower().contains("idle"), "O avatar remoto usa repouso quando está parado")
			scene.call("_animate_remote_avatar", 42, avatar, 0.05, 1.5)
			_check(animation_player.current_animation.to_lower().contains("walk"), "O avatar remoto muda para caminhada em movimento normal")
			scene.call("_animate_remote_avatar", 42, avatar, 0.05, 5.0)
			_check(animation_player.current_animation.to_lower().contains("run"), "O avatar remoto muda para corrida quando se desloca depressa")
			_check(animation_player.is_playing(), "A animação de corrida permanece ativa após a transição")
			_check(animation_names.has(avatar.get_instance_id()), "O estado de animação é guardado por avatar remoto")
		var initial_position := avatar.global_position
		scene.call("_apply_remote_position", 42, Vector3(4, 0.1, 5), 1.0, 0.2)
		_check((scene.get("_remote_targets") as Dictionary).has(42), "A posição recebida fica definida como destino de movimento")
		scene.call("_process", 0.05)
		_check(avatar.global_position.distance_to(initial_position) > 0.1 and avatar.global_position.distance_to(Vector3(4, 0.1, 5)) > 0.1, "O avatar remoto aproxima-se do destino sem saltar diretamente")
		var remote_skeletons := scene.get("_remote_skeletons") as Dictionary
		var animated_skeleton := remote_skeletons.get(avatar.get_instance_id()) as Skeleton3D
		_check(animated_skeleton != null, "O avatar remoto tem esqueleto associado ao sistema de animação")
		if animated_skeleton != null:
			var thigh_index := animated_skeleton.find_bone("thigh_l")
			_check(thigh_index >= 0, "O esqueleto tem o osso da perna esquerda")
			if thigh_index >= 0:
				_check(absf(animated_skeleton.get_bone_pose_rotation(thigh_index).angle_to(Quaternion.IDENTITY)) > 0.001, "O ciclo de caminhada altera a pose da perna")
		scene.call("_process", 1.0)
		_check(avatar.global_position.distance_to(Vector3(4, 0.1, 5)) < 0.001, "O avatar remoto converge para a posição recebida")
		_check(absf(avatar.rotation.y - 1.0) < 0.001, "A orientação recebida é interpolada até ao destino")
	scene.call("_apply_door_state", "DoorToNorth", true)
	_check(bool(door.get_meta("open", false)), "O estado remoto abre a porta no cenário")
	_check(absf(wrapf(door.rotation.y - float(door.get_meta("closed_yaw")), -PI, PI)) > 0.1, "A porta replica a rotação aberta")
	scene.call("_apply_door_state", "DoorToNorth", false)
	_check(not bool(door.get_meta("open", true)), "O estado remoto fecha a porta no cenário")
	scene.call("_toggle_door_authoritatively", "DoorToNorth")
	_check(bool(door.get_meta("open", false)), "O anfitrião alterna a porta a partir do estado autoritativo")
	scene.call("_toggle_door_authoritatively", "DoorToNorth")
	_check(not bool(door.get_meta("open", true)), "O anfitrião fecha a porta sem confiar no estado pedido pelo cliente")
