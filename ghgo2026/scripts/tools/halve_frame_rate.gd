@tool
extends EditorScript

const FRAMES: Array[String] = [
	"res://assets/sprites/Animations/frames/creature/creature_frames.tres",
	"res://assets/sprites/Animations/frames/dad/david_frames.tres",
	"res://assets/sprites/Animations/frames/mom/leanne_frames.tres",
]

func _run() -> void:
	var dropped := PackedStringArray()
	for path in FRAMES:
		var frames := load(path) as SpriteFrames
		if frames.has_meta("halved"):
			print("Already halved, skipping: ", path)
			continue
		for anim in frames.get_animation_names():
			# Work from the last frame back, so removing one doesn't shift the ones still to check.
			for i in range(frames.get_frame_count(anim) - 1, -1, -1):
				if i % 2 == 1:
					var texture := frames.get_frame_texture(anim, i)
					if texture:
						dropped.append(texture.resource_path)
					frames.remove_frame(anim, i)
			frames.set_animation_speed(anim, frames.get_animation_speed(anim) / 2.0)
		frames.set_meta("halved", true)
		ResourceSaver.save(frames, path)
		print("Halved: ", path)
	for file in dropped:
		_move_aside(file)
	EditorInterface.get_resource_filesystem().scan()
	print("Moved %d frames into _dropped_frames folders." % dropped.size())

func _move_aside(file: String) -> void:
	var folder := file.get_base_dir().path_join("_dropped_frames")
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
		FileAccess.open(folder.path_join(".gdignore"), FileAccess.WRITE).close()
	DirAccess.rename_absolute(file, folder.path_join(file.get_file()))
	DirAccess.remove_absolute(file + ".import")
