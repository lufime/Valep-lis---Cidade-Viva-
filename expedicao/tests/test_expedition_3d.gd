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

	_check(scene.get_node_or_null("LocalPlayer") != null, "A cena deve criar o jogador local")
	_check(scene.get_node_or_null("CentralFloor") != null, "A cena deve criar a sala central")
	_check(scene.get_node_or_null("NorthRoomFloor") != null, "A cena deve criar a zona norte")
	_check(scene.get_node_or_null("EastRoomFloor") != null, "A cena deve criar a zona este")
	_check(scene.get_node_or_null("SouthRoomFloor") != null, "A cena deve criar a zona sul")

	var player: Node = scene.get_node_or_null("LocalPlayer")
	var door_names := ["DoorToNorth", "DoorToEast", "DoorToSouth"]
	var target_floors := ["NorthRoomFloor", "EastRoomFloor", "SouthRoomFloor"]
	for i in range(door_names.size()):
		var door: Node3D = scene.get_node_or_null(door_names[i]) as Node3D
		_check(door != null, "A ligação " + door_names[i] + " deve ter porta")
		_check(scene.get_node_or_null(target_floors[i]) != null, "A ligação " + door_names[i] + " deve ter uma zona de destino")
		if door == null or player == null:
			continue

		_check(door.has_meta("is_door"), door_names[i] + " deve estar marcada como porta")
		_check(door.get_node_or_null("DoorCollider") != null, door_names[i] + " deve ter colisão física")
		var initial_yaw: float = door.rotation.y
		player.set("nearby_door", door)
		player.call("_interact")
		door.force_update_transform()
		_check(bool(door.get_meta("open", false)), door_names[i] + " deve abrir ao interagir")
		var opened_yaw: float = door.rotation.y
		_check(absf(wrapf(opened_yaw - initial_yaw, -PI, PI)) > 0.1, door_names[i] + " deve rodar ao abrir")
		var collider: Node3D = door.get_node_or_null("DoorCollider") as Node3D
		if collider != null:
			_check(collider.global_position.distance_to(door.global_position) < 0.1, door_names[i] + " deve mover a colisão com a porta")
		player.call("_interact")
		door.force_update_transform()
		_check(not bool(door.get_meta("open", true)), door_names[i] + " deve fechar na segunda interação")
		_check(absf(wrapf(door.rotation.y - initial_yaw, -PI, PI)) < 0.1, door_names[i] + " deve regressar à rotação inicial")

	if scene.has_node("LocalPlayer/PlayerCamera"):
		_check(true, "O jogador deve ter câmara em primeira pessoa")
	else:
		_check(false, "O jogador deve ter câmara em primeira pessoa")

	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS | ", message)
	else:
		push_error("FAIL | " + message)
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("RESULTADO=PASS | Todos os testes funcionais da cena 3D passaram.")
		quit(0)
	else:
		push_error("RESULTADO=FAIL | ", failures.size(), " teste(s) falharam.")
		quit(1)
