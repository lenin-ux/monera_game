extends PanelContainer


# CONTENEDOR DONDE ESTÁN TODOS LOS JUGADORES
@onready var players_container: Node2D = get_node(
	"../../Players"
) as Node2D

# CONTENEDOR VISUAL DE LA CLASIFICACIÓN
@onready var leaderboard_list: VBoxContainer = (
	$MarginContainer/LeaderboardContent/LeaderboardList
)

# TEMPORIZADOR DE ACTUALIZACIÓN
@onready var refresh_timer: Timer = $RefreshTimer


@export_group("Apariencia del Leaderboard")

@export var leaderboard_font: Font

@export_range(10, 40, 1)
var leaderboard_font_size: int = 18



func _ready() -> void:
	# POSICIONAR LA TABLA EN LA ESQUINA SUPERIOR DERECHA
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0

	# MÁRGENES RESPECTO A LA ESQUINA SUPERIOR DERECHA
	offset_left = -430.0
	offset_top = 20.0
	offset_right = -20.0
	offset_bottom = 250.0
	
	if players_container == null:
		push_error("No se encontró el nodo Players.")
		return

	# Permitir que los clics atraviesen la tabla
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Actualizar automáticamente
	refresh_timer.timeout.connect(
		_update_leaderboard
	)

	# Primera actualización
	_update_leaderboard()


# ORDENAR POR PUNTOS DE MAYOR A MENOR
func _compare_players(
	a: MoneraPlayer,
	b: MoneraPlayer
) -> bool:

	if a.points != b.points:
		return a.points > b.points

	# Si tienen los mismos puntos,
	# conservar un orden estable por ID
	return a.player_id < b.player_id


# ACTUALIZAR LA TABLA DE CLASIFICACIÓN
func _update_leaderboard() -> void:

	var ranking: Array[MoneraPlayer] = []

	# OBTENER LOS JUGADORES CONECTADOS
	for child in players_container.get_children():
		if child is MoneraPlayer:
			ranking.append(child as MoneraPlayer)

	# ORDENAR POR PUNTUACIÓN
	ranking.sort_custom(_compare_players)

	# IDENTIFICAR AL JUGADOR LOCAL
	var local_id: int = multiplayer.get_unique_id()

	# ACTUALIZAR CADA FILA
	for i in range(ranking.size()):

		var player: MoneraPlayer = ranking[i]

		var row: HBoxContainer

		# Reutilizar filas existentes
		if i < leaderboard_list.get_child_count():
			row = leaderboard_list.get_child(
				i
			) as HBoxContainer
		else:
			row = _create_player_row()
			leaderboard_list.add_child(row)

		row.show()

		# REFERENCIAS A LAS ETIQUETAS
		var rank_label := row.get_node(
			"Rank"
		) as Label

		var name_label := row.get_node(
			"PlayerName"
		) as Label

		var points_label := row.get_node(
			"Points"
		) as Label

		# POSICIÓN EN LA CLASIFICACIÓN
		rank_label.text = "%d." % (i + 1)

		# NOMBRE DEL JUGADOR
		var display_name: String = (
			player.username.strip_edges()
		)

		if display_name.is_empty():
			display_name = "Jugador %d" % (
				player.player_id
			)

		name_label.text = display_name.left(16)

		# PUNTUACIÓN ACTUAL
		points_label.text = str(player.points)

		# RESALTAR AL JUGADOR LOCAL
		var is_local: bool = (
			player.player_id == local_id
		)

		var text_color := Color.WHITE

		if is_local:
			text_color = Color(1.0, 0.8, 0.3)

		rank_label.add_theme_color_override(
			"font_color", text_color
		)

		name_label.add_theme_color_override(
			"font_color", text_color
		)

		points_label.add_theme_color_override(
			"font_color", text_color
		)

	# OCULTAR FILAS DE JUGADORES DESCONECTADOS
	for i in range(
		ranking.size(),
		leaderboard_list.get_child_count()
	):
		leaderboard_list.get_child(i).hide()


# CREAR UNA FILA NUEVA
func _create_player_row() -> HBoxContainer:

	var row := HBoxContainer.new()

	row.add_theme_constant_override(
		"separation", 8
	)

	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# NÚMERO DE POSICIÓN
	var rank_label := Label.new()

	rank_label.name = "Rank"
	rank_label.custom_minimum_size = Vector2(
		28, 0
	)

	row.add_child(rank_label)

	
	# NOMBRE DEL JUGADOR
	var name_label := Label.new()

	name_label.name = "PlayerName"

	# Aprovechar el espacio disponible
	name_label.custom_minimum_size = Vector2(0, 0)

	name_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	# Evitar que el texto se salga del panel
	name_label.clip_text = true

	# Mostrar puntos suspensivos si la fuente es demasiado grande
	name_label.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)

	row.add_child(name_label)

	# PUNTOS
	var points_label := Label.new()

	points_label.name = "Points"

	points_label.custom_minimum_size = Vector2(
		55, 0
	)

	points_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	row.add_child(points_label)
	
	
	# APLICAR LA FUENTE A LOS TRES LABELS
	for label in [rank_label, name_label, points_label]:

		if leaderboard_font != null:
			label.add_theme_font_override(
				"font",
				leaderboard_font
			)

		label.add_theme_font_size_override(
			"font_size",
			leaderboard_font_size
		)

	return row
