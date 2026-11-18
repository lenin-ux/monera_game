extends Control

# BOTONES DEL MENÚ
@onready var play_button: BaseButton = $MainContent/MenuButtons/PlayButton

# VENTANA DE INGRESO
@onready var name_overlay: Control = $NameOverlay
@onready var name_input: LineEdit = $NameOverlay/DialogCenter/DialogPanel/DialogContents/NameInput
@onready var enter_button: BaseButton = $NameOverlay/DialogCenter/DialogPanel/DialogContents/EnterButton
@onready var back_button: BaseButton = $NameOverlay/DialogCenter/DialogPanel/DialogContents/BackButton

# AUDIO
@onready var intro_music: AudioStreamPlayer = $IntroMusic
@onready var loop_music: AudioStreamPlayer = $LoopMusic
@onready var enter_sound: AudioStreamPlayer = $EnterSound

# ESTADO
var music_started: bool = false
var entering_game: bool = false


func _ready() -> void:
	name_overlay.hide()

	# Botones
	play_button.pressed.connect(_on_play_pressed)
	enter_button.pressed.connect(_join_game)
	back_button.pressed.connect(_on_back_pressed)

	# Confirmar con Enter
	name_input.text_submitted.connect(_on_name_submitted)

	# Al terminar la introducción, comenzar el loop
	intro_music.finished.connect(_on_intro_finished)

	# En escritorio, reproducir al iniciar el menú
	if not OS.has_feature("web"):
		start_menu_music()


# INICIAR MÚSICA DEL MENÚ
func start_menu_music() -> void:
	if music_started or entering_game:
		return

	music_started = true

	if intro_music.stream != null:
		intro_music.play()
	elif loop_music.stream != null:
		loop_music.play()


# TERMINÓ LA INTRODUCCIÓN
func _on_intro_finished() -> void:
	if entering_game:
		return

	if loop_music.stream != null:
		loop_music.play()


# BOTÓN JUGAR
func _on_play_pressed() -> void:
	# En navegador, iniciar música con interacción
	if OS.has_feature("web"):
		start_menu_music()

	name_overlay.show()
	name_input.clear()
	name_input.grab_focus()


# BOTÓN CANCELAR
func _on_back_pressed() -> void:
	name_overlay.hide()
	play_button.grab_focus()


# PRESIONAR ENTER EN EL CAMPO
func _on_name_submitted(_text: String) -> void:
	_join_game()


# ENTRAR A LA PARTIDA
func _join_game() -> void:
	if entering_game:
		return

	var username := name_input.text.strip_edges()

	if username.is_empty():
		name_input.grab_focus()
		return

	# Guardar nombre
	Session.username = username
	entering_game = true

	# Evitar múltiples entradas
	enter_button.disabled = true
	back_button.disabled = true
	name_input.editable = false

	# Detener música del menú
	intro_music.stop()
	loop_music.stop()

	# Reproducir sonido de entrada completo
	if enter_sound.stream != null:
		enter_sound.play()
		await enter_sound.finished

	if not is_inside_tree():
		return

	# Cargar el mundo multijugador
	var error := get_tree().change_scene_to_file(
		"res://scenes/World.tscn"
	)

	if error != OK:
		push_error("No se pudo cargar World.tscn")
		entering_game = false
		enter_button.disabled = false
		back_button.disabled = false
		name_input.editable = true
