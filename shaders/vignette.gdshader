shader_type canvas_item;
// Soft purple-black vignette over the whole screen.

uniform float strength : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.25;
	float v = smoothstep(0.32, 0.9, length(uv));
	COLOR = vec4(0.02, 0.0, 0.05, v * strength);
}
