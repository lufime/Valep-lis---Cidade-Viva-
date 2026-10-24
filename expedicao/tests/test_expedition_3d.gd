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

	await _test_main_menu()
	_finish()

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
		print("RESULTADO=PASS | Cena, deteção, abertura/fecho e passagem física pelas três portas passaram.")
		quit(0)
	else:
		push_error("RESULTADO=FAIL | ", failures.size(), " teste(s) falharam.")
		quit(1)
