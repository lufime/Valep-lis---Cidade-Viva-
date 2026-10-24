extends SceneTree

var passed_count: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := CharacterBody3D.new()
	player.name = "MouseCaptureTestPlayer"
	player.set_script(load("res://scripts/expedition_player.gd"))
	player.set_physics_process(false)
	root.add_child(player)
	await process_frame
	await process_frame

	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"GUI_MOUSE_CAPTURE_PASS | O arranque do jogador captura o rato")

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.physical_keycode = KEY_ESCAPE
	escape_event.pressed = true
	Input.parse_input_event(escape_event)
	await process_frame
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"GUI_MOUSE_ESCAPE_RELEASE_PASS | ESC liberta o rato")

	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	Input.parse_input_event(click_event)
	await process_frame
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"GUI_MOUSE_CLICK_CAPTURE_PASS | Clique esquerdo recaptura o rato")

	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("GUI_INPUT_PASS=%d GUI_INPUT_FAIL=0 RESULTADO=PASS" % passed_count)
		quit(0)
	else:
		push_error("GUI_INPUT_PASS=%d GUI_INPUT_FAIL=%d RESULTADO=FAIL" % [passed_count, failures.size()])
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print(message)
	else:
		failures.append(message)
		push_error("FAIL | " + message)
