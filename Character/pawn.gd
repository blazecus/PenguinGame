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
	Tile.TileType.ICE: 2000.0,
	Tile.TileType.GROUND: 10000.0,
	Tile.TileType.WATER: 900.0,
	Tile.TileType.SPIKES: 1000.0
}

const DRAG_FORCES := {
	Tile.TileType.ICE: 0.1,
	Tile.TileType.GROUND: 6.0,
	Tile.TileType.WATER: 0.3,
	Tile.TileType.SPIKES: 2.0
}

const TEAM_COLORS = [Color.BLUE, Color.RED]

const BELLY_DRAG_MULTIPLIER = 0.2
const BELLY_ROTATIONAL_SPEED = 1.7
const BELLY_FORCE_MULTIPLIER = 0.5

const AIRBORN_DRAG = 0.4
const AIRBORN_FORCE = 75.0

const VELOCITY_DRAG = 0.0001
const JUMP_VELOCITY = 15.0
const GRAVITY = 20.0

const THROW_STRENGTH = 5.0
const HEIGHT_THROW_STRENGTH = 0.1
const THROW_DRAG_LENGTH = 150
const THROW_HEIGHT_DRAG_LENGTH = 110

const MOVEMENT_LENGTH = 3.0

const TRAJECTORY_SIM_GRAVITY = 20.0
const TRAJECTORY_SIM_STEPS = 30
const TRAJECTORY_SIM_HEIGHT_SCALE = 100.0
const TRAJECTORY_TRIANGLE_SIZE = 15.0

const SHADOW_RATIO = 0.4
const SHADOW_OFFSET = Vector2(16,3)

const NO_COLLISION_LENGTH = 1.0

const STOP_SPEED = 20.0

const PENGUIN_MASS = 10.0

var moving = false
var state: PawnState = PawnState.IDLE

var team = 0
var health = 100
var selected = false
var height = 0.0
var vertical_velocity = 0.0
var on_belly = false
var belly_direction = Vector2.DOWN
var tile_state = Tile.TileType.ICE

var no_collision = 0.0
var projectile_throw_strength = Vector2.ZERO

var movement_timer = MOVEMENT_LENGTH
var bar: Node
var gui: Node

var tile_counts := {
	Tile.TileType.ICE: 0,
	Tile.TileType.GROUND: 0,
	Tile.TileType.WATER: 0,
	Tile.TileType.SPIKES: 0
}

var proj_counts := {
	Projectile.ProjectileType.SNOWBALL : 0,
	Projectile.ProjectileType.BOMB : 0,
	Projectile.ProjectileType.SPIKES : 0,
	Projectile.ProjectileType.BLOCK : 0,
	Projectile.ProjectileType.BUMPER : 0
}

var mouse_pressed = false
var throw_line = 0
var throw_line_start = Vector2.ZERO
var throw_line_mid = Vector2.ZERO
var throw_line_end = Vector2.ZERO
var projectile_type = Projectile.ProjectileType.BOMB

var prev_vel = Vector2.ZERO

@onready var sprite = $AnimatedSprite2D
@onready var shadow = $Shadow

func _ready() -> void:
	play_animation("default",0)
	mass = PENGUIN_MASS
	contact_monitor = true
	max_contacts_reported = 4


func set_gui(gui_control: Node, bar_control: Node):
	bar = bar_control
	gui = gui_control

func set_team(new_team: int) -> void:
	team = new_team
	set_highlight_color(TEAM_COLORS[team])

func _physics_process(delta: float) -> void:	
	if health <= 0:
		if sprite.animation == "death" and sprite.frame == 11:
			visible = false
			bar.visible = false
			if selected:
				get_parent().get_parent().end_turn() # code is a mess but I must finish in time
		return
	tile_state = get_tile_state()
	moving = check_moving()
	
	var movement_input = handle_input()
	compute_forces(movement_input, delta)

	if(state == PawnState.MOVING or state == PawnState.WAITING_FOR_MOVEMENT):
		movement_timer -= delta
		if(movement_timer <= 0.0 and slow_stopped()):
			state = PawnState.DONE_MOVING
			gui.visible = true
			gui.get_node("VBoxContainer").get_node("Move").disabled = true
	else:
		slow_stopped()
		if(state == PawnState.THROWING):
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
		set_deferred("lock_rotation", true)
	else:
		rotation = belly_direction.angle() - PI * 0.5
		set_deferred("lock_rotation", false)

	var delta = pstate.step

	height += vertical_velocity * delta
	if(height > 0):
		height = 0.0
		vertical_velocity = 0.0
		if state == PawnState.MOVING:
			set_collision(1)
	vertical_velocity += GRAVITY * delta

	for i in range(pstate.get_contact_count()):
		var collider = pstate.get_contact_collider_object(i)
		if collider.get_parent().has_method("get_collision_info"):
			#var normal = rect_normal(pstate.get_contact_local_normal(i))
			var collision_info = collider.get_parent().get_collision_info()
			#var collision_direction = prev_vel.normalized()
			#if abs(normal.x) > 0:
			#	collision_direction.x = -collision_direction.x
			#else:
			#	collision_direction.y = -collision_direction.y
			
			#collide_with_wall(collision_direction, collision_info.x, collision_info.y)
			if abs(collision_info.x) > 0 or abs(collision_info.y) > 0:
				collide_with_wall(collision_info.x, collision_info.y)
		#if collider is RigidBody2D:
			

	prev_vel = linear_velocity	

func rect_normal(n: Vector2) -> Vector2:
	if abs(n.x) > abs(n.y):
		return Vector2(sign(n.x), 0)
	else:
		return Vector2(0, sign(n.y))

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
	if(selected and (state == PawnState.WAITING_FOR_MOVEMENT or state == PawnState.MOVING) and movement_timer > 0.0):
		if Input.is_action_pressed("left"):
			movement_input += Vector2.LEFT
		if Input.is_action_pressed("right"):
			movement_input += Vector2.RIGHT
		if Input.is_action_pressed("up"):
			movement_input += Vector2.UP
		if Input.is_action_pressed("down"):
			movement_input += Vector2.DOWN

		if Input.is_action_just_pressed("shift"):
			toggle_belly()

	if selected:
		if Input.is_action_just_pressed("space"):
			vertical_velocity = -JUMP_VELOCITY
			set_collision(2)

	if(state == PawnState.WAITING_FOR_MOVEMENT && movement_input.length() > 0):
		state = PawnState.MOVING

	return movement_input.normalized()

func toggle_belly() -> void:
	on_belly = !on_belly
	if(on_belly):
		if(linear_velocity.length() > 10.0):
			belly_direction = -linear_velocity.normalized()

func handle_throw_input() -> void:
	projectile_throw_strength = get_throw_strength()
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
	proj_counts[projectile_type] -= 1

func _draw() -> void:
	if throw_line >= 3 or throw_line < 1:
		return
		
	# draw directions
	if(throw_line == 1):
		var max_line = throw_line_mid
		if (throw_line_mid - throw_line_start).length() > THROW_DRAG_LENGTH:
			max_line = throw_line_start + (throw_line_mid - throw_line_start).normalized() * THROW_DRAG_LENGTH
		draw_line(
			throw_line_start,
			max_line,
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
		var max_line = throw_line_end
		if throw_line_end.y - throw_line_mid.y > THROW_HEIGHT_DRAG_LENGTH:
			var dir = (throw_line_end - throw_line_mid).normalized()
			var hypot = THROW_HEIGHT_DRAG_LENGTH * 2.0/sin(dir.angle())
			max_line = throw_line_mid + dir * 0.5 * hypot
		draw_line(
			throw_line_mid,
			max_line,
			Color.BLACK,
			2.0
		)

	# draw trajectory
	if(throw_line >= 1):
		var trajectory = get_trajectory(projectile_throw_strength)

		for coord in trajectory:
			draw_circle(coord, 2, Color.BLACK)
		if(trajectory.size() == TRAJECTORY_SIM_STEPS):
			var tri_coords = PackedVector2Array()
			var orig = trajectory[trajectory.size()-1]
			var dir = (orig - trajectory[trajectory.size()-2]).normalized()
			tri_coords.append(orig + Vector2(dir.y, -dir.x) * 0.5 * TRAJECTORY_TRIANGLE_SIZE)
			tri_coords.append(orig + Vector2(-dir.y, dir.x) * 0.5 * TRAJECTORY_TRIANGLE_SIZE)
			tri_coords.append(orig + dir * TRAJECTORY_TRIANGLE_SIZE)
			
			draw_colored_polygon(tri_coords, Color.BLACK)

func get_trajectory(throw_strength: Vector2) -> PackedVector2Array:
	var delta = 1.0 / Engine.physics_ticks_per_second
	var trajectory = PackedVector2Array()	

	var proj_velocity = throw_strength.x / Projectile.MASSES[projectile_type]
	var height_velocity = throw_strength.y / Projectile.MASSES[projectile_type]

	var local_proj = Vector2.ZERO
	var proj_height = 0

	var throw_direction = (throw_line_start - throw_line_mid).normalized()
	for i in range(TRAJECTORY_SIM_STEPS):
		local_proj += throw_direction * proj_velocity * delta
		height_velocity += TRAJECTORY_SIM_GRAVITY * delta
		proj_height += height_velocity * delta
		if(proj_height > 0):
			break
		
		trajectory.append(local_proj + Vector2(0, proj_height * TRAJECTORY_SIM_HEIGHT_SCALE))

	return trajectory

func get_throw_strength() -> Vector2:
	var twod = clamp((throw_line_mid - throw_line_start).length(), 0, Globals.THROW_MAX_PULL_LENGTH) * Globals.THROW_STRENGTH_MODIFIER
	var height_strength = -clamp((throw_line_end.y - throw_line_mid.y), 0, THROW_HEIGHT_DRAG_LENGTH) * HEIGHT_THROW_STRENGTH
	if throw_line == 1:
		height_strength = -2.0
	elif height_strength > 0:
		height_strength = 0
	return Vector2(twod, height_strength)

func compute_forces(movement_input: Vector2, delta: float) -> void:
	var movement_force = Vector2.ZERO
	if(!on_belly or height > 0):
		movement_force = movement_input * (AIRBORN_FORCE if height < 0 else WALK_FORCES[tile_state])
	else:
		if movement_input.y < 0:
			movement_input.y *= 1.5
		else:
			movement_input.y = 0
		
		belly_direction = belly_direction.rotated(BELLY_ROTATIONAL_SPEED * delta * movement_input.x).normalized()
		
		movement_force = movement_input.y * belly_direction * WALK_FORCES[tile_state] * BELLY_FORCE_MULTIPLIER

	linear_damp = (AIRBORN_DRAG if height < 0 else DRAG_FORCES[tile_state]) * (BELLY_DRAG_MULTIPLIER if on_belly else 1.0)
	apply_central_force(movement_force)

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
	movement_timer = MOVEMENT_LENGTH 
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

func apply_external_impulse(force: Vector2) -> void:
	# this function exists so external forces know what forces can apply to
	apply_central_impulse(force)

func take_damage(amount: float) -> void:
	health -= amount

func add_tiles(tile_type: Tile.TileType, num: int):
	tile_counts[tile_type] += num

func get_tile_state() -> Tile.TileType:
	if(tile_counts[Tile.TileType.GROUND] > 0):
		return Tile.TileType.GROUND
	elif(tile_counts[Tile.TileType.ICE] > 0):
		return Tile.TileType.ICE
	elif(tile_counts[Tile.TileType.SPIKES] > 0):
		return Tile.TileType.ICE
	elif tile_counts[Tile.TileType.WATER] > 0: die(true)
	return Tile.TileType.WATER

func collide_with_wall(bounce_factor: float, flat_force: float) -> void:
	#linear_velocity = normal * (prev_vel.length() * bounce_factor + flat_force)
	#global_position += linear_velocity.normalized()
	linear_velocity = linear_velocity.normalized() * (linear_velocity.length() * bounce_factor + flat_force)
	if flat_force > 0.0 or linear_velocity.length() > 100.0:
		on_belly = false

func slow_stopped() -> bool:
	if linear_velocity.length() < STOP_SPEED:
		linear_velocity = Vector2.ZERO
		on_belly = false
		return true
	return false

func play_animation(animation: String, frame: int) -> void:
	$AnimatedSprite2D.play(animation)
	#$AnimatedSprite2D/Highlight.play(animation)
	$Shadow.play(animation)

	$AnimatedSprite2D.frame = frame
	#$AnimatedSprite2D/Highlight.frame = frame
	$Shadow.frame = frame

func set_highlight_color(hl_color: Color) -> void:
	$AnimatedSprite2D.set_instance_shader_parameter("highlight_color", hl_color)

func die(drown: bool) -> void:
	if drown:
		health = 0
	
	on_belly = false

	freeze = true
	collision_mask = 0
	collision_layer = 0

	rotation = 0

	play_animation("death", 0)

func set_projectile_type(proj_type: Projectile.ProjectileType) -> void:
	projectile_type = proj_type

func get_projectile_count(proj_type: Projectile.ProjectileType) -> int:
	return proj_counts[proj_type]

func set_proj_counts(item_counts: Array) -> void:
	for i in range(len(item_counts)):
		proj_counts[i] = item_counts[i]
