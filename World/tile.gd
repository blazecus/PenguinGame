extends Node2D

enum TileType {
	ICE,
	GROUND,
	WATER,
	SPIKES,
	WALL,
	BUMPER
}

const TILE_MAPPING := {
	TileType.ICE: "ice",
	TileType.GROUND: "ground",
	TileType.WATER: "water",
	TileType.SPIKES: "spikes",
	TileType.WALL: "wall",
	TileType.BUMPER: "bumper"
}

const TILE_SIZE = 32
const BUMPER_BOUNCE = 0.0 
const BUMPER_FLAT_FORCE = 100.0
const WALL_BOUNCE = 0.8
const WALL_FLAT_FORCE = 0.0

@onready var area = $Area2D
@onready var sprite = $AnimatedSprite2D

var type = TileType.ICE

func set_type(new_type: TileType):
	type = new_type
	if type == TileType.WALL or type == TileType.BUMPER:
		$Area2D.collision_layer = 0
		$Area2D.collision_mask = 0

		$StaticBody2D.collision_layer = 3
		$StaticBody2D.collision_mask = 3
	else:
		$Area2D.collision_layer = 1
		$Area2D.collision_mask = 1

		$StaticBody2D.collision_layer = 0
		$StaticBody2D.collision_mask = 0

	$AnimatedSprite2D.play(TILE_MAPPING[type])
	var random_frame = randi_range(0, $AnimatedSprite2D.sprite_frames.get_frame_count(TILE_MAPPING[type]) - 1)	
	$AnimatedSprite2D.frame = random_frame
	$AnimatedSprite2D.pause()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if is_floor():
		if body.has_method("add_tiles"):
			body.add_tiles(type, 1)
			
func _on_area_2d_body_exited(body: Node2D) -> void:
	if is_floor() and body.has_method("add_tiles"):
		body.add_tiles(type, -1)

func is_floor() -> bool:
	return type == TileType.ICE or type == TileType.GROUND or type == TileType.WATER or type == TileType.SPIKES

func get_collision_info() -> Vector2:
	if type == TileType.BUMPER:
		return Vector2(BUMPER_BOUNCE, BUMPER_FLAT_FORCE)
	elif type == TileType.WALL:
		return Vector2(WALL_BOUNCE, WALL_FLAT_FORCE)
	else:
		return Vector2.ZERO

func explosion_damage() -> void:
	if type == TileType.ICE:
		set_type(TileType.WATER)

func get_type():
	return type
