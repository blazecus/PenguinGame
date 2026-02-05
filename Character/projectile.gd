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
	Tile.TileType.WATER: 0.3
}

const AIRBORN_DRAG = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var shadow = $Shadow
@onready var explosion = $Explosion

# magic number that makes the physics match up for some god forsaken reason
const THROW_MODIFIER = 0.0045
const HEIGHT_MODIFIER = 100.0
const BOMB_TIME_LENGTH = 4.0
const TORQUE_MODIFIER = 0.04

const EXPLOSION_RADIUS = 180.0
const EXPLOSION_FORCE_MODIFIER = 10.0
const EXPLOSION_DAMAGE_MODIFIER = 50.0 / EXPLOSION_RADIUS

const SHADOW_RATIO = 0.4
const SHADOW_OFFSET = Vector2(8.0, -2.0)

const MAGIC_THROW_DAMPER_MODIFIER = 2.8
const MAGIC_THROW_DAMPER_OFFSET = 0.8

var height = 0.0
var vertical_velocity = 0.0
var type = ProjectileType.SNOWBALL

var bomb_timer = BOMB_TIME_LENGTH
var exploded = false

var ice_tile_count = 0
var ground_tile_count = 0
var water_tile_count = 0

var tile_state = Tile.TileType.ICE

func _ready() -> void:
	pass

func set_type(new_type: ProjectileType) -> void:
	type = new_type
	mass = MASSES[type]

func throw(power: float, direction: Vector2, vertical_power: float):
	# more goofy shit to make trajectory scaling work for no reason
	var scaling = (1.0 - (power / (Globals.THROW_MAX_PULL_LENGTH * Globals.THROW_STRENGTH_MODIFIER))) * MAGIC_THROW_DAMPER_MODIFIER + MAGIC_THROW_DAMPER_OFFSET
	apply_central_impulse(direction * power * THROW_MODIFIER * scaling)
	apply_torque_impulse(power * TORQUE_MODIFIER)
	vertical_velocity = vertical_power / mass

	set_collision(2)
	linear_damp = 0

func _physics_process(delta: float) -> void:
	tile_state = get_tile_state()

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

		if bomb_timer <= 1.0 and not exploded:
			explode()

		if bomb_timer <= 0.0:
			end()

	linear_damp = (AIRBORN_DRAG if height < 0 else DRAG_FORCES[tile_state]) 
	
func set_collision(toggle: int) -> void:
	collision_layer = toggle
	collision_mask = toggle

func explode() -> void:
	for body in explosion.get_overlapping_bodies():
		if body.has_method("apply_external_impulse"):
			var dir = (body.global_position - global_position)
			var distance = clamp(EXPLOSION_RADIUS - dir.length(), 10, EXPLOSION_RADIUS)
			body.apply_external_impulse(dir.normalized() *  distance * EXPLOSION_FORCE_MODIFIER)

			if body.has_method("take_damage"):
				body.take_damage(distance * EXPLOSION_DAMAGE_MODIFIER)
	exploded = true
	freeze = true

func end() -> void:
	get_parent().get_parent().end_projectile()
	queue_free()

func add_tiles(tile_type: Tile.TileType, num: int):
	if(tile_type == Tile.TileType.ICE):
		ice_tile_count += num
	elif(tile_type == Tile.TileType.GROUND):
		ground_tile_count += num
	else:
		water_tile_count += num

func get_tile_state() -> Tile.TileType:
	if(ground_tile_count > 0):
		return Tile.TileType.GROUND
	if(ice_tile_count > 0):
		return Tile.TileType.ICE
	return Tile.TileType.WATER
