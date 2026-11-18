# scripts/EvolutionVisual.gd
class_name EvolutionVisual extends Node2D

@export var body_shape: Shape2D        # forma de colisión del cuerpo
@export var body_offset := Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.play("idle")                # en bucle (con Loop activado en la animación)
