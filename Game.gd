extends Spatial

class_name Game

var current_character: Character = null
var current_tile: Tile = null setget set_current_tile
var current_team: Object
var current_selection
var current_selection_index: int setget set_current_selection_index

onready var allies := $World/Allies
onready var enemies := $World/Enemies
onready var camera := $Camera
onready var teamLabel := $Camera/UI/TurnStats/TeamLabel
onready var unitsLeftLabel := $Camera/UI/TurnStats/UnitsLeft
onready var CurrentTurnLabel := $Camera/UI/TurnStats/CurrentTurn
onready var unitActions := $Camera/UI/UnitActions/Actions
onready var selectionArrows := $Camera/UI/SelectionArrows
onready var tiles := $World/Tiles

onready var portrait := $Camera/UI/Portrait
onready var portrait_name := $Camera/UI/Portrait/Background/Name
onready var portrait_class := $Camera/UI/Portrait/Background/Class
onready var portrait_image := $Camera/UI/Portrait/Background/Image
onready var portrait_health_bar := $Camera/UI/Portrait/Background/HealthBar
onready var portrait_mana_bar := $Camera/UI/Portrait/Background/ManaBar

var i: int
var moving := true
var current_units: int
var turns_spent: int setget handle_turns_spent
var game_turns setget handle_new_game_turn
var world_rotation = 0

signal rotate_world_right
signal rotate_world_left

enum GAME_STATE { MAP_CONTROL, UNIT_CONTROL, UNIT_MOVE, UNIT_ATTACK, UNIT_ANIMATING, UNIT_WAIT, PAUSED }
var state
var prev_state

var character_signals = [
	{"sig": "unit_turn_finished", "fun": "handle_unit_turn_finished"},
	{"sig": "die", "fun": "handle_unit_death"}, {"sig": "direction_set", "fun": "character_wait"}
]


func set_game_state(new_state):
	if new_state == GAME_STATE.UNIT_CONTROL:
		unitActions.visible = true
		selectionArrows.visible = true
	else:
		unitActions.visible = false
		selectionArrows.visible = false
	state = new_state
	var state_string
	match state:
		GAME_STATE.MAP_CONTROL:
			state_string = "MAP_CONTROL"
		GAME_STATE.UNIT_CONTROL:
			state_string = "UNIT_CONTROL"
		GAME_STATE.UNIT_MOVE:
			state_string = "UNIT_MOVE"
		GAME_STATE.UNIT_ATTACK:
			state_string = "UNIT_ATTACK"
		GAME_STATE.UNIT_ANIMATING:
			state_string = "UNIT_ANIMATING"
		GAME_STATE.UNIT_WAIT:
			state_string = "UNIT_WAIT"
		GAME_STATE.PAUSED:
			state_string = "PAUSED"
	$Camera/UI/TurnStats/State.text = "State: " + state_string



func _ready():
	setup_unit_signals()
	setup_camera_signals()
	set_current_team(allies)
	current_units = current_team.get_child_count()
	self.game_turns = 0
	self.turns_spent = 0
	yield(get_tree().create_timer(0.00000001), "timeout")
	self.current_tile = allies.get_child(0).get_tile()
	self.current_selection_index = 0
	set_game_state(GAME_STATE.MAP_CONTROL)


func setup_unit_signals():
	for char_signal in character_signals:
		for ally in allies.get_children():
			ally.connect(char_signal.sig, self, char_signal.fun)
		for enemy in enemies.get_children():
			enemy.connect(char_signal.sig, self, char_signal.fun)

func setup_camera_signals():
	camera.connect("rotate_world", self, "_on_Camera_rotate_world")
	camera.connect("start_rotate_world", self, "_on_Camera_start_rotate_world")
	camera.connect("middle_rotate_world", self, "_on_Camera_middle_rotate_world")

func handle_unit_turn_finished():
	self.turns_spent += 1
	if turns_spent >= current_units:
		switch_team()


func switch_team():
	var new_char
	yield(get_tree().create_timer(1), "timeout")
	for unit in current_team.get_children():
		unit.reset_status()
	if current_team == allies:
		set_current_team(enemies)
	else:
		set_current_team(allies)
		self.game_turns += 1
	current_units = current_team.get_child_count()
	self.turns_spent = 0
	new_char = current_team.get_child(0)
	if new_char:
		self.current_tile = new_char.get_tile()


func set_current_team(team: Object) -> void:
	current_team = team
	teamLabel.text = current_team.name


func handle_turns_spent(val: int) -> void:
	turns_spent = val
	set_units_left_label(str(current_units - turns_spent))


func set_units_left_label(text: String) -> void:
	unitsLeftLabel.text = "Units left: " + str(text)


func handle_new_game_turn(val: int) -> void:
	CurrentTurnLabel.text = "Current Turn: " + str(val)
	game_turns = val


func _process(delta):
	if moving and current_tile:
		camera.move_to(current_tile.global_transform.origin, delta)
	if current_tile and is_body_above(current_tile) and not state == GAME_STATE.UNIT_ANIMATING:
		update_portrait()
	match state:
		GAME_STATE.MAP_CONTROL:
			map_control_state(delta)
		GAME_STATE.UNIT_CONTROL:
			unit_control_state(delta)
		GAME_STATE.UNIT_MOVE:
			unit_move_state(delta)
		GAME_STATE.UNIT_ATTACK:
			unit_attack_state(delta)
		GAME_STATE.UNIT_WAIT:
			unit_wait_state(delta)


func map_control_state(_delta: float):
	if Input.is_action_just_pressed("ui_accept"):
		if is_body_above(current_tile) and valid_character_choice(current_tile.get_character()):
			set_current_character(current_tile.get_character())
			character_move()
	control_tile()


func unit_control_state(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		self.current_selection_index -= 1
	if Input.is_action_just_pressed("ui_down"):
		self.current_selection_index += 1
	if Input.is_action_just_pressed("ui_accept"):
		print(current_selection.name)
		match current_selection.name:
			"Wait":
				character_wait()
			"Attack":
				character_attack()
			"Items":
				pass
		self.current_selection_index = 0


func character_move():
	current_character.active = true
	current_character.state = 1
	yield(current_character, "active_completed")
	for tile in tiles.get_children():
		if tile.available:
			tiles.enable_tile(tile)
		for neighbour in tile.neighbours:
			if tile.check_height(neighbour.global_transform.origin.y, current_character.jump):
				tiles.connect_points(tile, neighbour)
	set_game_state(GAME_STATE.UNIT_MOVE)


func character_attack():
	current_character.active = true
	current_character.state = 2
	yield(current_character, "active_completed")
	set_game_state(GAME_STATE.UNIT_ATTACK)

func character_wait():
	current_character.active = true
	current_character.state = 3
	yield(current_character, "active_completed")
	set_game_state(GAME_STATE.UNIT_WAIT)


func set_current_selection_index(val: int):
	selectionArrows.get_child(current_selection_index).visible = false
	if val < 0:
		current_selection_index = unitActions.get_child_count() - 1
	elif val >= unitActions.get_child_count():
		current_selection_index = 0
	else:
		current_selection_index = val
	current_selection = unitActions.get_child(current_selection_index)
	selectionArrows.get_child(current_selection_index).visible = true


func unit_move_state(delta):
	if Input.is_action_just_pressed("ui_accept"):
		if current_tile.available or current_tile == current_character.current_tile:
			move_character(delta)
	control_tile()

func unit_wait_state(_delta: float):
	if current_character:	
		current_character.set_direction()
		if Input.is_action_just_pressed("ui_accept"):
			set_game_state(GAME_STATE.MAP_CONTROL)
			current_character.active = false
			current_character = null

func unit_attack_state(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		if (
			current_tile.get_character() and current_tile.target
			or current_tile == current_character.current_tile
		):
			attack(current_tile.get_character())
	control_tile()


func attack(character: Character):
	if not character == current_character:
		current_character.attack(character)
		current_character.active = false
		current_character = null
		yield(get_tree().create_timer(1), "timeout")
		set_game_state(GAME_STATE.MAP_CONTROL)
	else:
		set_game_state(GAME_STATE.UNIT_CONTROL)
		current_character.reset_character()


func valid_character_choice(character: Character) -> bool:
	return not character.turn_spent and character.get_parent_spatial() == current_team


func move_character(delta: float) -> void:
	if current_tile != current_character.current_tile:
		set_game_state(GAME_STATE.UNIT_ANIMATING)
		current_character.move_to(
			tiles.aStar.get_future_point_path(
				int(current_character.get_tile().name), int(current_tile.name)
			),
			delta
		)
		yield(current_character, "move_completed")
	set_game_state(GAME_STATE.UNIT_CONTROL)
	current_character.state = 0
	current_character.current_tile = null


func control_tile():
	match world_rotation:
		0:
			tile_directions(
				current_tile.upRay,
				current_tile.upNRay,
				current_tile.rightRay,
				current_tile.rightNRay,
				current_tile.downRay,
				current_tile.downNRay,
				current_tile.leftRay,
				current_tile.leftNRay
			)
		1:
			tile_directions(
				current_tile.rightRay,
				current_tile.rightNRay,
				current_tile.downRay,
				current_tile.downNRay,
				current_tile.leftRay,
				current_tile.leftNRay,
				current_tile.upRay,
				current_tile.upNRay
			)
		2:
			tile_directions(
				current_tile.downRay,
				current_tile.downNRay,
				current_tile.leftRay,
				current_tile.leftNRay,
				current_tile.upRay,
				current_tile.upNRay,
				current_tile.rightRay,
				current_tile.rightNRay
			)
		3:
			tile_directions(
				current_tile.leftRay,
				current_tile.leftNRay,
				current_tile.upRay,
				current_tile.upNRay,
				current_tile.rightRay,
				current_tile.rightNRay,
				current_tile.downRay,
				current_tile.downNRay
			)


func tile_directions(upRay, upNRay, rightRay, rightNRay, downRay, downNRay, leftRay, leftNRay):
	if Input.is_action_just_pressed("ui_up"):
		move_to_tile(upNRay, upRay)
	if Input.is_action_just_pressed("ui_right"):
		move_to_tile(rightNRay, rightRay)
	if Input.is_action_just_pressed("ui_down"):
		move_to_tile(downNRay, downRay)
	if Input.is_action_just_pressed("ui_left"):
		move_to_tile(leftNRay, leftRay)


func move_to_tile(directionRay: RayCast, fallbackRay: RayCast) -> void:
	if directionRay.is_colliding():
		if not is_tile_above(directionRay.get_collider().owner):
			move_to_ray(directionRay)
			return
	move_to_ray(fallbackRay)


func move_to_ray(ray: RayCast):
	if ray.is_colliding() and not is_tile_above(ray.get_collider().owner):
		set_current_tile(ray.get_collider().owner)


func is_tile_above(tile: Tile):
	return tile.aboveAreaRay.is_colliding()


func is_body_above(tile: Tile):
	return tile.aboveBodyRay.is_colliding()


func set_current_tile(tile: Tile):
	if current_tile != null:
		current_tile.current = false
	current_tile = tile
	current_tile.current = true
	if is_body_above(tile):
		update_portrait()
	else:
		portrait.visible = false


func update_portrait():
	var character_stats = current_tile.get_character().stats
	portrait_name.text = character_stats.char_name
	portrait_class.text = character_stats.job
	portrait_health_bar.max_value = character_stats.max_health
	portrait_health_bar.value = character_stats.health
	portrait_mana_bar.max_value = character_stats.max_health
	portrait.visible = true


func set_current_character(character: Character):
	for tile in tiles.get_children():
		tiles.disable_tile(tile)
		for neighbour in tile.neighbours:
			tiles.disconnect_points(tile, neighbour)
	if current_character:
		current_character.active = false
		yield(current_character, "inactive_completed")
	current_character = character
	set_current_tile(current_character.get_tile())


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and (event.scancode == KEY_ESCAPE):
			get_tree().quit()


func show_controls():
	unitActions.visible = true


func hide_controls():
	unitActions.visible = false


func handle_unit_death(unit: Character):
	current_character.gain_experience(unit)
	yield(get_tree().create_timer(0.1), "timeout")  # TODO: Maybe change for something robust?
	if allies.get_child_count() == 0:
		print('no you lost')
	if enemies.get_child_count() == 0:
		print('conglaturations')


func _on_Camera_rotate_world(new_rotation):
	world_rotation = new_rotation
	state = prev_state


func _on_Camera_start_rotate_world(direction):
	prev_state = state
	state = GAME_STATE.PAUSED

func _on_Camera_middle_rotate_world(direction):
	if direction < 0:
		emit_signal("rotate_world_right")
	if direction > 0:
		emit_signal("rotate_world_left")
