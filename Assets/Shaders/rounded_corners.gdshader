shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 0.5) = 0.05;

void fragment() {
	vec2 uv = UV;
	vec4 tex_color = texture(TEXTURE, uv);

	// Get the size ratio for proper corner calculation
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	float aspect = size.x / size.y;

	// Normalize radius based on smaller dimension
	float radius = corner_radius;

	// Calculate distance from corners
	vec2 pos = uv;
	vec2 corner_dist = vec2(0.0);

	// Check each corner region
	if (pos.x < radius && pos.y < radius * aspect) {
		// Top-left corner
		corner_dist = vec2(radius - pos.x, (radius * aspect) - pos.y);
	} else if (pos.x > 1.0 - radius && pos.y < radius * aspect) {
		// Top-right corner
		corner_dist = vec2(pos.x - (1.0 - radius), (radius * aspect) - pos.y);
	} else if (pos.x < radius && pos.y > 1.0 - (radius * aspect)) {
		// Bottom-left corner
		corner_dist = vec2(radius - pos.x, pos.y - (1.0 - (radius * aspect)));
	} else if (pos.x > 1.0 - radius && pos.y > 1.0 - (radius * aspect)) {
		// Bottom-right corner
		corner_dist = vec2(pos.x - (1.0 - radius), pos.y - (1.0 - (radius * aspect)));
	}

	// Calculate if we're outside the rounded corner
	float dist = length(corner_dist / vec2(radius, radius * aspect));
	float alpha = 1.0 - smoothstep(0.95, 1.0, dist);

	COLOR = vec4(tex_color.rgb, tex_color.a * alpha);
}
