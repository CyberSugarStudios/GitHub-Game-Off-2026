shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

group_uniforms Grade;
uniform sampler2D grade_ramp : source_color, repeat_disable;
uniform float grade_amount : hint_range(0.0, 1.0) = 0.85;
uniform float accent_keep : hint_range(0.0, 1.0) = 0.8;
// Fog.
uniform vec3 haze_color : source_color = vec3(0.10, 0.38, 0.42);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.3;

group_uniforms Glow;
uniform float glow_amount : hint_range(0.0, 2.0) = 0.6;
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float glow_radius : hint_range(0.0, 0.02) = 0.004;

group_uniforms Distortion;
uniform float wave_amount : hint_range(0.0, 0.02) = 0.004;
uniform float wave_speed = 1.5;
uniform float wave_frequency = 12.0;
uniform float aberration : hint_range(0.0, 0.03) = 0.008;

group_uniforms Atmosphere;
uniform float vignette_amount : hint_range(0.0, 2.0) = 0.8;
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

	// Edge mask.
	float r = reach * 1.25;
	float mask = smoothstep(1.0 - r, 1.0 - r + 0.25, clamp(edge / 1.4142, 0.0, 1.0));
	float s = strength * mask;

	// Wobble.
	vec2 wave = vec2(
		sin(uv.y * wave_frequency + TIME * wave_speed),
		cos(uv.x * wave_frequency + TIME * wave_speed * 0.8)
	);
	uv += wave * wave_amount * s * wave_mix * (0.3 + edge);

	// Chromatic aberration.
	vec2 split = from_center * aberration * s * aberration_mix * edge;
	vec3 color;
	color.r = texture(screen_texture, uv + split).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - split).b;

	// Glow.
	vec3 bright = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		vec2 offset = vec2(cos(angle), sin(angle)) * glow_radius;
		bright += max(texture(screen_texture, uv + offset).rgb - glow_threshold, vec3(0.0));
	}
	bright /= 8.0;

	// Grade.
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 graded = texture(grade_ramp, vec2(clamp(luma, 0.0, 1.0), 0.5)).rgb;
	float saturation = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
	float keep = smoothstep(0.35, 0.7, saturation) * accent_keep;
	color = mix(color, graded, grade_amount * (1.0 - keep) * s);

	// Haze.
	color = mix(color, haze_color, haze_amount * (1.0 - luma) * s);

	// Neon glow, in the ramp's bright teal.
	vec3 glow_tint = texture(grade_ramp, vec2(0.85, 0.5)).rgb;
	color += bright * glow_tint * glow_amount * s * 2.0;

	// Vignette.
	float vignette = 1.0 - smoothstep(0.4, 1.4, edge) * vignette_amount * s;
	color *= clamp(vignette, 0.0, 1.0);

	// Grain.
	float noise = random(uv + fract(TIME)) - 0.5;
	color += noise * grain_amount * s * grain_mix;

	COLOR = vec4(color, 1.0);
}