
class_name AlienWaveVisual extends Node2D

@export_group("Área de ataque")
@export var attack_range: float = 1200
@export_range(10.0, 170.0, 1.0)
var cone_angle: float = 85.0

@export_group("Animación")
@export var wave_duration: float = 0.6

@export_group("Depuración")
@export var show_hit_area: bool = true

var elapsed: float = 0.0
var active: bool = false


func _ready() -> void:
	hide()
	set_process(false)


# INICIAR ANIMACIÓN
func play_wave() -> void:
	elapsed = 0.0
	active = true
	show()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta

	if elapsed >= wave_duration:
		active = false
		hide()
		set_process(false)
		return

	queue_redraw()


# DIBUJAR ÁREA Y ONDAS

func _draw() -> void:
	if not active:
		return

	# MISMA GEOMETRÍA QUE UTILIZARÁ EL DAÑO
	var polygon := get_hit_polygon()

	# Área visual del rayo
	draw_colored_polygon(
		polygon,
		Color(0.2, 0.85, 1.0, 0.12)
	)

	# CONTORNO DE DEPURACIÓN
	if show_hit_area:
		var outline := polygon.duplicate()
		outline.append(polygon[0])

		draw_polyline(
			outline,
			Color(1.0, 0.25, 0.15, 0.95),
			6.0,
			true
		)

	# ANIMACIÓN DE ONDAS
	var half_angle := deg_to_rad(cone_angle) * 0.5

	var progress := clampf(
		elapsed / maxf(wave_duration, 0.001),
		0.0,
		1.0
	)

	for i in range(3):
		var wave_progress := fposmod(
			progress + float(i) / 3.0,
			1.0
		)

		var radius := attack_range * wave_progress
		var alpha := 0.9 * (1.0 - wave_progress)

		if radius <= 0.0:
			continue

		draw_arc(
			Vector2.ZERO,
			radius,
			-half_angle,
			half_angle,
			32,
			Color(0.25, 0.9, 1.0, alpha),
			4.0,
			true
		)


# GENERAR EL POLÍGONO DEL ÁREA DEL RAYO
func get_hit_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()

	# Origen del ataque
	polygon.append(Vector2.ZERO)

	var half_angle := deg_to_rad(cone_angle) * 0.5
	var segments := 32

	for i in range(segments + 1):
		var angle := lerpf(
			-half_angle,
			half_angle,
			float(i) / float(segments)
		)

		polygon.append(
			Vector2.RIGHT.rotated(angle) * attack_range
		)

	return polygon
