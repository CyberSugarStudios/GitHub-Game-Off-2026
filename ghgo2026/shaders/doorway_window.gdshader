shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D room_view : source_color, filter_linear, repeat_disable;
uniform vec3 box_size = vec3(6.0, 2.6, 3.0);
uniform vec3 paint_eye = vec3(0.0, 1.5, 4.0);
uniform vec4 wall_rect = vec4(0.2, 0.05, 0.8, 0.75);
uniform float floor_offset = 1.02;

uniform float corner_shadow : hint_range(0.0, 1.0) = 0.35;
uniform float corner_width = 0.4;
uniform float ceiling_shade : hint_range(0.0, 1.0) = 0.5;
uniform float edge_shadow : hint_range(0.0, 1.0) = 0.55;
uniform float edge_width : hint_range(0.0, 0.5) = 0.18;

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
	vec3 hit = pos + ray * min(exits.x, min(exits.y, exits.z));

	float spread = (paint_eye.z + box_size.z) / (paint_eye.z - hit.z);
	vec2 wall = paint_eye.xy + (hit.xy - paint_eye.xy) * spread;
	vec2 uv = vec2(
		mix(wall_rect.x, wall_rect.z, wall.x / box_size.x + 0.5),
		mix(wall_rect.w, wall_rect.y, wall.y / box_size.y));
	vec3 color = texture(room_view, clamp(uv, 0.0, 1.0)).rgb;

	vec3 gaps = min(hit - lo, hi - hit);
	gaps.z = hit.z - lo.z;
	float corner = max(min(gaps.x, gaps.y), min(max(gaps.x, gaps.y), gaps.z));
	color *= mix(1.0 - corner_shadow, 1.0, smoothstep(0.0, corner_width, corner));
	if (hit.y > box_size.y - 0.01) {
		color *= ceiling_shade;
	}

	float sides = smoothstep(0.0, edge_width, min(UV.x, 1.0 - UV.x));
	float top = smoothstep(0.0, edge_width * 0.6, UV.y);
	color *= mix(1.0 - edge_shadow, 1.0, sides * top);
	ALBEDO = color;
}