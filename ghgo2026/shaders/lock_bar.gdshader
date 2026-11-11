shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix;

uniform float fill : hint_range(0.0, 1.0) = 0.0; // 0 empty, 1 full (fills left to right)
uniform sampler2D fill_texture : source_color, filter_linear_mipmap;
uniform vec4 fill_tint : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.85, 0.82, 0.95, 0.55);
uniform float outline_width : hint_range(0.0, 0.3) = 0.08;
uniform float aspect = 2.0;uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 size = vec2(aspect, 1.0);
	vec2 p = (UV - 0.5) * size;
	float d = rounded_box(p, size * 0.5, 0.5);
	if (d > 0.0) {
		discard;
	}

	vec3 color;
	float alpha;
	if (UV.x <= fill) {
		color = texture(fill_texture, UV).rgb * fill_tint.rgb;
		alpha = 1.0;
	} else {
		color = outline_color.rgb;
		alpha = (d > -outline_width) ? outline_color.a : 0.0;
	}
	color = mix(color, vec3(1.0), flash * 0.7);
	ALBEDO = color;
	ALPHA = alpha * opacity;
}