class_name BubbleExplosionVisual extends Node2D

var max_radius: float = 250.0
var duration: float = 0.35

var elapsed: float = 0.0


func _process(delta: float) -> void:
	elapsed += delta

	if elapsed >= duration:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var progress := clampf(
		elapsed / duration,
		0.0,
		1.0
	)

	var alpha := 1.0 - progress

	# ÁREA COMPLETA DE LA EXPLOSIÓN
	draw_circle(
		Vector2.ZERO,
		max_radius,
		Color(0.35, 0.85, 1.0, 0.16 * alpha)
	)

	# CONTORNO EXTERIOR
	draw_arc(
		Vector2.ZERO,
		max_radius,
		0.0,
		TAU,
		64,
		Color(0.5, 0.95, 1.0, 0.9 * alpha),
		6.0,
		true
	)

	# ONDA INTERIOR EXPANDIÉNDOSE
	var wave_radius := max_radius * (
		0.3 + 0.7 * progress
	)

	draw_arc(
		Vector2.ZERO,
		wave_radius,
		0.0,
		TAU,
		64,
		Color(0.8, 1.0, 1.0, 0.8 * alpha),
		4.0,
		true
	)
