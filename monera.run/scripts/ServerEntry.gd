
extends Node

const WORLD_SCENE := "res://scenes/World.tscn"


func _ready() -> void:
	if (
		OS.has_feature("dedicated_server")
		or "--server" in OS.get_cmdline_user_args()
	):
		print("Iniciando Monera.run como servidor...")

		get_tree().call_deferred(
			"change_scene_to_file",
			WORLD_SCENE
		)
