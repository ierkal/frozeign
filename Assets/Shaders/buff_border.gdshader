shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float border_width : hint_range(0.0, 0.5) = 0.15;
uniform float fade_power : hint_range(0.5, 5.0) = 2.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;

	// Distance from each edge
	float left = uv.x;
	float right = 1.0 - uv.x;
	float top = uv.y;
	float bottom = 1.0 - uv.y;

	// Minimum distance to any edge
	float edge_dist = min(min(left, right), min(top, bottom));

	// Create gradient from edge inward
	float gradient = 1.0 - smoothstep(0.0, border_width, edge_dist);
	gradient = pow(gradient, fade_power);

	// Apply color with intensity
	COLOR = vec4(border_color.rgb, gradient * border_color.a * intensity);
}
