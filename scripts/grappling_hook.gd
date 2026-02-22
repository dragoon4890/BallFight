extends Node

@export_group("Grapple Settings")
@export var max_range: float = 30.0
@export var spring_strength: float = 15.0
@export var damping: float = 1.0
@export var arrival_threshold: float = 2.0
@export var vertical_damping_near_anchor: float = 0.7
@export var vertical_threshold: float = 2.0

@export_group("Debug")
@export var show_debug_sphere: bool = true

var debug_sphere: MeshInstance3D

@onready var player: CharacterBody3D = owner
@onready var ray_cast: RayCast3D = player.get_node("SpringArm3D/Camera3D/RayCast3D")
@onready var camera_mount: Node3D = player.get_node("SpringArm3D")

var is_active: bool = false
var grapple_point: Vector3

func _ready():
	ray_cast.add_exception(player)
	ray_cast.add_exception(player.get_node("WeakPoint"))
	ray_cast.add_exception(player.get_node("AttackArea"))
	
	if show_debug_sphere:
		debug_sphere = MeshInstance3D.new()
		debug_sphere.mesh = SphereMesh.new()
		debug_sphere.mesh.radius = 0.3
		debug_sphere.mesh.height = 0.6
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.GREEN
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		debug_sphere.mesh.surface_set_material(0, material)
		add_child(debug_sphere)
		debug_sphere.visible = false

func _physics_process(_delta):
	if Input.is_action_pressed("grapple"):
		if not is_active:
			try_start_grapple()
	else:
		if is_active:
			release_grapple()
	
	if is_active:
		apply_spring_force()
		check_arrival()

func try_start_grapple():
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		grapple_point = ray_cast.get_collision_point()
		is_active = true
		if show_debug_sphere and debug_sphere:
			debug_sphere.global_position = grapple_point
			debug_sphere.visible = true

func release_grapple():
	is_active = false
	if show_debug_sphere and debug_sphere:
		debug_sphere.visible = false

func apply_spring_force():
	var to_anchor = grapple_point - player.global_position
	var distance = to_anchor.length()
	var direction = to_anchor.normalized()
	
	var force_magnitude = spring_strength * (distance / max_range)
	var velocity_along_rope = player.velocity.project(direction)
	var force = direction * force_magnitude - velocity_along_rope * damping * 0.1
	
	if player.global_position.y > grapple_point.y - vertical_threshold:
		force.y *= (1.0 - vertical_damping_near_anchor)
	
	player.velocity += force

func check_arrival():
	if player.global_position.distance_to(grapple_point) < arrival_threshold:
		release_grapple()
