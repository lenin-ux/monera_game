# autoload/Net.gd
extends Node

const PORT := 7777
const MAX_PLAYERS := 16

var username := ""

func start_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("No se pudo iniciar el servidor: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_left)
	print("Servidor escuchando en UDP %d" % PORT)

func join(ip: String, user: String) -> void:
	username = user
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer

func get_peer_ip(peer_id: int) -> String:
	var p := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id)
	return p.get_remote_address() if p else ""

func _on_peer_left(id: int) -> void:
	var world := get_tree().root.get_node_or_null("World")
	if world:
		world.remove_player(id)
