extends Node2D

const Tile = preload("res://World/tile.gd")
const TILE_SCENE = preload("res://World/tile.tscn")

const map_size = Vector2(50,50)
var children : Array

func _ready() -> void:
	for i in range(map_size.x):
		children.append(Array())
		for j in range(map_size.y):
			children[i].append(create_tile(i, j, Tile.TileType.ICE))
	
func load_tiles(map: Dictionary) -> void:
	var tiles = map["map"]
	for key in tiles:
		var coords = tiles[key]
		var type = int(key)
		for coord in coords:
			set_tile(coord[0], coord[1], type)
	
func create_tile(x: int, y: int, type: Tile.TileType) -> Tile:
	var tile = TILE_SCENE.instantiate()
	tile.set_type(type)
	set_tile_position(x,y,tile)
	add_child(tile)
	return tile

func set_tile_position(x: int, y: int, tile: Tile):
	tile.position = Vector2(
		(-map_size.x * 0.5 + x - 1) * Tile.TILE_SIZE,
		(-map_size.y * 0.5 + y - 1) * Tile.TILE_SIZE
	)

func get_tile(x: int, y: int) -> Tile:
	return children[x][y]

func set_tile(x:int, y:int, type: Tile.TileType) -> void:
	children[x][y].set_type(type)
