extends PanelContainer

# Para clientes en otra computadora, cambia 127.0.0.1 por la
# IP o el dominio público de tu servidor.
@export var leaderboard_url: String = "http://IP_DE_UBUNTU:8080/api/leaderboard"
@export var ranking_font: Font
@export_range(10, 32, 1) var ranking_font_size: int = 17
@export var text_color: Color = Color.WHITE
@export var highlight_color: Color = Color("#F4C95D")

var entries: VBoxContainer
var status_label: Label
var request_node: HTTPRequest


func _ready() -> void:
	custom_minimum_size = Vector2(405.0, 0.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)

	var header := _new_label("MEJORES PARTIDAS · TOP 10", highlight_color)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	var separator := HSeparator.new()
	content.add_child(separator)

	status_label = _new_label("Cargando clasificación...", text_color)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status_label)

	entries = VBoxContainer.new()
	entries.add_theme_constant_override("separation", 6)
	content.add_child(entries)

	request_node = HTTPRequest.new()
	request_node.timeout = 5.0
	add_child(request_node)
	request_node.request_completed.connect(_on_response)
	_load_scores()

func _load_scores() -> void:
	var error := request_node.request(_get_ranking_url())

	if error != OK:
		status_label.text = "Clasificación no disponible"
		push_warning(
			"No se pudo consultar el ranking: %d" % error
		)


func _on_response(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "Clasificación no disponible"
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		status_label.text = "Respuesta inválida del servidor"
		return

	var records: Variant = parsed.get("entries", [])
	if not (records is Array):
		status_label.text = "Datos de clasificación inválidos"
		return

	for child in entries.get_children():
		child.queue_free()

	if records.is_empty():
		status_label.text = "Aún no hay puntuaciones"
		status_label.show()
		return

	status_label.hide()
	var rank := 0
	for record in records:
		if not (record is Dictionary):
			continue
		rank += 1
		_add_entry(
			rank,
			str(record.get("player_name", "Jugador")).left(16),
			int(record.get("score", 0))
		)


func _add_entry(rank: int, player_name: String, score: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	entries.add_child(row)

	var rank_label := _new_label("%d." % rank, highlight_color if rank <= 3 else text_color)
	rank_label.custom_minimum_size = Vector2(28, 0)
	row.add_child(rank_label)

	var name_label := _new_label(player_name, text_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	var score_label := _new_label("%d pts" % score, text_color)
	score_label.custom_minimum_size = Vector2(94, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score_label)


func _new_label(value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", ranking_font_size)
	if ranking_font != null:
		label.add_theme_font_override("font", ranking_font)
	return label



func _get_ranking_url() -> String:
	if OS.has_feature("web"):
		var origin: String = str(
			JavaScriptBridge.eval(
				"window.location.origin"
			)
		)

		return origin + "/api/leaderboard"

	# Prueba desde Godot en Windows por SSH
	return "http://127.0.0.1:19081/leaderboard"
