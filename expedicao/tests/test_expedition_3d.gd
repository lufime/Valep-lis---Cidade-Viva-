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
	_check(scene.get_node_or_null("DoorToNorth") != null, "A ligação norte deve ter porta")
	_check(scene.get_node_or_null("DoorToEast") != null, "A ligação este deve ter porta")
	_check(scene.get_node_or_null("DoorToSouth") != null, "A ligação sul deve ter porta")

	var player := scene.get_node_or_null("LocalPlayer")
	var door := scene.get_node_or_null("DoorToNorth")
	if player != null and door != null:
		player.set("nearby_door", door)
		var initial_yaw: float = door.rotation.y
		player.call("_interact")
		_check(bool(door.get_meta("open", false)), "Interagir deve abrir a porta")
		_check(not is_equal_approx(door.rotation.y, initial_yaw), "Abrir deve alterar a rotação da porta")
		player.call("_interact")
		_check(not bool(door.get_meta("open", true)), "Uma segunda interação deve fechar a porta")
		_check(is_equal_approx(door.rotation.y, initial_yaw), "Fechar deve repor a rotação inicial")

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
