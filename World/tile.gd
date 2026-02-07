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
const BUMPER_FLAT_FORCE = 825.0
const WALL_BOUNCE = 0.85
const WALL_FLAT_FORCE = 0.0
const SPIKE_DAMAGE = 10.0

@onready var area = $Area2D
@onready var sprite = $AnimatedSprite2D

var bodies_on_top = 0

var type = TileType.ICE
var spikes_up = true

func set_type(new_type: TileType):
	type = new_type
	if type == TileType.WALL or type == TileType.BUMPER:
		$Area2D.collision_layer = 0
		$Area2D.collision_mask = 0

		$StaticBody2D.collision_layer = 3
		$StaticBody2D.collision_mask = 3

		var mat := PhysicsMaterial.new()
		mat.friction = 0.0
		if type == TileType.WALL:
			mat.bounce = 1.0
		else:
			mat.bounce = 100.0
		$StaticBody2D.set_physics_material_override(mat)
	else:
		$Area2D.collision_layer = 1
		$Area2D.collision_mask = 1

		$StaticBody2D.collision_layer = 0
		$StaticBody2D.collision_mask = 0
	if type == TileType.WATER:
		var random_tile = str(randi_range(0,1) + 1)
		$AnimatedSprite2D.play(TILE_MAPPING[type] + random_tile)
	else:
		$AnimatedSprite2D.play(TILE_MAPPING[type])
		$AnimatedSprite2D.pause()
		
	if type == TileType.SPIKES:
		toggle_spikes(true)
	elif type != TileType.WATER:
		var random_frame = randi_range(0, $AnimatedSprite2D.sprite_frames.get_frame_count(TILE_MAPPING[type]) - 1)	
		$AnimatedSprite2D.frame = random_frame

func _on_area_2d_body_entered(body: Node2D) -> void:
	if is_floor():
		if body.has_method("add_tiles"):
			bodies_on_top += 1
			body.add_tiles(type, 1)
			if type == TileType.SPIKES and bodies_on_top == 1:
				toggle_spikes(false)	
				if body.has_method("take_damage"):
					body.take_damage(SPIKE_DAMAGE)
			
func _on_area_2d_body_exited(body: Node2D) -> void:
	if is_floor() and body.has_method("add_tiles"):
		body.add_tiles(type, -1)
		bodies_on_top -= 1
		if bodies_on_top == 0 and type == TileType.SPIKES: toggle_spikes(true)

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
	if type == TileType.ICE or type == TileType.GROUND:
		set_type(TileType.WATER)

func get_type():
	return type

func toggle_spikes(spike_toggle: bool) -> void:
	spikes_up = spike_toggle
	$AnimatedSprite2D.frame = 0 if spike_toggle else 1
