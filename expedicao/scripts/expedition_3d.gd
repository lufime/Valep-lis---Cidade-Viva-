extends Node3D

const PLAYER_SCENE_SCRIPT := "res://scripts/expedition_player.gd"

const REMOTE_PLAYER_COLOR := Color("#e2a35c")
const PLAYER_SYNC_INTERVAL := 0.05
const MIN_CLIENT_SYNC_INTERVAL := 0.045
const CLIENT_MOVEMENT_SPEED := 4.2
const CLIENT_MOVEMENT_DISTANCE_TOLERANCE := 0.03

var _local_player: CharacterBody3D
var _remote_players: Dictionary = {}
var _remote_targets: Dictionary = {}
var _remote_skeletons: Dictionary = {}
var _remote_animation_players: Dictionary = {}
var _remote_animation_names: Dictionary = {}
var _remote_anim_time: Dictionary = {}
var _player_states: Dictionary = {}
var _last_server_sync_msec: Dictionary = {}
var _sync_elapsed := 0.0
var _local_peer_id := 1

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
	var active_peer := multiplayer.multiplayer_peer
	var connection_active := active_peer != null and active_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	# A ligação pode cair enquanto a cena continua a processar frames. Não consultar
	# get_unique_id() quando o peer ENet já não está ativo.
	var peer_id := 1
	if connection_active:
		peer_id = _local_peer_id
	var state := {"position": _local_player.global_position, "yaw": _local_player.rotation.y, "pitch": float(_local_player.get("pitch"))}
	_player_states[peer_id] = state
	if not connection_active:
		return
	if multiplayer.is_server():
		_broadcast_player_state(peer_id, state)
	else:
		_rpc_submit_player_state.rpc_id(1, peer_id, state.position, state.yaw, state.pitch)

func _register_with_host() -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var p := multiplayer.get_unique_id()
		_local_peer_id = p
		_rpc_register_player.rpc_id(1, p, _local_player.global_position, _local_player.rotation.y, float(_local_player.get("pitch")))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_player(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id or peer_id == 1:
		return
	var spawn_position := Vector3(0, 0.1, 0)
	var state := {"position": spawn_position, "yaw": 0.0, "pitch": 0.0}
	_player_states[peer_id] = state
	_last_server_sync_msec[peer_id] = Time.get_ticks_msec()
	for existing_id in _player_states.keys():
		var existing_state: Dictionary = _player_states[existing_id]
		if int(existing_id) != peer_id:
			_rpc_add_remote_player.rpc_id(peer_id, int(existing_id), existing_state.position, float(existing_state.yaw), float(existing_state.pitch))
	_add_remote_player(peer_id, spawn_position, 0.0, 0.0)
	_rpc_add_remote_player.rpc(peer_id, spawn_position, 0.0, 0.0)

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
	var fallback_name := ""
	for animation_name in animation_player.get_animation_list():
		var normalized_name := String(animation_name).to_lower()
		if normalized_name == keyword.to_lower():
			return String(animation_name)
		if fallback_name.is_empty() and normalized_name.contains(keyword.to_lower()):
			# Do not select crouched/sitting/swimming clips as the generic idle pose.
			if keyword.to_lower() != "idle" or (not normalized_name.contains("crouch") and not normalized_name.contains("sitting") and not normalized_name.contains("swim")):
				fallback_name = String(animation_name)
	return fallback_name

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
func _rpc_submit_player_state(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	# Clientes apenas submetem movimento ao anfitrião; nunca podem publicar diretamente
	# estados de outros jogadores para os restantes clientes.
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id or peer_id == 1:
		return
	if not _player_states.has(peer_id):
		return
	var previous_state: Dictionary = _player_states[peer_id]
	var now_msec := Time.get_ticks_msec()
	var last_msec := int(_last_server_sync_msec.get(peer_id, now_msec))
	var elapsed_seconds := float(now_msec - last_msec) / 1000.0
	if not _is_client_movement_valid(previous_state.position, position, elapsed_seconds):
		return
	if not _is_movement_path_clear(previous_state.position, position):
		return
	if not is_finite(yaw) or not is_finite(pitch) or absf(pitch) > 1.5:
		return
	_last_server_sync_msec[peer_id] = now_msec
	var state := {"position": position, "yaw": yaw, "pitch": pitch}
	_player_states[peer_id] = state
	_apply_remote_position(peer_id, position, yaw, pitch)
	_broadcast_player_state(peer_id, state)

@rpc("authority", "call_remote", "unreliable")
func _rpc_sync_player(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	# Apenas o anfitrião pode distribuir estados de movimento aos clientes.
	if multiplayer.is_server():
		return
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

func _build_creature() -> void:
	# A criatura é criada em todas as expedições e não é controlada por um jogador.
	var creature := CharacterBody3D.new()
	creature.set_script(load("res://scripts/creature_ai.gd"))
	creature.name = "CreatureAI"
	add_child(creature)

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_build_environment()
	_build_map()
	var player := CharacterBody3D.new()
	player.name = "LocalPlayer"
	player.set_script(load(PLAYER_SCENE_SCRIPT))
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	_local_player = player
	var initial_peer_id := 1
	var initial_peer := multiplayer.multiplayer_peer
	if initial_peer != null and initial_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		initial_peer_id = multiplayer.get_unique_id()
	_player_states[initial_peer_id] = {"position": player.position, "yaw": player.rotation.y, "pitch": 0.0}
	_build_hud()
	_build_creature()
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not multiplayer.is_server():
		call_deferred("_register_with_host")

func _on_peer_disconnected(peer_id: int) -> void:
	# Remove all transient state for a player who left; do not leave a ghost avatar.
	var avatar := _remote_players.get(peer_id) as Node3D
	if is_instance_valid(avatar):
		var avatar_key := avatar.get_instance_id()
		_remote_skeletons.erase(avatar_key)
		_remote_animation_players.erase(avatar_key)
		_remote_animation_names.erase(avatar_key)
		_remote_anim_time.erase(peer_id)
		avatar.queue_free()
	_remote_players.erase(peer_id)
	_remote_targets.erase(peer_id)
	_player_states.erase(peer_id)
	_last_server_sync_msec.erase(peer_id)

func _is_client_movement_valid(previous_position: Vector3, new_position: Vector3, elapsed_seconds: float) -> bool:
	if not is_finite(new_position.x) or not is_finite(new_position.y) or not is_finite(new_position.z):
		return false
	if not is_finite(elapsed_seconds) or elapsed_seconds < MIN_CLIENT_SYNC_INTERVAL:
		return false
	# A pausa não acumula deslocação disponível; um pacote isolado não pode aproveitar
	# vários segundos sem movimento para saltar uma grande distância.
	var bounded_elapsed := minf(elapsed_seconds, PLAYER_SYNC_INTERVAL)
	var maximum_distance := CLIENT_MOVEMENT_SPEED * bounded_elapsed + CLIENT_MOVEMENT_DISTANCE_TOLERANCE
	return previous_position.distance_to(new_position) <= maximum_distance

func _is_movement_path_clear(previous_position: Vector3, new_position: Vector3) -> bool:
	# Varre o volume da cápsula real do jogador no mundo físico do anfitrião.
	# Um raio central permitiria a um cliente atravessar cantos/arestas com passos pequenos.
	var displacement := new_position - previous_position
	if displacement.length_squared() <= 0.000001:
		return true
	var world := get_world_3d()
	if world == null:
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	# Mantém a cápsula 2 cm acima do chão: o root do jogador pode estar a y=0
	# depois da gravidade, e uma margem a tocar no chão bloquearia todo o movimento horizontal.
	query.transform = Transform3D(Basis.IDENTITY, previous_position + Vector3(0.0, 0.92, 0.0))
	query.motion = displacement