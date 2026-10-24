extends Node3D

const PLAYER_SCENE_SCRIPT := "res://scripts/expedition_player.gd"

func _ready() -> void:
	_build_environment()
	_build_map()
	var player := CharacterBody3D.new()
	player.name = "LocalPlayer"
	player.set_script(load(PLAYER_SCENE_SCRIPT))
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	_build_hud()

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#101a2a")
	sky_material.sky_horizon_color = Color("#35404a")
	sky_material.ground_bottom_color = Color("#080b10")
	sky_material.ground_horizon_color = Color("#20262d")
	env.sky.sky_material = sky_material
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8ba0b8")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -28, 0)
	light.light_energy = 0.35
	light.shadow_enabled = true
	add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.7, 0)
	fill.light_color = Color("#b9d9ff")
	fill.light_energy = 1.1
	fill.omni_range = 12.0
	add_child(fill)

func _build_map() -> void:
	# Central room, two side rooms and a rear corridor, connected by real door openings.
	_add_box("CentralFloor", Vector3(0, -0.2, 0), Vector3(10, 0.4, 10), Color("#303740"))
	_add_box("NorthRoomFloor", Vector3(0, -0.2, -12), Vector3(10, 0.4, 10), Color("#29343b"))
	_add_box("EastRoomFloor", Vector3(12, -0.2, 0), Vector3(10, 0.4, 10), Color("#34333a"))
	_add_box("SouthRoomFloor", Vector3(0, -0.2, 12), Vector3(10, 0.4, 10), Color("#2e353a"))

	# Fill the 2 m gaps between the central room and each outer zone so
	# players have continuous collision floor while crossing the doorways.
	_add_box("NorthConnectorFloor", Vector3(0, -0.2, -6), Vector3(4.4, 0.4, 2), Color("#29343b"))
	_add_box("EastConnectorFloor", Vector3(6, -0.2, 0), Vector3(2, 0.4, 4.4), Color("#34333a"))
	_add_box("SouthConnectorFloor", Vector3(0, -0.2, 6), Vector3(4.4, 0.4, 2), Color("#2e353a"))

	# Central room walls with openings at each connection.
	_add_box("CentralWestWall", Vector3(-5, 1.5, 0), Vector3(0.3, 3, 10), Color("#505760"))
	_add_box("CentralEastUpper", Vector3(5, 1.5, -3.6), Vector3(0.3, 3, 2.8), Color("#505760"))
	_add_box("CentralEastLower", Vector3(5, 1.5, 3.6), Vector3(0.3, 3, 2.8), Color("#505760"))
	_add_box("CentralNorthLeft", Vector3(-3.6, 1.5, -5), Vector3(2.8, 3, 0.3), Color("#505760"))
	_add_box("CentralNorthRight", Vector3(3.6, 1.5, -5), Vector3(2.8, 3, 0.3), Color("#505760"))
	_add_box("CentralSouthLeft", Vector3(-3.6, 1.5, 5), Vector3(2.8, 3, 0.3), Color("#505760"))
	_add_box("CentralSouthRight", Vector3(3.6, 1.5, 5), Vector3(2.8, 3, 0.3), Color("#505760"))

	# Outer walls for connected zones.
	_add_box("NorthWest", Vector3(-5, 1.5, -12), Vector3(0.3, 3, 10), Color("#46515b"))
	_add_box("NorthEast", Vector3(5, 1.5, -12), Vector3(0.3, 3, 10), Color("#46515b"))
	_add_box("NorthBack", Vector3(0, 1.5, -17), Vector3(10, 3, 0.3), Color("#46515b"))
	_add_box("EastTop", Vector3(12, 1.5, -5), Vector3(10, 3, 0.3), Color("#46515b"))
	_add_box("EastBottom", Vector3(12, 1.5, 5), Vector3(10, 3, 0.3), Color("#46515b"))
	_add_box("EastBack", Vector3(17, 1.5, 0), Vector3(0.3, 3, 10), Color("#46515b"))
	_add_box("SouthWest", Vector3(-5, 1.5, 12), Vector3(0.3, 3, 10), Color("#46515b"))
	_add_box("SouthEast", Vector3(5, 1.5, 12), Vector3(0.3, 3, 10), Color("#46515b"))
	_add_box("SouthBack", Vector3(0, 1.5, 17), Vector3(10, 3, 0.3), Color("#46515b"))

	_add_door("DoorToNorth", Vector3(0, 1.15, -5), 0.0)
	_add_door("DoorToEast", Vector3(5, 1.15, 0), PI / 2.0)
	_add_door("DoorToSouth", Vector3(0, 1.15, 5), 0.0)
	_add_box("NorthConsole", Vector3(-2.7, 0.65, -13.5), Vector3(1.1, 1.3, 0.7), Color("#657d88"))
	_add_box("EastCrate", Vector3(14.5, 0.55, 2.5), Vector3(1.2, 1.1, 1.2), Color("#75634d"))
	_add_box("SouthTable", Vector3(1.8, 0.8, 13.5), Vector3(2.2, 1.6, 1.0), Color("#4c555d"))

func _add_box(label: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_door(label: String, pos: Vector3, yaw: float) -> void:
	# Hinge the door at one edge so the opened panel swings out of the walking line.
	# The pivot is offset from the doorway centre; the child body is offset back
	# so the closed panel remains centred in the opening.
	var hinge_offset := Vector3(0.9, 0.0, 0.0).rotated(Vector3.UP, yaw)
	var door := Node3D.new()
	door.name = label
	door.position = pos + hinge_offset
	door.rotation.y = yaw
	door.set_meta("is_door", true)
	door.set_meta("open", false)
	door.set_meta("closed_yaw", yaw)
	door.set_meta("doorway_center", pos)

	var body := StaticBody3D.new()
	body.name = "DoorCollider"
	body.position = Vector3(-0.9, 0.0, 0.0)
	body.set_meta("is_door", true)
	body.set_meta("door_root", NodePath(".."))
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.8, 2.3, 0.16)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#6d8795")
	material.metallic = 0.45
	material.roughness = 0.38
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.3, 0.16)
	collision.shape = shape
	body.add_child(collision)
	door.add_child(body)
	add_child(door)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(360, 0)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var title := Label.new()
	title.text = "A ÚLTIMA EXPEDIÇÃO | PROTÓTIPO 3D"
	title.add_theme_font_size_override("font_size", 18)
	stack.add_child(title)
	var info := Label.new()
	info.text = "WASD: mover  |  rato: olhar  |  E: abrir/fechar porta  |  ESC: libertar rato"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(info)
	var note := Label.new()
	note.text = "Mapa de teste: sala central e 3 zonas ligadas. Multijogador e IA ainda não integrados neste cenário."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)
