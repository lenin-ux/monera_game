
extends TextureButton

@export_range(0.0, 1.0, 0.01)
var alpha_threshold: float = 0.1

@onready var animated: AnimatedSprite2D = $AnimatedSprite2D

# Guardar máscaras para no generarlas repetidamente
var mask_cache: Dictionary = {}


func _ready() -> void:
	# El TextureButton maneja los clics,
	# pero su imagen no se dibuja.
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	self_modulate.a = 0.0

	if animated.sprite_frames == null:
		push_error("Faltan los SpriteFrames del botón.")
		return

	if not animated.sprite_frames.has_animation(&"default"):
		push_error("Falta la animación idle.")
		return

	# Detectar cambios de animación
	animated.frame_changed.connect(_update_frame)
	animated.animation_changed.connect(_update_frame)

	# Ajustar el sprite al tamaño del botón
	resized.connect(_update_sprite_layout)

	# Eventos del cursor
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	animated.centered = true
	animated.play(&"default")

	_update_frame()


# ACTUALIZAR IMAGEN Y MÁSCARA
func _update_frame() -> void:
	var texture: Texture2D = animated.sprite_frames.get_frame_texture(
		animated.animation,
		animated.frame
	)

	if texture == null:
		return

	# Utilizar el fotograma actual como referencia
	texture_normal = texture

	var key := "%s_%d" % [
		animated.animation,
		animated.frame
	]

	# Crear máscara solamente la primera vez
	if not mask_cache.has(key):
		var image: Image = texture.get_image()

		if image == null:
			return

		if image.is_compressed():
			if image.decompress() != OK:
				push_error("No se pudo leer la imagen.")
				return

		var bitmap := BitMap.new()

		bitmap.create_from_image_alpha(
			image,
			alpha_threshold
		)

		mask_cache[key] = bitmap

	# Aplicar máscara según píxeles visibles
	texture_click_mask = mask_cache[key]

	_update_sprite_layout()


# AJUSTAR ANIMACIÓN AL TAMAÑO DEL BOTÓN
func _update_sprite_layout() -> void:
	if animated.sprite_frames == null:
		return

	var texture := animated.sprite_frames.get_frame_texture(
		animated.animation,
		animated.frame
	)

	if texture == null:
		return

	animated.position = size / 2.0

	animated.scale = Vector2(
		size.x / texture.get_width(),
		size.y / texture.get_height()
	)


# CURSOR ENCIMA

func _on_mouse_entered() -> void:
	if disabled:
		return

	change_animation(&"hover")


func _on_mouse_exited() -> void:
	change_animation(&"default")


# CAMBIAR ANIMACIÓN SIN REINICIAR FOTOGRAMAS
func change_animation(new_animation: StringName) -> void:
	if animated.animation == new_animation:
		return

	if not animated.sprite_frames.has_animation(new_animation):
		return

	# Guardar fotograma y progreso actual
	var current_frame := animated.frame
	var current_progress := animated.frame_progress

	# Cambiar animación
	animated.play(new_animation)

	# Restaurar el fotograma y su progreso
	animated.set_frame_and_progress(
		current_frame,
		current_progress
	)
