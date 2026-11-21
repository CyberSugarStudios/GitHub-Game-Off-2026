shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float gamma = 1.0;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	color = pow(max(color, vec3(0.0)), vec3(1.0 / gamma));
	color = (color - 0.5) * contrast + 0.5;
	COLOR = vec4(clamp(color * brightness, 0.0, 1.0), 1.0);
}