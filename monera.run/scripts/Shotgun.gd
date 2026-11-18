class_name Shotgun extends WeaponBase

@export_group("Escopeta")

# Dispersión lateral de cada proyectil
@export_range(0.0, 45.0, 1.0)
var spread_degrees: float = 12.0


# DEVOLVER LAS TRES DIRECCIONES DE DISPARO
func get_shot_directions(
	direction: Vector2
) -> Array[Vector2]:

	if direction.is_zero_approx():
		return []

	var forward := direction.normalized()

	# Convertir grados a radianes
	var spread := deg_to_rad(spread_degrees)

	var directions: Array[Vector2] = []

	# Proyectil superior
	directions.append(
		forward.rotated(-spread)
	)

	# Proyectil central
	directions.append(
		forward
	)

	# Proyectil inferior
	directions.append(
		forward.rotated(spread)
	)

	return directions
