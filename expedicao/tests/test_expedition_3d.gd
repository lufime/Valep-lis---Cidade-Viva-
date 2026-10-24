extends SceneTree

var failures: Array[String] = []

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

	await _test_player_navigation(scene, player)
	await _test_main_menu()
	await _test_multiplayer_connection()
	await _test_start_expedition_button()
	_finish()

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
	player.call("_interact")
	await physics_frame
	await physics_frame
	_check(bool(door.get_meta("open", false)), "A interação abre a porta " + direction_name)
	_check(absf(wrapf(door.rotation.y - initial_yaw, -PI, PI)) > 0.1, "A porta " + direction_name + " roda ao abrir")

	var open_hit := _raycast(scene, player, ray_from, ray_to)
	_check(open_hit.is_empty(), "A passagem " + direction_name + " fica desimpedida com a porta aberta")

	player.position = traversal_start
	_walk_steps(player, traversal_motion, 40)
	_check(_crossed_doorway(direction_name, player.position), "O corpo do jogador atravessa fisicamente a porta " + direction_name + " aberta")

	player.set("nearby_door", door)
	player.call("_interact")
	await physics_frame
	await physics_frame
	_check(not bool(door.get_meta("open", true)), "Uma segunda interação fecha a porta " + direction_name)
	_check(absf(wrapf(door.rotation.y - initial_yaw, -PI, PI)) < 0.1, "A porta " + direction_name + " regressa à rotação inicial")

	var closed_again_hit := _raycast(scene, player, ray_from, ray_to)
	_check(_is_door_hit(closed_again_hit), "A passagem " + direction_name + " volta a ficar bloqueada ao fechar")

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
		print("PASS | ", message)
	else:
		push_error("FAIL | " + message)
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("RESULTADO=PASS | Cena, portas/passagens, navegação/colisão, menu, transição para a expedição e ligação ENet local passaram.")
		quit(0)
	else:
		push_error("RESULTADO=FAIL | ", failures.size(), " teste(s) falharam.")
		quit(1)
