extends Node2D

const CAMERA_SPEED = 10.0
const TEXT_TIME = 4.0

const PAWN_SCENE = preload("res://Character/pawn.tscn")
const BAR_SCENE = preload("res://Character/Bars.tscn")
const PawnScript = preload("res://Character/pawn.gd")
const Tile = preload("res://World/tile.gd")
const Projectile = preload("res://Character/projectile.gd")

@onready var team1 = $Team1
@onready var team2 = $Team2
@onready var camera = $Camera2D

@onready var teams = [team1, team2]

@onready var selected_gui = $Control
@onready var bars = $Bars
@onready var map = $Map
@onready var projectiles = $Projectiles

var team_turns = [0,0]
var current_team = 0
var camera_goal_position = Vector2.ZERO
var selected_pawn: Node2D
var watching_projectile: Node2D

var start_timer = TEXT_TIME
var end_timer = 0

func _ready() -> void:
	load_map("")
	select_pawn(0,0)

func load_map(map_dir: String) -> void:
	var map_file = FileAccess.open("res://World/Maps/testmap.json", FileAccess.READ)
	var map_json = JSON.parse_string(map_file.get_as_text())	
	
	for team in range(2):
		for pawn in map_json["teams"][team]:
			var instanced_pawn = PAWN_SCENE.instantiate()
			instanced_pawn.position = Vector2(pawn[0], pawn[1])
			teams[team].add_child(instanced_pawn)

			var instanced_bar = BAR_SCENE.instantiate()
			instanced_bar.position = instanced_pawn.position
			bars.add_child(instanced_bar)
			instanced_pawn.set_gui(selected_gui, instanced_bar)
			instanced_pawn.set_team(team)
	
	map.load_tiles(map_json)
				
func _process(delta: float) -> void:
	handle_controls()
	control_camera(delta)

	var game_state = check_win()
	if game_state == 0:
		return
	
	if game_state == 1:
		print("YOU WIN")
		# display win, exit to main menu
		pass
	else:
		print("YOU LOSE")
		# display lose, exit to main menu
		pass

func end_turn() -> void:
	unselect_pawn()
	current_team = (current_team + 1) % 2
	team_turns[current_team] = find_next(current_team, team_turns[current_team]) 
	select_pawn(current_team, team_turns[current_team])

func find_next(team: int, turn: int) -> int:
	var found_next = false
	var team_size = teams[team].get_child_count()
	var next = turn
	while(not found_next):
		next = (next + 1) % team_size	
		found_next = get_pawn(team, next).is_alive()
	
	return next

func handle_controls() -> void:
	if(Input.is_action_just_pressed("enter")):
		end_turn()

	if selected_pawn.state == PawnScript.PawnState.THROWING:
		pass

func get_pawn(team: int, offset: int) -> Node:
	assert(offset < teams[team].get_child_count(), "not enough children in team")
	return teams[team].get_children()[offset]

func select_pawn(team: int, offset: int) -> void:
	selected_pawn = get_pawn(team, offset)
	selected_pawn.select()

func unselect_pawn() -> void:
	selected_pawn.unselect()

func control_camera(delta:float) -> void:
	# different camera options
	if(selected_pawn.state == PawnScript.PawnState.WATCHING and watching_projectile.has_method("throw")):
		camera_goal_position = watching_projectile.global_position
	else:
		camera_goal_position = selected_pawn.position

	if(selected_pawn.state == PawnScript.PawnState.WAITING_FOR_ACTION):
		camera.position = camera.position.lerp(camera_goal_position, delta * CAMERA_SPEED)
	else:
		camera.position = camera_goal_position

func _on_move_pressed() -> void:
	selected_pawn._on_move_pressed()	

func _on_throw_pressed() -> void:
	selected_pawn.state = PawnScript.PawnState.THROWING

func _on_end_turn_pressed() -> void:
	end_turn()	

func set_watching_projectile(projectile: Projectile) -> void:
	watching_projectile = projectile
	projectiles.add_child(projectile)

func end_projectile(projectile: Node2D) -> void:
	if projectile == watching_projectile:
		selected_pawn.state = PawnScript.PawnState.WAITING_FOR_ACTION

func check_win() -> int:
	var player_alive = false
	for child in team1.get_children():
		if child.health > 0:
			player_alive = true
	
	if not player_alive:
		return -1

	var computer_alive = false
	for child in team2.get_children():
		if child.health > 0:
			computer_alive = true
	
	if not computer_alive: 
		return 1
	
	return 0
