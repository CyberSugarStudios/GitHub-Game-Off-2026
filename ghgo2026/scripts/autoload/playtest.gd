extends Node

const FORM_ID := "1FAIpQLSfatGLctTLhUCTkvCQmdYIMcUE2KsamTFjJ7h2SW3QfrAiRWw"
const DEBUG_ENTRY := "entry.2135919735"
const HITCH_SECONDS := 0.25
const BACKGROUND_SECONDS := 3.0
const MAX_HITCHES := 8
const RENDERER_JS := """
	(function () {
		try {
			var canvas = document.createElement('canvas');
			var gl = canvas.getContext('webgl2', { failIfMajorPerformanceCaveat: true });
			var slow = !gl;
			if (!gl) { gl = canvas.getContext('webgl2') || canvas.getContext('webgl'); }
			if (!gl) { return 'none|1'; }
			var info = gl.getExtension('WEBGL_debug_renderer_info');
			var name = info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
			return name + '|' + (slow ? '1' : '0');
		} catch (e) {
			return 'unknown|0';
		}
	})()
	"""

const CLIENT_JS := """
	(function () {
		var info = { ua: navigator.userAgent };
		try {
			var ua = navigator.userAgent;
			var data = navigator.userAgentData;
			var brands = (data && data.brands) ? data.brands.filter(function (b) {
				return b.brand.indexOf('Brand') < 0 && b.brand !== 'Chromium';
			}) : [];
			if (brands.length) {
				info.browser = brands.map(function (b) { return b.brand + ' ' + b.version; }).join(' / ');
			} else {
				var checks = [['Edg/', 'Edge'], ['OPR/', 'Opera'], ['Firefox/', 'Firefox'], ['Chrome/', 'Chrome'], ['Version/', 'Safari']];
				for (var i = 0; i < checks.length; i++) {
					var at = ua.indexOf(checks[i][0]);
					if (at >= 0) {
						info.browser = checks[i][1] + ' ' + ua.substring(at + checks[i][0].length).split(' ')[0];
						break;
					}
				}
			}
			info.platform = (data && data.platform) || navigator.platform || '';
			info.threads = navigator.hardwareConcurrency || 0;
			info.memory = navigator.deviceMemory || 0;
			info.dpr = window.devicePixelRatio || 1;
			var gl = document.createElement('canvas').getContext('webgl2');
			if (gl) {
				var dbg = gl.getExtension('WEBGL_debug_renderer_info');
				info.gl_vendor = dbg ? gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR);
				info.max_texture = gl.getParameter(gl.MAX_TEXTURE_SIZE);
				var high = gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT);
				info.frag_highp = high ? high.precision : 0;
				info.float_buffers = !!gl.getExtension('EXT_color_buffer_float');
				var lose = gl.getExtension('WEBGL_lose_context');
				if (lose) { lose.loseContext(); }
			}
		} catch (e) {
			info.error = String(e);
		}
		return JSON.stringify(info);
	})()
	"""
const CONTEXT_WATCH_JS := """
	(function () {
		if (window._interimLost !== undefined) { return; }
		window._interimLost = 0;
		var canvas = document.getElementById('canvas') || document.querySelector('canvas');
		if (canvas) {
			canvas.addEventListener('webglcontextlost', function () { window._interimLost++; });
		}
	})()
	"""

class ErrorLog extends Logger:
	const MAX_KEPT := 10
	var total := 0
	var _kept := PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kinds := ["error", "warning", "script", "shader"]
		var kind: String = kinds[error_type] if error_type < kinds.size() else "error"
		var text := ("%s: %s (%s:%d %s)" % [kind, rationale if rationale != "" else code,
				file.get_file(), line, function]).left(240)
		_mutex.lock()
		total += 1
		if _kept.size() < MAX_KEPT and not _kept.has(text):
			_kept.append(text)
		_mutex.unlock()

	func kept() -> PackedStringArray:
		_mutex.lock()
		var copy := _kept.duplicate()
		_mutex.unlock()
		return copy

var _renderer := ""
var _software := false
var _renderer_checked := false
var _client: Dictionary = {}
var _errors := ErrorLog.new()

var _started_at := 0
var _hitches := PackedStringArray()
var _hitch_count := 0
var _last_event := "start"
var _last_event_at := 0
var _fps_total := 0.0
var _fps_samples := 0
var _fps_low := INF
var _sample_clock := 0.0
var _load_clicked := -1
var _load_marks := PackedStringArray()

func is_enabled() -> bool:
	return OS.is_debug_build() or OS.has_feature("playtest")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_at = Time.get_ticks_msec()
	_last_event_at = _started_at
	set_process(is_enabled())
	if not is_enabled():
		return
	OS.add_logger(_errors)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(CONTEXT_WATCH_JS, true)
	GameState.room_changed.connect(func(room: StringName) -> void:
		_note("entered %s" % (room if room != &"" else &"hall")))
	GameState.plane_changed.connect(func(astral: bool) -> void:
		_note("astral on" if astral else "astral off"))
	Events.story_event.connect(func(id: StringName) -> void:
		_note("event %s" % id))
	Events.conversation_requested.connect(func(_dialogue: DialogueResource, title: String, _frozen: bool) -> void:
		_note("line %s" % title))
	Events.creature_moment.connect(func(kind: StringName) -> void:
		_note("creature %s" % kind))

func _process(delta: float) -> void:
	if Time.get_ticks_msec() - _started_at < 5000:
		return
	if delta >= HITCH_SECONDS and delta < BACKGROUND_SECONDS:
		_record_hitch(delta)
	_sample_clock += delta
	if _sample_clock < 1.0:
		return
	_sample_clock = 0.0
	var fps := Engine.get_frames_per_second()
	_fps_total += fps
	_fps_samples += 1
	_fps_low = minf(_fps_low, fps)

func start_load_clock() -> void:
	_load_clicked = Time.get_ticks_msec()
	_load_marks.clear()

func mark_load(what: String) -> void:
	if _load_clicked < 0:
		return
	var entry := "%s %.2f s" % [what, (Time.get_ticks_msec() - _load_clicked) / 1000.0]
	_load_marks.append(entry)
	print("[LOAD] ", entry)

func _note(what: String) -> void:
	_last_event = what
	_last_event_at = Time.get_ticks_msec()

func _record_hitch(delta: float) -> void:
	_hitch_count += 1
	var now := Time.get_ticks_msec()
	var place := String(GameState.current_room) if GameState.is_in_room() else "hall"
	var entry := "%.2f s at %.1f min: stage %d, %s, %s, %.1f s after %s" % [
		delta, (now - _started_at) / 60000.0, GameState.story_stage, place,
		"astral" if GameState.in_astral else "living", (now - _last_event_at) / 1000.0, _last_event]
	if _hitches.size() < MAX_HITCHES:
		_hitches.append(entry)
	print("[HITCH] ", entry)

func web_renderer() -> String:
	_check_renderer()
	return _renderer

func is_software_rendering() -> bool:
	_check_renderer()
	return _software

func _check_renderer() -> void:
	if _renderer_checked or not OS.has_feature("web"):
		return
	_renderer_checked = true
	var parts := str(JavaScriptBridge.eval(RENDERER_JS, true)).split("|")
	_renderer = parts[0]
	var lower := _renderer.to_lower()
	_software = (parts.size() > 1 and parts[1] == "1") or "swiftshader" in lower \
		or "llvmpipe" in lower or "software" in lower or "basic render" in lower

func _client_info() -> Dictionary:
	if _client.is_empty() and OS.has_feature("web"):
		var parsed = JSON.parse_string(str(JavaScriptBridge.eval(CLIENT_JS, true)))
		_client = parsed if parsed is Dictionary else {"browser": "unknown"}
	return _client

func _context_losses() -> int:
	return int(JavaScriptBridge.eval("window._interimLost || 0", true)) if OS.has_feature("web") else 0

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
	var client := _client_info()
	if OS.has_feature("web"):
		lines.append("Browser: %s on %s" % [client.get("browser", "unknown"), client.get("platform", "?")])
		lines.append("User agent: %s" % client.get("ua", ""))
		var ram := "%s GB (browser estimate)" % str(client["memory"]) if client.get("memory", 0) else "not reported"
		lines.append("CPU threads: %d, RAM: %s" % [int(client.get("threads", 0)), ram])
	else:
		lines.append("CPU: %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	var memory: Dictionary = OS.get_memory_info()
	if memory.get("physical", -1) > 0:
		lines.append("RAM: %.1f GB" % (memory["physical"] / 1073741824.0))
	if OS.has_feature("web"):
		lines.append("WebGL renderer: %s%s" % [web_renderer(), " (SOFTWARE: acceleration off)" if is_software_rendering() else ""])
		lines.append("WebGL: vendor %s, max texture %d, fragment highp bits %d, float buffers %s, context lost %d times" % [
				client.get("gl_vendor", "?"), int(client.get("max_texture", 0)), int(client.get("frag_highp", 0)),
				"yes" if client.get("float_buffers", false) else "no", _context_losses()])
	else:
		lines.append("GPU: %s %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()])
	lines.append("Renderer: %s" % RenderingServer.get_current_rendering_method())
	var screen := "Screen: %s, window: %s" % [DisplayServer.screen_get_size(), DisplayServer.window_get_size()]
	if OS.has_feature("web"):
		screen += ", pixel ratio %s" % str(client.get("dpr", "?"))
	lines.append(screen)
	lines.append("Language: %s" % OS.get_locale())
	if _fps_samples > 0:
		lines.append("FPS: avg %d, low %d" % [roundi(_fps_total / _fps_samples), roundi(_fps_low)])
	if not _load_marks.is_empty():
		lines.append("Load (from click): %s" % ", ".join(_load_marks))
	if _hitch_count > 0:
		lines.append("Hitches (%.2f s or longer): %d" % [HITCH_SECONDS, _hitch_count])
		for hitch in _hitches:
			lines.append("  " + hitch)
	if _errors.total > 0:
		lines.append("Engine errors/warnings: %d" % _errors.total)
		for error in _errors.kept():
			lines.append("  " + error)
	lines.append("Progress: stage %d, %d bars, day %d %s, in %s" % [GameState.story_stage, GameState.max_bars,
			GameClock.day, GameClock.get_time_text(), String(GameState.current_room) if GameState.is_in_room() else "hall"])
	lines.append("Flags: %s" % ", ".join(PackedStringArray(GameState.flags.keys())))
	return "\n".join(lines)
