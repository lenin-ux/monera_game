
extends PanelContainer

# PUNTOS NECESARIOS PARA EVOLUCIONAR
const NEXT_LEVEL_POINTS := {
	1: 100,
	2: 500,
	3: 1000
}

# PUNTOS DONDE COMIENZA CADA NIVEL
const PREVIOUS_LEVEL_POINTS := {
	1: 0,
	2: 100,
	3: 500
}

# NOMBRES DE LAS ARMAS
const WEAPON_NAMES := {
	"resortera": "Resortera",
	"cerbatana": "Cerbatana",
	"cerbatana_pegajosa": "Cerbatana Pegajosa",
	"alienigena": "Arma Alienígena",
	"pompero": "Pompero",
	"escopeta": "Escopeta"
}

@onready var players_container: Node2D = (
	get_node_or_null("../../Players") as Node2D
)

@onready var level_label: Label = (
	$MarginContainer/Content/LevelLabel
)

@onready var weapon_label: Label = (
	$MarginContainer/Content/WeaponLabel
)

@onready var next_label: Label = (
	$MarginContainer/Content/NextEvolutionLabel
)

@onready var progress_bar: ProgressBar = (
	$MarginContainer/Content/EvolutionProgress
)

@onready var update_timer: Timer = $UpdateTimer


func _ready() -> void:
	# Colocar debajo de los puntos del jugador
	position = Vector2(20, 85)
	custom_minimum_size = Vector2(320, 0)

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.show_percentage = false

	if players_container == null:
		push_error("No se encontró World/Players.")
		return

	update_timer.timeout.connect(_update_status)
	_update_status()


func _update_status() -> void:
	var local_id: int = multiplayer.get_unique_id()

	var player := players_container.get_node_or_null(
		str(local_id)
	) as MoneraPlayer

	if player == null:
		visible = false
		return

	# Ocultar durante la eliminación
	visible = not player.is_dead

	if player.is_dead:
		return

	# OBTENER NIVEL ACTUAL
	var character_key: String = str(player.character_id)

	var level: int = clampi(
		int(character_key.trim_prefix("nivel_")),
		1,
		4
	)

	level_label.text = "NIVEL %d" % level

	# MOSTRAR ARMA EQUIPADA
	var weapon_key: String = str(player.weapon_id)

	weapon_label.text = "ARMA: " + str(
		WEAPON_NAMES.get(
			weapon_key,
			weapon_key.capitalize()
		)
	)

	# NIVEL MÁXIMO
	if level >= 4:
		next_label.text = "EVOLUCIÓN MÁXIMA"
		progress_bar.visible = false
		return

	progress_bar.visible = true

	# CALCULAR PROGRESO
	var required: int = NEXT_LEVEL_POINTS[level]
	var previous: int = PREVIOUS_LEVEL_POINTS[level]
	var points: int = player.points

	progress_bar.min_value = 0.0
	progress_bar.max_value = float(
		required - previous
	)

	progress_bar.value = float(
		clampi(
			points - previous,
			0,
			required - previous
		)
	)

	# MOSTRAR ESTADO
	if points >= required:
		next_label.text = (
			"¡EVOLUCIÓN DISPONIBLE! PRESIONA E"
		)
	else:
		next_label.text = (
			"SIGUIENTE NIVEL: %d / %d"
			% [points, required]
		)
