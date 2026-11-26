shader_type canvas_item;

uniform vec4 ink : source_color = vec4(0.8, 0.804, 0.769, 1.0);

void fragment() {
	COLOR = vec4(ink.rgb, ink.a * COLOR.a);
}