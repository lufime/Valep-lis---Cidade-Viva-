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
	var player_id := multiplayer.get_unique_id()
	scene.rpc_id(1, "_rpc_sync_player", player_id, Vector3(50.0, 0.1, 50.0), 0.0, 0.0)
	print("CLIENT_TELEPORT_ATTEMPT_SENT | O cliente enviou uma posição impossível para verificar a rejeição do anfitrião")
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0)
