extends CharacterBody3D
## Criatura neutra em termos de lore: presença obrigatória e controlo exclusivo da IA.
## O comportamento inicial é de patrulha, deteção por proximidade e perseguição direta.
## Não revela qualquer informação narrativa sobre a criatura.

const WALK_SPEED := 1.65
const CHASE_SPEED := 3.1
const DETECTION_DISTANCE := 8.0
const ATTACK_DISTANCE := 1.35
const GRAVITY := 18.0
const WAYPOINTS: Array[Vector3] = [
	Vector3(-2.2, 0.1, -1.8),
	Vector3(2.0, 0.1, -1.7),
	Vector3(1.8, 0.1, 2.0),
	Vector3(-2.0, 0.1, 1.8)
]

var target: CharacterBody3D
var waypoint_index := 0
var state := "patrol"
var attack_cooldown := 0.0

func _ready() -> void:
	name = "CreatureAI"
	collision_layer = 0
	collision_mask = 1
	_build_placeholder_visual()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)
	position = Vector3(0.0, 0.1, -1.8)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		target = _find_target()
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var desired := Vector3.ZERO
	if is_instance_valid(target):
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() <= DETECTION_DISTANCE:
			state = "chase"
			if offset.length() > ATTACK_DISTANCE:
				desired = offset.normalized() * CHASE_SPEED
			else:
				state = "attack"
				attack_cooldown = maxf(attack_cooldown, 0.0)
		else:
			state = "patrol"
	else:
		state = "patrol"
	if state == "patrol":
		var waypoint := WAYPOINTS[waypoint_index]
		var to_waypoint := waypoint - global_position
		to_waypoint.y = 0.0
		if to_waypoint.length() < 0.55:
			waypoint_index = (waypoint_index + 1) % WAYPOINTS.size()
			waypoint = WAYPOINTS[waypoint_index]
			to_waypoint = waypoint - global_position
			to_waypoint.y = 0.0
		if to_waypoint.length() > 0.05:
			desired = to_waypoint.normalized() * WALK_SPEED
	velocity.x = desired.x
	velocity.z = desired.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if Vector2(velocity.x, velocity.z).length() > 0.08:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), minf(1.0, delta * 5.0))

func _find_target() -> CharacterBody3D:
	var player := get_parent().get_node_or_null("LocalPlayer") as CharacterBody3D
	if is_instance_valid(player):
		return player
	return null

func _build_placeholder_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#16191e")
	material.roughness = 0.92
	material.metallic = 0.05
	material.emission_enabled = true
	material.emission = Color("#350d16")
	material.emission_energy_multiplier = 0.18
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.34
	torso_mesh.height = 1.35
	var torso := MeshInstance3D.new()
	torso.name = "Silhouette"
	torso.mesh = torso_mesh
	torso.material_override = material
	torso.position.y = 1.05
	add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.42
	var head := MeshInstance3D.new()
	head.name = "HeadSilhouette"
	head.mesh = head_mesh
	head.material_override = material
	head.position = Vector3(0.0, 1.82, 0.0)
	add_child(head)
