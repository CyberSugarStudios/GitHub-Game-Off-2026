extends RichTextLabel

func _process(_delta: float) -> void:
	text = "Day: " + str(GameClock.day) + " Time: " + GameClock.get_time_text()
