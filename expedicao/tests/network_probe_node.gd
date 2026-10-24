extends Node

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
	get_tree().quit(0)
