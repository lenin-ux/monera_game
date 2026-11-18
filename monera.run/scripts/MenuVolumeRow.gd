
extends HBoxContainer

@export_group("Posición")
@export var separation_y: float = 15.0

@onready var sound_button: TextureButton = (
	get_parent() as TextureButton
)

@onready var volume_slider: HSlider = (
	$VolumeArea/VolumeSlider
)

@onready var volume_label: Label = $VolumeLabel

var master_bus: int = -1


func _ready() -> void:
	if sound_button == null:
		push_error("VolumeRow debe estar dentro de SoundButton.")
		return

	master_bus = AudioServer.get_bus_index("Master")

	if master_bus < 0:
		push_error("No se encontró el bus Master.")
		return

	# Permitir que la barra se muestre
	# fuera del rectángulo del botón
	sound_button.clip_contents = false

	# Ocultar la barra al iniciar
	hide()

	# Recuperar el volumen general
	_sync_volume()

	# Conectar el botón original
	sound_button.pressed.connect(_toggle_volume)

	# Conectar la barra
	volume_slider.value_changed.connect(_change_volume)

	# Posicionar la barra debajo del botón
	sound_button.resized.connect(_update_position)

	# Esperar al ajuste inicial del VBoxContainer
	await get_tree().process_frame

	_update_position()


# MOSTRAR U OCULTAR EL VOLUMEN
func _toggle_volume() -> void:
	if visible:
		hide()
	else:
		_sync_volume()
		_update_position()
		show()



# CENTRAR SOLAMENTE LA BARRA DE VOLUMEN
func _update_position() -> void:
	if sound_button == null:
		return

	var volume_area: Control = $VolumeArea

	# Obtener el ancho de la barra, sin incluir
	# el VolumeLabel ni la separación.
	var bar_width: float = maxf(
		volume_area.size.x,
		volume_area.custom_minimum_size.x
	)

	# Centrar únicamente la barra respecto
	# al botón Sonido.
	position = Vector2(
		(sound_button.size.x - bar_width) / 2.0,
		sound_button.size.y + separation_y
	)


# RECUPERAR VOLUMEN ACTUAL
func _sync_volume() -> void:
	if master_bus < 0:
		return

	var volume: float = (
		AudioServer.get_bus_volume_linear(master_bus)
		* 100.0
	)

	if AudioServer.is_bus_mute(master_bus):
		volume = 0.0

	volume_slider.set_value_no_signal(
		clampf(volume, 0.0, 100.0)
	)

	_update_label()


# MODIFICAR VOLUMEN GENERAL
func _change_volume(value: float) -> void:
	if master_bus < 0:
		return

	AudioServer.set_bus_volume_linear(
		master_bus,
		maxf(value / 100.0, 0.0001)
	)

	AudioServer.set_bus_mute(
		master_bus,
		value <= 0.0
	)

	_update_label()


# ACTUALIZAR PORCENTAJE
func _update_label() -> void:
	volume_label.text = "%d%%" % (
		roundi(volume_slider.value)
	)
