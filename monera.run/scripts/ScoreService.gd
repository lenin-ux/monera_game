extends Node

# API en la misma máquina que el servidor dedicado de Godot.
const SAVE_URL := "http://127.0.0.1:9081/result"


func save_result(player_name: String, score: int) -> void:
	# Nunca aceptar puntuaciones de los clientes.
	if not multiplayer.is_server() or score <= 0:
		return

	var safe_name := player_name.strip_edges().left(16)
	if safe_name.is_empty():
		return

	# Una solicitud independiente por registro permite guardar
	# eliminaciones cercanas sin bloquear la simulación.
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)

	http.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
			if result != HTTPRequest.RESULT_SUCCESS or response_code != 201:
				push_warning("No se guardó puntuación. Resultado=%d, HTTP=%d" % [result, response_code])
			http.queue_free()
	)

	var payload := JSON.stringify({
		"player_name": safe_name,
		"score": score
	})
	var error := http.request(
		SAVE_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		payload
	)
	if error != OK:
		push_warning("No fue posible enviar la puntuación: %d" % error)
		http.queue_free()
