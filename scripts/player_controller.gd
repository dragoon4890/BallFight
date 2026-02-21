extends CharacterBody3D

# --- Stats Configuration ---
@export_group("Stats")
@export var speed_points: int = 5
@export var strength_points: int = 5
@export var flexibility_points: int = 5

# Base Stats
const BASE_SPEED = 5.0
const BASE_JUMP_VELOCITY = 4.5
const BASE_DAMAGE = 10.0
const BASE_DODGE_COOLDOWN = 2.0

# Calculated Stats
var move_speed: float
var damage: float
var dodge_cooldown_time: float
var knockback_resistance: float

# --- Components ---
@onready var camera_mount = $SpringArm3D
@onready var attack_area = $AttackArea # Area3D for melee

# --- State ---
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_sensitivity = 0.005
var is_dodging = false
var can_dodge = true

func _ready():
	# Calculate stats based on points
	calculate_stats()
	
	# Network setup: Only the local player controls this character
	if not is_multiplayer_authority():
		# Disable Camera for other players so we don't look through their eyes
		camera_mount.get_node("Camera3D").current = false
		return
	
	# Setup Camera for local player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_mount.get_node("Camera3D").current = true

func calculate_stats():
	move_speed = BASE_SPEED + (speed_points * 0.5)
	damage = BASE_DAMAGE + (strength_points * 1.0)
	# Strength reduces knockback
	knockback_resistance = float(strength_points) * 0.1 
	# Flexibility reduces dodge cooldown
	dodge_cooldown_time = max(0.5, BASE_DODGE_COOLDOWN - (flexibility_points * 0.2))

func _input(event):
	# Mouse Capture Toggle (Available to all, but only affects local window)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if not is_multiplayer_authority(): return

	# Camera Rotation (Only if captured)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_mount.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-60), deg_to_rad(60))

func _physics_process(delta):
	if not is_multiplayer_authority():
		# If not local player, just apply gravity and move_and_slide to smooth out network jitter
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = BASE_JUMP_VELOCITY

	# Handle Dodge (Flexibility)
	if Input.is_action_just_pressed("dodge") and can_dodge and not is_dodging:
		perform_dodge()

	# Handle Attack
	if Input.is_action_just_pressed("attack"): # Left Click
		perform_attack()

	# Get movement vector
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and not is_dodging:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	elif not is_dodging:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

func perform_dodge():
	is_dodging = true
	can_dodge = false
	
	# Dodge boost
	var dodge_vector = velocity.normalized() * (move_speed * 2.5) # 2.5x speed burst
	velocity = Vector3(dodge_vector.x, velocity.y, dodge_vector.z)
	
	# Visual/Logic delay
	await get_tree().create_timer(0.3).timeout
	is_dodging = false
	
	# Cooldown
	await get_tree().create_timer(dodge_cooldown_time).timeout
	can_dodge = true

func perform_attack():
	# Play animation (RPC to sync visuals)
	rpc("anim_attack")
	
	# Check for hits in AttackArea
	# This logic runs only on the authority (attacker), then tells the server/victim
	for body in attack_area.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			# Check if we hit their WeakPoint specifically
			# We do this by checking if the Area3D overlapping is their WeakPoint
			var hit_weak_point = false
			for area in attack_area.get_overlapping_areas():
				if area.name == "WeakPoint" and area.get_parent() == body:
					hit_weak_point = true
					break
			
			# Send damage RPC
			body.rpc("take_damage", damage, hit_weak_point, global_position)

@rpc("call_local")
func anim_attack():
	# if animation_player: animation_player.play("Attack")
	pass

@rpc("any_peer")
func take_damage(_amount: float, is_critical: bool, attacker_pos: Vector3):
	var knockback_force = 10.0
	
	if is_critical:
		print("CRITICAL HIT! RIGHT IN THE BALLS!")
		knockback_force *= 2.0 # Extra knockback
	
	# TODO: Implement health reduction using _amount
	
	# Apply Knockback
	var direction = (global_position - attacker_pos).normalized()
	direction.y = 0.5 # Lift them up a bit
	
	# Strength reduces knockback distance
	var final_knockback = max(0.0, knockback_force - knockback_resistance)
	velocity += direction * final_knockback
