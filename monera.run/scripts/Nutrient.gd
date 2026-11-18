
class_name Nutrient extends Area2D

# Puntos otorgados al recoger el nutriente
@export_range(1, 100, 1) var point_value: int = 1

# Tolerancia para recoger nutrientes
@export_range(0.5, 1.0, 0.05)
var collection_tolerance: float = 0.5

@onready var nutrient_collider: CollisionShape2D = $CollisionShape2D

var collected: bool = false


func _ready() -> void:
	# Solamente el servidor detecta recolecciones
	monitoring = multiplayer.is_server()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or collected:
		return

	# Buscar bacterias que se superponen al nutriente
	for body in get_overlapping_bodies():
		var player := body as MoneraPlayer

		if player == null:
			continue

		if player.is_dead:
			continue

		# No basta con tocarlo: debe cubrirlo entero
		if _is_fully_covered(player):
			_collect(player)
			return


# COMPROBAR COBERTURA COMPLETA
func _is_fully_covered(player: MoneraPlayer) -> bool:
	var player_collider := player.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D

	if player_collider == null:
		return false

	if player_collider.disabled:
		return false

	var nutrient_shape := (
		nutrient_collider.shape as CircleShape2D
	)

	var body_shape: Shape2D = player_collider.shape

	if nutrient_shape == null or body_shape == null:
		return false

	# Radio del nutriente en coordenadas globales.
	# Usamos la escala mayor para evitar falsos positivos.
	var nutrient_scale := nutrient_collider.global_scale

	var world_radius: float = nutrient_shape.radius * maxf(
		absf(nutrient_scale.x),
		absf(nutrient_scale.y)
	)

	# Transformar al espacio local de la colisión del jugador
	var player_scale := player_collider.global_scale

	var smallest_scale: float = minf(
		absf(player_scale.x),
		absf(player_scale.y)
	)

	if smallest_scale <= 0.0001:
		return false

	var center: Vector2 = player_collider.to_local(
		nutrient_collider.global_position
	)

	
	var radius: float = world_radius / smallest_scale

	# Reducir el radio exigido para permitir
	# una pequeña parte fuera del cuerpo
	var required_radius: float = radius * collection_tolerance

	return _circle_inside_shape(
		center,
		required_radius,
		body_shape
	)



# COMPROBAR QUE UN CÍRCULO QUEPA DENTRO DEL CUERPO
func _circle_inside_shape(
	center: Vector2,
	radius: float,
	shape: Shape2D
) -> bool:

	# CUERPO CIRCULAR
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D

		return (
			center.length() + radius <= circle.radius
		)

	# CUERPO RECTANGULAR
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		var half_size := rectangle.size * 0.5

		return (
			absf(center.x) + radius <= half_size.x
			and absf(center.y) + radius <= half_size.y
		)

	# CUERPO CON FORMA DE CÁPSULA
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D

		var half_segment: float = maxf(
			0.0,
			capsule.height * 0.5 - capsule.radius
		)

		var nearest := Vector2(
			0.0,
			clampf(center.y, -half_segment, half_segment)
		)

		return (
			center.distance_to(nearest) + radius
			<= capsule.radius
		)

	# CUERPO CON POLÍGONO CONVEXO
	if shape is ConvexPolygonShape2D:
		var polygon_shape := shape as ConvexPolygonShape2D
		var polygon: PackedVector2Array = polygon_shape.points

		if polygon.size() < 3:
			return false

		if not Geometry2D.is_point_in_polygon(
			center, polygon
		):
			return false

		# El círculo debe quedar lejos de todos los bordes
		for i in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[
				(i + 1) % polygon.size()
			]

			var nearest := Geometry2D.get_closest_point_to_segment(
				center, a, b
			)

			if center.distance_to(nearest) < radius:
				return false

		return true

	# No recoger si el personaje usa una forma no admitida
	return false


# RECOGER NUTRIENTE
func _collect(player: MoneraPlayer) -> void:
	if collected or not multiplayer.is_server():
		return

	collected = true

	# Sumar puntos al jugador que lo cubrió
	player.points += point_value
	
	
	# REPRODUCIR SONIDO DE RECOGER NUTRIENTE
	var audio := get_tree().current_scene.get_node_or_null(
	    "WorldAudio"
	) as WorldAudio

	if audio != null and multiplayer.is_server():
		audio.anunciar(
			"nutriente",
			player.global_position,
			player.player_id
		)


	print(
		"Jugador ", player.player_id,
		" recogió +", point_value,
		" puntos. Total: ", player.points
	)

	# El servidor elimina el nutriente para todos
	queue_free()
