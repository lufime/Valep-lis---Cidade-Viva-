extends SceneTree

const TEST_PORT: int = 24561
const EXPECTED_CLIENT_POSITION := Vector3(0.0, 0.1, -3.2)
const EXPECTED_HOST_POSITION := Vector3(1.5, 0.1, 0.75)
const EXPECTED_HOST_YAW := 0.65
const EXPECTED_HOST_PITCH := 0.22

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
		var host_player := expedition.get_node_or_null("LocalPlayer") as CharacterBody3D
		if host_player == null:
			_fail("O jogador local do anfitrião não foi criado.")
			return
		host_player.global_position = EXPECTED_HOST_POSITION
		host_player.rotation.y = EXPECTED_HOST_YAW
		host_player.set("pitch", EXPECTED_HOST_PITCH)
		host_player.camera.rotation.x = EXPECTED_HOST_PITCH
		var host_states: Dictionary = expedition.get("_player_states")
		host_states[api.get_unique_id()] = {"position": EXPECTED_HOST_POSITION, "yaw": EXPECTED_HOST_YAW, "pitch": EXPECTED_HOST_PITCH}
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
	var remote_host: Node3D
	for attempt in range(20):
		await create_timer(0.1).timeout
		remote_host = expedition.get_node_or_null("RemotePlayer_1") as Node3D
		var remote_targets: Dictionary = expedition.get("_remote_targets")
		if remote_host != null and remote_targets.has(1):
			break
	if remote_host == null:
		_fail("O cliente não criou o avatar remoto do anfitrião (RemotePlayer_1).")
		return
	var replicated_targets: Dictionary = expedition.get("_remote_targets")
	if not replicated_targets.has(1):
		_fail("O cliente não recebeu o estado de posição do anfitrião.")
		return
	var host_state: Dictionary = replicated_targets[1]
	var replicated_host_position: Vector3 = host_state.position
	if replicated_host_position.distance_to(EXPECTED_HOST_POSITION) > 0.75:
		_fail("A posição replicada do anfitrião não corresponde ao destino de teste: %s" % replicated_host_position)
		return
	if remote_host.global_position.distance_to(EXPECTED_HOST_POSITION) > 1.0:
		_fail("O avatar remoto do anfitrião não se aproximou da posição replicada.")
		return
	if absf(wrapf(float(host_state.yaw) - EXPECTED_HOST_YAW, -PI, PI)) > 0.1:
		_fail("A orientação horizontal do anfitrião não foi replicada: %s" % host_state.yaw)
		return
	if absf(float(host_state.pitch) - EXPECTED_HOST_PITCH) > 0.1:
		_fail("A inclinação da vista do anfitrião não foi replicada: %s" % host_state.pitch)
		return
	print("CLIENT_REMOTE_PLAYER_PASS | O cliente recebeu posição e avatar remoto do anfitrião")
	print("CLIENT_REMOTE_ORIENTATION_PASS | Yaw e pitch do anfitrião replicados")
	print("CLIENT_REPLICATION_PASS | Replicação anfitrião-cliente verificada no cliente")
	var test_door := expedition.get_node_or_null("DoorToNorth") as Node3D
	if test_door == null:
		_fail("A porta norte não existe no cliente.")
		return
	var local_player := expedition.get_node_or_null("LocalPlayer") as CharacterBody3D
	if local_player == null:
		_fail("O jogador local do cliente não existe para o teste de autorização da porta.")
		return
	local_player.global_position = Vector3(20.0, 0.1, 20.0)
	await create_timer(0.45).timeout
	expedition.call("_request_door_toggle", test_door)
	await create_timer(0.45).timeout
	if bool(test_door.get_meta("open", false)):
		_fail("O anfitrião aceitou indevidamente a abertura de porta pedida por um cliente distante.")
		return
	print("CLIENT_DOOR_DISTANCE_GUARD_PASS | Pedido de cliente distante rejeitado")
	local_player.global_position = EXPECTED_CLIENT_POSITION
	await create_timer(0.45).timeout
	expedition.call("_request_door_toggle", test_door)
	print("CLIENT_DOOR_REQUESTED | O cliente próximo pediu a abertura da porta norte")

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
