
class_name PauseOverlay extends Control

signal resume_requested
signal leave_requested



@onready var background: ColorRect = (
	get_node_or_null("DimBackground") as ColorRect
)

@onready var center_container: CenterContainer = (
	get_node_or_null("CenterContainer") as CenterContainer
)

@onready var resume_button: BaseButton = (
	$CenterContainer/MenuContent/ResumeButton
)


@onready var sound_button: BaseButton = (
	$CenterContainer/MenuContent/VolumeRow/SoundButton
)

@onready var volume_slider: HSlider = (
	$CenterContainer/MenuContent/VolumeRow/VolumeArea/VolumeSlider
)

@onready var volume_label: Label = (
	$CenterContainer/MenuContent/VolumeRow/VolumeArea/VolumeLabel
)

@onready var menu_button: BaseButton = (
	$CenterContainer/MenuContent/MenuButton
)


var master_bus: int = -1
var last_nonzero_volume: float = 75.0


func _ready() -> void:
	# Configurar el menú completo
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Comprobar el fondo
	if background != null:
		background.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
	else:
		push_error(
			"No se encontró PauseMenu/DimBackground"
		)

	mouse_filter = Control.MOUSE_FILTER_STOP
	background.mouse_filter = Control.MOUSE_FILTER_STOP

	# Conectar botones
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	sound_button.pressed.connect(_on_sound_pressed)

	# Obtener el volumen general
	master_bus = AudioServer.get_bus_index("Master")

	if master_bus >= 0:
		var current_volume: float = (
			AudioServer.get_bus_volume_linear(master_bus)
			* 100.0
		)

		volume_slider.set_value_no_signal(
			clampf(current_volume, 0.0, 100.0)
		)

		if current_volume > 0.0:
			last_nonzero_volume = current_volume

	# Conectar barra
	volume_slider.value_changed.connect(
		_on_volume_changed
	)

	_update_volume_label()

	# Empezar con el menú cerrado
	hide()


# MODIFICAR EL VOLUMEN GENERAL
func _on_volume_changed(value: float) -> void:
	if master_bus < 0:
		return

	if value > 0.0:
		last_nonzero_volume = value

	# Aplicar el volumen al bus Master
	AudioServer.set_bus_volume_linear(
		master_bus,
		maxf(value / 100.0, 0.001)
	)

	# Cero significa silencio
	AudioServer.set_bus_mute(
		master_bus,
		value <= 0.0
	)

	_update_volume_label()


# BOTÓN DE SONIDO: SILENCIAR / ACTIVAR
func _on_sound_pressed() -> void:
	if master_bus < 0:
		return

	var currently_muted: bool = (
		AudioServer.is_bus_mute(master_bus)
	)

	if currently_muted:
		# Recuperar el volumen anterior
		if volume_slider.value <= 0.0:
			volume_slider.value = last_nonzero_volume

		AudioServer.set_bus_mute(
			master_bus,
			false
		)
	else:
		AudioServer.set_bus_mute(
			master_bus,
			true
		)

	_update_volume_label()


# ACTUALIZAR EL PORCENTAJE
func _update_volume_label() -> void:
	if master_bus < 0:
		volume_label.text = "--"
		return

	if AudioServer.is_bus_mute(master_bus):
		volume_label.text = "SILENCIO"
	else:
		volume_label.text = "%d%%" % (
			int(round(volume_slider.value))
		)


# REANUDAR PARTIDA
func _on_resume_pressed() -> void:
	resume_requested.emit()


# REGRESAR AL MENÚ PRINCIPAL
func _on_menu_pressed() -> void:
	leave_requested.emit()
