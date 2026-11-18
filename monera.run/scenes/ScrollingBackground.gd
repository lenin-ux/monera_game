extends Sprite2D

@export var scroll_speed: float = 35.0

# Escala del patrón
@export_range(0.1, 2.0, 0.05)
var pattern_scale: float = 0.5


func _ready() -> void:
	centered = false
	region_enabled = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	# Reducir el tamaño de los cuadros
	scale = Vector2.ONE * pattern_scale

	ajustar_fondo()
	get_viewport().size_changed.connect(ajustar_fondo)


func _process(delta: float) -> void:
	if texture == null:
		return

	var region := region_rect

	region.position.x = fposmod(
		region.position.x + scroll_speed * delta / pattern_scale,
		float(texture.get_width())
	)

	region_rect = region


func ajustar_fondo() -> void:
	var region := region_rect

	# Compensar la escala para llenar la pantalla
	region.size = get_viewport_rect().size / pattern_scale

	region_rect = region
