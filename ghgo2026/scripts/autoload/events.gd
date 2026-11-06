extends Node #Events autoload

signal interaction_prompt_changed(text: String, available: bool)
signal door_opened(room_id: StringName, exit_spot: Transform3D)
signal returned_to_hall(exit_spot: Transform3D)
signal story_event(story_id: StringName)
