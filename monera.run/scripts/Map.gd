# scripts/Map.gd
extends Node2D

const WALL_THICKNESS := 200.0   # grosor generoso para que nadie los atraviese

@onready var floor_sprite: Sprite2D = $Floor

func _ready() -> void:
	_build_walls(floor_sprite.region_rect.size)

func _build_walls(size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"

	# Capa 1: conserva las colisiones con jugadores
	# Capa 3: permite detectar las paredes con proyectiles
	body.collision_layer = 5

	add_child(body)


	var t := WALL_THICKNESS
	# Cada muro: [posición del centro, tamaño]
	var walls := [
		[Vector2(size.x / 2, -t / 2), Vector2(size.x + t * 2, t)],           # arriba
		[Vector2(size.x / 2, size.y + t / 2), Vector2(size.x + t * 2, t)],   # abajo
		[Vector2(-t / 2, size.y / 2), Vector2(t, size.y)],                   # izquierda
		[Vector2(size.x + t / 2, size.y / 2), Vector2(t, size.y)],           # derecha
	]
	for w in walls:
		var shape := RectangleShape2D.new()
		shape.size = w[1]
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = w[0]
		body.add_child(cs)
