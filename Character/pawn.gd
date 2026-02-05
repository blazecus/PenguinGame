extends RigidBody2D

enum PawnState {
	IDLE,
	WAITING_FOR_ACTION,
	WAITING_FOR_MOVEMENT,
	MOVING,
	DONE_MOVING,
	THROWING,
	WATCHING,
	DEAD
}

const PROJECTILE_SCENE = preload("res://Character/projectile.tscn")
const Tile = preload("res://World/tile.gd")
const Projectile = preload("res://Character/projectile.gd")

const WALK_FORCES := {
	Tile.TileType.GROUND: 900.0,
	Tile.TileType.ICE: 100.0,
	Tile.TileType.WATER: 900.0
}

const DRAG_FORCES := {
	Tile.TileType.GROUND: 800.0,
	Tile.TileType.ICE: 50.0,
	Tile.TileType.WATER: 800.0
}

const BELLY_DRAG_MULTIPLIER = 0.5
const BELLY_ROTATIONAL_SPEED = 1.7
const BELLY_FORCE_MULTIPLIER = 0.5

const AIRBORN_DRAG = 100.0
const AIRBORN_FORCE = 150.0

const VELOCITY_DRAG = 0.0001
const JUMP_VELOCITY = 15.0
const GRAVITY = 20.0

const THROW_STRENGTH = 10.0
const HEIGHT_THROW_STRENGTH = 0.1

const MOVEMENT_LENGTH = 3.0

const TRAJECTORY_SIM_GRAVITY = 20.0
const TRAJECTORY_SIM_STEPS = 30
const TRAJECTORY_SIM_DELTA = 0.016
const TRAJECTORY_SIM_HEIGHT_SCALE = 100.0

const SHADOW_RATIO = 0.4
const SHADOW_OFFSET = Vector2(16,3)

const NO_COLLISION_LENGTH = 1.0

var moving = false
var state: PawnState = PawnState.IDLE

var team = 0
var health = 100
var selected = false
var height = 0.0
var vertical_velocity = 0.0
var on_belly = false
var belly_direction = Vector2.UP
var tile_state = Tile.TileType.ICE

var no_collision = 0.0
var projectile_throw_strength = Vector2.ZERO

var movement_timer = MOVEMENT_LENGTH
var bar: Node
var gui: Node

var ice_tile_count = 0
var ground_tile_count = 0
var water_tile_count = 0

var mouse_pressed = false
var throw_line = 0
var throw_line_start = Vector2.ZERO
var throw_line_mid = Vector2.ZERO
var throw_line_end = Vector2.ZERO
var projectile_type = Projectile.ProjectileType.BOMB

@onready var sprite = $AnimatedSprite2D
@onready var shadow = $Shadow

func _ready() -> void:
	sprite.play()	

func set_gui(gui_control: Node, bar_control: Node):
	bar = bar_control
	gui = gui_control

func _physics_process(delta: float) -> void:	
	tile_state = get_tile_state()
	moving = check_moving()
	
	var movement_input = Vector2.ZERO 
	if(selected and (state == PawnState.WAITING_FOR_MOVEMENT or state == PawnState.MOVING)):
		movement_input = handle_input()
	compute_forces(movement_input, delta)

	if(state == PawnState.MOVING):
		movement_timer -= delta
		if(movement_timer <= 0.0):
			state = PawnState.DONE_MOVING
			gui.visible = true
			gui.get_node("VBoxContainer").get_node("Move").disabled = true
	elif(state == PawnState.THROWING):
		handle_throw_input()
	
	if(no_collision > 0.0):
		no_collision -= delta
		if(no_collision < 0.0):
			no_collision = 0.0
			set_collision(1)	

	handle_gui()
	handle_sprites()
	queue_redraw()

func handle_sprites() -> void:
	sprite.global_position = global_position + Vector2(0, height * 10.0)
	shadow.global_position = global_position + Vector2(-height * 10.0 * SHADOW_RATIO, 0) + SHADOW_OFFSET

func set_collision(toggle: int):
	collision_layer = toggle
	collision_mask = toggle

func _integrate_forces(pstate: PhysicsDirectBodyState2D) -> void:
	pstate.angular_velocity = 0

	if(!on_belly):
		rotation = 0
	else:
		rotation = belly_direction.angle() - PI * 0.5

	var delta = pstate.step

	height += vertical_velocity * delta
	if(height > 0):
		height = 0.0
		vertical_velocity = 0.0
	vertical_velocity += GRAVITY * delta

func handle_gui() -> void:
	if(selected):
		gui.global_position = global_position

	bar.get_node("VBoxContainer").get_node("StaminaBar").value = movement_timer
	bar.get_node("VBoxContainer").get_node("StaminaBar").visible = state == PawnState.MOVING or state == PawnState.WAITING_FOR_MOVEMENT

	bar.get_node("VBoxContainer").get_node("HealthBar").value = health
	bar.global_position = global_position

	if(selected):
		gui.visible = (
			state == PawnState.DONE_MOVING or 
			state == PawnState.WAITING_FOR_ACTION
		)

func handle_input() -> Vector2:
	var movement_input = Vector2.ZERO
	if Input.is_action_pressed("left"):
		movement_input += Vector2.LEFT
	if Input.is_action_pressed("right"):
		movement_input += Vector2.RIGHT
	if Input.is_action_pressed("up"):
		movement_input += Vector2.UP
	if Input.is_action_pressed("down"):
		movement_input += Vector2.DOWN

	if Input.is_action_just_pressed("space"):
		vertical_velocity = -JUMP_VELOCITY

	if Input.is_action_just_pressed("shift"):
		on_belly = !on_belly
		if(on_belly):
			belly_direction = -linear_velocity.normalized()

	if(state == PawnState.WAITING_FOR_MOVEMENT && movement_input.length() > 0):
		state = PawnState.MOVING
		movement_timer = MOVEMENT_LENGTH 

	return movement_input.normalized()

func handle_throw_input() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not mouse_pressed and throw_line == 0:
			throw_line += 1
			throw_line_start = get_local_mouse_position()
		elif not mouse_pressed and throw_line == 1:
			throw_line += 1
			throw_line_mid = get_local_mouse_position()
		elif not mouse_pressed and throw_line == 2:
			throw_line += 1
			throw_line_end = get_local_mouse_position()
			throw()
		mouse_pressed = true
	else:
		mouse_pressed = false
	
	if throw_line > 0:
		gui.get_node("VBoxContainer").get_node("Throw").disabled = true

	if(throw_line == 1):
		throw_line_mid = get_local_mouse_position()

	elif throw_line == 2:
		throw_line_end = get_local_mouse_position()

func throw() -> void:
	set_collision(0)
	no_collision = NO_COLLISION_LENGTH
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.global_position = global_position

	projectile.set_type(projectile_type)
	projectile.throw(projectile_throw_strength.x, (throw_line_start - throw_line_mid), projectile_throw_strength.y)
	get_parent().get_parent().set_watching_projectile(projectile)
	state = PawnState.WATCHING

func _draw() -> void:
	if throw_line >= 3 or throw_line < 1:
		return
		
	# draw directions
	if(throw_line == 1):
		draw_line(
			throw_line_start,
			throw_line_mid,
			Color.BLACK,
			2.0
		)
	elif(throw_line >= 2):
		draw_line(
			throw_line_start,
			throw_line_mid,
			Color.BLACK,
			2.0
		)
		draw_line(
			throw_line_mid,
			throw_line_end,
			Color.BLACK,
			2.0
		)

	# draw trajectory
	if(throw_line >= 1):
		projectile_throw_strength = get_throw_strength()
		var trajectory = get_trajectory(projectile_throw_strength)

		#if trajectory.size() >= 2:
		#	draw_polyline(trajectory, Color.BLACK, 2.0)
		for coord in trajectory:
			draw_circle(coord, 2, Color.BLACK)

func get_trajectory(throw_strength: Vector2) -> PackedVector2Array:
	var trajectory = PackedVector2Array()	

	var proj_velocity = throw_strength.x / Projectile.MASSES[projectile_type]
	var height_velocity = throw_strength.y / Projectile.MASSES[projectile_type]
	print("traj")
	print(throw_strength.x)

	var local_proj = Vector2.ZERO
	var proj_height = 0

	var throw_direction = (throw_line_start - throw_line_mid).normalized()
	for i in range(TRAJECTORY_SIM_STEPS):
		local_proj += throw_direction * proj_velocity * TRAJECTORY_SIM_DELTA
		proj_height += height_velocity * TRAJECTORY_SIM_DELTA
		height_velocity += TRAJECTORY_SIM_GRAVITY * TRAJECTORY_SIM_DELTA
		if(proj_height > 0):
			break
		
		trajectory.append(local_proj + Vector2(0, proj_height * TRAJECTORY_SIM_HEIGHT_SCALE))

	return trajectory

func get_throw_strength() -> Vector2:
	var twod = clamp((throw_line_mid - throw_line_start).length(), 0, 300) * THROW_STRENGTH 
	var height_strength = (throw_line_mid.y - throw_line_end.y) * HEIGHT_THROW_STRENGTH
	if throw_line == 1:
		height_strength = -2.0
	elif height_strength > 0:
		height_strength = 0
	return Vector2(twod, height_strength)

func compute_forces(movement_input: Vector2, delta: float) -> void:
	# apply drag
	var drag_force = Vector2.ZERO 
	if(moving):
		var drag_mag = linear_velocity.length() * linear_velocity.length() * VELOCITY_DRAG
		drag_force = clamp(drag_mag, 0.05, 0.5) * -linear_velocity.normalized() * (BELLY_DRAG_MULTIPLIER if on_belly else 1.0)
	elif(movement_input.length() == 0.0):
		force_stop()

	var movement_force = Vector2.ZERO
	if(!on_belly or height > 0):
		movement_force = movement_input * (AIRBORN_FORCE if height > 0 else WALK_FORCES[tile_state])
	else:
		if movement_input.y < 0:
			movement_input.y *= 1.5
		else:
			movement_input.y = 0
		
		belly_direction = belly_direction.rotated(BELLY_ROTATIONAL_SPEED * delta * movement_input.x).normalized()
		
		movement_force = movement_input.y * belly_direction * WALK_FORCES[tile_state] * BELLY_FORCE_MULTIPLIER

	apply_central_force(movement_force + drag_force * (AIRBORN_DRAG if height > 0 else DRAG_FORCES[tile_state]))

func check_moving() -> bool:
	if(linear_velocity.length() < 2.0):
		return false
	return true

func force_stop() -> void:
	linear_velocity = Vector2.ZERO

func on_ice() -> bool:
	return false

func is_alive() -> bool:
	return health > 0

func select() -> void:
	selected = true
	gui.visible = true
	gui.get_node("VBoxContainer").get_node("Move").disabled = false
	gui.get_node("VBoxContainer").get_node("Throw").disabled = false
	state = PawnState.WAITING_FOR_ACTION
	throw_line = 0

func unselect() -> void:
	selected = false
	# enforce idle state
	state = PawnState.IDLE

func _on_move_pressed() -> void:
	if(state == PawnState.WAITING_FOR_ACTION):
		state = PawnState.WAITING_FOR_MOVEMENT
		gui.visible = false
	else:
		print("wrong state on move press")

func add_tiles(type: Tile.TileType, num: int):
	if(type == Tile.TileType.ICE):
		ice_tile_count += num
	elif(type == Tile.TileType.GROUND):
		ground_tile_count += num
	else:
		water_tile_count += num

func get_tile_state() -> Tile.TileType:
	if(ground_tile_count > 0):
		return Tile.TileType.GROUND
	if(ice_tile_count > 0):
		return Tile.TileType.ICE
	return Tile.TileType.WATER
