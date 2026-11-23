shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.714, 0.682, 0.604, 0.4);
uniform float feather = 0.2;

void fragment() {
	vec2 to_edge = min(UV, 1.0 - UV);
	float soft = smoothstep(0.0, feather, min(to_edge.x, to_edge.y));
	COLOR *= vec4(tint.rgb, tint.a * soft);
}