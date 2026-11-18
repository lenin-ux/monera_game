
class_name CharacterDef extends Resource

# IDENTIFICACIÓN
@export_group("Identificación")

@export var id: StringName
@export var display_name: String = ""

# APARIENCIA
@export_group("Apariencia")

@export var visual_scene: PackedScene

# EVOLUCIÓN
@export_group("Evolución")

@export var evolves_to: StringName = &""

# ESTADÍSTICAS
@export_group("Estadísticas")

@export_group("Opciones de armas")
@export var weapon_options: Array[WeaponDef] = []

@export_range(1, 10000, 1)
var max_health: int = 100

@export_range(1.0, 5000.0, 1.0)
var movement_speed: float = 1000.0
