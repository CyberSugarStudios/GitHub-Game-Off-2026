shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D props_view : source_color, filter_linear, repeat_disable;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform mat4 to_room;

varying float room_z;

void vertex() {
	room_z = (to_room * MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	if (room_z > 0.0) {
		discard;
	}
	vec4 color = texture(props_view, mix(region.xy, region.zw, UV));
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}