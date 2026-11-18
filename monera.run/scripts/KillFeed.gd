class_name KillFeed extends VBoxContainer


@export_group("Posición")
@export var separation_from_leaderboard: float = 10.0

@export_group("Mensajes")
@export var visible_seconds: float = 5.0
@export var fade_duration: float = 0.7
@export_range(1, 10, 1)
var max_messages: int = 5

@export_group("Apariencia")
@export var feed_font: Font
@export_range(10, 32, 1)
var feed_font_size: int = 16


# REFERENCIA AL PANEL DE CLASIFICACIÓN
@onready var leaderboard_panel: Control = (
	get_node_or_null("../LeaderboardPanel") as Control
)


@export_group("Fondo de mensajes")

# Usar automáticamente el color del Leaderboard
@export var use_leaderboard_color: bool = true

# Color alternativo si desactivas la opción anterior
@export var custom_background_color: Color = Color(
	0.09, 0.12, 0.18, 1.0
)

# Transparencia independiente
@export_range(0.0, 1.0, 0.05)
var background_opacity: float = 0.75


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_theme_constant_override(
		"separation", 6
	)

	if leaderboard_panel == null:
		push_error(
			"No se encontró LeaderboardPanel."
		)
		return

	_update_position()


# MANTENER EL KILL FEED DEBAJO DEL LEADERBOARD
func _process(_delta: float) -> void:
	_update_position()


func _update_position() -> void:
	if not is_instance_valid(leaderboard_panel):
		return

	global_position = (
		leaderboard_panel.global_position
		+ Vector2(
			0.0,
			leaderboard_panel.size.y
			+ separation_from_leaderboard
		)
	)

	# Utilizar el mismo ancho del Leaderboard
	size.x = leaderboard_panel.size.x


# AGREGAR UNA ELIMINACIÓN

# AGREGAR UNA ELIMINACIÓN
func add_elimination(
	killer_name: String,
	victim_name: String
) -> void:

	# CREAR PANEL DEL MENSAJE
	var message_panel := PanelContainer.new()

	message_panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	message_panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	# CONFIGURAR FONDO
	var style := StyleBoxFlat.new()

	var background_color: Color = (
		custom_background_color
	)

	# Copiar color del Leaderboard
	if use_leaderboard_color and is_instance_valid(
		leaderboard_panel
	):
		var leaderboard_style := (
			leaderboard_panel.get_theme_stylebox("panel")
		)

		if leaderboard_style is StyleBoxFlat:
			background_color = leaderboard_style.bg_color

	# Aplicar transparencia personalizada
	background_color.a = background_opacity

	style.bg_color = background_color

	# Bordes redondeados
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	# Espaciado interior
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7

	message_panel.add_theme_stylebox_override(
		"panel", style
	)

	# TEXTO ADAPTABLE
	var message_text := RichTextLabel.new()

	message_text.bbcode_enabled = false
	message_text.fit_content = true
	message_text.scroll_active = false

	# Ajustar el texto automáticamente en varias líneas
	message_text.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	# Limitar el ancho del texto al espacio del panel
	var available_width: float = 350.0

	if is_instance_valid(leaderboard_panel):
		available_width = maxf(
			100.0,
			leaderboard_panel.size.x - 20.0
		)

	message_text.custom_maximum_size = Vector2(
		available_width, -1.0
	)

	message_text.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	message_text.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	# Evitar otro fondo detrás del texto
	message_text.add_theme_stylebox_override(
		"normal",
		StyleBoxEmpty.new()
	)

	# FUENTE PERSONALIZADA
	if feed_font != null:
		message_text.add_theme_font_override(
			"normal_font",
			feed_font
		)

	message_text.add_theme_font_size_override(
		"normal_font_size",
		feed_font_size
	)

	# NOMBRE DEL ASESINO - BLANCO
	message_text.push_color(Color.WHITE)

	message_text.add_text(
		killer_name.left(16)
	)

	message_text.pop()

	# TEXTO INTERMEDIO - GRIS
	message_text.push_color(
		Color(0.72, 0.76, 0.82)
	)

	message_text.add_text(" eliminó a ")

	message_text.pop()

	# NOMBRE DEL ELIMINADO - ROJO
	message_text.push_color(
		Color(1.0, 0.35, 0.42)
	)

	message_text.add_text(
		victim_name.left(16)
	)

	message_text.pop()

	# AGREGAR TEXTO AL PANEL
	message_panel.add_child(message_text)

	# MOSTRAR MENSAJE
	add_child(message_panel)

	# LIMITAR MENSAJES VISIBLES
	while get_child_count() > max_messages:
		var oldest := get_child(0)

		remove_child(oldest)
		oldest.queue_free()

	# ESPERAR Y DESVANECER
	var tween := message_panel.create_tween()

	tween.tween_interval(visible_seconds)

	tween.tween_property(
		message_panel,
		"modulate:a",
		0.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE)

	# ELIMINAR AL TERMINAR
	tween.tween_callback(
		message_panel.queue_free
	)


# CREAR TEXTO CON COLOR PERSONALIZADO
func _create_text(
	container: HBoxContainer,
	content: String,
	text_color: Color
) -> void:

	var label := Label.new()

	label.text = content

	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	# COLOR
	label.add_theme_color_override(
		"font_color",
		text_color
	)

	# FUENTE
	if feed_font != null:
		label.add_theme_font_override(
			"font",
			feed_font
		)

	# TAMAÑO
	label.add_theme_font_size_override(
		"font_size",
		feed_font_size
	)

	container.add_child(label)
