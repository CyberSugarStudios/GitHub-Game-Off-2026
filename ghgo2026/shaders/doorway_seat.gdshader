shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D actors_view : source_color, filter_linear, repeat_disable;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform mat3 plane_map;
uniform mat4 to_room;

varying float room_z;

void vertex() {
	room_z = (to_room * MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec3 mapped = plane_map * vec3(UV, 1.0);
	vec2 room_uv = mapped.xy / mapped.z;
	if (room_z > 0.0 || any(lessThan(room_uv, region.xy)) || any(greaterThan(room_uv, region.zw))) {
		discard;
	}
	vec4 color = texture(actors_view, room_uv);
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}