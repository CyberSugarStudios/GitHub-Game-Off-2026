extends RichTextLabel

func _ready() -> void:
	visible = OS.is_debug_build()

func _process(_delta: float) -> void:
	text = "Day: " + str(GameClock.day) + " Time: " + GameClock.get_time_text()
