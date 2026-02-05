extends RigidBody2D

const GRAVITY = 20.0

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

@onready var sprite = $AnimatedSprite2D
@onready var shadow = $Shadow

# magic number that makes the physics match up for some god forsaken reason
const THROW_MODIFIER = 0.0092
const HEIGHT_MODIFIER = 100.0
const BOMB_TIME_LENGTH = 4.0
const TORQUE_MODIFIER = 0.04

const SHADOW_RATIO = 0.4
const SHADOW_OFFSET = Vector2(8.0, -2.0)

var height = 0.0
var vertical_velocity = 0.0
var type = ProjectileType.SNOWBALL

var bomb_timer = BOMB_TIME_LENGTH
var exploded = false

func _ready() -> void:
	pass

func set_type(new_type: ProjectileType) -> void:
	type = new_type
	mass = MASSES[type]

func throw(power: float, direction: Vector2, vertical_power: float):
	apply_central_impulse(direction * power * THROW_MODIFIER)
	#linear_velocity = (power / mass) * direction
	apply_torque_impulse(power * TORQUE_MODIFIER)
	vertical_velocity = vertical_power / mass

	set_collision(2)

func _physics_process(delta: float) -> void:
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

		if bomb_timer <= 1.0:
			explode()

		if bomb_timer <= 0.0:
			end()
	
func set_collision(toggle: int) -> void:
	collision_layer = toggle
	collision_mask = toggle

func explode() -> void:
	pass

func end() -> void:
	get_parent().get_parent().end_projectile()
	queue_free()
