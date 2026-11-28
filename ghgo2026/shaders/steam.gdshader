shader_type canvas_item;

uniform sampler2D noise : repeat_enable, filter_linear;
uniform float noise_scale = 0.004;
uniform vec2 drift = vec2(0.01, -0.04);
uniform float wispiness : hint_range(0.0, 1.0) = 0.5;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 puff = texture(TEXTURE, UV) * COLOR;
	float n = texture(noise, world * noise_scale + drift * TIME).r;
	puff.a *= mix(1.0, smoothstep(0.3, 0.8, n), wispiness);
	COLOR = puff;
}