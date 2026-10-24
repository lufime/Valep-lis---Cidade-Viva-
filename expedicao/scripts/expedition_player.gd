extends CharacterBody3D

const SPEED := 4.2
const MOUSE_SENSITIVITY := 0.0022
const INTERACTION_DISTANCE := 3.0
const GRAVITY := 18.0

var camera: Camera3D
var pitch := 0.0
var nearby_door: Node3D
var prompt: Label

func _ready() -> void:
	_build_player()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_player() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0, 1.58, 0)
	camera.current = true
	camera.fov = 78.0
	add_child(camera)

	var layer := CanvasLayer.new()
	add_child(layer)
	prompt = Label.new()
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-180, -90)
	prompt.size = Vector2(360, 40)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 20)
	layer.add_child(prompt)
	prompt.text = "Explora a instalação"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.35, 1.35)
		camera.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E:
			_interact()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0
	input_vector = input_vector.normalized()
	var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	if direction.length() > 0.0:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 5.0 * delta)
	move_and_slide()
	_update_door_prompt()

func _update_door_prompt() -> void:
	nearby_door = null
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * INTERACTION_DISTANCE)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node3D and collider.has_meta("is_door"):
			nearby_door = collider
			prompt.text = "[E] Abrir porta" if not bool(collider.get_meta("open")) else "[E] Fechar porta"
			return
	prompt.text = "Explora a instalação"

func _interact() -> void:
	if nearby_door == null or not is_instance_valid(nearby_door):
		return
	var is_open := bool(nearby_door.get_meta("open", false))
	var closed_yaw := float(nearby_door.get_meta("closed_yaw", nearby_door.rotation.y))
	if not nearby_door.has_meta("closed_yaw"):
		nearby_door.set_meta("closed_yaw", closed_yaw)
	var next_open := not is_open
	nearby_door.set_meta("open", next_open)
	# Aplicar a rotação a partir do ângulo fechado guardado, sem acumular erro.
	var target_rotation := nearby_door.rotation
	target_rotation.y = closed_yaw + (PI / 2.0 if next_open else 0.0)
	nearby_door.set_rotation(target_rotation)
	nearby_door.set_meta("current_yaw", target_rotation.y)
	prompt.text = "[E] Fechar porta" if next_open else "[E] Abrir porta"
