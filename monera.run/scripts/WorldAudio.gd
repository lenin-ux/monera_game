
class_name WorldAudio
extends Node

@export_group("Musica de la partida")
@export var musica_fondo: AudioStream
@export_range(-30.0, 0.0, 1.0)
var musica_volumen_db: float = -8.0

@export_group("Efectos de sonido")
@export var sonido_danio: AudioStream
@export var sonido_proyectil: AudioStream
@export var sonido_escopeta: AudioStream
@export var sonido_level_up: AudioStream
@export var sonido_lazer: AudioStream
@export var sonido_nutriente: AudioStream

@export_group("Limites de audio")
@export_range(1, 24, 1)
var max_sonidos_simultaneos: int = 10

@export_range(0, 300, 10)
var intervalo_minimo_danio_ms: int = 90

var reproductores: Array[AudioStreamPlayer] = []
var ultimo_danio_ms: int = -100000
var reproductor_musica: AudioStreamPlayer


func _ready() -> void:
	# El servidor dedicado no reproduce sonido.
	if _es_servidor_dedicado():
		return

	# CREAR REPRODUCTOR DE MÚSICA
	reproductor_musica = AudioStreamPlayer.new()
	reproductor_musica.name = "Musica"
	reproductor_musica.bus = &"Master"
	reproductor_musica.volume_db = musica_volumen_db
	add_child(reproductor_musica)

	if musica_fondo != null:
		# Activar bucle según el formato
		if musica_fondo is AudioStreamOggVorbis:
			(musica_fondo as AudioStreamOggVorbis).loop = true
		elif musica_fondo is AudioStreamMP3:
			(musica_fondo as AudioStreamMP3).loop = true
		elif musica_fondo is AudioStreamWAV:
			(musica_fondo as AudioStreamWAV).loop_mode = (
				AudioStreamWAV.LOOP_FORWARD
			)

		reproductor_musica.stream = musica_fondo
		reproductor_musica.play()

	# CREAR REPRODUCTORES PARA LOS EFECTOS
	for i in range(max_sonidos_simultaneos):
		var reproductor := AudioStreamPlayer.new()
		reproductor.name = "Efecto_%d" % i
		reproductor.bus = &"Master"
		add_child(reproductor)
		reproductores.append(reproductor)


func _es_servidor_dedicado() -> bool:
	return (
		OS.has_feature("dedicated_server")
		or "--server" in OS.get_cmdline_user_args()
	)


# EL SERVIDOR ANUNCIA UN EVENTO DE SONIDO
func anunciar(
	tipo: String,
	posicion: Vector2,
	actor_id: int
) -> void:
	if not multiplayer.is_server():
		return

	# NUTRIENTE: SOLO QUIEN LO RECOGIÓ
	if tipo == "nutriente":
		if actor_id == multiplayer.get_unique_id():
			_recibir_sonido(tipo, posicion, actor_id)
		else:
			_recibir_sonido.rpc_id(
				actor_id, tipo, posicion, actor_id
			)
		return

	# LOS DEMÁS SONIDOS SE FILTRAN POR PANTALLA
	_recibir_sonido.rpc(tipo, posicion, actor_id)


@rpc("authority", "call_local", "unreliable")
func _recibir_sonido(
	tipo: String,
	posicion: Vector2,
	actor_id: int
) -> void:
	if _es_servidor_dedicado():
		return

	var mi_id: int = multiplayer.get_unique_id()

	# Decidir si corresponde escuchar el evento
	if tipo == "nutriente":
		if actor_id != mi_id:
			return
	elif actor_id != mi_id and not _esta_en_pantalla(
		posicion
	):
		return

	# Evitar que varios impactos simultáneos
	# saturen el sonido de daño
	if tipo == "danio":
		var ahora: int = Time.get_ticks_msec()

		if ahora - ultimo_danio_ms < (
			intervalo_minimo_danio_ms
		):
			return

		ultimo_danio_ms = ahora

	var sonido: AudioStream = _obtener_sonido(tipo)

	if sonido == null:
		return

	# Utilizar un reproductor disponible
	for reproductor in reproductores:
		if not reproductor.playing:
			reproductor.stream = sonido
			reproductor.play()
			return


# COMPROBAR SI EL EVENTO OCURRE EN PANTALLA
func _esta_en_pantalla(
	posicion_global: Vector2
) -> bool:
	var viewport: Viewport = get_viewport()

	if viewport.get_camera_2d() == null:
		return false

	# Convertir posición del mundo a pantalla
	var posicion_pantalla: Vector2 = (
		viewport.get_canvas_transform()
		* posicion_global
	)

	return viewport.get_visible_rect().has_point(
		posicion_pantalla
	)


# SELECCIONAR EL ARCHIVO DE SONIDO
func _obtener_sonido(tipo: String) -> AudioStream:
	match tipo:
		"danio":
			return sonido_danio
		"proyectil":
			return sonido_proyectil
		"escopeta":
			return sonido_escopeta
		"level_up":
			return sonido_level_up
		"lazer":
			return sonido_lazer
		"nutriente":
			return sonido_nutriente

	return null
