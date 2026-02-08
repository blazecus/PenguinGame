extends Node2D

const GAME_SCENE := preload("res://World/world.tscn")

func _ready() -> void:
	var map_file = FileAccess.open("res://World/Maps/menu.json", FileAccess.READ)
	var map_json := {} 
	if map_file:
		map_json = JSON.parse_string(map_file.get_as_text())	
		map_file.close()
	else:
		push_error("failed to open level file")
	$Map.load_tiles(map_json)


func _on_level_select_pressed() -> void:
	$Control.visible = false
	$LevelMenu.visible = true


func _on_level_select_2_pressed() -> void:
	$Control2.visible = true
	$Control.visible = false

func _on_level_select_3_pressed() -> void:
	$Control3.visible = true
	$Control.visible = false


func _on_level_1_pressed() -> void:
	Globals.current_level = "level1"
	get_tree().change_scene_to_packed(GAME_SCENE)


func _on_level_2_pressed() -> void:
	Globals.current_level = "level2"
	get_tree().change_scene_to_packed(GAME_SCENE)

func _on_level_3_pressed() -> void:
	Globals.current_level = "level3"
	get_tree().change_scene_to_packed(GAME_SCENE)

func _on_back_pressed() -> void:
	$Control.visible = true
	$LevelMenu.visible = false


func _on_back2_pressed() -> void:
	$Control.visible = true
	$Control2.visible = false

func _on_back3_pressed() -> void:
	$Control.visible = true
	$Control3.visible = false
