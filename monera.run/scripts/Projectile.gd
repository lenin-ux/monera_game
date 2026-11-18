
class_name Projectile extends Area2D

@export var lifetime: float = 1.5


@export_group("Límites del proyectil")

@export var use_lifetime: bool = true
@export var use_max_range: bool = true


# ORIENTACIÓN VISUAL DEL PROYECTIL
@export_enum(
	"Rotar con trayectoria",
	"Solo izquierda/derecha",
	"Imagen fija"
)
var visual_mode: int = 1


@onready var projectile_collider: CollisionShape2D = $CollisionShape2D
@onready var travel_cast: ShapeCast2D = $ShapeCast2D
@onready var projectile_sprite: Sprite2D = $Sprite2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 2000.0
var damage: int = 20
var shooter_id: int = 0

var max_range: float = 3000.0
var traveled_distance: float = 0.0
var elapsed: float = 0.0

var slow_fraction: float = 0.0
var slow_duration: float = 0.0


# CONFIGURAR PROYECTIL
func setup(
	new_direction: Vector2,
	new_speed: float,
	new_damage: int,
	new_shooter_id: int,
	new_range: float = 3000.0,
	new_slow_fraction: float = 0.0,
	new_slow_duration: float = 0.0
) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage
	shooter_id = new_shooter_id

	max_range = new_range
	slow_fraction = new_slow_fraction
	slow_duration = new_slow_duration

	rotation = direction.angle()


func _ready() -> void:
	# Ya no utilizamos body_entered.
	# ShapeCast2D se encargará de los impactos.
	monitoring = false

	travel_cast.shape = projectile_collider.shape
	travel_cast.position = projectile_collider.position
	travel_cast.rotation = projectile_collider.rotation
	travel_cast.collision_mask = 5
	travel_cast.collide_with_bodies = true
	travel_cast.collide_with_areas = false

	# Solamente el servidor detecta impactos
	travel_cast.enabled = multiplayer.is_server()

	if multiplayer.is_server():
		# Evitar detectar al jugador que disparó
		var owner_player := get_node_or_null(
			"../../Players/%s" % shooter_id
		) as CollisionObject2D

		if owner_player != null:
			travel_cast.add_exception(owner_player)
	# Aplicar orientación del sprite
	_update_projectile_visual()


func _physics_process(delta: float) -> void:
	var travel_distance: float = speed * delta

	# LIMITAR DISTANCIA SOLO SI ESTÁ ACTIVADO
	if use_max_range:
		var remaining_range: float = (
			max_range - traveled_distance
		)

		if remaining_range <= 0.0:
			if multiplayer.is_server():
				queue_free()
			return

		travel_distance = minf(
			travel_distance,
			remaining_range
		)

	var movement: Vector2 = direction * travel_distance

	# DETECTAR IMPACTOS EN EL SERVIDOR
	if multiplayer.is_server():
		travel_cast.target_position = (
			Vector2.RIGHT * travel_distance
		)

		travel_cast.force_shapecast_update()

		if travel_cast.is_colliding():
			for i in range(travel_cast.get_collision_count()):
				var collider := travel_cast.get_collider(i)

				# IMPACTO CONTRA UNA BACTERIA
				if collider is MoneraPlayer:
					var player := collider as MoneraPlayer

					if player.player_id == shooter_id:
						continue

					if player.is_dead:
						continue

					position += movement * clampf(
						travel_cast.get_closest_collision_safe_fraction(),
						0.0,
						1.0
					)

					player.take_damage(damage, shooter_id)

					# EFECTO DE RALENTIZACIÓN
					if slow_fraction > 0.0 and not player.is_dead:
						player.apply_slow(
							slow_fraction,
							slow_duration
						)

					queue_free()
					return

				# IMPACTO CONTRA UNA PARED
				elif collider != null:
					queue_free()
					return

	# MOVER PROYECTIL
	position += movement

	# ACTUALIZAR TIEMPO
	if use_lifetime:
		elapsed += delta

	# ACTUALIZAR DISTANCIA
	if use_max_range:
		traveled_distance += travel_distance

	# COMPROBAR LÍMITES ACTIVADOS
	if multiplayer.is_server():
		var time_expired := (
			use_lifetime and elapsed >= lifetime
		)

		var range_expired := (
			use_max_range
			and traveled_distance >= max_range
		)

		if time_expired or range_expired:
			queue_free()


# AJUSTAR ORIENTACIÓN VISUAL DEL PROYECTIL
func _update_projectile_visual() -> void:
	if projectile_sprite == null:
		return

	# Restablecer volteos anteriores
	projectile_sprite.flip_h = false
	projectile_sprite.flip_v = false

	match visual_mode:
		0:
			# El sprite gira hacia donde se dirige
			projectile_sprite.rotation = 0.0

		1:
			# Mantener el sprite horizontal
			projectile_sprite.rotation = -rotation

			# Voltear únicamente izquierda/derecha
			projectile_sprite.flip_h = direction.x < 0.0

		2:
			# Mantener siempre su orientación original
			projectile_sprite.rotation = -rotation
