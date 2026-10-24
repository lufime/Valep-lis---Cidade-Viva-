extends Node3D

const PLAYER_SCENE_SCRIPT := "res://scripts/expedition_player.gd"

const REMOTE_PLAYER_COLOR := Color("#e2a35c")
const PLAYER_SYNC_INTERVAL := 0.05

var _local_player: CharacterBody3D
var _remote_players: Dictionary = {}
var _remote_targets: Dictionary = {}
var _player_states: Dictionary = {}
var _sync_elapsed := 0.0

func _process(delta: float) -> void:
	var blend := 1.0 - exp(-12.0 * delta)
	for remote_id in _remote_targets.keys():
		var remote_avatar := _remote_players.get(remote_id) as Node3D
		if not is_instance_valid(remote_avatar):
			continue
		var target: Dictionary = _remote_targets[remote_id]
		remote_avatar.global_position = remote_avatar.global_position.lerp(target.position, blend)
		remote_avatar.rotation.y = lerp_angle(remote_avatar.rotation.y, float(target.yaw), blend)
	if not is_instance_valid(_local_player):
		return
	_sync_elapsed += delta
	if _sync_elapsed < PLAYER_SYNC_INTERVAL:
		return
	_sync_elapsed = 0.0
	var peer_id := multiplayer.get_unique_id()
	var state := {"position": _local_player.global_position, "yaw": _local_player.rotation.y, "pitch": float(_local_player.get("pitch"))}
	_player_states[peer_id] = state
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if multiplayer.is_server():
		_broadcast_player_state(peer_id, state)
	else:
		_rpc_sync_player.rpc_id(1, peer_id, state.position, state.yaw, state.pitch)

func _register_with_host() -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var p := multiplayer.get_unique_id()
		_rpc_register_player.rpc_id(1, p, _local_player.global_position, _local_player.rotation.y, float(_local_player.get("pitch")))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_player(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id or peer_id == 1:
		return
	var state := {"position": position, "yaw": yaw, "pitch": pitch}
	_player_states[peer_id] = state
	for existing_id in _player_states.keys():
		var existing_state: Dictionary = _player_states[existing_id]
		if int(existing_id) != peer_id:
			_rpc_add_remote_player.rpc_id(peer_id, int(existing_id), existing_state.position, float(existing_state.yaw), float(existing_state.pitch))
	_add_remote_player(peer_id, position, yaw, pitch)
	_rpc_add_remote_player.rpc(peer_id, position, yaw, pitch)

@rpc("authority", "call_remote", "reliable")
func _rpc_add_remote_player(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	_add_remote_player(peer_id, position, yaw, pitch)

func _add_remote_player(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var state := {"position": position, "yaw": yaw, "pitch": pitch}
	_player_states[peer_id] = state
	var avatar := _remote_players.get(peer_id) as Node3D
	if not is_instance_valid(avatar):
		avatar = Node3D.new()
		avatar.name = "RemotePlayer_%d" % peer_id
		_build_remote_avatar(avatar)
		add_child(avatar)
		_remote_players[peer_id] = avatar
	avatar.global_position = position
	avatar.rotation.y = yaw
	_remote_targets[peer_id] = state

func _build_remote_avatar(avatar: Node3D) -> void:
	# Modelo humanoide procedural de protótipo: cabeça, tronco, braços, pernas e botas.
	# Mantém o avatar leve e sem dependências de assets externos.
	var torso := CapsuleMesh.new()
	torso.radius = 0.25
	torso.height = 0.82
	_make_remote_avatar_part(avatar, "Torso", torso, Vector3(0, 1.15, 0), REMOTE_PLAYER_COLOR)

	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	_make_remote_avatar_part(avatar, "Head", head, Vector3(0, 1.78, 0), Color("#d6a078"))

	var left_arm := CapsuleMesh.new()
	left_arm.radius = 0.095
	left_arm.height = 0.68
	_make_remote_avatar_part(avatar, "ArmLeft", left_arm, Vector3(-0.34, 1.16, 0), Color("#c7864d"), Vector3(0, 0, -0.12))

	var right_arm := CapsuleMesh.new()
	right_arm.radius = 0.095
	right_arm.height = 0.68
	_make_remote_avatar_part(avatar, "ArmRight", right_arm, Vector3(0.34, 1.16, 0), Color("#c7864d"), Vector3(0, 0, 0.12))

	var left_leg := CapsuleMesh.new()
	left_leg.radius = 0.13
	left_leg.height = 0.78
	_make_remote_avatar_part(avatar, "LegLeft", left_leg, Vector3(-0.15, 0.48, 0), Color("#303d50"))

	var right_leg := CapsuleMesh.new()
	right_leg.radius = 0.13
	right_leg.height = 0.78
	_make_remote_avatar_part(avatar, "LegRight", right_leg, Vector3(0.15, 0.48, 0), Color("#303d50"))

	var boot := BoxMesh.new()
	boot.size = Vector3(0.23, 0.13, 0.34)
	_make_remote_avatar_part(avatar, "BootLeft", boot, Vector3(-0.15, 0.09, -0.055), Color("#171c22"))
	_make_remote_avatar_part(avatar, "BootRight", boot, Vector3(0.15, 0.09, -0.055), Color("#171c22"))

func _make_remote_avatar_part(
	avatar: Node3D,
	part_name: String,
	mesh: Mesh,
	part_position: Vector3,
	color: Color,
	part_rotation: Vector3 = Vector3.ZERO
) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = part_position
	part.rotation = part_rotation
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	part.material_override = material
	avatar.add_child(part)

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_sync_player(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	if multiplayer.is_server():
		if multiplayer.get_remote_sender_id() != peer_id or peer_id == 1:
			return
		var state := {"position": position, "yaw": yaw, "pitch": pitch}
		_player_states[peer_id] = state
		_apply_remote_position(peer_id, position, yaw, pitch)
		_broadcast_player_state(peer_id, state)
	else:
		_apply_remote_position(peer_id, position, yaw, pitch)

func _broadcast_player_state(peer_id: int, state: Dictionary) -> void:
	_apply_remote_position(peer_id, state.position, float(state.yaw), float(state.pitch))
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_rpc_sync_player.rpc(peer_id, state.position, float(state.yaw), float(state.pitch))

func _apply_remote_position(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	var state := {"position": position, "yaw": yaw, "pitch": pitch}
	var had_target: bool = _remote_targets.has(peer_id)
	_player_states[peer_id] = state
	_remote_targets[peer_id] = state
	var avatar := _remote_players.get(peer_id) as Node3D
	if is_instance_valid(avatar) and not had_target:
		avatar.global_position = position
		avatar.rotation.y = yaw

func _request_door_toggle(door: Node3D) -> void:
	if not is_instance_valid(door):
		return
	var next_open := not bool(door.get_meta("open", false))
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if multiplayer.is_server():
			_toggle_door_authoritatively(door.name)
		else:
			_rpc_request_door_toggle.rpc_id(1, door.name, next_open)
	else:
		_toggle_door_authoritatively(door.name)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_door_toggle(door_name: String, _requested_open: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or not _player_states.has(sender):
		return
	var door := get_node_or_null(door_name) as Node3D
	if door == null or not door.has_meta("is_door"):
		return
	var player_position: Vector3 = _player_states[sender].position
	var doorway_center: Vector3 = door.get_meta("doorway_center", door.global_position)
	if player_position.distance_to(doorway_center) > 4.0:
		return
	_toggle_door_authoritatively(door_name)

func _toggle_door_authoritatively(door_name: String) -> void:
	var door := get_node_or_null(door_name) as Node3D
	if door == null or not door.has_meta("is_door"):
		return
	var authoritative_open := not bool(door.get_meta("open", false))
	_apply_door_state(door_name, authoritative_open)
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server():
		_rpc_set_door_state.rpc(door_name, authoritative_open)

@rpc("authority", "call_remote", "reliable")
func _rpc_set_door_state(door_name: String, is_open: bool) -> void:
	_apply_door_state(door_name, is_open)

func _apply_door_state(door_name: String, is_open: bool) -> void:
	var door := get_node_or_null(door_name) as Node3D
	if door == null or not door.has_meta("is_door"):
		return
	var closed_yaw := float(door.get_meta("closed_yaw", door.rotation.y))
	var target_rotation := door.rotation
	target_rotation.y = closed_yaw + (PI / 2.0 if is_open else 0.0)
	door.rotation = target_rotation
	door.set_meta("open", is_open)
	door.set_meta("current_yaw", target_rotation.y)
	if is_instance_valid(_local_player):
		var player_prompt := _local_player.get("prompt") as Label
		if _local_player.get("nearby_door") == door and is_instance_valid(player_prompt):
			player_prompt.text = "[E] Fechar porta" if is_open else "[E] Abrir porta"
		else:
			_local_player.call("_update_door_prompt")

func _ready() -> void:
	_build_environment()
	_build_map()
	var player := CharacterBody3D.new()
	player.name = "LocalPlayer"
	player.set_script(load(PLAYER_SCENE_SCRIPT))
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	_local_player = player
	_player_states[multiplayer.get_unique_id()] = {"position": player.position, "yaw": player.rotation.y, "pitch": 0.0}
	_build_hud()
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not multiplayer.is_server():
		call_deferred("_register_with_host")

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
