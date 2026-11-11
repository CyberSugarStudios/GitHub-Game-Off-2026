shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

group_uniforms Color;
uniform vec3 astral_tint : source_color = vec3(0.35, 0.75, 0.85);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.55;
uniform float desaturation : hint_range(0.0, 1.0) = 0.7;

group_uniforms Distortion;
uniform float wave_amount : hint_range(0.0, 0.02) = 0.004;
uniform float wave_speed = 1.5;
uniform float wave_frequency = 12.0;
uniform float aberration : hint_range(0.0, 0.03) = 0.008;

group_uniforms Atmosphere;
uniform float vignette_amount : hint_range(0.0, 2.0) = 1.1;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.04;

group_uniforms Focus;
uniform float reach : hint_range(0.0, 1.0) = 1.0;
uniform float wave_mix : hint_range(0.0, 1.0) = 1.0;
uniform float aberration_mix : hint_range(0.0, 1.0) = 1.0;
uniform float grain_mix : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - 0.5;
	float edge = length(from_center) * 2.0;

	// edge mask
	float r = reach * 1.25;
	float mask = smoothstep(1.0 - r, 1.0 - r + 0.25, clamp(edge / 1.4142, 0.0, 1.0));
	float s = strength * mask;

	// wobble
	vec2 wave = vec2(
		sin(uv.y * wave_frequency + TIME * wave_speed),
		cos(uv.x * wave_frequency + TIME * wave_speed * 0.8)
	);
	uv += wave * wave_amount * s * wave_mix * (0.3 + edge);

	// chromatic aberration
	vec2 split = from_center * aberration * s * aberration_mix * edge;
	vec3 color;
	color.r = texture(screen_texture, uv + split).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - split).b;

	// color
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma), desaturation * s);
	color = mix(color, luma * astral_tint * 1.6, tint_amount * s);

	// vignette
	float vignette = 1.0 - smoothstep(0.4, 1.4, edge) * vignette_amount * s;
	color *= clamp(vignette, 0.0, 1.0);

	// grain
	float noise = random(uv + fract(TIME)) - 0.5;
	color += noise * grain_amount * s * grain_mix;

	COLOR = vec4(color, 1.0);
}