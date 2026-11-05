extends Node #Events autoload

signal interaction_prompt_changed(text: String, available: bool)
signal door_opened(room_id: StringName)
signal story_event(story_id: StringName)
