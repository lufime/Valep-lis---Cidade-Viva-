extends SceneTree

const TEST_PORT := 24561

var api: MultiplayerAPI
var expedition: Node3D

func _initialize() -> void:
	call_deferred("_start_observer")

func _start_observer() -> void:
	api = MultiplayerAPI.create_default_interface()
	set_multiplayer(api, root.get_path())
	api.connected_to_server.connect(_on_connected_to_server)
	api.connection_failed.connect(_on_connection_failed)
	var client_peer := ENetMultiplayerPeer.new()
	var error: Error = client_peer.create_client("127.0.0.1", TEST_PORT)
	if error != OK:
		_fail("O cliente observador não conseguiu iniciar ENet: %s" % error)
		return
	api.multiplayer_peer = client_peer
	create_timer(30.0).timeout.connect(_on_timeout)

func _on_connected_to_server() -> void:
	print("OBSERVER_CONNECTED | Segundo cliente ligado ao anfitrião")
	var packed := load("res://scenes/expedition_3d.tscn") as PackedScene
	if packed == null:
		_fail("Não foi possível carregar a cena 3D no cliente observador.")
		return
	expedition = packed.instantiate() as Node3D
	if expedition == null:
		_fail("A cena 3D não produziu um Node3D no cliente observador.")
		return
	root.add_child(expedition)
	_watch_for_second_client()

func _watch_for_second_client() -> void:
	var host_ready := false
	for attempt in range(100):
		await create_timer(0.1).timeout
		if is_instance_valid(expedition) and expedition.get_node_or_null("RemotePlayer_1") != null:
			host_ready = true
			break
	if not host_ready:
		_fail("O cliente observador não recebeu o avatar do anfitrião.")
		return
	print("OBSERVER_READY | Avatar do anfitrião recebido; à espera do outro cliente")

	for attempt in range(200):
		await create_timer(0.1).timeout
		if not is_instance_valid(expedition):
			_fail("A cena do cliente observador deixou de existir.")
			return
		var remote_players: Dictionary = expedition.get("_remote_players")
		var remote_targets: Dictionary = expedition.get("_remote_targets")
		var player_states: Dictionary = expedition.get("_player_states")
		for remote_id_variant in remote_players.keys():
			var remote_id := int(remote_id_variant)
			if remote_id == 1 or remote_id == api.get_unique_id():
				continue
			if not remote_targets.has(remote_id) or not player_states.has(remote_id):
				continue
			print("OBSERVER_MULTI_CLIENT_PASS | O segundo cliente recebeu o avatar e o estado do primeiro cliente ENet")
			# Mantém a sessão viva enquanto o cliente principal conclui os testes de portas e movimento.
			await create_timer(25.0).timeout
			quit(0)
			return
	_fail("O cliente observador não recebeu o avatar do outro cliente ligado em simultâneo.")

func _on_connection_failed() -> void:
	_fail("A ligação ENet do cliente observador falhou.")

func _on_timeout() -> void:
	_fail("O teste de visibilidade entre dois clientes excedeu o tempo limite.")

func _fail(message: String) -> void:
	push_error("NETWORK_OBSERVER_FAIL | " + message)
	quit(1)
