shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(0.82, 1.0, 0.95, 0.9);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 24.0;

void fragment() {
	float inside = texture(TEXTURE, UV).a;
	float ring = 0.0;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 0.39269908;
		vec2 dir = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * radius;
		ring = max(ring, texture(TEXTURE, UV + dir * 0.5).a);
		ring = max(ring, texture(TEXTURE, UV + dir).a * 0.45);
	}
	float edge = clamp(ring - inside, 0.0, 1.0);
	COLOR = vec4(glow_color.rgb, glow_color.a * edge * strength);
}