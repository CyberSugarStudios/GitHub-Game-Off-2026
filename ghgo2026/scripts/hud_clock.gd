extends RichTextLabel

func _ready() -> void:
	GameClock.minute_changed.connect(
		func(_day: int, _minute: int) -> void:
			_show())
	_show()

func _show() -> void:
	text = GameClock.get_clock_text()
