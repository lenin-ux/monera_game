class_name WeaponBase extends Node2D

@onready var muzzle: Marker2D = $Muzzle


# POSICIÓN DESDE DONDE SALE EL PROYECTIL
func get_muzzle_position() -> Vector2:
	return muzzle.global_position


# DIRECCIONES DE LOS PROYECTILES
func get_shot_directions(
	direction: Vector2
) -> Array[Vector2]:

	return [direction.normalized()]
