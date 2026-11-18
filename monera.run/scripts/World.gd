
extends Node2D

# CONFIGURACIÓN DE RED
const PORT: int = 9080

# Cambiar por la IP de la VM cuando se despliegue
@export var server_ip: String = "127.0.0.1"


# CONFIGURACIÓN DE REAPARICIÓN
@export_group("Reaparición")

@export var respawn_delay: float = 2.0
@export var spawn_protection: float = 1.5


# SISTEMA DE PUNTUACIÓN
@export_group("Puntuación")

@export var points_per_elimination: int = 100


# Puntos de aparición dentro del mapa
@export var spawn_points: Array[Vector2] = [
	Vector2(1000, 1000),
	Vector2(2500, 1000),
	Vector2(1000, 2500),
	Vector2(2500, 2500)
]


# CONFIGURACIÓN DE NUTRIENTES
@export_group("Nutrientes")

@export var nutrient_one_scene: PackedScene
@export var nutrient_five_scene: PackedScene

@export_range(1, 200, 1) var max_nutrients: int = 35

@export_range(0.0, 1.0, 0.05) var five_points_chance: float = 0.20

@export var nutrient_spawn_rect: Rect2 = Rect2(
	200.0, 200.0, 3000.0, 3000.0
)

# Distancia mínima de aparición respecto a los bordes
@export_range(0.0, 1000.0, 10.0)
var nutrient_edge_margin: float = 200.0

@export var minimum_nutrient_spacing: float = 65.0
@export var minimum_player_distance: float = 180.0


# REFERENCIAS A NODOS
@onready var nutrients_root: Node2D = $Nutrients
@onready var nutrient_spawner: MultiplayerSpawner = $NutrientSpawner
@onready var nutrient_timer: Timer = $NutrientTimer


# Ajusta esta ruta a la ubicación de tu Player.tscn
const PLAYER_SCENE = preload("res://scenes/Player.tscn")

@onready var players: Node2D = $Players
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

# SISTEMA DE PROYECTILES
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner

@onready var points_label: Label = $HUD/PointsLabel

# Próximo momento en que cada jugador puede disparar
var next_shot_time: Dictionary = {}

# Usuarios registrados en el servidor
var users_by_peer: Dictionary = {}

var spawn_count: int = 0

# Control de envío de movimiento
var input_timer: float = 0.0
var last_direction: Vector2 = Vector2.ZERO

var aim_timer: float = 0.0


# UMBRALES DE EVOLUCIÓN
const EVOLUTION_THRESHOLDS := {
	2: 100,
	3: 500,
	4: 1000
}

@onready var evolution_hint: Label = $HUD/EvolutionHint


@export_group("Iconos de evolución")

@export var icon_cerbatana: Texture2D
@export var icon_cerbatana_pegajosa: Texture2D
@export var icon_alienigena: Texture2D
@export var icon_pompero: Texture2D
@export var icon_escopeta: Texture2D


# INTERFAZ DE EVOLUCIÓN
@onready var evolution_overlay: Control = $HUD/EvolutionOverlay

@onready var evolution_title: Label = $HUD/EvolutionOverlay/Center/DialogPanel/DialogContents/Title

@onready var evolution_level_label: Label = $HUD/EvolutionOverlay/Center/DialogPanel/DialogContents/LevelLabel


@onready var evolution_option_a: TextureButton = $HUD/EvolutionOverlay/Center/DialogPanel/DialogContents/Choices/OptionAContainer/OptionA

@onready var evolution_option_b: TextureButton = $HUD/EvolutionOverlay/Center/DialogPanel/DialogContents/Choices/OptionBContainer/OptionB

@onready var evolution_close_button: Button = $HUD/EvolutionOverlay/Center/DialogPanel/DialogContents/CloseButton


# MENÚ DE PAUSA LOCAL
@onready var pause_menu: PauseOverlay = $HUD/PauseMenu

var local_pause_open: bool = false

# Estado de pausa individual, controlado por el servidor
var paused_players: Dictionary = {}

# Evitar que la salida al menú se ejecute varias veces
var is_leaving_to_menu: bool = false

# Ajusta esta ruta a donde tengas MainMenu.tscn
const MAIN_MENU_SCENE: String = "res://scenes/MainMenu.tscn"

# ARMAS DISPONIBLES EN CADA EVOLUCIÓN
const EVOLUTION_CHOICES := {
	2: ["cerbatana", "cerbatana_pegajosa"],
	3: ["alienigena", "pompero"],
	4: ["escopeta"]
}


# ARMA ALIENÍGENA
const ALIEN_ATTACK_RANGE: float = 650.0
const ALIEN_CONE_ANGLE: float = 70.0
const ALIEN_SECOND_PULSE_DELAY: int = 500

# Pulsos pendientes de ejecutar
var pending_alien_pulses: Array[Dictionary] = []


# INFORMACIÓN MOSTRADA EN EL MENÚ
const WEAPON_INFO := {
	"cerbatana": {
		"name": "Cerbatana",
		"stats": "Daño: 30\nCadencia: 0.5 s\nVelocidad: 10000"
	},
	"cerbatana_pegajosa": {
		"name": "Cerbatana Pegajosa",
		"stats": "Daño: 25\nCadencia: 0.7 s\nRalentiza 25% por 1.5 s"
	},
	"alienigena": {
		"name": "Arma Alienígena",
		"stats": "Daño: 35 por pulso\nCadencia: 1 s\nOndas de corto alcance"
	},
	"pompero": {
		"name": "Pompero",
		"stats": "Daño en área: 35\nCadencia: 1.5 s\nVelocidad: 2500\nRadio: 250"
	},
	"escopeta": {
		"name": "Escopeta",
		"stats": "Daño: 25 x 3\nCadencia: 0.75 s\nDispersión: 12 grados"
	}
}


# NIVEL ACTUAL DEL JUGADOR
func _get_player_level(player: MoneraPlayer) -> int:
	match player.character_id:
		&"nivel_1":
			return 1
		&"nivel_2":
			return 2
		&"nivel_3":
			return 3
		&"nivel_4":
			return 4

	return 0


# COMPROBAR SI PUEDE EVOLUCIONAR
func _get_available_evolution(player: MoneraPlayer) -> int:
	if player == null or player.is_dead:
		return 0

	var next_level := _get_player_level(player) + 1

	if not EVOLUTION_THRESHOLDS.has(next_level):
		return 0

	if player.points < int(EVOLUTION_THRESHOLDS[next_level]):
		return 0

	return next_level


# CONTAR EVOLUCIONES PENDIENTES
func _count_pending_evolutions(player: MoneraPlayer) -> int:
	var current_level := _get_player_level(player)
	if current_level < 1 or current_level >= 4:
		return 0
	var pending := 0

	for level in range(current_level + 1, 5):
		if player.points >= int(EVOLUTION_THRESHOLDS[level]):
			pending += 1
		else:
			break

	return pending


# ACTUALIZAR INDICADOR
func _update_evolution_hint() -> void:
	var player := players.get_node_or_null(
		str(multiplayer.get_unique_id())
	) as MoneraPlayer

	if player == null or player.is_dead:
		evolution_hint.hide()

		if evolution_overlay.visible:
			_close_evolution_window()

		return

	if evolution_overlay.visible:
		if _get_available_evolution(player) == 0:
			_close_evolution_window()

	var pending := _count_pending_evolutions(player)

	evolution_hint.visible = pending > 0

	if pending == 1:
		evolution_hint.text = "E ¡Evolución disponible!"
	elif pending > 1:
		evolution_hint.text = (
			"E ¡%d evoluciones disponibles!" % pending
		)

func _ready() -> void:
	_generate_spawn_points()
	# SPAWNER DE JUGADORES
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_function = _instantiate_player

	# SPAWNER DE PROYECTILES (NUEVO)
	projectile_spawner.spawn_path = NodePath("../Projectiles")
	projectile_spawner.spawn_function = _instantiate_projectile
	
	# SPAWNER DE NUTRIENTES
	nutrient_spawner.spawn_path = NodePath("../Nutrients")
	nutrient_spawner.spawn_function = _instantiate_nutrient

	# TEMPORIZADOR DE NUTRIENTES
	nutrient_timer.timeout.connect(_maintain_nutrients)

	# SEÑALES DE CONEXIÓN
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	
	# BOTONES DE EVOLUCIÓN
	evolution_option_a.pressed.connect(_on_evolution_option_a)
	evolution_option_b.pressed.connect(_on_evolution_option_b)
	evolution_close_button.pressed.connect(_close_evolution_window)

	# INICIAR SERVIDOR O CLIENTE
	if _is_dedicated_server():
		_start_dedicated_server()
	else:
		_connect_to_dedicated_server()
		
	pause_menu.resume_requested.connect(
		_close_pause_menu
	)

	pause_menu.leave_requested.connect(
		_leave_to_main_menu
	)


# INICIAR SERVIDOR O CONECTARSE
func start_or_join() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_server(PORT)

	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Servidor iniciado en puerto ", PORT)

		# El host también participa como jugador
		call_deferred("_register_host_player")
	else:
		join_server()


# CONECTARSE COMO CLIENTE
func join_server() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var url := "ws://%s:%d" % [server_ip, PORT]

	var error := peer.create_client(url)

	if error != OK:
		push_error("No se pudo iniciar la conexión.")
		return

	multiplayer.multiplayer_peer = peer
	print("Conectando con ", url)


func _connected_to_server() -> void:
	print("Conectado. ID: ", multiplayer.get_unique_id())

	# Enviar el nombre escrito en el menú
	_register_username.rpc_id(1, Session.username)


func _connection_failed() -> void:
	push_error("No se pudo conectar con el servidor.")


# CUANDO ENTRA UN JUGADOR
func _peer_connected(id: int) -> void:
	if multiplayer.is_server():
		print("Nueva conexión: ", id)
		print("Esperando nombre de usuario...")


# CUANDO SALE UN JUGADOR
func _peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
		
	users_by_peer.erase(id)
	next_shot_time.erase(id)

	var player := players.get_node_or_null(str(id))
	
	
	# GUARDAR LOS PUNTOS SI SALE CON VIDA
	var departing_player := players.get_node_or_null(
		str(id)
	) as MoneraPlayer

	if departing_player != null:
		if not departing_player.is_dead:
			$ScoreService.save_result(
				departing_player.username,
				departing_player.points
			)

	if player != null:
		player.queue_free()
		users_by_peer.erase(id)

	print("Jugador desconectado: ", id)


# CREAR JUGADOR EN EL SERVIDOR
func _create_player(id: int) -> void:
	if not multiplayer.is_server():
		return

	# Evitar jugadores duplicados
	if players.has_node(str(id)):
		return

	# Verificar registro del usuario
	if not users_by_peer.has(id):
		return

	# Obtener punto de aparición
	var spawn_position := _get_next_spawn_position()

	# Crear personaje multijugador
	var player := spawner.spawn({
		"id": id,
		"position": spawn_position,
		"username": users_by_peer[id]["username"]
	}) as MoneraPlayer

	if player == null:
		push_error("No se pudo crear el jugador.")
		return

	# Escuchar cuando el personaje sea eliminado
	player.died.connect(_on_player_died)

	print("Jugador creado: ", id)



# INSTANCIAR EN TODOS LOS CLIENTES

func _instantiate_player(data: Variant) -> Node:
	var player := PLAYER_SCENE.instantiate()

	# Identificación del jugador
	player.name = str(data["id"])
	player.set("player_id", int(data["id"]))

	# Posición inicial
	player.position = data["position"]

	# Nombre de usuario
	player.set("username", str(data["username"]))

	print(
		"Jugador creado: ",
		data["id"],
		" | Nombre: ",
		data["username"]
	)

	return player


# LEER CONTROLES LOCALES


func _physics_process(delta: float) -> void:
	var peer := multiplayer.multiplayer_peer
	
	# Procesar ataques especiales pendientes
	if multiplayer.is_server():
		_process_pending_alien_pulses()

	if peer == null:
		return

	if peer.get_connection_status() != \
			MultiplayerPeer.CONNECTION_CONNECTED:
		return

	var direction := Input.get_vector(
		"mover_izquierda",
		"mover_derecha",
		"mover_arriba",
		"mover_abajo"
	)
	
	if local_pause_open:
		direction = Vector2.ZERO

	# MOVIMIENTO
	if multiplayer.is_server():
		_apply_direction(1, direction)
	else:
		input_timer += delta

		if input_timer >= 0.05 or direction != last_direction:
			input_timer = 0.0
			last_direction = direction
			_receive_direction.rpc_id(1, direction)

	# ABRIR O CERRAR VENTANA DE EVOLUCIÓN
	if Input.is_action_just_pressed("evolucionar"):
		_toggle_evolution_window()

	# DAÑO DE PRUEBA
	if Input.is_action_just_pressed("dano_prueba"):
		if multiplayer.is_server():
			_apply_test_damage(1)
		else:
			_request_test_damage.rpc_id(1)

	# ACTUALIZAR DIRECCIÓN DEL ARMA
	_update_local_aim(delta)
	
	# DISPARAR CON CLIC IZQUIERDO
	if not evolution_overlay.visible and Input.is_action_just_pressed("disparar"):
		if multiplayer.is_server():
			_try_shoot(1)
		else:
			_request_shoot.rpc_id(1)

# RECIBIR MOVIMIENTO DE UN CLIENTE
@rpc("any_peer", "call_remote", "reliable")
func _receive_direction(direction: Vector2) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	
	# BLOQUEAR MOVIMIENTO SI ESTÁ EN PAUSA
	if paused_players.get(sender_id, false):
		return

	_apply_direction(sender_id, direction)


# APLICAR MOVIMIENTO EN EL SERVIDOR

func _apply_direction(id: int, direction: Vector2) -> void:
	var player := players.get_node_or_null(str(id))

	if player == null:
		return

	# Evitar que los jugadores muertos se muevan
	if player.is_dead:
		return

	player.set("input_direction", direction.limit_length(1.0))


# RECIBIR SOLICITUD DE EVOLUCIÓN
@rpc("any_peer", "call_remote", "reliable")


# REGISTRAR AL JUGADOR ANFITRIÓN
func _register_host_player() -> void:
	if multiplayer.is_server():
		_save_player_registration(1, Session.username)


# RECIBIR NOMBRE DESDE UN CLIENTE
@rpc("any_peer", "call_remote", "reliable")
func _register_username(requested_name: String) -> void:
	if not multiplayer.is_server():
		return

	# Identificador real del cliente que envió la solicitud
	var id := multiplayer.get_remote_sender_id()

	_save_player_registration(id, requested_name)


# GUARDAR INFORMACIÓN DEL USUARIO
func _save_player_registration(id: int, requested_name: String) -> void:
	if not multiplayer.is_server():
		return

	# Evitar registros duplicados
	if users_by_peer.has(id):
		return

	var clean_name := requested_name.strip_edges().substr(0, 16)

	if clean_name.is_empty():
		clean_name = "Jugador%d" % id

	# Dirección observada por el servidor
	var ip := "127.0.0.1"

	if id != 1:
		var socket := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer

		if socket != null:
			ip = socket.get_peer_address(id)

	# Guardar información
	users_by_peer[id] = {
		"username": clean_name,
		"ip": ip
	}

	print("Usuario registrado: ", clean_name)
	print("ID: ", id)
	print("IP: ", ip)

	# Crear al jugador después del registro
	_create_player(id)


# SOLICITAR DAÑO DE PRUEBA
@rpc("any_peer", "call_remote", "reliable")
func _request_test_damage() -> void:
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()

	_apply_test_damage(id)


# APLICAR DAÑO AL JUGADOR
func _apply_test_damage(id: int) -> void:
	var player := players.get_node_or_null(str(id))

	if player == null:
		return

	player.call("take_damage", 20)


# LEER LA DIRECCIÓN DEL MOUSE LOCAL
func _update_local_aim(delta: float) -> void:
	var id := multiplayer.get_unique_id()
	var player := players.get_node_or_null(str(id)) as Node2D

	if player == null:
		return

	var direction := (
		player.get_global_mouse_position()
		- player.global_position
	)

	if direction.length_squared() < 1.0:
		return

	var angle := direction.angle()

	if multiplayer.is_server():
		_apply_aim(1, angle)
	else:
		aim_timer += delta

		if aim_timer >= 0.05:
			aim_timer = 0.0
			_send_aim.rpc_id(1, angle)


# RECIBIR DIRECCIÓN DEL CLIENTE
@rpc("any_peer", "call_remote", "unreliable")
func _send_aim(angle: float) -> void:
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()
	_apply_aim(id, angle)


# APLICAR DIRECCIÓN EN EL SERVIDOR
func _apply_aim(id: int, angle: float) -> void:
	if not multiplayer.is_server():
		return

	if not is_finite(angle):
		return

	var player := players.get_node_or_null(str(id))

	if player == null:
		return

	player.set("aim_angle", wrapf(angle, -PI, PI))


# INSTANCIAR PROYECTILES EN TODOS LOS CLIENTES
func _instantiate_projectile(data: Variant) -> Node:
	# Cargar la escena del proyectil
	var scene := load(
		str(data["scene_path"])
	) as PackedScene

	if scene == null:
		push_error("No se pudo cargar la escena del proyectil.")
		return null

	# Crear una instancia
	var projectile := scene.instantiate() as Projectile

	if projectile == null:
		push_error("La escena debe utilizar Projectile.gd")
		return null

	# Establecer posición inicial
	projectile.position = data["position"]

	# Configurar características del disparo
	
	projectile.setup(
		data["direction"],
		float(data["speed"]),
		int(data["damage"]),
		int(data["shooter_id"]),
		float(data["max_range"]),
		float(data["slow_fraction"]),
		float(data["slow_duration"])
	)
	
	
	# Conectar explosión si es una burbuja
	if projectile is BubbleProjectile:
		var bubble := projectile as BubbleProjectile

		bubble.exploded.connect(
			_on_bubble_exploded
	 )

	return projectile


# SOLICITUD DE DISPARO DESDE CLIENTE
@rpc("any_peer", "call_remote", "reliable")
func _request_shoot() -> void:
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()

	_try_shoot(id)


# CREAR DISPAROS EN EL SERVIDOR


func _try_shoot(id: int) -> void:
	if not multiplayer.is_server():
		return

	var player := players.get_node_or_null(str(id))

	if player == null:
		return
		
	# Un jugador con el menú abierto no puede disparar
	if paused_players.get(id, false):
		return
		
	# Evitar disparos mientras está muerto
	if bool(player.get("is_dead")):
		return

	# Obtener arma equipada
	var weapon_data := player.get("weapon_def") as WeaponDef
	var weapon_instance := player.get("current_weapon") as WeaponBase

	if weapon_data == null or weapon_instance == null:
		return
	
	# ARMA ALIENÍGENA: ATAQUE ESPECIAL SIN PROYECTIL
	if weapon_data.id == &"alienigena":
		_try_shoot_alien(id, weapon_data)
		return

	if weapon_data.projectile_scene == null:
		push_warning("El arma no tiene proyectil asignado.")
		return

	# VERIFICAR CADENCIA DE DISPARO
	var now: int = Time.get_ticks_msec()
	var next_time: int = int(next_shot_time.get(id, 0))

	if now < next_time:
		return

	var cooldown_ms := maxi(
		1,
		roundi(weapon_data.fire_interval * 1000.0)
	)

	next_shot_time[id] = now + cooldown_ms

	# DIRECCIÓN Y ORIGEN DEL DISPARO
	var angle: float = player.get("aim_angle")
	var direction := Vector2.RIGHT.rotated(angle)

	var spawn_position: Vector2 = (
		weapon_instance.get_muzzle_position()
	)

	# Obtener direcciones de los proyectiles
	var directions := weapon_instance.get_shot_directions(
		direction
	)
	
	
	# SONIDO DEL DISPARO CONFIRMADO
	var tipo_sonido: String = "proyectil"

	if str(player.weapon_id) == "escopeta":
		tipo_sonido = "escopeta"

	$WorldAudio.anunciar(
		tipo_sonido,
		player.global_position,
		id
	)


	# CREAR PROYECTILES
	for shot_direction in directions:
		if shot_direction.is_zero_approx():
			continue

		
		projectile_spawner.spawn({
			"scene_path": weapon_data.projectile_scene.resource_path,
			"position": spawn_position,
			"direction": shot_direction.normalized(),
			"speed": weapon_data.projectile_speed,
			"damage": weapon_data.damage,
			"shooter_id": id,
			"max_range": weapon_data.projectile_range,
			"slow_fraction": weapon_data.slow_fraction,
			"slow_duration": weapon_data.slow_duration
		})



# OBTENER SIGUIENTE PUNTO DE APARICIÓN
func _get_next_spawn_position() -> Vector2:
	if spawn_points.is_empty():
		return Vector2.ZERO

	var index := spawn_count % spawn_points.size()
	var next_position: Vector2 = spawn_points[index]

	spawn_count += 1

	return next_position


# CUANDO UN JUGADOR ES ELIMINADO


# GESTIONAR ELIMINACIÓN Y REAPARICIÓN
func _on_player_died(
	victim_id: int,
	killer_id: int
) -> void:
	if not multiplayer.is_server():
		return

	print("================================")
	print("Jugador eliminado: ", victim_id)
	print("Eliminado por: ", killer_id)
	print("================================")
	
	
	# GUARDAR LA PUNTUACIÓN ANTES DE TRANSFERIRLA
	var defeated_player := players.get_node_or_null(
		str(victim_id)
	) as MoneraPlayer

	if defeated_player != null:
		$ScoreService.save_result(
			defeated_player.username,
			defeated_player.points
		)


	# TRANSFERIR PUNTOS DE LA VÍCTIMA
	_award_elimination_points(victim_id, killer_id)
	
	
	# REGISTRAR LA ELIMINACIÓN EN EL KILL FEED

	# Evitar mostrar muertes sin asesino válido
	if killer_id > 0 and killer_id != victim_id:

		var killer := players.get_node_or_null(
			str(killer_id)
		) as MoneraPlayer

		var victim := players.get_node_or_null(
			str(victim_id)
		) as MoneraPlayer

		if killer != null and victim != null:

			var killer_name: String = (
				killer.username.strip_edges()
			)

			var victim_name: String = (
				victim.username.strip_edges()
			)

			# NOMBRES ALTERNATIVOS
			if killer_name.is_empty():
				killer_name = "Jugador %d" % killer_id

			if victim_name.is_empty():
				victim_name = "Jugador %d" % victim_id

			# ENVIAR MENSAJE A TODAS LAS VENTANAS
			_show_kill_feed.rpc(
				killer_name,
				victim_name
			)


	# ESPERAR EL TIEMPO DE REAPARICIÓN
	await get_tree().create_timer(respawn_delay).timeout

	if not is_inside_tree():
		return

	if not users_by_peer.has(victim_id):
		return

	var player := players.get_node_or_null(
		str(victim_id)
	) as MoneraPlayer

	if player == null or not player.is_dead:
		return

	# PREPARAR AL JUGADOR
	player.invulnerable = true

	player.velocity = Vector2.ZERO
	player.input_direction = Vector2.ZERO

	# RESTAURAR PERSONAJE Y ARMA INICIALES
	player.character_id = &"nivel_1"
	player.weapon_id = &"resortera"

	# RESTAURAR ESTADÍSTICAS
	player.points = 0
	player.current_health = player.max_health

	# BUSCAR UN PUNTO DE REAPARICIÓN LIBRE
	var safe_position: Variant = null

	while safe_position == null:
		await get_tree().physics_frame

		if not is_inside_tree():
			return

		if not users_by_peer.has(victim_id):
			return

		player = players.get_node_or_null(
			str(victim_id)
		) as MoneraPlayer

		if player == null or not player.is_dead:
			return

		safe_position = _find_free_respawn_position(
			player
		)

		if safe_position == null:
			await get_tree().create_timer(0.25).timeout

	# MOVER AL JUGADOR A SU NUEVA POSICIÓN
	# SIN REACTIVAR TODAVÍA SU COLISIÓN
	player.position = safe_position
	player.velocity = Vector2.ZERO
	player.input_direction = Vector2.ZERO

	# REINICIAR INTERPOLACIÓN
	player.reset_physics_interpolation()

	# PERMITIR ACTUALIZAR LA TRANSFORMACIÓN
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	player = players.get_node_or_null(
		str(victim_id)
	) as MoneraPlayer

	if player == null or not player.is_dead:
		return

	# DEVOLVER EL CUERPO AL MUNDO FÍSICO,
	# PERO MANTENER LA COLISIÓN DESACTIVADA
	player.restore_body_to_physics_while_dead()

	# SINCRONIZAR LA POSICIÓN DEL CUERPO FÍSICO
	PhysicsServer2D.body_set_state(
		player.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		player.global_transform
	)

	# ESPERAR DOS ACTUALIZACIONES FÍSICAS
	# ANTES DE ACTIVAR LA COLISIÓN
	await get_tree().physics_frame
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	if not users_by_peer.has(victim_id):
		return

	player = players.get_node_or_null(
		str(victim_id)
	) as MoneraPlayer

	if player == null or not player.is_dead:
		return

	# REAPARECER Y ACTIVAR SU COLISIÓN
	player.is_dead = false

	print(
		"Jugador ", victim_id,
		" reapareció en: ", player.global_position
	)

	# PROTECCIÓN TEMPORAL AL REAPARECER
	await get_tree().create_timer(
		spawn_protection
	).timeout

	if not is_inside_tree():
		return

	player = players.get_node_or_null(
		str(victim_id)
	) as MoneraPlayer

	if player != null and not player.is_dead:
		player.invulnerable = false

		print(
			"Protección terminada: ", victim_id
		)
		

# BUSCAR UN PUNTO DE REAPARICIÓN LIBRE
func _find_free_respawn_position(
	player: MoneraPlayer
) -> Variant:
	if not multiplayer.is_server():
		return null

	if player == null:
		return null

	if spawn_points.is_empty():
		push_warning("No hay puntos de reaparición.")
		return null

	# Obtener la colisión real del personaje
	var collider := player.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D

	if collider == null or collider.shape == null:
		push_warning("El jugador no tiene colisión válida.")
		return null

	var parent_node := player.get_parent() as Node2D

	if parent_node == null:
		return null

	# Preparar consulta física
	var query := PhysicsShapeQueryParameters2D.new()

	query.shape = collider.shape
	query.margin = 8.0

	# Capas 1 (jugadores) y 3 (paredes)
	query.collision_mask = 5

	query.collide_with_bodies = true
	query.collide_with_areas = false

	# Ignorar al propio jugador
	query.exclude = [player.get_rid()]

	var space_state := get_world_2d().direct_space_state

	# Recorrer los puntos disponibles
	var start_index: int = (
		spawn_count % spawn_points.size()
	)

	for i in range(spawn_points.size()):
		var index: int = (
			start_index + i
		) % spawn_points.size()

		var candidate: Vector2 = spawn_points[index]

		# Calcular dónde quedaría la colisión
		# sin mover realmente al jugador
		var proposed_transform := player.global_transform

		proposed_transform.origin = (
			parent_node.to_global(candidate)
		)

		query.transform = (
			proposed_transform * collider.transform
		)

		# Comprobar si existe alguna colisión
		var collisions := space_state.intersect_shape(
			query,
			1
		)

		if collisions.is_empty():
			# Encontramos un lugar libre
			spawn_count = index + 1

			return candidate

	# Todos los puntos están ocupados
	return null

# TRANSFERIR PUNTOS AL ELIMINAR UN JUGADOR
func _award_elimination_points(
	victim_id: int,
	killer_id: int
) -> void:
	if not multiplayer.is_server():
		return

	# Buscar al jugador eliminado
	var victim := players.get_node_or_null(
		str(victim_id)
	) as MoneraPlayer

	if victim == null:
		return

	# Guardar sus puntos antes de reiniciarlos
	var stolen_points: int = victim.points

	# El jugador eliminado pierde todos sus puntos
	victim.points = 0

	# Evitar recompensas por daño de prueba
	# o eliminaciones propias
	if killer_id <= 0 or killer_id == victim_id:
		return

	# Buscar al jugador que consiguió la eliminación
	var killer := players.get_node_or_null(
		str(killer_id)
	) as MoneraPlayer

	if killer == null:
		return

	# Transferir los puntos de la víctima
	killer.points += stolen_points

	print(
		"Jugador ", killer_id,
		" eliminó a ", victim_id
	)

	print("Puntos robados: +", stolen_points)
	print("Puntuación total: ", killer.points)


# ACTUALIZAR PUNTUACIÓN DEL JUGADOR LOCAL
func _process(_delta: float) -> void:
	_update_evolution_hint()
	# Obtener el identificador de esta ventana
	var local_id := multiplayer.get_unique_id()

	# Buscar el personaje correspondiente
	var player := players.get_node_or_null(
		str(local_id)
	) as MoneraPlayer

	if player == null:
		points_label.text = "Puntos: 0"
		return

	# Mostrar puntos del jugador local
	points_label.text = "Puntos: %d" % player.points


# MANTENER NUTRIENTES EN EL MAPA
func _maintain_nutrients() -> void:
	if not multiplayer.is_server():
		return

	# Comprobar que el servidor esté conectado
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	# Verificar escenas configuradas
	if nutrient_one_scene == null or nutrient_five_scene == null:
		return

	# Calcular cuántos nutrientes faltan
	var missing: int = maxi(
		0,
		max_nutrients - nutrients_root.get_child_count()
	)

	for i in range(missing):
		# Elegir tipo de nutriente
		var scene: PackedScene

		if randf() < five_points_chance:
			scene = nutrient_five_scene
		else:
			scene = nutrient_one_scene

		# Encontrar un lugar disponible
		var spawn_position: Variant = _find_nutrient_position()

		if spawn_position == null:
			break

		# Crear nutriente en todos los jugadores
		nutrient_spawner.spawn({
			"scene_path": scene.resource_path,
			"position": spawn_position
		})


# ELEGIR UNA POSICIÓN DISPONIBLE

# ELEGIR UNA POSICIÓN SEGURA PARA UN NUTRIENTE
func _find_nutrient_position() -> Variant:

	# Verificar que el margen no sea demasiado grande
	if nutrient_spawn_rect.size.x <= nutrient_edge_margin * 2.0:
		return null

	if nutrient_spawn_rect.size.y <= nutrient_edge_margin * 2.0:
		return null

	# Reducir el área de aparición por los cuatro lados
	var safe_area := nutrient_spawn_rect.grow(
		-nutrient_edge_margin
	)

	# Buscar una posición disponible
	for attempt in range(30):

		# Posición aleatoria dentro de la zona segura
		var pos := Vector2(
			randf_range(
				safe_area.position.x,
				safe_area.end.x
			),
			randf_range(
				safe_area.position.y,
				safe_area.end.y
			)
		)

		var free_space := true

		# Evitar nutrientes demasiado juntos
		for nutrient in nutrients_root.get_children():
			var other := nutrient as Node2D

			if other == null:
				continue

			if pos.distance_to(other.position) < minimum_nutrient_spacing:
				free_space = false
				break

		if not free_space:
			continue

		# Evitar apariciones demasiado cerca de jugadores
		for player_node in players.get_children():
			var player := player_node as MoneraPlayer

			if player == null or player.is_dead:
				continue

			if pos.distance_to(player.position) < minimum_player_distance:
				free_space = false
				break

		if free_space:
			return pos

	# No se encontró una posición disponible
	return null


# CREAR NUTRIENTE EN TODAS LAS INSTANCIAS
func _instantiate_nutrient(data: Variant) -> Node:
	var scene := load(
		str(data["scene_path"])
	) as PackedScene

	if scene == null:
		push_error("No se pudo cargar la escena del nutriente.")
		return null

	var nutrient := scene.instantiate() as Nutrient

	if nutrient == null:
		push_error("La escena debe utilizar Nutrient.gd")
		return null

	# Posición recibida del servidor
	nutrient.position = data["position"]

	return nutrient


# OBTENER ICONO DEL ARMA
func _get_weapon_icon(weapon_id: StringName) -> Texture2D:
	match weapon_id:
		&"cerbatana":
			return icon_cerbatana
		&"cerbatana_pegajosa":
			return icon_cerbatana_pegajosa
		&"alienigena":
			return icon_alienigena
		&"pompero":
			return icon_pompero
		&"escopeta":
			return icon_escopeta

	return null


# RELLENAR UNA TARJETA DE ARMA

# CONFIGURAR LA OPCIÓN DE ARMA
func _setup_weapon_option(
	button: TextureButton,
	weapon_id: StringName
) -> void:

	var info: Dictionary = WEAPON_INFO.get(
		String(weapon_id), {}
	)

	# Obtener la imagen correspondiente al arma
	var weapon_texture: Texture2D = _get_weapon_icon(
		weapon_id
	)

	# UTILIZAR EL SPRITE COMO BOTÓN
	button.texture_normal = weapon_texture

	button.ignore_texture_size = true

	button.stretch_mode = (
		TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	)

	button.custom_minimum_size = Vector2(230, 110)

	# PERMITIR CLIC SOLO EN PÍXELES VISIBLES
	if weapon_texture != null:
		var image := weapon_texture.get_image()

		if image != null:
			var mask := BitMap.new()
			mask.create_from_image_alpha(image, 0.15)
			button.texture_click_mask = mask
		else:
			button.texture_click_mask = null
	else:
		button.texture_click_mask = null

	# Obtener contenedor del botón
	var container := button.get_parent()

	# Obtener las etiquetas debajo del arma
	var name_label := container.get_node(
		"WeaponName"
	) as Label

	var stats_label := container.get_node(
		"Stats"
	) as Label

	# Actualizar textos
	name_label.text = str(
		info.get("name", String(weapon_id))
	)

	stats_label.text = str(
		info.get("stats", "")
	)

	stats_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	# Mostrar la opción
	container.show()
	button.show()


# ACTUALIZAR CONTENIDO DE LA VENTANA
func _refresh_evolution_window() -> void:
	var player := players.get_node_or_null(
		str(multiplayer.get_unique_id())
	) as MoneraPlayer

	if player == null:
		return

	var next_level := _get_available_evolution(player)

	if next_level == 0:
		_close_evolution_window()
		return

	evolution_title.text = "SELECCIONA TU PRÓXIMA ARMA"

	evolution_level_label.text = (
		"Evolución al nivel %d" % next_level
	)

	var choices: Array = EVOLUTION_CHOICES[next_level]

	_setup_weapon_option(
		evolution_option_a,
		StringName(choices[0])
	)

	if choices.size() > 1:
		_setup_weapon_option(
			evolution_option_b,
			StringName(choices[1])
		)
	else:
		evolution_option_b.get_parent().hide()


# ABRIR O CERRAR VENTANA CON E
func _toggle_evolution_window() -> void:
	if evolution_overlay.visible:
		_close_evolution_window()
		return

	var player := players.get_node_or_null(
		str(multiplayer.get_unique_id())
	) as MoneraPlayer

	if player == null:
		return

	if _get_available_evolution(player) == 0:
		return

	_refresh_evolution_window()
	evolution_overlay.show()


# CERRAR VENTANA
func _close_evolution_window() -> void:
	evolution_overlay.hide()


# CLIC EN LA PRIMERA OPCIÓN
func _on_evolution_option_a() -> void:
	_choose_evolution_option(0)


# CLIC EN LA SEGUNDA OPCIÓN
func _on_evolution_option_b() -> void:
	_choose_evolution_option(1)


# SOLICITAR EL ARMA SELECCIONADA
func _choose_evolution_option(option_index: int) -> void:
	if not evolution_overlay.visible:
		return

	var player := players.get_node_or_null(
		str(multiplayer.get_unique_id())
	) as MoneraPlayer

	if player == null:
		return

	var next_level := _get_available_evolution(player)

	if next_level == 0:
		return

	var choices: Array = EVOLUTION_CHOICES[next_level]

	if option_index < 0 or option_index >= choices.size():
		return

	var weapon_id := StringName(choices[option_index])

	# Servidor local
	if multiplayer.is_server():
		_server_choose_evolution(1, weapon_id)
	else:
		# Solicitar al servidor
		_request_evolution_choice.rpc_id(
			1, String(weapon_id)
		)


# RECIBIR ELECCIÓN DESDE UN CLIENTE
@rpc("any_peer", "call_remote", "reliable")
func _request_evolution_choice(weapon_id: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()

	_server_choose_evolution(
		sender_id,
		StringName(weapon_id)
	)


# VALIDAR Y APLICAR EVOLUCIÓN
func _server_choose_evolution(
	player_id: int,
	weapon_id: StringName
) -> void:
	if not multiplayer.is_server():
		return

	var player := players.get_node_or_null(
		str(player_id)
	) as MoneraPlayer

	if player == null or player.is_dead:
		return

	# Calcular el siguiente nivel desde el servidor
	var next_level := _get_available_evolution(player)

	if next_level == 0:
		return

	# Comprobar que el arma pertenece al nivel
	var valid_choices: Array = EVOLUTION_CHOICES[next_level]

	if not valid_choices.has(String(weapon_id)):
		push_warning("Elección de arma no permitida.")
		return

	# Verificar que existe el recurso del arma
	var weapon_path := (
		"res://data/weapons/%s.tres" % String(weapon_id)
	)

	if not ResourceLoader.exists(weapon_path):
		push_warning("Falta configurar el arma: " + weapon_path)
		return

	var weapon_data := load(weapon_path) as WeaponDef

	if weapon_data == null or weapon_data.weapon_scene == null:
		push_warning("El arma no tiene una escena válida.")
		return

	# Verificar que existe el siguiente personaje
	var character_path := (
		"res://data/characters/nivel_%d.tres" % next_level
	)

	if not ResourceLoader.exists(character_path):
		push_warning("Falta la evolución: " + character_path)
		return

	var character_data := load(character_path) as CharacterDef

	if character_data == null or character_data.visual_scene == null:
		push_warning("La evolución no tiene escena visual.")
		return

	# APLICAR EVOLUCIÓN
	player.character_id = StringName(
		"nivel_%d" % next_level
	)

	player.weapon_id = weapon_id
	
	
	# SONIDO DE EVOLUCIÓN
	$WorldAudio.anunciar(
		"level_up",
		player.global_position,
		player.player_id
	)

	print(
		"Jugador ", player_id,
		" evolucionó al nivel ", next_level,
		" con ", weapon_data.display_name
	)

	# Cerrar el menú del jugador correspondiente
	if player_id == multiplayer.get_unique_id():
		_close_evolution_window()
	else:
		_confirm_evolution_choice.rpc_id(player_id)


# CONFIRMACIÓN EN EL CLIENTE
@rpc("authority", "call_remote", "reliable")
func _confirm_evolution_choice() -> void:
	_close_evolution_window()


# DISPARAR ARMA ALIENÍGENA
func _try_shoot_alien(
	id: int,
	weapon_data: WeaponDef
) -> void:
	if not multiplayer.is_server():
		return

	# Comprobar cadencia
	var now: int = Time.get_ticks_msec()
	var next_time: int = int(next_shot_time.get(id, 0))

	if now < next_time:
		return

	var cooldown_ms: int = maxi(
		1,
		roundi(weapon_data.fire_interval * 1000.0)
	)

	next_shot_time[id] = now + cooldown_ms

	# Mostrar las ondas en todos los jugadores
	_play_alien_wave.rpc(id)
	
	
	# OBTENER AL JUGADOR QUE DISPARÓ
	var attacker := players.get_node_or_null(
		str(id)
	) as MoneraPlayer

	# REPRODUCIR SONIDO DEL LÁSER
	if attacker != null:
		$WorldAudio.anunciar(
			"lazer",
			attacker.global_position,
			id
		)


	# Primer pulso: inmediatamente
	_apply_alien_damage_pulse(id)

	# Programar el segundo pulso
	pending_alien_pulses.append({
		"player_id": id,
		"execute_at": now + ALIEN_SECOND_PULSE_DELAY
	})

	print("Jugador ", id, " disparó el Arma Alienígena")
	
	
# REPRODUCIR ONDA EN TODAS LAS VENTANAS
@rpc("authority", "call_local", "reliable")
func _play_alien_wave(player_id: int) -> void:
	var player := players.get_node_or_null(
		str(player_id)
	) as MoneraPlayer

	if player == null:
		return

	var weapon := player.current_weapon as WeaponBase

	if weapon == null:
		return

	# Buscar efecto visual dentro del arma
	var wave := weapon.get_node_or_null(
		"Muzzle/AlienWaveVisual"
	) as AlienWaveVisual

	if wave == null:
		push_warning("No se encontró AlienWaveVisual.")
		return

	# Activar la animación
	wave.play_wave()


# EJECUTAR PULSOS PENDIENTES
func _process_pending_alien_pulses() -> void:
	if not multiplayer.is_server():
		return

	var now: int = Time.get_ticks_msec()

	# Recorrer de atrás hacia delante
	for i in range(
		pending_alien_pulses.size() - 1,
		-1,
		-1
	):
		var pulse: Dictionary = pending_alien_pulses[i]

		if now < int(pulse["execute_at"]):
			continue

		var player_id: int = int(pulse["player_id"])

		# Retirar el pulso de la lista
		pending_alien_pulses.remove_at(i)

		# Aplicar segundo pulso
		_apply_alien_damage_pulse(player_id)


# APLICAR DAÑO DEL ARMA ALIENÍGENA

# APLICAR DAÑO DEL ARMA ALIENÍGENA
func _apply_alien_damage_pulse(shooter_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Buscar jugador que disparó
	var shooter := players.get_node_or_null(
		str(shooter_id)
	) as MoneraPlayer

	if shooter == null or shooter.is_dead:
		return

	# Comprobar que sigue usando el arma
	if shooter.weapon_id != &"alienigena":
		return

	var weapon := shooter.current_weapon as WeaponBase
	var weapon_data := shooter.weapon_def

	if weapon == null or weapon_data == null:
		return

	# Obtener el efecto visual
	var wave_visual := weapon.get_node_or_null(
		"Muzzle/AlienWaveVisual"
	) as AlienWaveVisual

	if wave_visual == null:
		push_warning("No se encontró AlienWaveVisual.")
		return

	# OBTENER EXACTAMENTE EL MISMO POLÍGONO
	# QUE SE DIBUJA EN PANTALLA
	var local_points := wave_visual.get_hit_polygon()

	# Transformarlo a coordenadas globales
	var world_points := PackedVector2Array()

	for point in local_points:
		world_points.append(
			wave_visual.to_global(point)
		)

	# Crear forma física con los puntos reales
	var cone_shape := ConvexPolygonShape2D.new()
	cone_shape.points = world_points

	# CONFIGURAR CONSULTA
	var query := PhysicsShapeQueryParameters2D.new()

	query.shape = cone_shape

	# Los puntos ya están en coordenadas globales
	query.transform = Transform2D.IDENTITY

	# Detectar bacterias en capa 1
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	# Excluir al atacante
	query.exclude = [shooter.get_rid()]

	# REALIZAR CONSULTA FÍSICA
	var space_state := get_world_2d().direct_space_state
	var results := space_state.intersect_shape(query, 64)

	var already_hit: Dictionary = {}

	for result in results:
		var target := result.get(
			"collider"
		) as MoneraPlayer

		if target == null:
			continue

		if target.is_dead:
			continue

		if target.player_id == shooter_id:
			continue

		# Evitar daño duplicado en el mismo pulso
		var target_id := target.get_instance_id()

		if already_hit.has(target_id):
			continue

		already_hit[target_id] = true

		# APLICAR DAÑO
		target.take_damage(
			weapon_data.damage,
			shooter_id
		)

		print(
			"Onda alienígena: ",
			shooter_id,
			" golpeó a ",
			target.player_id,
			" por ",
			weapon_data.damage,
			" HP"
		)


# PROCESAR EXPLOSIÓN DE UNA BURBUJA
func _on_bubble_exploded(
	center: Vector2,
	radius: float,
	amount: int,
	attacker_id: int
) -> void:
	if not multiplayer.is_server():
		return

	# Mostrar el efecto en todas las ventanas
	_show_bubble_explosion.rpc(center, radius)

	# Crear un círculo para detectar jugadores
	var explosion_shape := CircleShape2D.new()
	explosion_shape.radius = radius

	var query := PhysicsShapeQueryParameters2D.new()

	query.shape = explosion_shape
	query.transform = Transform2D(
		0.0,
		center
	)

	# Capa 1: jugadores
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	# Evitar daño al jugador que disparó
	var shooter := players.get_node_or_null(
		str(attacker_id)
	) as MoneraPlayer

	if shooter != null:
		query.exclude = [shooter.get_rid()]

	# Consultar los cuerpos dentro de la explosión
	var space_state := get_world_2d().direct_space_state
	var results := space_state.intersect_shape(
		query,
		64
	)

	# Evitar daño duplicado
	var damaged_players: Dictionary = {}

	for result in results:
		var target := result.get(
			"collider"
		) as MoneraPlayer

		if target == null:
			continue

		if target.is_dead:
			continue

		if target.player_id == attacker_id:
			continue

		var target_id := target.get_instance_id()

		if damaged_players.has(target_id):
			continue

		damaged_players[target_id] = true

		# Aplicar daño una sola vez
		target.take_damage(
			amount,
			attacker_id
		)

		print(
			"Explosión del Pompero: ",
			attacker_id,
			" golpeó a ",
			target.player_id,
			" por ", amount, " HP"
		)


# EFECTO DE EXPLOSIÓN EN TODAS LAS VENTANAS
@rpc("authority", "call_local", "reliable")
func _show_bubble_explosion(
	center: Vector2,
	radius: float
) -> void:
	# Crear efecto visual temporal
	var effect := BubbleExplosionVisual.new()

	effect.max_radius = radius

	# Mostrarlo en el mundo
	$Projectiles.add_child(effect)
	effect.global_position = center


# MOSTRAR ELIMINACIÓN EN TODOS LOS JUGADORES
@rpc("authority", "call_local", "reliable")
func _show_kill_feed(
	killer_name: String,
	victim_name: String
) -> void:

	var feed := get_node_or_null(
		"HUD/KillFeed"
	) as KillFeed

	if feed == null:
		return

	feed.add_elimination(
		killer_name,
		victim_name
	)


# ABRIR O CERRAR LA PAUSA
func _toggle_pause_menu() -> void:
	_set_local_pause(not local_pause_open)


func _close_pause_menu() -> void:
	_set_local_pause(false)


func _set_local_pause(paused: bool) -> void:
	local_pause_open = paused
	pause_menu.visible = paused

	# Informar al servidor de nuestra pausa
	if multiplayer.is_server():
		_set_player_paused_on_server(
			multiplayer.get_unique_id(),
			paused
		)
	else:
		_request_pause_state.rpc_id(1, paused)


# EL CLIENTE SOLICITA CAMBIAR SU ESTADO
@rpc("any_peer", "call_remote", "reliable")
func _request_pause_state(paused: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = (
		multiplayer.get_remote_sender_id()
	)

	_set_player_paused_on_server(
		sender_id,
		paused
	)


# EL SERVIDOR CONTROLA LA PAUSA DE CADA JUGADOR
func _set_player_paused_on_server(
	player_id: int,
	paused: bool
) -> void:
	if not multiplayer.is_server():
		return

	if paused:
		paused_players[player_id] = true
	else:
		paused_players.erase(player_id)

	var player := players.get_node_or_null(
		str(player_id)
	) as MoneraPlayer

	if player == null:
		return

	if paused:
		# Detener las órdenes de movimiento
		player.input_direction = Vector2.ZERO
		player.velocity = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return

	# No procesar controles de juego durante la pausa
	if local_pause_open:
		return


# SALIR DE LA PARTIDA
func _leave_to_main_menu() -> void:
	print("Saliendo de la partida...")

	# Protección mientras exista el antiguo sistema
	# donde el primer jugador también es servidor
	if multiplayer.is_server():
		push_warning(
			"No se puede abandonar como anfitrión. "
			+ "Es necesario utilizar el servidor dedicado."
		)
		return

	# Bloquear nuevas entradas
	local_pause_open = false

	# Cerrar solamente nuestra conexión
	var peer := multiplayer.multiplayer_peer

	if peer != null:
		peer.close()

	# Restaurar el modo multijugador local
	multiplayer.multiplayer_peer = (
		OfflineMultiplayerPeer.new()
	)

	# Regresar al menú de inicio
	var error := get_tree().change_scene_to_file(
		MAIN_MENU_SCENE
	)

	if error != OK:
		push_error(
			"No se pudo abrir MainMenu. Error: %d"
			% error
		)


# DETECTAR MODO SERVIDOR DEDICADO
func _is_dedicated_server() -> bool:
	return (
		OS.has_feature("dedicated_server")
		or "--server" in OS.get_cmdline_user_args()
	)



# INICIAR EL SERVIDOR DEDICADO
func _start_dedicated_server() -> void:
	var peer := WebSocketMultiplayerPeer.new()

	var error := peer.create_server(9080)

	if error != OK:
		push_error(
			"Error al iniciar servidor: %d" % error
		)
		return

	multiplayer.multiplayer_peer = peer

	print("Servidor Monera.run iniciado.")
	print("Esperando jugadores en puerto 9080...")


# CONECTAR UN JUGADOR AL SERVIDOR
func _connect_to_dedicated_server() -> void:
	var peer := WebSocketMultiplayerPeer.new()

	var error := peer.create_client(
		_get_game_server_url()
	)

	if error != OK:
		push_error(
			"Error al conectar: %d" % error
		)
		return

	multiplayer.multiplayer_peer = peer

	print("Conectando al servidor...")

func _on_server_disconnected() -> void:
	if is_leaving_to_menu:
		return

	print("Se perdió la conexión con el servidor.")
	_leave_to_main_menu()
	
	

# CONFIGURACIÓN PARA PRUEBAS
@export var probar_servidor_local: bool = true


func _get_game_server_url() -> String:

	# Navegadores: conexión automática
	if OS.has_feature("web"):

		var origin: String = str(
			JavaScriptBridge.eval(
				"window.location.origin"
			)
		)

		if origin.begins_with("https://"):
			return origin.replace(
				"https://", "wss://"
			) + "/ws"

		return origin.replace(
			"http://", "ws://"
		) + "/ws"

	# PRUEBAS LOCALES EN WINDOWS
	if probar_servidor_local:
		return "ws://127.0.0.1:9080"

	# PRUEBAS CON UBUNTU SERVER
	return "ws://192.168.1.100:8080/ws"


# GENERAR PUNTOS DE APARICION EN TODO EL MAPA
func _generate_spawn_points() -> void:
	var map_node: Node2D = $Map
	var floor_sprite: Sprite2D = $Map/Floor

	# Obtener el tamaño utilizado por el mapa
	# para construir sus paredes.
	var map_size: Vector2 = floor_sprite.region_rect.size

	if map_size.x <= 0.0 or map_size.y <= 0.0:
		push_error("El tamaño del mapa no es válido.")
		return

	# Cuatro columnas y cuatro filas: 16 puntos.
	var columns: int = 4
	var rows: int = 4

	# Margen de seguridad respecto a las paredes.
	var margin_x: float = minf(800.0, map_size.x * 0.18)
	var margin_y: float = minf(800.0, map_size.y * 0.18)

	spawn_points.clear()

	for y in range(rows):
		for x in range(columns):
			var fx: float = float(x) / float(columns - 1)
			var fy: float = float(y) / float(rows - 1)

			var map_position := Vector2(
				lerpf(margin_x, map_size.x - margin_x, fx),
				lerpf(margin_y, map_size.y - margin_y, fy)
			)

			var world_position: Vector2 = to_local(
				map_node.to_global(map_position)
			)

			spawn_points.append(world_position)

	# Variar el orden en que se eligen los puntos.
	spawn_points.shuffle()

	print(
		"Puntos de spawn generados: ",
		spawn_points.size()
	)
