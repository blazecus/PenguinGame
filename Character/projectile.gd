extends RigidBody2D

const GRAVITY = 20.0

const Tile = preload("res://World/tile.gd")

enum ProjectileType {
	SNOWBALL,
	BOMB,
	SPIKES,
	BLOCK,
	BUMPER
}

const MASSES := {
	ProjectileType.SNOWBALL : 1.0,
	ProjectileType.BOMB : 1.5,
	ProjectileType.SPIKES : 5.0,
	ProjectileType.BLOCK : 15.0,
	ProjectileType.BUMPER : 15.0
}

const ANIMATIONS := {
	ProjectileType.SNOWBALL : "snowball",
	ProjectileType.BOMB : "bomb",
	ProjectileType.SPIKES : "spikes",
	ProjectileType.BLOCK : "block",
	ProjectileType.BUMPER : "bumper"
}

const DRAG_FORCES := {
	Tile.TileType.GROUND: 2.0,
	Tile.TileType.ICE: 0.5,
	Tile.TileType.WATER: 0.3,
	Tile.TileType.SPIKES: 2.0,
}

const AIRBORN_DRAG = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var shadow = $Shadow
@onready var explosion = $Explosion

# magic number that makes the physics match up for some god forsaken reason
const THROW_MODIFIER = 0.0045
const HEIGHT_MODIFIER = 100.0
const BOMB_TIME_LENGTH = 3.33
const TORQUE_MODIFIER = 0.04
const BOUNCE_TORQUE_MODIFIER = 0.06
const ANGULAR_DAMP = 0.4
const MAX_ANGULAR_VEL = 70.0

const EXPLOSION_RADIUS = 180.0
const EXPLOSION_FORCE_MODIFIER = 100.0
const EXPLOSION_DAMAGE_MODIFIER = 50.0 / EXPLOSION_RADIUS
const TILE_EXPLOSION_RADIUS = 50.0

const SHADOW_RATIO = 0.4
const SHADOW_OFFSET = Vector2(8.0, -2.0)

const MAGIC_THROW_DAMPER_MODIFIER = 2.8
const MAGIC_THROW_DAMPER_OFFSET = 0.8

const BOUNCINESS = 3.5

var height = 0.0
var vertical_velocity = 0.0
var type = ProjectileType.SNOWBALL

var bomb_timer = BOMB_TIME_LENGTH
var exploded = false

var prev_vel = Vector2.ZERO

var tile_counts := {
	Tile.TileType.ICE: 0,
	Tile.TileType.GROUND: 0,
	Tile.TileType.WATER: 0,
	Tile.TileType.SPIKES: 0
}

var tile_state = Tile.TileType.ICE

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	angular_damp = ANGULAR_DAMP

func set_type(new_type: ProjectileType) -> void:
	type = new_type
	mass = MASSES[type]

	$AnimatedSprite2D.play(ANIMATIONS[type])
	$Shadow.play(ANIMATIONS[type])

func throw(power: float, direction: Vector2, vertical_power: float):
	# more goofiness to make trajectory scaling work for no reason
	var scaling = (1.0 - (power / (Globals.THROW_MAX_PULL_LENGTH * Globals.THROW_STRENGTH_MODIFIER))) * MAGIC_THROW_DAMPER_MODIFIER + MAGIC_THROW_DAMPER_OFFSET
	apply_central_impulse(direction * power * THROW_MODIFIER * scaling)
	apply_torque_impulse(power * TORQUE_MODIFIER)
	vertical_velocity = vertical_power / mass

	set_collision(2)
	linear_damp = 0

func _physics_process(delta: float) -> void:
	tile_state = get_tile_state()

	if tile_state == Tile.TileType.WATER:
		end()
		return

	sprite.global_position = global_position + Vector2(0, height * HEIGHT_MODIFIER)	
	shadow.global_position = global_position + Vector2(-height * HEIGHT_MODIFIER * SHADOW_RATIO, 0) + SHADOW_OFFSET

	height += vertical_velocity * delta
	if(height >= 0):
		height = 0.0
		vertical_velocity = 0.0
		set_collision(1)
	vertical_velocity += GRAVITY * delta
	
	if type == ProjectileType.BOMB:
		bomb_timer -= delta

		if bomb_timer <= 0.33 and not exploded:
			explode()

		if bomb_timer <= 0.0:
			terrain_explode()
			end()

	linear_damp = (AIRBORN_DRAG if height < 0 else DRAG_FORCES[tile_state]) 
	angular_velocity = sign(angular_velocity) * clamp(abs(angular_velocity), 0, MAX_ANGULAR_VEL)

func set_collision(toggle: int) -> void:
	collision_layer = toggle
	collision_mask = toggle

func explode() -> void:
	for body in explosion.get_overlapping_bodies():
		if body.has_method("apply_external_impulse"):
			if not check_for_wall(body.global_position):
				var dir = (body.global_position - global_position)
				var distance = clamp(EXPLOSION_RADIUS - dir.length(), 10, EXPLOSION_RADIUS)
				#body.apply_external_impulse(dir.normalized() *  distance * EXPLOSION_FORCE_MODIFIER)
				body.linear_velocity = dir.normalized() * distance * EXPLOSION_FORCE_MODIFIER / body.mass

				if body.has_method("take_damage"):
					body.take_damage(distance * EXPLOSION_DAMAGE_MODIFIER)
	exploded = true
	freeze = true
	$AnimatedSprite2D.play("explosion")
	$Shadow.visible = false

func terrain_explode() -> void:
	for area in explosion.get_overlapping_areas():
		if area.get_parent().has_method("explosion_damage") and not check_for_wall(area.global_position):
			if (area.global_position - global_position).length() < TILE_EXPLOSION_RADIUS:
				area.get_parent().explosion_damage()

func check_for_wall(body_position: Vector2) -> bool:
	var query = PhysicsRayQueryParameters2D.create(global_position, body_position)
	var collision = get_world_2d().direct_space_state.intersect_ray(query)
	if collision.size() == 0: return false
	var collider = collision["collider"]
	if collider is StaticBody2D and collider.has_method("get_type"):
		if collider.get_type() == Tile.TileType.BUMPER or collider.get_type() == Tile.TileType.WALL:
			return true
	return false

func end() -> void:
	get_parent().get_parent().end_projectile(self)
	call_deferred("queue_free")

func add_tiles(tile_type: Tile.TileType, num: int):
	tile_counts[tile_type] += num

func get_tile_state() -> Tile.TileType:
	if(tile_counts[Tile.TileType.GROUND] > 0):
		return Tile.TileType.GROUND
	elif(tile_counts[Tile.TileType.ICE] > 0):
		return Tile.TileType.ICE
	elif(tile_counts[Tile.TileType.WATER] > 0):
		return Tile.TileType.WATER
	return Tile.TileType.ICE

func collide_with_wall(bounce_factor: float, flat_force: float) -> void:
	apply_torque_impulse((bounce_factor * prev_vel.length() + flat_force) * BOUNCE_TORQUE_MODIFIER)
	#linear_velocity = normal * (prev_vel.length() * bounce_factor + flat_force)
	#global_position += linear_velocity.normalized() * 4.0
	linear_velocity = linear_velocity.normalized() * (linear_velocity.length() * bounce_factor + flat_force)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	for i in range(state.get_contact_count()):
		var collider = state.get_contact_collider_object(i)
		if collider.get_parent().has_method("get_collision_info"):
			#var normal = rect_normal(state.get_contact_local_normal(i))
			var collision_info = collider.get_parent().get_collision_info()
			#var collision_direction = prev_vel.normalized()
			#if abs(normal.x) > 0:
				#collision_direction.x = -collision_direction.x
			#else:
				#collision_direction.y = -collision_direction.y
			
			collide_with_wall(collision_info.x, collision_info.y)
	prev_vel = linear_velocity

func rect_normal(n: Vector2) -> Vector2:
	if abs(n.x) > abs(n.y):
		return Vector2(sign(n.x), 0)
	else:
		return Vector2(0, sign(n.y))
