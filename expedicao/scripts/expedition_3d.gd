extends Node3D

const PLAYER_SCENE_SCRIPT := "res://scripts/expedition_player.gd"

const REMOTE_PLAYER_COLOR := Color("#e2a35c")
const PLAYER_SYNC_INTERVAL := 0.05

var _local_player: CharacterBody3D
var _remote_players: Dictionary = {}
var _remote_targets: Dictionary = {}
var _remote_skeletons: Dictionary = {}
var _remote_animation_players: Dictionary = {}
var _remote_animation_names: Dictionary = {}
var _remote_anim_time: Dictionary = {}
var _player_states: Dictionary = {}
var _sync_elapsed := 0.0

func _process(delta: float) -> void:
	var blend := 1.0 - exp(-12.0 * delta)
	for remote_id in _remote_targets.keys():
		var remote_avatar := _remote_players.get(remote_id) as Node3D
		if not is_instance_valid(remote_avatar):
			continue
		var target: Dictionary = _remote_targets[remote_id]
		var previous_position := remote_avatar.global_position
		remote_avatar.global_position = remote_avatar.global_position.lerp(target.position, blend)
		remote_avatar.rotation.y = lerp_angle(remote_avatar.rotation.y, float(target.yaw), blend)
		var moved_distance := previous_position.distance_to(remote_avatar.global_position)
		_animate_remote_avatar(int(remote_id), remote_avatar, delta, moved_distance / maxf(delta, 0.0001))
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
	# Usa o modelo com animações CC0 quando foi gerado no PRE-FLIGHT.
	# O modelo original continua disponível como fallback de importação.
	var model_scene := load("res://assets/character_animated.glb") as PackedScene
	if model_scene == null:
		model_scene = load("res://assets/character.glb") as PackedScene
	if model_scene != null:
		var character := model_scene.instantiate() as Node3D
		if character != null:
			character.name = "CharacterModel"
			character.scale = Vector3.ONE
			avatar.add_child(character)
			var skeleton := _find_skeleton(character)
			if skeleton != null:
				_remote_skeletons[avatar.get_instance_id()] = skeleton
			var animation_player := _find_animation_player(character)
			if animation_player != null:
				var walk_name := _find_animation_name(animation_player, "walk")
				var idle_name := _find_animation_name(animation_player, "idle")
				var run_name := _find_animation_name(animation_player, "run")
				if run_name.is_empty():
					run_name = _find_animation_name(animation_player, "jog")
				if run_name.is_empty():
					run_name = _find_animation_name(animation_player, "sprint")
				if run_name.is_empty():
					run_name = _find_animation_name(animation_player, "fast")
				# As animações de locomoção e repouso devem repetir continuamente.
				# Alguns clips importados podem vir sem loop configurado no recurso.
				for locomotion_name in [idle_name, walk_name, run_name]:
					if not locomotion_name.is_empty():
						var locomotion_animation := animation_player.get_animation(locomotion_name)
						if locomotion_animation != null:
							locomotion_animation.loop_mode = Animation.LOOP_LINEAR
				if not walk_name.is_empty() or not idle_name.is_empty() or not run_name.is_empty():
					_remote_animation_players[avatar.get_instance_id()] = animation_player
					_remote_animation_names[avatar.get_instance_id()] = {"walk": walk_name, "idle": idle_name, "run": run_name, "current": ""}
					if not idle_name.is_empty():
						animation_player.play(idle_name)
			return

	_build_remote_avatar_fallback(avatar)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_animation_name(animation_player: AnimationPlayer, keyword: String) -> String:
	for animation_name in animation_player.get_animation_list():
		if String(animation_name).to_lower().contains(keyword):
			return String(animation_name)
	return ""

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _animate_remote_avatar(remote_id: int, avatar: Node3D, delta: float, movement_speed: float) -> void:
	var avatar_key := avatar.get_instance_id()
	var is_moving := movement_speed > 0.04
	var animation_player := _remote_animation_players.get(avatar_key) as AnimationPlayer
	if is_instance_valid(animation_player):
		var names: Dictionary = _remote_animation_names.get(avatar_key, {})
		var desired := String(names.get("idle", ""))
		if is_moving:
			var run_name := String(names.get("run", ""))
			var walk_name := String(names.get("walk", ""))
			desired = run_name if movement_speed >= 3.5 and not run_name.is_empty() else walk_name
			if desired.is_empty():
				desired = run_name
		if desired.is_empty():
			desired = String(names.get("walk", "")) if not is_moving else String(names.get("idle", ""))
		if not desired.is_empty() and String(names.get("current", "")) != desired:
			# Crossfade curto para evitar cortes bruscos entre repouso e locomoção.
			animation_player.play(desired, 0.18)
			names["current"] = desired
			_remote_animation_names[avatar_key] = names
		return
	var skeleton := _remote_skeletons.get(avatar_key) as Skeleton3D
	if not is_instance_valid(skeleton):
		return
	var elapsed := float(_remote_anim_time.get(remote_id, 0.0)) + delta
	_remote_anim_time[remote_id] = elapsed
	var phase := elapsed * (10.0 if is_moving else 2.2)
	var swing := sin(phase) * (0.42 if is_moving else 0.025)
	var knee := maxf(0.0, sin(phase + 0.65)) * (0.5 if is_moving else 0.008)
	var arm_swing := -swing * 0.72
	_set_bone_rotation(skeleton, "thigh_l", swing)
	_set_bone_rotation(skeleton, "thigh_r", -swing)
	_set_bone_rotation(skeleton, "calf_l", knee)
	_set_bone_rotation(skeleton, "calf_r", maxf(0.0, sin(phase + PI + 0.65)) * (0.5 if is_moving else 0.008))
	_set_bone_rotation(skeleton, "upperarm_l", arm_swing)
	_set_bone_rotation(skeleton, "upperarm_r", -arm_swing)
	_set_bone_rotation(skeleton, "lowerarm_l", -0.12 if is_moving else 0.0)
	_set_bone_rotation(skeleton, "lowerarm_r", -0.12 if is_moving else 0.0)
	_set_bone_rotation(skeleton, "spine_01", sin(elapsed * 2.2) * 0.025)

func _set_bone_rotation(skeleton: Skeleton3D, bone_name: String, angle: float) -> void:
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index < 0:
		return
	skeleton.set_bone_pose_rotation(bone_index, Quaternion(Vector3.RIGHT, angle))

func _build_remote_avatar_fallback(avatar: Node3D) -> void:
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
	
	var neck := CylinderMesh.new()
	neck.top_radius = 0.105
	neck.bottom_radius = 0.12
	neck.height = 0.18
	_make_remote_avatar_part(avatar, "Neck", neck, Vector3(0, 1.55, 0), Color("#bd8966"))
	
	var hair := SphereMesh.new()
	hair.radius = 0.195
	hair.height = 0.16
	_make_remote_avatar_part(avatar, "Hair", hair, Vector3(0, 1.91, 0.015), Color("#30251f"))
	
	var left_eye := SphereMesh.new()
	left_eye.radius = 0.027
	left_eye.height = 0.04
	_make_remote_avatar_part(avatar, "EyeLeft", left_eye, Vector3(-0.065, 1.80, -0.165), Color("#f5f2e9"))
	var right_eye := SphereMesh.new()
	right_eye.radius = 0.027
	right_eye.height = 0.04
	_make_remote_avatar_part(avatar, "EyeRight", right_eye, Vector3(0.065, 1.80, -0.165), Color("#f5f2e9"))
	var nose := SphereMesh.new()
	nose.radius = 0.035
	nose.height = 0.065
	_make_remote_avatar_part(avatar, "Nose", nose, Vector3(0, 1.755, -0.185), Color("#c28d69"))
	
	var vest := BoxMesh.new()
	vest.size = Vector3(0.43, 0.48, 0.29)
	_make_remote_avatar_part(avatar, "UtilityVest", vest, Vector3(0, 1.22, -0.015), Color("#d18a3e"))
	var vest_panel := BoxMesh.new()
	vest_panel.size = Vector3(0.32, 0.07, 0.025)
	_make_remote_avatar_part(avatar, "VestReflectiveBand", vest_panel, Vector3(0, 1.17, -0.168), Color("#e8e5cc"))
	var belt := BoxMesh.new()
	belt.size = Vector3(0.43, 0.09, 0.27)
	_make_remote_avatar_part(avatar, "UtilityBelt", belt, Vector3(0, 0.91, 0), Color("#222b34"))
	
	var left_arm := CapsuleMesh.new()
	left_arm.radius = 0.095
	left_arm.height = 0.68
	_make_remote_avatar_part(avatar, "ArmLeft", left_arm, Vector3(-0.34, 1.16, 0), Color("#c7864d"), Vector3(0, 0, -0.12))
	
	var right_arm := CapsuleMesh.new()
	right_arm.radius = 0.095
	right_arm.height = 0.68
	_make_remote_avatar_part(avatar, "ArmRight", right_arm, Vector3(0.34, 1.16, 0), Color("#c7864d"), Vector3(0, 0, 0.12))
	
	var left_shoulder := SphereMesh.new()
	left_shoulder.radius = 0.13
	left_shoulder.height = 0.22
	_make_remote_avatar_part(avatar, "ShoulderLeft", left_shoulder, Vector3(-0.31, 1.39, 0), Color("#d18a3e"))
	var right_shoulder := SphereMesh.new()
	right_shoulder.radius = 0.13
	right_shoulder.height = 0.22
	_make_remote_avatar_part(avatar, "ShoulderRight", right_shoulder, Vector3(0.31, 1.39, 0), Color("#d18a3e"))
	
	var left_hand := SphereMesh.new()
	left_hand.radius = 0.085
	left_hand.height = 0.13
	_make_remote_avatar_part(avatar, "HandLeft", left_hand, Vector3(-0.37, 0.79, -0.01), Color("#c28d69"))
	var right_hand := SphereMesh.new()
	right_hand.radius = 0.085
	right_hand.height = 0.13
	_make_remote_avatar_part(avatar, "HandRight", right_hand, Vector3(0.37, 0.79, -0.01), Color("#c28d69"))
	
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

	# Molduras arquitetónicas visíveis em torno das três ligações.
	var frame_color := Color("#8da7b5")
	var frame_dark := Color("#263744")
	for z_pos in [-5.0, 5.0]:
		for x_pos in [-1.2, 1.2]:
			_add_box("DoorFramePost_%s_%s" % [str(z_pos), str(x_pos)], Vector3(x_pos, 1.35, z_pos), Vector3(0.16, 2.7, 0.24), frame_color)
		_add_box("DoorFrameHeader_%s" % str(z_pos), Vector3(0, 2.72, z_pos), Vector3(2.55, 0.16, 0.24), frame_color)
		_add_box("DoorFrameThreshold_%s" % str(z_pos), Vector3(0, 0.025, z_pos), Vector3(2.2, 0.05, 0.42), frame_dark)
	for z_pos in [-1.2, 1.2]:
		_add_box("DoorFramePostEast_%s" % str(z_pos), Vector3(5.0, 1.35, z_pos), Vector3(0.24, 2.7, 0.16), frame_color)
	_add_box("DoorFrameHeaderEast", Vector3(5.0, 2.72, 0), Vector3(0.24, 0.16, 2.55), frame_color)
	_add_box("DoorFrameThresholdEast", Vector3(5.0, 0.025, 0), Vector3(0.42, 0.05, 2.2), frame_dark)

	# Iluminação técnica e sinalética das zonas.
	_add_detail_box("CeilingLightCentral", Vector3(0, 2.86, 0), Vector3(2.4, 0.06, 0.28), Color("#d6efff"), 0.18)
	_add_detail_box("CeilingLightNorth", Vector3(0, 2.86, -12), Vector3(2.4, 0.06, 0.28), Color("#d6efff"), 0.18)
	_add_detail_box("CeilingLightEast", Vector3(12, 2.86, 0), Vector3(0.28, 0.06, 2.4), Color("#d6efff"), 0.18)
	_add_detail_box("CeilingLightSouth", Vector3(0, 2.86, 12), Vector3(2.4, 0.06, 0.28), Color("#d6efff"), 0.18)
	_add_detail_box("NorthZoneSign", Vector3(0, 2.45, -4.72), Vector3(1.25, 0.24, 0.06), Color("#214c63"), 0.35)
	_add_detail_box("EastZoneSign", Vector3(4.72, 2.45, 0), Vector3(0.06, 0.24, 1.25), Color("#214c63"), 0.35)
	_add_detail_box("SouthZoneSign", Vector3(0, 2.45, 4.72), Vector3(1.25, 0.24, 0.06), Color("#214c63"), 0.35)

func _add_detail_box(label: String, pos: Vector3, size: Vector3, color: Color, emission: float = 0.0) -> void:
	var detail := MeshInstance3D.new()
	detail.name = label
	detail.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	detail.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	detail.material_override = material
	add_child(detail)

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
