extends Spatial

class_name Character

enum TEAMS { ALLIES, ENEMIES, NEUTRAL }
enum STATE { CONTROL, MOVE, ATTACK, WAIT }

export (int) var movement = 2
export (int) var speed = 5
export (int) var jump = 2
export (int) var attack_range = 1
var state
var character_class = "Warrior"
var boss = false
onready var stats = $Stats

var active := false
var current_tile = null
export (int) var team
onready var tileRay = $CurrentTile
onready var tween = $Tween
onready var endSign = $END
onready var sprite := $CharSprite
onready var arrows := $DirectionArrows
var game

var poss_moves = []
var possible_attacks = []
var turn_spent setget set_turn_spent

const SPRITE_TRANSLATION_ABOVE_GAME_OBJECT = 2.3


func set_turn_spent(val: bool):
	endSign.visible = val
	turn_spent = val


signal active_completed
signal inactive_completed
signal movement_completed
signal move_completed
signal unit_turn_finished
signal die
signal direction_set


func set_sprite_direction(front, right):
	sprite.frame = front
	sprite.flip_h = bool(right)


func rotate_sprite_right():
	var front = sprite.frame
	var mirror = sprite.flip_h
	if front == 0 and not mirror:
		set_sprite_direction(1, 1)
	if front == 1 and mirror:
		set_sprite_direction(1, 0)
	if front == 1 and not mirror:
		set_sprite_direction(0, 1)
	if front == 0 and mirror:
		set_sprite_direction(0, 0)


func rotate_sprite_left():
	var front = sprite.frame
	var mirror = sprite.flip_h
	if front == 0 and not mirror:
		set_sprite_direction(0, 1)
	if front == 1 and mirror:
		set_sprite_direction(0, 0)
	if front == 1 and not mirror:
		set_sprite_direction(1, 1)
	if front == 0 and mirror:
		set_sprite_direction(1, 0)


func _ready():
	game = get_tree().get_root().get_node("Game")
	game.connect("rotate_world_right", self, "rotate_sprite_right")
	game.connect("rotate_world_left", self, "rotate_sprite_left")
	stats.connect("no_health", self, "die")
	if active:
		on_active()


func get_tile():
	return tileRay.get_collider().owner


func on_active():
	current_tile = tileRay.get_collider().owner
	match state:
		STATE.MOVE:
			find_possible_movement(movement, jump)
		STATE.ATTACK:
			show_attack_range(attack_range)
		STATE.CONTROL:
			reset_character()
		STATE.WAIT:
			set_direction()
	emit_signal("active_completed")


func find_possible_movement(possible_movement: int, jump: int):
	poss_moves = []
	for tile in current_tile.neighbours:
		if (
			not opposing_teams(tile.get_character())
			and current_tile.check_height(tile.global_transform.origin.y, jump)
		):
			poss_moves = poss_moves + [tile]
	for _i in range(possible_movement - 1):
		for move in poss_moves:
			for poss_new_move in move.neighbours:
				if (
					not poss_new_move in poss_moves
					and not opposing_teams(poss_new_move.get_character())
					and move.check_height(poss_new_move.global_transform.origin.y, jump)
				):
					poss_moves = poss_moves + [poss_new_move]
	for tile in poss_moves:
		tile.check_availability()


func show_attack_range(attack_range: int):
	possible_attacks = []
	for _i in range(attack_range):
		for target in current_tile.neighbours:
			if current_tile.check_height(target.global_transform.origin.y, 1):
				possible_attacks = possible_attacks + [target]
	for target in possible_attacks:
		target.check_targetability()


func exit_active():
	print("exiting")
	reset_character()
	self.turn_spent = true
	emit_signal("inactive_completed")
	emit_signal("unit_turn_finished")


func attack(target: Character) -> void:
	print(self.name, ' attacked ', target.name)
	determine_direction(target.transform.origin)
	target.stats.health -= self.stats.strength


func reset_character():
	if not (poss_moves.size() == 0 and possible_attacks.size() == 0):
		for tile in poss_moves:
			tile.available = false
		for tile in possible_attacks:
			tile.target = false
	make_character_sprite_opaque()
	hide_arrows()
	current_tile = null
	state = STATE.CONTROL
	poss_moves = []
	possible_attacks = []
	active = false


func opposing_teams(character: Character):
	if character == null:
		return false
	return team != character.team


func determine_direction(tile: Vector3):
	var rotation = game.world_rotation
	var movement_dir = self.transform.origin - tile
	match rotation:
		0:
			if movement_dir.x > 0:
				set_sprite_direction(0, 1)
			if movement_dir.x < 0:
				set_sprite_direction(1, 1)
			if movement_dir.z < 0:
				set_sprite_direction(0, 0)
			if movement_dir.z > 0:
				set_sprite_direction(1, 0)
		1:
			if movement_dir.x > 0:
				set_sprite_direction(0, 0)
			if movement_dir.x < 0:
				set_sprite_direction(1, 0)
			if movement_dir.z < 0:
				set_sprite_direction(1, 1)
			if movement_dir.z > 0:
				set_sprite_direction(0, 1)
		2:
			if movement_dir.x > 0:
				set_sprite_direction(1, 1)
			if movement_dir.x < 0:
				set_sprite_direction(0, 1)
			if movement_dir.z < 0:
				set_sprite_direction(1, 0)
			if movement_dir.z > 0:
				set_sprite_direction(0, 0)
		3:
			if movement_dir.x > 0:
				set_sprite_direction(1, 0)
			if movement_dir.x < 0:
				set_sprite_direction(0, 0)
			if movement_dir.z < 0:
				set_sprite_direction(0, 1)
			if movement_dir.z > 0:
				set_sprite_direction(1, 1)


func move_to(path: Array, _delta: float):
	for tile in path:
		tween.interpolate_property(
			self,
			"translation",
			self.transform.origin,
			tile + Vector3(0, SPRITE_TRANSLATION_ABOVE_GAME_OBJECT, 0),
			0.62,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN_OUT
		)
		determine_direction(tile)
		tween.start()
		yield(tween, "tween_completed")
	emit_signal("move_completed")


func _process(_delta):
	if active and current_tile == null:
		on_active()
	if not active and not current_tile == null:
		exit_active()


func reset_status() -> void:
	self.turn_spent = false


func die() -> void:
	emit_signal("die", self)
	get_parent().remove_child(self)


func gain_experience(target) -> void:
	var base_experience = 200
	var boss_factor := 1
	var level = self.stats.level
	var target_level = target.stats.level
	if target.boss:
		boss_factor = 2
	if level > target.stats.level:
		base_experience = int(base_experience / (level - target_level))
	if level < target_level:
		base_experience = int(base_experience * (target_level - level))
	self.stats.experience_points = base_experience * boss_factor


func set_direction():
	make_character_sprite_transparent()
	show_arrows()
	if Input.is_action_pressed("ui_up"):
		set_sprite_direction(1, 1)
		highlight_arrow($DirectionArrows/Up)
		emit_signal("direction_set")
	elif Input.is_action_pressed("ui_down"):
		set_sprite_direction(0, 1)
		highlight_arrow($DirectionArrows/Down)
		emit_signal("direction_set")
	elif Input.is_action_pressed("ui_right"):
		set_sprite_direction(0, 0)
		highlight_arrow($DirectionArrows/Right)
		emit_signal("direction_set")
	elif Input.is_action_pressed("ui_left"):
		highlight_arrow($DirectionArrows/Left)
		set_sprite_direction(1, 0)
		emit_signal("direction_set")



func make_character_sprite_transparent():
	sprite.opacity = 0.5


func make_character_sprite_opaque():
	sprite.opacity = 1


func show_arrows():
	var rotation = get_tree().root.get_node("Game/World").rotation
	arrows.rotation = -rotation
	arrows.visible = true


func hide_arrows():
	arrows.visible = false


func highlight_arrow(arrow: Sprite3D):
	reset_arrows()
	arrow.opacity = 1
	arrow.modulate = Color.lightsalmon


func reset_arrows():
	for arrow in arrows.get_children():
		arrow.modulate = Color.white
