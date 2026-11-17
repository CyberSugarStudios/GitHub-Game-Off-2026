shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D room_view : source_color, filter_linear;
uniform float edge_shadow : hint_range(0.0, 1.0) = 0.55;
uniform float edge_width : hint_range(0.0, 0.5) = 0.18;

void fragment() {
	vec3 color = texture(room_view, UV).rgb;
	float sides = smoothstep(0.0, edge_width, min(UV.x, 1.0 - UV.x));
	float top = smoothstep(0.0, edge_width * 0.6, UV.y);
	color *= mix(1.0 - edge_shadow, 1.0, sides * top);
	ALBEDO = color;
}