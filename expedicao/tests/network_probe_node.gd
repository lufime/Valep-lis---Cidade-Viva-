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
	print("CLIENT_REPLICATION_PASS | O cliente recebeu confirmação de posição remota")
	get_tree().quit(0)
