
class_name BubbleProjectile extends Projectile

# AVISAR AL MUNDO CUANDO EXPLOTE
signal exploded(
	center: Vector2,
	radius: float,
	explosion_damage: int,
	attacker_id: int
)

@export_group("Explosión")
@export_range(50.0, 1000.0, 10.0)
var explosion_radius: float = 250.0

var has_exploded: bool = false


func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	# COMPROBAR TIEMPO DE VIDA
	if use_lifetime and elapsed >= lifetime:
		if multiplayer.is_server():
			_explode()
		return

	# CALCULAR DESPLAZAMIENTO
	var travel_distance: float = speed * delta

	# LIMITAR DISTANCIA SI CORRESPONDE
	if use_max_range:
		var remaining := max_range - traveled_distance

		if remaining <= 0.0:
			if multiplayer.is_server():
				_explode()
			return

		travel_distance = minf(
			travel_distance,
			remaining
		)

	var movement := direction * travel_distance

	# DETECTAR IMPACTOS EN EL SERVIDOR
	if multiplayer.is_server():
		travel_cast.target_position = (
			Vector2.RIGHT * travel_distance
		)

		travel_cast.force_shapecast_update()

		if travel_cast.is_colliding():
			var should_explode := false

			for i in range(
				travel_cast.get_collision_count()
			):
				var collider := travel_cast.get_collider(i)

				# IMPACTO CONTRA UN JUGADOR
				if collider is MoneraPlayer:
					var player := collider as MoneraPlayer

					if player.player_id == shooter_id:
						continue

					if player.is_dead:
						continue

					should_explode = true
					break

				# IMPACTO CONTRA UNA PARED
				if collider is StaticBody2D:
					should_explode = true
					break

			if should_explode:
				var fraction := clampf(
					travel_cast.get_closest_collision_safe_fraction(),
					0.0,
					1.0
				)

				global_position += movement * fraction

				_explode()
				return

	# CONTINUAR RECORRIDO
	global_position += movement

	traveled_distance += travel_distance
	elapsed += delta

	# EXPLOTAR AL LLEGAR AL LÍMITE
	if multiplayer.is_server():
		var range_expired := (
			use_max_range
			and traveled_distance >= max_range
		)

		var time_expired := (
			use_lifetime
			and elapsed >= lifetime
		)

		if range_expired or time_expired:
			_explode()


# ACTIVAR EXPLOSIÓN
func _explode() -> void:
	if not multiplayer.is_server():
		return

	if has_exploded:
		return

	has_exploded = true

	# Avisar al servidor para aplicar daño y efectos
	exploded.emit(
		global_position,
		explosion_radius,
		damage,
		shooter_id
	)

	# Desaparecer en todas las ventanas
	queue_free()
