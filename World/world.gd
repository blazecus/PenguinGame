extends Node2D

const CAMERA_SPEED = 10.0
const TEXT_TIME = 4.0
const AI_WAIT = 0.5
const END_TIME = 4.0

const PAWN_SCENE = preload("res://Character/pawn.tscn")
const BAR_SCENE = preload("res://Character/Bars.tscn")
const PawnScript = preload("res://Character/pawn.gd")
const Tile = preload("res://World/tile.gd")
const Projectile = preload("res://Character/projectile.gd")
const Map = preload("res://World/map.gd")

const MENU_SCENE := preload("res://Menus/main_menu.tscn")

@onready var team1 = $Team1
@onready var team2 = $Team2
@onready var camera = $Camera2D

@onready var teams = [team1, team2]

@onready var selected_gui = $Control
@onready var bars = $Bars
@onready var map = $Map
@onready var projectiles = $Projectiles

@onready var projectile_menu = $Control/VBoxContainer2
@onready var proj_buttons  := {
	Projectile.ProjectileType.SNOWBALL : projectile_menu.get_node("Snowball"),
	Projectile.ProjectileType.BOMB : projectile_menu.get_node("Bomb"),
	Projectile.ProjectileType.SPIKES : projectile_menu.get_node("Spikes"),
	Projectile.ProjectileType.BLOCK : projectile_menu.get_node("Block"),
	Projectile.ProjectileType.BUMPER : projectile_menu.get_node("Bumper")
}

var team_turns = [0,0]
var current_team = 0
var camera_goal_position = Vector2.ZERO
var selected_pawn: Node2D
var watching_projectile: Node2D

var start_timer = TEXT_TIME
var end_timer = 0

var s_collide = false
var s_jump = false
var s_select = false
var ai_timer = 0.0
var game_state = 0

func _ready() -> void:
	load_map()
	select_pawn(0,0)

func load_map() -> void:
	var map_file = FileAccess.open("res://World/Maps/" + Globals.current_level + ".json", FileAccess.READ)
	var map_json := {} 
	if map_file:
		map_json = JSON.parse_string(map_file.get_as_text())	
		map_file.close()
	else:
		push_error("failed to open level file")
	
	for team in range(2):
		for pawn in map_json["teams"][team]:
			var instanced_pawn = PAWN_SCENE.instantiate()

			instanced_pawn.position = Vector2(
				(-Map.map_size.x * 0.5 + pawn[0] - 1) * Tile.TILE_SIZE,
				(-Map.map_size.y * 0.5 + pawn[1] - 1) * Tile.TILE_SIZE
			)
			instanced_pawn.set_proj_counts(map_json["items"][team])
			teams[team].add_child(instanced_pawn)
			connect_pawn_signals(instanced_pawn)

			var instanced_bar = BAR_SCENE.instantiate()
			instanced_bar.position = instanced_pawn.position
			bars.add_child(instanced_bar)
			instanced_pawn.set_gui(selected_gui, instanced_bar)
			instanced_pawn.set_team(team)
	
	map.load_tiles(map_json)

func connect_pawn_signals(pawn: Node2D) -> void:
	pawn.connect("s_jumped", _on_pawn_jumped)
	pawn.connect("s_collide", _on_pawn_collided)
	pawn.connect("s_select", _on_pawn_selected)
	pawn.connect("s_throw", _on_pawn_throw)
	pawn.connect("s_die", _on_pawn_die)
	pawn.connect("s_damage", _on_pawn_damage)
	pawn.connect("s_bumper", _on_bumper)

func _on_pawn_jumped() -> void:
	$Sound.get_node("Jump").play()

func _on_pawn_collided() -> void:
	$Sound.get_node("Thud").play()

func _on_pawn_selected() -> void:
	$Sound.get_node("Select").play()

func _on_pawn_die() -> void:
	$Sound.get_node("Die").play()

func _on_pawn_throw() -> void:
	$Sound.get_node("Throw").play()

func _on_pawn_damage() -> void:
	$Sound.get_node("Damage").play()

func _on_explode() -> void:
	$Sound.get_node("Explode").play()

func _on_spikes() -> void:
	$Sound.get_node("Spikes").play()

func _on_bumper() -> void:
	$Sound.get_node("Bumper").play()
				
func _process(delta: float) -> void:
	if game_state != 0:
		end_timer += delta
		if end_timer > END_TIME:
			get_tree().change_scene_to_packed(MENU_SCENE)
		return
			
	handle_controls()
	control_camera(delta)
	ai_turn(delta)
	manage_disables()

	game_state = check_win()
	if game_state == 0:
		return
	
	var end_text = "You lose!"
	if game_state == 1:
		end_text = "You win!"
	
	$Message/TextureRect/Label.text = end_text
	$Message.visible = true

	for child in team1.get_children():
		child.queue_free()	

	for child in team2.get_children():
		child.queue_free()	
	camera.position = Vector2.ZERO

func manage_disables() -> void:
	for i in $Control/VBoxContainer.get_children():
		i.get_node("Label").add_theme_color_override("font_color", Color(0,0,0) if not i.disabled else Color(0.6,0.6,0.6))

func ai_turn(delta: float):
	if selected_pawn.team == 1:
		if selected_pawn.state == PawnScript.PawnState.WAITING_FOR_ACTION:
			ai_timer += delta
			if not selected_pawn.ai_moved and ai_timer > AI_WAIT:
				selected_pawn.state = PawnScript.PawnState.WAITING_FOR_MOVEMENT
				ai_timer = 0.0
		elif selected_pawn.state == PawnScript.PawnState.DONE_MOVING:
			ai_timer += delta
			if not selected_pawn.ai_threw and ai_timer > AI_WAIT * 1.5:
				selected_pawn.state = PawnScript.PawnState.THROWING
				ai_timer = 0.0
		if selected_pawn.state != PawnScript.PawnState.WATCHING and selected_pawn.ai_moved and selected_pawn.ai_threw:
			ai_timer += delta
			if ai_timer > AI_WAIT * 3.0:
				end_turn()

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
	if(Input.is_action_just_pressed("enter") and selected_pawn.team == 0):
		end_turn()

	if selected_pawn.state == PawnScript.PawnState.THROWING:
		pass

func get_target_position() -> Vector2:
	var target = Vector2.ZERO
	var potential_targets = []
	for child in team1.get_children():
		if child.health > 0:
			potential_targets.append(child.global_position)
	if potential_targets.size() > 0:
		target = potential_targets[randi_range(0, potential_targets.size() - 1)]
	return target

func get_pawn(team: int, offset: int) -> Node:
	assert(offset < teams[team].get_child_count(), "not enough children in team")
	return teams[team].get_children()[offset]

func select_pawn(team: int, offset: int) -> void:
	selected_pawn = get_pawn(team, offset)
	selected_pawn.select()
	projectile_menu.visible = false
	for i in proj_buttons.keys():
		if i != Projectile.ProjectileType.SNOWBALL:	
			var item_count = selected_pawn.get_projectile_count(i)
			proj_buttons[i].get_node("Label").text = proj_buttons[i].get_node("Label").text.substr(0, proj_buttons[i].get_node("Label").text.length() - 1) + str(item_count)
			proj_buttons[i].disabled = item_count <= 0
	
	ai_timer = 0.0

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
	projectile_menu.visible = not projectile_menu.visible

func _on_end_turn_pressed() -> void:
	end_turn()	

func set_watching_projectile(projectile: Projectile) -> void:
	watching_projectile = projectile
	projectiles.add_child(projectile)
	projectile.connect("s_collide", _on_pawn_collided)
	projectile.connect("s_explode", _on_explode)
	projectile.connect("s_spikes", _on_spikes)	
	projectile.connect("s_bumper", _on_bumper)

func end_projectile(projectile: Node2D) -> void:
	if projectile == watching_projectile:
		selected_pawn.state = PawnScript.PawnState.WAITING_FOR_ACTION
		watching_projectile = null

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


func _on_snowball_pressed() -> void:
	select_projectile(Projectile.ProjectileType.SNOWBALL)


func _on_bomb_pressed() -> void:
	select_projectile(Projectile.ProjectileType.BOMB)


func _on_spikes_pressed() -> void:
	select_projectile(Projectile.ProjectileType.SPIKES)


func _on_block_pressed() -> void:
	select_projectile(Projectile.ProjectileType.BLOCK)


func _on_bumper_pressed() -> void:
	select_projectile(Projectile.ProjectileType.BUMPER)

func select_projectile(proj_type: Projectile.ProjectileType) -> void:
	selected_pawn.state = PawnScript.PawnState.THROWING
	selected_pawn.set_projectile_type(proj_type)
	projectile_menu.visible = false
