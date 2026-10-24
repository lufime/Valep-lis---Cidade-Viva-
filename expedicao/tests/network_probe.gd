extends SceneTree

const TEST_PORT: int = 24561
const EXPECTED_CLIENT_POSITION := Vector3(0.0, 0.1, -3.2)

var probe: Node
var api: MultiplayerAPI
var expedition: Node3D

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
		_create_expedition()
		print("SERVER_READY | À escuta na porta UDP %d" % TEST_PORT)
		_watch_server_replication()
		create_timer(10.0).timeout.connect(_on_timeout)
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
		create_timer(9.0).timeout.connect(_on_timeout)
	else:
		_fail("Modo desconhecido: %s" % mode)

func _create_expedition() -> void:
	var packed := load("res://scenes/expedition_3d.tscn") as PackedScene
	if packed == null:
		_fail("Não foi possível carregar a cena 3D.")
		return
	expedition = packed.instantiate() as Node3D
	root.add_child(expedition)

func _on_connected_to_server() -> void:
	print("CLIENT_CONNECTED | Ligação estabelecida; a enviar RPC PING")
	probe.rpc_id(1, "ping")
	_create_expedition()
	await create_timer(0.5).timeout
	var local_player := expedition.get_node_or_null("LocalPlayer") as CharacterBody3D
	if local_player == null:
		_fail("O jogador local não foi criado no cliente.")
		return
	local_player.global_position = EXPECTED_CLIENT_POSITION
	print("CLIENT_MOVED | Posição de teste enviada para replicação")
	await create_timer(0.5).timeout
	var test_door := expedition.get_node_or_null("DoorToNorth") as Node3D
	if test_door == null:
		_fail("A porta norte não existe no cliente.")
		return
	expedition.call("_request_door_toggle", test_door)
	print("CLIENT_DOOR_REQUESTED | O cliente pediu a abertura da porta norte")

func _watch_server_replication() -> void:
	for attempt in range(80):
		await create_timer(0.1).timeout
		if api.get_peers().is_empty() or not is_instance_valid(expedition):
			continue
		var states: Dictionary = expedition.get("_player_states")
		for peer_id in api.get_peers():
			if not states.has(peer_id):
				continue
			var state: Dictionary = states[peer_id]
			var position: Vector3 = state.position
			var avatar := expedition.get_node_or_null("RemotePlayer_%d" % int(peer_id))
			if position.distance_to(EXPECTED_CLIENT_POSITION) < 0.6 and avatar is Node3D:
				print("SERVER_REPLICATION_PASS | Posição do cliente recebida e avatar remoto criado")
				var test_door := expedition.get_node_or_null("DoorToNorth") as Node3D
				for door_attempt in range(40):
					await create_timer(0.1).timeout
					if is_instance_valid(test_door) and bool(test_door.get_meta("open", false)):
						print("SERVER_DOOR_REPLICATION_PASS | O anfitrião recebeu e aplicou a abertura pedida pelo cliente")
						probe.rpc_id(int(peer_id), "replication_ack")
						await create_timer(0.5).timeout
						quit(0)
						return
				_fail("O anfitrião não recebeu a abertura da porta pedida pelo cliente.")
				return
	_fail("O anfitrião não recebeu a posição de teste nem criou o avatar remoto.")

func _on_connection_failed() -> void:
	_fail("O cliente não conseguiu ligar-se ao servidor ENet.")

func _on_timeout() -> void:
	_fail("O teste ENet de replicação entre processos excedeu o tempo limite.")

func _fail(message: String) -> void:
	push_error("NETWORK_PROBE_FAIL | " + message)
	quit(1)
