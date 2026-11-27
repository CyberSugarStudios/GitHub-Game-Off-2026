@tool
extends EditorScript

const JOBS := [
	["res://assets/sprites/Animations/frames/dad/david_frames.tres", &"sitting", "res://assets/sprites/Animations/dad/Dad-sitting", 2, 12.0],
	["res://assets/sprites/Animations/frames/dad/david_frames.tres", &"sleeping", "res://assets/sprites/Animations/dad/Dad-sleeping", 2, 12.0],
	["res://assets/sprites/Animations/frames/mom/leanne_frames.tres", &"reading", "res://assets/sprites/Animations/mom/Reading", 2, 12.0],
	["res://assets/sprites/Animations/frames/rooms/music_box_frames.tres", &"default", "res://assets/sprites/Animations/rooms/living_room/Music-box", 1, 8.0],
	["res://assets/sprites/Animations/frames/rooms/shower_frames.tres", &"default", "res://assets/sprites/Animations/rooms/bathroom", 1, 10.0],
]

func _run() -> void:
	for job in JOBS:
		var path: String = job[0]
		var frames: SpriteFrames = load(path) if ResourceLoader.exists(path) else SpriteFrames.new()
		var anim: StringName = job[1]
		if frames.has_animation(anim):
			frames.clear(anim)
		else:
			frames.add_animation(anim)
		frames.set_animation_speed(anim, job[4])
		frames.set_animation_loop(anim, true)
		var pngs := Array(DirAccess.get_files_at(job[2])).filter(func(f: String) -> bool: return f.ends_with(".png"))
		pngs.sort()
		for i in range(0, pngs.size(), job[3]):
			frames.add_frame(anim, load(job[2] + "/" + pngs[i]))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		ResourceSaver.save(frames, path)
		print("%s: %s (%d frames)" % [path.get_file(), anim, frames.get_frame_count(anim)])
