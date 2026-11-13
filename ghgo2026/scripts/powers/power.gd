class_name Power
extends Resource

@export var id: StringName
@export var display_name: String = "Power"
@export var energy_cost: float = 1.0 #cost in bars
@export_range(1, 5) var required_bars: int = 1
@export var requires_flag: StringName
@export_multiline var description: String = ""
