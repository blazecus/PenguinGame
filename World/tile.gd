extends Node2D

enum TileType {
	ICE,
	GROUND,
	WATER
}

const TILE_SIZE = 32

var ice_texture := preload("res://Assets/ice.png") as Texture2D
var ground_texture := preload("res://Assets/ground.png") as Texture2D
var water_texture := preload("res://Assets/water.png") as Texture2D

var textures := {
	TileType.ICE : ice_texture,
	TileType.GROUND : ground_texture,
	TileType.WATER : water_texture 
}
var type = TileType.ICE

func set_type(new_type: TileType):
	type = new_type
	$Sprite2D.texture = textures[type]

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("add_tiles"):
		body.add_tiles(type, 1)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.has_method("add_tiles"):
		body.add_tiles(type, -1)
