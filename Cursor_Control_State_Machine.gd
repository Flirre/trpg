extends Node


func control_tile(world_rotation: int, current_tile: Tile):
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
		MAYBE USE SIGNALS I DUNNO

func is_tile_above(tile: Tile):
	return tile.aboveAreaRay.is_colliding()

