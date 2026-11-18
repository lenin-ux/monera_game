
extends Node

@export var cursor_texture: Texture2D = preload(
	"res://assets/sprites/armas/mira.png"
)

@export var hotspot: Vector2 = Vector2(64, 64)


func _ready() -> void:
	# Cursor normal
	Input.set_custom_mouse_cursor(
		cursor_texture,
		Input.CURSOR_ARROW,
		hotspot
	)

	# Cursor sobre botones
	Input.set_custom_mouse_cursor(
		cursor_texture,
		Input.CURSOR_POINTING_HAND,
		hotspot
	)

	# Cursor sobre campos de texto
	Input.set_custom_mouse_cursor(
		cursor_texture,
		Input.CURSOR_IBEAM,
		hotspot
	)
