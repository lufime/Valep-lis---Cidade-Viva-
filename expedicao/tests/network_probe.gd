extends SceneTree

const TEST_PORT: int = 24561

var probe: Node
var api: MultiplayerAPI

func _initialize() -> void:
	call_deferred("_start_probe")

func _start_probe() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("É necessário indicar o modo server ou client.")
		return

	var mode: String = args[0]
	api = MultiplayerAPI.create_default_interface()
	set_multiplayer(api, root.get_path())
	probe = Node.new()
	probe.name = "Probe"
	probe.set_script(load("res://tests/network_probe_node.gd"))
	root.add_child(probe)

	if mode == "server":
		var server_peer := ENetMultiplayerPeer.new()
		var server_error: Error = server_peer.create_server(TEST_PORT, 4)
		if server_error != OK:
			_fail("O servidor ENet não arrancou: %s" % server_error)
			return
		api.multiplayer_peer = server_peer
		print("SERVER_READY | À escuta na porta UDP %d" % TEST_PORT)
		create_timer(12.0).timeout.connect(_on_timeout)
	elif mode == "client":
		api.connected_to_server.connect(_on_connected_to_server)
		api.connection_failed.connect(_on_connection_failed)
		var client_peer := ENetMultiplayerPeer.new()
		var client_error: Error = client_peer.create_client("127.0.0.1", TEST_PORT)
		if client_error != OK:
			_fail("O cliente ENet não arrancou: %s" % client_error)
			return
		api.multiplayer_peer = client_peer
		print("CLIENT_STARTED | A ligar ao servidor local")
		create_timer(10.0).timeout.connect(_on_timeout)
	else:
		_fail("Modo desconhecido: %s" % mode)

func _on_connected_to_server() -> void:
	print("CLIENT_CONNECTED | Ligação estabelecida; a enviar RPC PING")
	probe.rpc_id(1, "ping")

func _on_connection_failed() -> void:
	_fail("O cliente não conseguiu ligar-se ao servidor ENet.")

func _on_timeout() -> void:
	_fail("O teste ENet entre processos excedeu o tempo limite.")

func _fail(message: String) -> void:
	push_error("NETWORK_PROBE_FAIL | " + message)
	quit(1)
