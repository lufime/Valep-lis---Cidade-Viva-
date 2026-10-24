extends Node

var wall_probe_start_acknowledged := false
var wall_probe_completed := false

@rpc("any_peer", "call_remote", "reliable")
func ping() -> void:
	if not multiplayer.is_server():
		push_error("NETWORK_PROBE_FAIL | PING recebido fora do servidor.")
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	print("SERVER_PASS | PING recebido do cliente %d" % sender_id)
	rpc_id(sender_id, "pong")

@rpc("authority", "call_remote", "reliable")
func pong() -> void:
	print("CLIENT_PASS | PONG recebido do servidor")

@rpc("any_peer", "call_remote", "reliable")
func door_spoof_attempted() -> void:
	if not multiplayer.is_server():
		push_error("SERVER_DOOR_SPOOF_REJECT_FAIL | O aviso chegou a um processo que não é anfitrião.")
		get_tree().quit(1)
		return
	var sender_id := multiplayer.get_remote_sender_id()
	await get_tree().create_timer(0.3).timeout
	var scene := get_tree().root.get_node_or_null("Expedition3D") as Node3D
	var door := scene.get_node_or_null("DoorToNorth") as Node3D if scene != null else null
	var states: Dictionary = scene.get("_player_states") if scene != null else {}
	if door == null or not states.has(sender_id):
		push_error("SERVER_DOOR_SPOOF_REJECT_FAIL | Faltam porta ou estado do cliente após a tentativa.")
		get_tree().quit(1)
		return
	var state: Dictionary = states[sender_id]
	var authoritative_position: Vector3 = state.position
	# O jogador pode assentar de y=0.1 para y=0.0 por gravidade; a tentativa
	# de falsificação só deve falhar se o cliente conseguir deslocar-se horizontalmente.
	if Vector2(authoritative_position.x, authoritative_position.z).length() > 0.1 or authoritative_position.y < -0.1 or authoritative_position.y > 0.2:
		push_error("SERVER_DOOR_SPOOF_REJECT_FAIL | O servidor aceitou posição falsificada: %s" % authoritative_position)
		get_tree().quit(1)
		return
	if bool(door.get_meta("open", false)):
		push_error("SERVER_DOOR_SPOOF_REJECT_FAIL | A porta abriu após a tentativa de falsificação.")
		get_tree().quit(1)
		return
	print("SERVER_DOOR_SPOOF_REJECT_PASS | O anfitrião manteve o estado no spawn e rejeitou a abertura falsificada")

@rpc("authority", "call_remote", "reliable")
func replication_ack() -> void:
	print("CLIENT_ACK_PASS | O cliente recebeu confirmação do anfitrião")
	var scene := get_tree().root.get_node_or_null("Expedition3D") as Node3D
	var door := scene.get_node_or_null("DoorToNorth") as Node3D if scene != null else null
	if door == null or not bool(door.get_meta("open", false)):
		push_error("CLIENT_DOOR_REPLICATION_FAIL | O cliente não recebeu o estado aberto da porta.")
		get_tree().quit(1)
		return
	print("CLIENT_DOOR_REPLICATION_PASS | O cliente recebeu o estado aberto da porta")
	scene.call("_request_door_toggle", door)
	print("CLIENT_DOOR_CLOSE_REQUESTED | O cliente pediu o fecho da porta norte")

@rpc("authority", "call_remote", "reliable")
func close_replication_ack() -> void:
	var scene := get_tree().root.get_node_or_null("Expedition3D") as Node3D
	var door := scene.get_node_or_null("DoorToNorth") as Node3D if scene != null else null
	if door == null or bool(door.get_meta("open", true)):
		push_error("CLIENT_DOOR_CLOSE_REPLICATION_FAIL | O cliente não recebeu o estado fechado da porta.")
		get_tree().quit(1)
		return
	print("CLIENT_DOOR_CLOSE_REPLICATION_PASS | O cliente recebeu o estado fechado da porta")
	var local_player := scene.get_node_or_null("LocalPlayer") as CharacterBody3D
	if local_player == null:
		push_error("CLIENT_MOVEMENT_BURST_FAIL | O jogador local não existe para o teste de cadência.")
		get_tree().quit(1)
		return
	var player_id := multiplayer.get_unique_id()
	var valid_burst_position := local_player.global_position + Vector3(0.18, 0.0, 0.0)
	var too_fast_position := valid_burst_position + Vector3(0.18, 0.0, 0.0)
	local_player.global_position = valid_burst_position
	scene.rpc_id(1, "_rpc_submit_player_state", player_id, valid_burst_position, local_player.rotation.y, float(local_player.get("pitch")))
	scene.rpc_id(1, "_rpc_submit_player_state", player_id, too_fast_position, local_player.rotation.y, float(local_player.get("pitch")))
	print("CLIENT_MOVEMENT_BURST_SENT | O cliente enviou dois estados consecutivos sem intervalo suficiente")
	scene.rpc_id(1, "_rpc_submit_player_state", player_id, Vector3(50.0, 0.1, 50.0), 0.0, 0.0)
	print("CLIENT_TELEPORT_ATTEMPT_SENT | O cliente enviou uma posição impossível para verificar a rejeição do anfitrião")

@rpc("authority", "call_remote", "reliable")
func teleport_reject_ack() -> void:
	print("CLIENT_TELEPORT_REJECT_ACK_PASS | O cliente recebeu confirmação da rejeição do anfitrião")
	var scene := get_tree().root.get_node_or_null("Expedition3D") as Node3D
	var player := scene.get_node_or_null("LocalPlayer") as CharacterBody3D if scene != null else null
	if player == null or scene == null:
		push_error("CLIENT_WALL_MOVEMENT_REJECT_FAIL | Falta a cena ou o jogador para o teste de parede.")
		get_tree().quit(1)
		return
	await _move_local_player_gradually(player, Vector3(4.45, player.global_position.y, 0.0))
	rpc_id(1, "wall_probe_start")
	for attempt in range(30):
		if wall_probe_start_acknowledged:
			break
		await get_tree().create_timer(0.05).timeout
	if not wall_probe_start_acknowledged:
		push_error("CLIENT_WALL_MOVEMENT_REJECT_FAIL | O anfitrião não confirmou a posição segura junto à porta.")
		get_tree().quit(1)
		return
	# Cliente adulterado tenta avançar em passos curtos através da porta este fechada.
	# O primeiro passo respeita o limite de velocidade, mas a cápsula deve colidir com a porta.
	for x_position in [4.60, 4.75, 4.90]:
		var candidate := Vector3(float(x_position), player.global_position.y, 0.0)
		player.global_position = candidate
		scene.rpc_id(1, "_rpc_submit_player_state", multiplayer.get_unique_id(), candidate, player.rotation.y, float(player.get("pitch")))
		await get_tree().create_timer(0.12).timeout
	print("CLIENT_WALL_MOVEMENT_SPOOF_SENT | O cliente tentou atravessar a porta fechada em passos curtos")
	rpc_id(1, "wall_probe_done")

func _move_local_player_gradually(player: CharacterBody3D, target: Vector3) -> void:
	var horizontal_delta := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
	while horizontal_delta.length() > 0.02:
		var step_distance := minf(0.15, horizontal_delta.length())
		var horizontal_step := Vector3(horizontal_delta.x, 0.0, horizontal_delta.y).normalized() * step_distance
		player.global_position += horizontal_step
		await get_tree().create_timer(0.05).timeout
		horizontal_delta = Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
	await get_tree().create_timer(0.1).timeout

@rpc("any_peer", "call_remote", "reliable")
func wall_probe_start() -> void:
	if not multiplayer.is_server():
		push_error("SERVER_WALL_MOVEMENT_REJECT_FAIL | O pedido de preparação não chegou ao anfitrião.")
		get_tree().quit(1)
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var scene := get_tree().root.get_node_or_null("Expedition3D") as Node3D
	if scene == null:
		push_error("SERVER_WALL_MOVEMENT_REJECT_FAIL | A cena 3D não existe.")
		get_tree().quit(1)
		return
	var at_safe_position := false
	for attempt in range(30):
		var states: Dictionary = scene.get("_player_states")
		if states.has(sender_id):
			var state: Dictionary = states[sender_id]
			var position: Vector3 = state.position
			if absf(position.x - 4.45) <= 0.18 and absf(position.z) <= 0.18 and position.y >= -0.1 and position.y <= 0.2:
				at_safe_position = true
				break
		await get_tree().create_timer(0.05).timeout
	if not at_safe_position:
		push_error("SERVER_WALL_MOVEMENT_REJECT_FAIL | O jogador não chegou à posição segura antes do teste.")
		get_tree().quit(1)
		return
	print("SERVER_WALL_PROBE_START_PASS | O cliente chegou à posição segura antes da porta fechada")
	rpc_id(sender_id, "wall_probe_start_ack")

@rpc("authority", "call_remote", "reliable")
func wall_probe_start_ack() -> void:
	wall_probe_start_acknowledged = true

@rpc("any_peer", "call_remote", "reliable")
func wall_probe_done() -> void:
	if not multiplayer.is_server():
		push_error("SERVER_WALL_MOVEMENT_REJECT_FAIL | A conclusão chegou fora do anfitrião.")
		get_tree().quit(1)
		return
	var sender_id := multiplayer.get_remote_sender_id()
	await get_tree().create_timer(0.2).timeout
	var scene := get_tree().root.get_node_or_null("Expedition3D") as Node3D
	var states: Dictionary = scene.get("_player_states") if scene != null else {}
	var door := scene.get_node_or_null("DoorToEast") as Node3D if scene != null else null
	if not states.has(sender_id) or door == null:
		push_error("SERVER_WALL_MOVEMENT_REJECT_FAIL | Falta o estado do jogador ou a porta este.")
		get_tree().quit(1)
		return
	var state: Dictionary = states[sender_id]
	var position: Vector3 = state.position
	if position.x > 4.55 or position.x < 4.30 or absf(position.z) > 0.2 or position.y < -0.1 or position.y > 0.2:
		push_error("SERVER_WALL_MOVEMENT_REJECT_FAIL | A posição autoritativa ultrapassou a zona segura: %s" % position)
		get_tree().quit(1)
		return
	if bool(door.get_meta("open", false)):
		push_error("SERVER_WALL_MOVEMENT_REJECT_FAIL | A porta este estava aberta durante a tentativa.")
		get_tree().quit(1)
		return
	print("SERVER_WALL_MOVEMENT_REJECT_PASS | O anfitrião rejeitou passos falsificados através da porta este fechada")
	wall_probe_completed = true
	rpc_id(sender_id, "wall_probe_result_ack")

@rpc("authority", "call_remote", "reliable")
func wall_probe_result_ack() -> void:
	print("CLIENT_WALL_MOVEMENT_REJECT_ACK_PASS | O cliente recebeu confirmação da rejeição dos passos falsificados")
	get_tree().quit(0)
