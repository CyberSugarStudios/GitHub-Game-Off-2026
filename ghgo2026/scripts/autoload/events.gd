extends Node #Events autoload

@warning_ignore_start("unused_signal")
signal interaction_prompt_changed(text: String, available: bool)
signal door_opened(room_id: StringName, exit_spot: Transform3D)
signal returned_to_hall(exit_spot: Transform3D)
signal story_event(story_id: StringName)
signal conversation_requested(dialogue: DialogueResource, title: String, frozen: bool)
signal subtitle_changed(character: String, text: String, clarity: float, is_thought: bool)
signal conversation_finished(title: String)
signal power_used(power_id: StringName, parent_id: StringName)
signal door_unlock_failed(room_id: StringName)
@warning_ignore_restore("unused_signal")
