class_name MoneraPlayer extends CharacterBody2D

@export var username: String = "" : set = _set_username

# CONFIGURACIÓN DEL PERSONAJE
@export_group("Personaje")
@export var character_id: StringName = &"nivel_1" : set = _set_character

# CONFIGURACIÓN DEL MOVIMIENTO
@export_group("Movimiento")
@export var speed: float = 200.0
@export var acceleration: float = 1400.0
@export var friction: float = 700.0
@export var current_health: int = 100 : set = _set_current_health


# SEÑAL DE ELIMINACIÓN
signal died(victim_id: int, killer_id: int)

# ESTADO DEL JUGADOR
@export var is_dead: bool = false : set = _set_is_dead

# PUNTOS (los utilizaremos en la siguiente etapa)
@export var points: int = 0

# Protección temporal al reaparecer
var invulnerable: bool = false

# REFERENCIAS A LOS NODOS
@onready var slot: Node2D = $VisualSlot
@onready var body_shape_node: CollisionShape2D = $CollisionShape2D

@onready var name_label: Label = $NameLabel

@onready var health_bar: TextureProgressBar = $HealthBar
# ESTADÍSTICAS ACTUALES
var max_health: int = 100


# ARMA EQUIPADA
@export var weapon_id: StringName = &"resortera" : set = _set_weapon

# DIRECCIÓN DEL ARMA
@export var aim_angle: float = 0.0 : set = _set_aim_angle

@onready var weapon_slot: Node2D = $WeaponSlot

var weapon_def: WeaponDef
var current_weapon: WeaponBase


# IDENTIFICACIÓN MULTIJUGADOR
var player_id: int = 0

# Dirección que recibe del servidor
var input_direction: Vector2 = Vector2.ZERO

@onready var player_camera: Camera2D = $Camera2D

# DATOS DEL PERSONAJE
var char_def: CharacterDef
var visual: EvolutionVisual

# EFECTOS DE MOVIMIENTO
var movement_multiplier: float = 1.0
var slow_end_time: int = 0

# GUARDAR LA CONFIGURACIÓN ORIGINAL DE COLISIONES
@onready var original_collision_layer: int = collision_layer
@onready var original_collision_mask: int = collision_mask


# EFECTO VISUAL AL RECIBIR DAÑO
@export_group("Efectos de daño")
@export var damage_flash_color: Color = Color(1.0, 0.3, 0.3)
@export_range(0.05, 1.0, 0.05)
var damage_flash_duration: float = 0.2

@onready var damage_visual: Node2D = $VisualSlot

var last_observed_health: float = -1.0
var damage_flash_tween: Tween
var original_visual_color: Color = Color.WHITE


func _ready() -> void:
	_apply_character()
	_apply_weapon()
	weapon_slot.rotation = aim_angle

	# Detectar si probamos Player individualmente
	var standalone_test := get_tree().current_scene == self

	# Solo el jugador local utiliza su cámara
	player_camera.enabled = (
		standalone_test
		or multiplayer.get_unique_id() == player_id
	)

	if player_camera.enabled:
		player_camera.make_current()

	# Actualizar el nombre de TODOS los jugadores
	update_name_label()
	update_dead_state()
	# Guardar el color original
	original_visual_color = damage_visual.modulate

	# Guardar la salud inicial
	last_observed_health = float(current_health)

# MOVIMIENTO DEL JUGADOR
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
		
	_update_slow_effect()
		
	# No mover jugadores eliminados
	if is_dead:
		return

	move_player(delta)


func move_player(delta: float) -> void:
	var target_velocity := (
	input_direction * speed * movement_multiplier
)

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(
			target_velocity,
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			friction * delta
		)

	move_and_slide()


# CAMBIAR EL PERSONAJE
func _set_character(v: StringName) -> void:
	character_id = v

	if is_node_ready():
		_apply_character()


# APLICAR LA EVOLUCIÓN


func _apply_character() -> void:
	var path := "res://data/characters/%s.tres" % character_id

	var new_def := load(path) as CharacterDef

	if new_def == null:
		push_error("No se pudo cargar: " + path)
		return

	if new_def.visual_scene == null:
		push_error("El personaje no tiene escena visual.")
		return

	var new_visual := new_def.visual_scene.instantiate() as EvolutionVisual

	if new_visual == null:
		push_error("Escena visual incorrecta.")
		return

	# ELIMINAR EVOLUCIÓN ANTERIOR
	if visual:
		slot.remove_child(visual)
		visual.queue_free()

	# GUARDAR NUEVA EVOLUCIÓN
	char_def = new_def
	visual = new_visual

	# INSTANCIAR APARIENCIA
	slot.add_child(visual)

	# ACTUALIZAR COLISIONES
	body_shape_node.set_deferred(
		"shape",
		visual.body_shape
	)

	body_shape_node.set_deferred(
		"position",
		visual.body_offset
	)

	# APLICAR ESTADÍSTICAS
	speed = char_def.movement_speed
	max_health = maxi(char_def.max_health, 1)

	# SOLO EL SERVIDOR RESTAURA LA SALUD
	if multiplayer.is_server():
		current_health = max_health

	# ACTUALIZAR INTERFAZ
	update_health_bar()

	print("Evolución: ", character_id)
	print("Vida máxima: ", max_health)
	print("Velocidad: ", speed)


# EVOLUCIONAR AL SIGUIENTE NIVEL
func evolve() -> void:
	if char_def == null:
		return

	if char_def.evolves_to != &"":
		character_id = char_def.evolves_to
		print("¡Evolución completada!")
	else:
		print("Evolución máxima alcanzada.")



# ASIGNAR NOMBRE
func _set_username(value: String) -> void:
	username = value

	if is_node_ready():
		update_name_label()


# ACTUALIZAR ETIQUETA
func update_name_label() -> void:
	if name_label == null:
		return

	if username.is_empty():
		name_label.text = "SIN NOMBRE"
	else:
		name_label.text = username

	name_label.show()

	print(
		"Jugador ", player_id,
		" muestra: ", name_label.text
	)
	
	
# ACTUALIZAR SALUD ACTUAL
func _set_current_health(value: int) -> void:
	current_health = maxi(value, 0)

	if is_node_ready():
		update_health_bar()


# ACTUALIZAR LA BARRA DE VIDA
func update_health_bar() -> void:
	if health_bar == null:
		return

	health_bar.max_value = max_health
	health_bar.value = clampi(
		current_health,
		0,
		max_health
	)


# RECIBIR DAÑO

# RECIBIR DAÑO
func take_damage(
	amount: int,
	attacker_id: int = 0
) -> void:
	# Solo el servidor administra la salud
	if not multiplayer.is_server():
		return

	# No recibir daño estando muerto o protegido
	if is_dead or invulnerable:
		return

	if amount <= 0:
		return

	# Restar salud
	current_health = maxi(0, current_health - amount)

	print(
		"Jugador ", player_id,
		" | Salud: ", current_health,
		"/", max_health
	)
	
	# REPRODUCIR SONIDO CUANDO SE APLICA DAÑO
	var audio := get_tree().current_scene.get_node_or_null(
	    "WorldAudio"
	) as WorldAudio

	if audio != null:
		audio.anunciar(
			"danio",
			global_position,
			player_id
		)

	# Detectar eliminación
	if current_health <= 0:
		die(attacker_id)


# ELIMINAR JUGADOR
func die(attacker_id: int) -> void:
	if not multiplayer.is_server():
		return

	if is_dead:
		return

	is_dead = true
	
	# Retirar el cuerpo físico después del procesamiento actual
	call_deferred("_remove_body_from_physics")
	
	# Detener completamente el movimiento
	input_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	
	movement_multiplier = 1.0
	slow_end_time = 0

	print("Jugador eliminado: ", player_id)

	# Avisar al mundo para gestionar la reaparición
	died.emit(player_id, attacker_id)


# CAMBIAR ARMA
func _set_weapon(value: StringName) -> void:
	weapon_id = value

	if is_node_ready():
		_apply_weapon()


# CARGAR ARMA EQUIPADA

func _apply_weapon() -> void:
	var path := "res://data/weapons/%s.tres" % weapon_id

	var new_def := load(path) as WeaponDef

	if new_def == null:
		push_error("No existe el arma: " + path)
		return

	if new_def.weapon_scene == null:
		push_error("El arma no tiene escena asignada.")
		return

	var new_weapon := new_def.weapon_scene.instantiate() as WeaponBase

	if new_weapon == null:
		push_error("La escena debe utilizar WeaponBase.")
		return

	# Verificar que el arma tenga Muzzle
	if new_weapon.get_node_or_null("Muzzle") == null:
		push_error("El arma no tiene el nodo Muzzle.")
		new_weapon.free()
		return

	# Eliminar arma anterior
	if is_instance_valid(current_weapon):
		weapon_slot.remove_child(current_weapon)
		current_weapon.queue_free()

	# Guardar nueva arma
	weapon_def = new_def
	current_weapon = new_weapon

	# Instanciar arma en WeaponSlot
	current_weapon.name = "EquippedWeapon"
	weapon_slot.add_child(current_weapon)

	# Aplicar dirección y volteo visual
	weapon_slot.rotation = aim_angle
	update_weapon_flip()

	print("Arma equipada: ", weapon_def.display_name)


# ROTAR ARMA

func _set_aim_angle(value: float) -> void:
	aim_angle = value

	if is_node_ready():
		weapon_slot.rotation = aim_angle
		update_weapon_flip()


# EVITAR QUE EL ARMA QUEDE DE CABEZA

func update_weapon_flip() -> void:
	if not is_instance_valid(current_weapon):
		return

	# Comprobar si apunta hacia la izquierda
	var facing_left := cos(aim_angle) < 0.0

	# Desactivar el volteo individual del sprite
	var sprite := current_weapon.get_node_or_null(
		"Sprite2D"
	) as Sprite2D

	if sprite != null:
		sprite.flip_v = false

	# Voltear el arma completa, incluyendo Muzzle
	var weapon_scale := current_weapon.scale

	weapon_scale.y = (
		-absf(weapon_scale.y)
		if facing_left
		else absf(weapon_scale.y)
	)

	current_weapon.scale = weapon_scale
	

# CAMBIAR ESTADO DE ELIMINACIÓN
func _set_is_dead(value: bool) -> void:
	is_dead = value

	if is_node_ready():
		update_dead_state()
		
		
# ACTUALIZAR ESTADO VISUAL Y FÍSICO
func update_dead_state() -> void:
	# APARIENCIA DEL JUGADOR
	$VisualSlot.visible = not is_dead
	$WeaponSlot.visible = not is_dead
	$NameLabel.visible = not is_dead
	$HealthBar.visible = not is_dead

	# SOLO EL SERVIDOR TIENE COLISIONES ACTIVAS
	# Y ÚNICAMENTE CUANDO EL JUGADOR ESTÁ VIVO
	var enable_collision: bool = (
		multiplayer.is_server() and not is_dead
	)

	var collider := $CollisionShape2D as CollisionShape2D

	if enable_collision:
		# Restaurar las capas originales
		set_deferred(
			"collision_layer",
			original_collision_layer
		)

		set_deferred(
			"collision_mask",
			original_collision_mask
		)

		collider.set_deferred("disabled", false)

	else:
		# Muertos y copias de clientes:
		# sin interacciones físicas
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)

		collider.set_deferred("disabled", true)

	if is_dead:
		velocity = Vector2.ZERO

# APLICAR RALENTIZACIÓN
func apply_slow(
	percentage: float,
	duration: float
) -> void:
	if not multiplayer.is_server():
		return

	if is_dead or duration <= 0.0:
		return

	var multiplier := clampf(
		1.0 - percentage,
		0.1,
		1.0
	)

	# No acumular ralentizaciones
	movement_multiplier = minf(
		movement_multiplier,
		multiplier
	)

	# Renovar la duración
	slow_end_time = maxi(
		slow_end_time,
		Time.get_ticks_msec() + roundi(duration * 1000.0)
	)

	print(
		"Jugador ", player_id,
		" ralentizado durante ", duration, " s"
	)


# RECUPERAR VELOCIDAD NORMAL
func _update_slow_effect() -> void:
	if movement_multiplier >= 1.0:
		return

	if Time.get_ticks_msec() >= slow_end_time:
		movement_multiplier = 1.0
		slow_end_time = 0


# SACAR AL JUGADOR MUERTO DEL MUNDO FÍSICO
func _remove_body_from_physics() -> void:
	if not multiplayer.is_server():
		return

	if not is_inside_tree() or not is_dead:
		return

	# Retirar completamente el cuerpo de la simulación
	PhysicsServer2D.body_set_space(
		get_rid(),
		RID()
	)

	print(
		"Jugador ", player_id,
		": cuerpo físico retirado"
	)


# DEVOLVER EL CUERPO FÍSICO, TODAVÍA DESACTIVADO
func restore_body_to_physics_while_dead() -> void:
	if not multiplayer.is_server():
		return

	if not is_inside_tree() or not is_dead:
		return

	# Devolverlo al mundo físico, pero todavía
	# sin colisión gracias a is_dead
	PhysicsServer2D.body_set_space(
		get_rid(),
		get_world_2d().space
	)

	print(
		"Jugador ", player_id,
		": cuerpo físico restaurado"
	)


# COMPROBAR SI EL JUGADOR RECIBIÓ DAÑO
func _check_damage_flash() -> void:
	var health_now: float = float(current_health)

	if last_observed_health < 0.0:
		last_observed_health = health_now
		return

	# Detectar una disminución de salud
	if health_now < last_observed_health and not is_dead:
		_play_damage_flash()

	# Guardar la salud actual para la siguiente comprobación
	last_observed_health = health_now

func _process(_delta: float) -> void:
	_check_damage_flash()
	
	
# REPRODUCIR DESTELLO ROJO
func _play_damage_flash() -> void:
	if not is_instance_valid(damage_visual):
		return

	# Detener un destello anterior si todavía existe
	if damage_flash_tween != null:
		if damage_flash_tween.is_valid():
			damage_flash_tween.kill()

	# Aplicar color rojo inmediatamente
	damage_visual.modulate = damage_flash_color

	# Recuperar suavemente el color original
	damage_flash_tween = create_tween()

	damage_flash_tween.tween_property(
		damage_visual,
		"modulate",
		original_visual_color,
		damage_flash_duration
	).set_trans(Tween.TRANS_SINE)
