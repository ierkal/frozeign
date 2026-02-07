shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);
uniform vec4 bottom_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
	float t = smoothstep(0.0, 1.0, UV.y);
	vec4 gradient = mix(top_color, bottom_color, t);
	COLOR = vec4(gradient.rgb, gradient.a * COLOR.a);
}
