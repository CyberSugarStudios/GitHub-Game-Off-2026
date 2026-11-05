shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float fill : hint_range(0.0, 1.0) = 0.0; //0 empty, 1 full
uniform vec4 fill_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec4 empty_color : source_color = vec4(0.12, 0.12, 0.16, 1.0);

//thin dark bar around frame
uniform float frame_thickness : hint_range(0.0, 0.3) = 0.12;
uniform vec4 frame_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);

void fragment() {
	float height = 1.0 - UV.y;
	vec3 color = height <= fill ? fill_color.rgb : empty_color.rgb;
	
	bool on_frame = UV.x < frame_thickness ||  UV.x > 1.0 - frame_thickness || UV.y < frame_thickness * 0.5
	|| UV.y > 1.0 - frame_thickness * 0.5;
	if (on_frame) {
		color = frame_color.rgb;
	}
	
	ALBEDO = color;
}
