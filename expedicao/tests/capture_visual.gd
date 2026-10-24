extends SceneTree

func _initialize() -> void:
	call_deferred("_capture_scene")

func _capture_scene() -> void:
	var packed := load("res://scenes/expedition_3d.tscn") as PackedScene
	if packed == null:
		push_error("FAIL | Não foi possível carregar a cena 3D para captura")
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	if scene == null:
		push_error("FAIL | A cena 3D não é Node3D")
		quit(1)
		return
	root.add_child(scene)
	await process_frame
	await process_frame
	var camera := scene.get_node_or_null("LocalPlayer/PlayerCamera") as Camera3D
	if camera == null:
		push_error("FAIL | Câmara do jogador não encontrada para captura")
		quit(1)
		return
	camera.current = true

	# Mostrar também o avatar humanoide na captura de validação.
	var player_model := load("res://assets/character_animated.glb") as PackedScene
	if player_model == null:
		player_model = load("res://assets/character.glb") as PackedScene
	if player_model != null:
		var showcase_character := player_model.instantiate() as Node3D
		if showcase_character != null:
			showcase_character.name = "ShowcaseCharacter"
			showcase_character.position = Vector3(0.0, 0.0, -2.0)
			showcase_character.rotation.y = PI
			scene.add_child(showcase_character)

	# A captura de validação mostra as três ligações abertas para que os vãos
	# não sejam confundidos com portas bloqueadas na imagem estática.
	for door_name in ["DoorToNorth", "DoorToEast", "DoorToSouth"]:
		scene.call("_apply_door_state", door_name, true)
	for frame in range(30):
		await process_frame
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty() or image.get_width() < 640 or image.get_height() < 360:
		push_error("FAIL | A captura gráfica não tem dimensões válidas")
		quit(1)
		return
	var save_error := image.save_png("/tmp/expedition-showcase.png")
	if save_error != OK:
		push_error("FAIL | Não foi possível guardar a captura PNG: %s" % error_string(save_error))
		quit(1)
		return
	print("GRAPHICAL_CAPTURE_PASS | %dx%d | /tmp/expedition-showcase.png" % [image.get_width(), image.get_height()])
	quit(0)
