extends Node

const FORM_ID := "1FAIpQLSfatGLctTLhUCTkvCQmdYIMcUE2KsamTFjJ7h2SW3QfrAiRWw"
const DEBUG_ENTRY := "entry.2135919735"

var _started_at := 0
var _fps_total := 0.0
var _fps_samples := 0
var _fps_low := INF
var _sample_clock := 0.0

func is_enabled() -> bool:
	return OS.is_debug_build() or OS.has_feature("playtest")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_at = Time.get_ticks_msec()
	set_process(is_enabled())

func _process(delta: float) -> void:
	if Time.get_ticks_msec() - _started_at < 5000:
		return
	_sample_clock += delta
	if _sample_clock < 1.0:
		return
	_sample_clock = 0.0
	var fps := Engine.get_frames_per_second()
	_fps_total += fps
	_fps_samples += 1
	_fps_low = minf(_fps_low, fps)

func open_form() -> void:
	var url := "https://docs.google.com/forms/d/e/%s/viewform?usp=pp_url&%s=%s" \
			% [FORM_ID, DEBUG_ENTRY, build_report().uri_encode()]
	OS.shell_open(url)

func build_report() -> String:
	var lines := PackedStringArray()
	var zone := Time.get_time_zone_from_system()
	lines.append("Game: %s (%s build)" % [ProjectSettings.get_setting("application/config/version"),
			"debug" if OS.is_debug_build() else "release"])
	lines.append("Godot: %s" % Engine.get_version_info().string)
	lines.append("Local time: %s (%s)" % [Time.get_datetime_string_from_system(false, true), zone.get("name", "?")])
	lines.append("Session: %.1f min" % ((Time.get_ticks_msec() - _started_at) / 60000.0))
	lines.append("OS: %s %s" % [OS.get_name(), OS.get_version()])
	if OS.has_feature("web"):
		lines.append("Browser: %s" % str(JavaScriptBridge.eval("navigator.userAgent", true)))
	lines.append("CPU: %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	var memory: Dictionary = OS.get_memory_info()
	if memory.get("physical", -1) > 0:
		lines.append("RAM: %.1f GB" % (memory["physical"] / 1073741824.0))
	lines.append("GPU: %s %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()])
	lines.append("Renderer: %s" % RenderingServer.get_current_rendering_method())
	lines.append("Screen: %s, window: %s" % [DisplayServer.screen_get_size(), DisplayServer.window_get_size()])
	lines.append("Language: %s" % OS.get_locale())
	if _fps_samples > 0:
		lines.append("FPS: avg %d, low %d" % [roundi(_fps_total / _fps_samples), roundi(_fps_low)])
	lines.append("Progress: stage %d, %d bars, day %d %s, in %s" % [GameState.story_stage, GameState.max_bars,
			GameClock.day, GameClock.get_time_text(), String(GameState.current_room) if GameState.is_in_room() else "hall"])
	lines.append("Flags: %s" % ", ".join(PackedStringArray(GameState.flags.keys())))
	return "\n".join(lines)
