shader_type canvas_item;
render_mode unshaded;

uniform vec3 light_color = vec3(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(tex.rgb, vec3(lum), tint_amount) * light_color, COLOR.a);
}