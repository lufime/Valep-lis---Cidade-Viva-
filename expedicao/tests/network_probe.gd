extends SceneTree

const TEST_PORT: int = 24561
const MAX_ATTEMPTS: int = 500
const POLL_INTERVAL: float = 0.02

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("É necessário indicar o modo server ou client.")
		return

	var mode: String = args[0]
	var peer := ENetMultiplayerPeer.new()
	if mode == "server":
		var error: Error = peer.create_server(TEST_PORT, 4)
		if error != OK:
			_fail("O servidor ENet não arrancou: %s" % error)
			return
		print("SERVER_READY | À escuta na porta UDP %d" % TEST_PORT)
		await _run_server(peer)
	elif mode == "client":
		var error: Error = peer.create_client("127.0.0.1", TEST_PORT)
		if error != OK:
			_fail("O cliente ENet não arrancou: %s" % error)
			return
		print("CLIENT_STARTED | A ligar ao servidor local")
		await _run_client(peer)
	else:
		_fail("Modo desconhecido: %s" % mode)

func _run_server(peer: ENetMultiplayerPeer) -> void:
	for attempt in range(MAX_ATTEMPTS):
		peer.poll()
		if peer.get_available_packet_count() > 0:
			var packet: PackedByteArray = peer.get_packet()
			var message: String = packet.get_string_from_utf8()
			var sender_id: int = peer.get_packet_peer()
			if message == "PING":
				peer.set_target_peer(sender_id)
				var send_error: Error = peer.put_packet("PONG".to_utf8_buffer())
				if send_error != OK:
					_fail("O servidor não conseguiu enviar PONG: %s" % send_error)
					return
				print("SERVER_PASS | Recebeu PING e respondeu PONG ao peer %d" % sender_id)
				for flush_attempt in range(5):
					peer.poll()
					await create_timer(POLL_INTERVAL).timeout
				quit(0)
				return
		await create_timer(POLL_INTERVAL).timeout
	_fail("O servidor não recebeu PING dentro do limite.")

func _run_client(peer: ENetMultiplayerPeer) -> void:
	var ping_sent := false
	for attempt in range(MAX_ATTEMPTS):
		peer.poll()
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not ping_sent:
			peer.set_target_peer(1)
			var send_error: Error = peer.put_packet("PING".to_utf8_buffer())
			if send_error != OK:
				_fail("O cliente não conseguiu enviar PING: %s" % send_error)
				return
			ping_sent = true
			print("CLIENT_PING_SENT | PING enviado ao anfitrião")
		if peer.get_available_packet_count() > 0:
			var packet: PackedByteArray = peer.get_packet()
			var message: String = packet.get_string_from_utf8()
			if message == "PONG":
				print("CLIENT_PASS | Recebeu PONG do anfitrião")
				quit(0)
				return
		await create_timer(POLL_INTERVAL).timeout
	_fail("O cliente não recebeu PONG dentro do limite.")

func _fail(message: String) -> void:
	push_error("NETWORK_PROBE_FAIL | " + message)
	quit(1)
