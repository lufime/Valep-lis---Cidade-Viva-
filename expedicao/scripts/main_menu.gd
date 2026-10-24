extends Control

const DEFAULT_PORT: int = 24560
const MAX_PLAYERS: int = 8

var address_input: LineEdit
var status_label: Label
var players_label: Label
var host_button: Button
var join_button: Button
var disconnect_button: Button
var start_expedition_button: Button

func _ready() -> void:
	_build_interface()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_set_status("Pronto. Crie uma sala ou introduza o endereço do anfitrião.")

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#10151d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	layout.add_theme_constant_override("margin_left", 24)
	layout.add_theme_constant_override("margin_right", 24)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "A ÚLTIMA EXPEDIÇÃO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "NOVA BASE — MULTIJOGADOR"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)

	start_expedition_button = Button.new()
	start_expedition_button.text = "INICIAR EXPEDIÇÃO 3D (TESTE)"
	start_expedition_button.pressed.connect(_start_expedition)
	layout.add_child(start_expedition_button)

	address_input = LineEdit.new()
	address_input.placeholder_text = "Endereço IP do anfitrião"
	address_input.text = "127.0.0.1"
	address_input.clear_button_enabled = true
	layout.add_child(address_input)

	host_button = Button.new()
	host_button.text = "CRIAR SALA"
	host_button.pressed.connect(_host_game)
	layout.add_child(host_button)

	join_button = Button.new()
	join_button.text = "ENTRAR NA SALA"
	join_button.pressed.connect(_join_game)
	layout.add_child(join_button)

	disconnect_button = Button.new()
	disconnect_button.text = "DESLIGAR"
	disconnect_button.pressed.connect(_disconnect_game)
	disconnect_button.disabled = true
	layout.add_child(disconnect_button)

	status_label = Label.new()
	status_label.text = "Estado: a iniciar"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)

	players_label = Label.new()
	players_label.text = "Jogadores ligados: 0"
	layout.add_child(players_label)

	var note := Label.new()
	note.text = "A expedição 3D é um protótipo local. O multijogador ainda não sincroniza o cenário ou as ações de jogo. Para Internet é necessário anfitrião acessível e porta UDP configurada."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("#c1c8d2"))
	layout.add_child(note)

func _start_expedition() -> void:
	get_tree().change_scene_to_file("res://scenes/expedition_3d.tscn")

func _host_game() -> void:
	_disconnect_game()
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS - 1)
	if error != OK:
		_set_status("Não foi possível criar a sala. Código de erro: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	disconnect_button.disabled = false
	host_button.disabled = true
	join_button.disabled = true
	_update_players()
	_set_status("Sala criada nesta máquina na porta UDP %d. Para ligações externas, configure a rede/servidor." % DEFAULT_PORT)

func _join_game() -> void:
	_disconnect_game()
	var address := address_input.text.strip_edges()
	if address.is_empty():
		_set_status("Introduza o endereço IP do anfitrião.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, DEFAULT_PORT)
	if error != OK:
		_set_status("Não foi possível iniciar a ligação. Código de erro: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	disconnect_button.disabled = false
	host_button.disabled = true
	join_button.disabled = true
	_set_status("A tentar ligar a %s:%d…" % [address, DEFAULT_PORT])

func _disconnect_game() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	disconnect_button.disabled = true
	host_button.disabled = false
	join_button.disabled = false
	_update_players()

func _on_peer_connected(_peer_id: int) -> void:
	_update_players()
	_set_status("Um jogador entrou na sala.")

func _on_peer_disconnected(_peer_id: int) -> void:
	_update_players()
	_set_status("Um jogador saiu da sala.")

func _on_connected_to_server() -> void:
	_set_status("Ligação ao anfitrião estabelecida.")
	_update_players()

func _on_connection_failed() -> void:
	_disconnect_game()
	_set_status("A ligação falhou. Verifique o endereço, a porta UDP e se o anfitrião está ativo.")

func _on_server_disconnected() -> void:
	_disconnect_game()
	_set_status("A ligação ao anfitrião foi perdida.")

func _update_players() -> void:
	var count := 0
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		count = multiplayer.get_peers().size()
		if multiplayer.is_server():
			count += 1
	players_label.text = "Jogadores ligados: %d" % count

func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "Estado: " + message
