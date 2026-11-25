shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D art_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D light_view : source_color, filter_linear, repeat_disable;
uniform mat3 art_from_room = mat3(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform mat3 plane_map;
uniform mat4 to_room;

varying float room_z;

void vertex() {
	room_z = (to_room * MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec3 mapped = plane_map * vec3(UV, 1.0);
	vec2 room_uv = mapped.xy / mapped.z;
	vec2 art_uv = (art_from_room * vec3(room_uv, 1.0)).xy;
	if (room_z > 0.0 || any(lessThan(art_uv, vec2(0.0))) || any(greaterThan(art_uv, vec2(1.0)))) {
		discard;
	}
	vec4 art = texture(art_texture, art_uv) * tint;
	ALBEDO = art.rgb * texture(light_view, room_uv).rgb;
	ALPHA = art.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}