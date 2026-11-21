@tool
extends EditorScript

const SETS: Dictionary[String, String] = {
	"res://assets/audio/sfx/footsteps/leanne": "res://assets/audio/sfx/footsteps/leanne_steps.tres",
	"res://assets/audio/sfx/footsteps/david": "res://assets/audio/sfx/footsteps/david_steps.tres",
	"res://assets/audio/sfx/footsteps/creature": "res://assets/audio/sfx/footsteps/creature_steps.tres",
}

func _run() -> void:
	for folder in SETS:
		var files := Array(DirAccess.get_files_at(folder)).filter(
			func(file: String) -> bool: return file.get_extension() == "wav")
		files.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		var steps := AudioStreamRandomizer.new()
		steps.random_pitch = 1.08
		steps.random_volume_offset_db = 1.5
		for file in files:
			steps.add_stream(-1, load(folder.path_join(file)))
		ResourceSaver.save(steps, SETS[folder])
		print("%s: %d steps" % [SETS[folder], files.size()])
	EditorInterface.get_resource_filesystem().scan()
