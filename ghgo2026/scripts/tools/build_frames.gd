@tool
extends EditorScript

const JOBS := [
	["res://assets/sprites/Animations/frames/dad/david_frames.tres", &"sitting", "res://assets/sprites/Animations/dad/Dad-sitting", 2, 12.0],
	["res://assets/sprites/Animations/frames/dad/david_frames.tres", &"sleeping", "res://assets/sprites/Animations/dad/Dad-sleeping", 2, 12.0],
	["res://assets/sprites/Animations/frames/mom/leanne_frames.tres", &"reading", "res://assets/sprites/Animations/mom/Reading", 2, 12.0],
	["res://assets/sprites/Animations/frames/mom/leanne_frames.tres", &"sleeping", "res://assets/sprites/Animations/mom/sleeping", 2, 12.0],
	["res://assets/sprites/Animations/frames/rooms/music_box_frames.tres", &"default", "res://assets/sprites/Animations/rooms/living_room/Music-box", 1, 24.0],
	["res://assets/sprites/Animations/frames/rooms/shower_frames.tres", &"default", "res://assets/sprites/Animations/rooms/bathroom", 1, 12.0],
	["res://assets/sprites/Animations/frames/windows/leaves01_frames.tres", &"default", "res://assets/sprites/Animations/background/Leaves01", 2, 12.0],
	["res://assets/sprites/Animations/frames/windows/leaves02_frames.tres", &"default", "res://assets/sprites/Animations/background/Leaves02", 2, 12.0],
	["res://assets/sprites/Animations/frames/windows/leaves03_frames.tres", &"default", "res://assets/sprites/Animations/background/Leaves03", 2, 12.0],
	["res://assets/sprites/Animations/frames/windows/leaves04_frames.tres", &"default", "res://assets/sprites/Animations/background/Leaves04", 2, 12.0, 1],
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
		var offset: int = job[5] if job.size() > 5 else 0
		for png in pngs:
			if posmod(_frame_number(png) - offset, job[3]) == 0:
				frames.add_frame(anim, load(job[2] + "/" + png))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		ResourceSaver.save(frames, path)
		print("%s: %s (%d frames)" % [path.get_file(), anim, frames.get_frame_count(anim)])

func _frame_number(file: String) -> int:
	var base := file.get_basename()
	return base.get_slice("_", base.get_slice_count("_") - 1).to_int()
