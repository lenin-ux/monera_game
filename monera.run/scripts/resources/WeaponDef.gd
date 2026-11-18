class_name WeaponDef extends Resource

@export_group("Identificación")
@export var id: StringName
@export var display_name: String = ""

@export_group("Escenas")
@export var weapon_scene: PackedScene
@export var projectile_scene: PackedScene

@export_group("Estadísticas")
@export var damage: int = 20
@export var fire_interval: float = 0.5
@export var projectile_speed: float = 2000.0


@export_group("Alcance")
@export var projectile_range: float = 3000.0

@export_group("Efectos especiales")
@export_range(0.0, 1.0, 0.05)
var slow_fraction: float = 0.0

@export var slow_duration: float = 0.0
