# autoload/PlayerDB.gd
extends Node

const PATH := "user://players.json"
var db := {}

func _ready() -> void:
	if FileAccess.file_exists(PATH):
		db = JSON.parse_string(FileAccess.get_file_as_string(PATH))

func load_or_create(user: String, ip: String) -> Dictionary:
	var key := user.to_lower()
	if not db.has(key):
		db[key] = {"character_id": "nivel_1", "level": 1, "xp": 0}
	db[key]["ip"] = ip
	_flush()
	return db[key]

func save(user: String, data: Dictionary) -> void:
	var key := user.to_lower()
	db[key].merge(data, true)
	_flush()

func _flush() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(db))
