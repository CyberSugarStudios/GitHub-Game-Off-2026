shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D room_view : source_color, filter_linear, repeat_disable;
uniform vec3 box_size = vec3(6.0, 2.6, 3.0);
uniform float floor_offset = 1.02;
uniform mat3 back_map;
uniform mat3 floor_map;
uniform mat3 ceiling_map;
uniform mat3 left_map;
uniform mat3 right_map;

uniform float corner_shadow : hint_range(0.0, 1.0) = 0.35;
uniform float corner_width = 0.4;
uniform float ceiling_shade : hint_range(0.0, 1.0) = 0.5;
uniform float edge_shadow : hint_range(0.0, 1.0) = 0.55;
uniform float edge_width : hint_range(0.0, 0.5) = 0.18;
uniform float past_walls = 1.0;
uniform float past_floor = 20.0;
uniform int debug_mode = 0;

varying vec3 pos;
varying vec3 eye;

void vertex() {
	vec3 lift = vec3(0.0, floor_offset, 0.0);
	pos = VERTEX + lift;
	eye = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz + lift;
}

void fragment() {
	vec3 ray = normalize(pos - eye);
	vec3 lo = vec3(-box_size.x * 0.5, 0.0, -box_size.z);
	vec3 hi = vec3(box_size.x * 0.5, box_size.y, 0.0);
	vec3 exits = (mix(lo, hi, step(0.0, ray)) - pos) / ray;
	int face = 2;
	float t = exits.z;
	if (exits.y < t) {
		face = 1;
		t = exits.y;
	}
	if (exits.x < t) {
		face = 0;
		t = exits.x;
	}
	vec3 hit = pos + ray * t;

	vec3 n = (hit - lo) / box_size;	// x: left to right, y: floor to ceiling, z: back wall to doorway
	vec3 mapped;
	bool on_ceiling = false;
	if (face == 2) {
		mapped = back_map * vec3(n.x, 1.0 - n.y, 1.0);
	} else if (face == 1) {
		on_ceiling = ray.y > 0.0;
		if (on_ceiling) {
			mapped = ceiling_map * vec3(n.x, n.z, 1.0);
		} else {
			mapped = floor_map * vec3(n.x, n.z, 1.0);
		}
	} else if (ray.x < 0.0) {
		mapped = left_map * vec3(n.z, 1.0 - n.y, 1.0);
	} else {
		mapped = right_map * vec3(n.z, 1.0 - n.y, 1.0);
	}
	vec3 color = texture(room_view, clamp(mapped.xy / mapped.z, 0.0, 1.0)).rgb;

	vec3 gaps = min(hit - lo, hi - hit);
	gaps.z = hit.z - lo.z;
	float corner = max(min(gaps.x, gaps.y), min(max(gaps.x, gaps.y), gaps.z));
	color *= mix(1.0 - corner_shadow, 1.0, smoothstep(0.0, corner_width, corner));
	if (on_ceiling) {
		color *= ceiling_shade;
	}

	float sides = smoothstep(0.0, edge_width, min(UV.x, 1.0 - UV.x));
	float top = smoothstep(0.0, edge_width * 0.6, UV.y);
	color *= mix(1.0 - edge_shadow, 1.0, sides * top);
	if (debug_mode == 1) {
		color = vec3(0.85, 0.25, 0.85);
	} else if (debug_mode == 4) {
		color = face == 2 ? vec3(0.2, 0.35, 0.95) : (face == 0 ? vec3(0.95, 0.25, 0.2) : (on_ceiling ? vec3(0.95, 0.9, 0.2) : vec3(0.2, 0.85, 0.35)));
	}
	ALBEDO = color;

	float past = (face == 1 && ray.y < 0.0) ? past_floor : past_walls;
	if (debug_mode == 2) {
		past = 0.0;
	}
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * vec4(hit + ray * past - vec3(0.0, floor_offset, 0.0), 1.0);
	float ndc = clip.z / clip.w;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	DEPTH = ndc * 0.5 + 0.5;
#else
	DEPTH = ndc;
#endif
	if (debug_mode == 3) {
		DEPTH = FRAGCOORD.z;
	}
}