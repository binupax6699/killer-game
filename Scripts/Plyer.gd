extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal died

@onready var anim_tree: AnimationTree = $PlyerModle/AnimationTree
@onready var cam: Node3D = $PlyerModle/Armature/Skeleton3D/mixamorig_Head/Cam

# Movement
const WALK_SPEED := 3.0
const RUN_SPEED := 5.5
const CROUCH_SPEED := 1.5
const JUMP_VELOCITY := 4.5

# Look
var sens := 0.002
const MAX_PITCH := 80.0
var pitch := 0.0

# Health
@export var max_health := 100
var health := max_health
var is_dead := false

# Animation
var jump_from_moving := false
var current_state := ""
var locomotion_blend := Vector2.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	anim_tree.active = true
	health = max_health
	health_changed.emit(health, max_health)


func _input(event: InputEvent) -> void:
	# ESC
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if is_dead:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sens)
		pitch = clamp(pitch - event.relative.y * sens, deg_to_rad(-MAX_PITCH), deg_to_rad(MAX_PITCH))
		cam.rotation.x = pitch


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Dead
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED * delta * 10.0)
		move_and_slide()
		return

	var input_dir := Input.get_vector("Left", "Right", "Forwerd", "Backwerd")
	var moving := input_dir.length() > 0.0
	var forward_pressed := input_dir.y < 0.0

	var crouching := Input.is_action_pressed("Crouch")
	var running := Input.is_action_pressed("Run") and forward_pressed and not crouching

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif running:
		speed = RUN_SPEED

	if is_on_floor():
		jump_from_moving = Vector2(velocity.x, velocity.z).length() > 0.5

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not crouching:
		velocity.y = JUMP_VELOCITY
		jump_from_moving = moving

	# Horizontal
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	_update_animation(input_dir, moving, running, crouching, delta)


# Animation (AnimationTree)
func _update_animation(input_dir: Vector2, moving: bool, running: bool, crouching: bool, delta: float) -> void:
	
	var target := Vector2(input_dir.x, -input_dir.y)
	locomotion_blend = locomotion_blend.lerp(target, 10.0 * delta)
	anim_tree["parameters/Locomotion/blend_position"] = locomotion_blend

	if not is_on_floor():
		_set_state("run_jump" if jump_from_moving else "idle_jump")
	elif moving and crouching:
		_set_state("crouch")
	elif moving and running:
		_set_state("run")
	else:
		_set_state("locomotion")


func _set_state(state_name: String) -> void:
	if current_state == state_name:
		return
	current_state = state_name
	anim_tree["parameters/state/transition_request"] = state_name


# Health
func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = clamp(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()


func heal(amount: int) -> void:
	if is_dead:
		return
	health = clamp(health + amount, 0, max_health)
	health_changed.emit(health, max_health)


func _die() -> void:
	is_dead = true
	_set_state("knock")
	died.emit()
