shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 screen_color = texture(screen_texture, SCREEN_UV);
	vec3 color = screen_color.rgb;

	// Apply brightness
	color += brightness;

	// Apply contrast (centered around 0.5)
	color = (color - 0.5) * contrast + 0.5;

	// Apply saturation
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, saturation);

	// Apply color tint (multiply blend)
	color = mix(color, color * tint_color.rgb, tint_strength);

	// Clamp to valid range
	color = clamp(color, 0.0, 1.0);

	// Mix between original and adjusted based on intensity
	vec3 final_color = mix(screen_color.rgb, color, intensity);

	COLOR = vec4(final_color, screen_color.a);
}
