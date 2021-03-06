extends Camera

var motion := Vector3()
var velocity := Vector3()
var init_rotation := rotation.y
enum CAMERA_STATE { IDLE, ROTATING }
var camera_state = CAMERA_STATE.IDLE
onready var game_world = get_parent().get_node("World")
onready var world_tween = game_world.get_node("Tween")
var world_rotation = 0
signal rotate_world
signal start_rotate_world
signal middle_rotate_world

const GAME_STATE = preload("res://Game.gd").GAME_STATE


func _process(delta: float) -> void:
	var state = get_tree().get_root().get_node("Game").state
	match camera_state:
		CAMERA_STATE.IDLE:
			match state:
				GAME_STATE.UNIT_MOVE:
					continue

				GAME_STATE.MAP_CONTROL:
					if Input.is_action_pressed("ui_rotate_right"):
						rotate_camera_right()

						#Rotate around X, good enough for now
					if Input.is_action_pressed("ui_rotate_left"):
						rotate_camera_left()

						#Rotate around X, good enough for now
					if Input.is_action_pressed("ui_up"):
						motion.y = 1

						#Rotate around X, good enough for now
					elif Input.is_action_pressed("ui_down"):
						motion.y = -1

						#Rotate around X, good enough for now
					else:
						motion.y = 0

						#Rotate around X, good enough for now
					if Input.is_action_pressed("ui_right"):
						motion.z = 1

						#Rotate around X, good enough for now
					elif Input.is_action_pressed("ui_left"):
						motion.z = -1

						#Rotate around X, good enough for now
					else:
						motion.z = 0

						#Rotate around X, good enough for now
					motion.x = 0
					motion = motion.normalized()

					var prev_motion = motion

					#Rotate around X, good enough for now
					motion.x = prev_motion.x
					motion.y = (prev_motion.y * cos(-270)) - (prev_motion.z * sin(-270))
					motion.z = (prev_motion.y * sin(-270)) + (prev_motion.z * cos(-270))

					velocity += motion
					velocity *= 0.9
					translation += velocity * delta

				GAME_STATE.UNIT_CONTROL:
					pass
		CAMERA_STATE.ROTATING:
			pass


func rotate_world(right: bool):
	if right:
		world_rotation = (world_rotation + 1) % 4
	else:
		if world_rotation <= 0:
			world_rotation = 3
		else:
			world_rotation -= 1
	emit_signal("rotate_world", world_rotation)


func rotate_camera_right():
	camera_state = CAMERA_STATE.ROTATING
	emit_signal("start_rotate_world", -1)
	world_tween.interpolate_property(
		game_world,
		"rotation",
		game_world.rotation,
		game_world.rotation + Vector3(0, PI / 4, 0),
		0.5,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	world_tween.start()
	yield(world_tween, "tween_completed")
	emit_signal("middle_rotate_world", -1)
	world_tween.interpolate_property(
		game_world,
		"rotation",
		game_world.rotation,
		game_world.rotation + Vector3(0, PI / 4, 0),
		0.5,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	world_tween.start()
	yield(world_tween, "tween_completed")
	camera_state = CAMERA_STATE.IDLE
	rotate_world(true)


func rotate_camera_left():
	camera_state = CAMERA_STATE.ROTATING
	world_tween.interpolate_property(
		game_world,
		"rotation",
		game_world.rotation,
		game_world.rotation - Vector3(0, PI / 4, 0),
		0.5,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	world_tween.start()
	yield(world_tween, "tween_completed")
	emit_signal("middle_rotate_world", 1)
	world_tween.interpolate_property(
		game_world,
		"rotation",
		game_world.rotation,
		game_world.rotation - Vector3(0, PI / 4, 0),
		0.5,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	world_tween.start()
	yield(world_tween, "tween_completed")
	camera_state = CAMERA_STATE.IDLE
	rotate_world(false)


func move_to(target: Vector3, delta: float) -> void:
	var offsetVector := Vector3(-12, 18, 12)
	transform.origin = lerp(
		transform.origin,
		Vector3(offsetVector.x + target.x, offsetVector.y + target.y, offsetVector.z + target.z),
		delta
	)
