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
	ProjectileType.BOMB : 10.0,
	ProjectileType.SPIKES : 5.0,
	ProjectileType.BLOCK : 15.0,
	ProjectileType.BUMPER : 15.0
}

@onready var sprite = $AnimatedSprite2D

const THROW_MODIFIER = 0.005
const HEIGHT_STRENGTH_MODIFIER = 10.0
const HEIGHT_MODIFIER = 10.0

var height = 0.0
var vertical_velocity = 0.0
var type = ProjectileType.SNOWBALL

func _ready() -> void:
	pass

func set_type(new_type: ProjectileType) -> void:
	type = new_type
	mass = MASSES[type]

func throw(power: float, direction: Vector2, vertical_power: float):
	apply_central_impulse(direction * power * THROW_MODIFIER)
	vertical_velocity = vertical_power * HEIGHT_STRENGTH_MODIFIER / mass

func _physics_process(delta: float) -> void:
	sprite.global_position = global_position + Vector2(0, height * HEIGHT_MODIFIER)	
	vertical_velocity += GRAVITY * delta

	if(abs(vertical_velocity) > 0):
		height += vertical_velocity * delta
		if(height > 0):
			height = 0.0
			vertical_velocity = 0.0
		vertical_velocity += GRAVITY * delta
