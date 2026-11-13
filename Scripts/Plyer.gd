extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal died

@onready var animation_player: AnimationPlayer = $PlyerModle/player/AnimationPlayer
@onready var cam: Node3D = $PlyerModle/player/Armature/Skeleton3D/mixamorig_Head/Cam

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
const ANIM_IDLE := "idle"
const ANIM_IDLE_JUMP := "idle_jump"
const ANIM_WALK := "walking"
const ANIM_RUN := "runing"
const ANIM_RUN_JUMP := "runing_jump"
const ANIM_CROUCH_WALK := "crouch_walking"
const ANIM_KNOCK := "knock"

var jump_from_moving := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health = max_health
	health_changed.emit(health, max_health)


func _input(event: InputEvent) -> void:
	# ESC frees the mouse so you can leave the game window while testing
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if is_dead:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Left/right turns the whole body
		rotate_y(-event.relative.x * sens)
		# Up/down tilts only the camera
		pitch = clamp(pitch - event.relative.y * sens, deg_to_rad(-MAX_PITCH), deg_to_rad(MAX_PITCH))
		cam.rotation.x = pitch


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Dead: no control, just fall and slow down
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED * delta * 10.0)
		move_and_slide()
		return

	var input_dir := Input.get_vector("Left", "Right", "Forwerd", "Backwerd")
	var moving := input_dir.length() > 0.0
	var forward_pressed := input_dir.y < 0.0

	# Crouch (Z) wins over run. Run (Shift) only works while moving forward.
	var crouching := Input.is_action_pressed("Crouch")
	var running := Input.is_action_pressed("Run") and forward_pressed and not crouching

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif running:
		speed = RUN_SPEED

	# Remember if we were moving when we left the ground (decides which jump animation)
	if is_on_floor():
		jump_from_moving = Vector2(velocity.x, velocity.z).length() > 0.5

	# Jump (not while crouching)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not crouching:
		velocity.y = JUMP_VELOCITY
		jump_from_moving = moving

	# Horizontal movement
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	_update_animation(moving, running, crouching)


# Animation
func _update_animation(moving: bool, running: bool, crouching: bool) -> void:
	if not is_on_floor():
		_play(ANIM_RUN_JUMP if jump_from_moving else ANIM_IDLE_JUMP)
	elif moving and crouching:
		_play(ANIM_CROUCH_WALK)
	elif moving and running:
		_play(ANIM_RUN)
	elif moving:
		_play(ANIM_WALK)
	else:
		_play(ANIM_IDLE)


func _play(anim_name: String, blend: float = 0.2) -> void:
	if animation_player.current_animation == anim_name:
		return
	if not animation_player.has_animation(anim_name):
		push_warning("Animation not found: " + anim_name)
		return
	animation_player.play(anim_name, blend)


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
	_play(ANIM_KNOCK, 0.1)
	died.emit()
