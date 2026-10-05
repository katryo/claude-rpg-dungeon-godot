shader_type canvas_item;
// Screen transition: a plain fade plus a diagonal diamond wipe.

uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float wipe : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 cell = FRAGCOORD.xy / 48.0;
	vec2 f = abs(fract(cell) - 0.5);
	float d = f.x + f.y;
	float w = wipe * 2.2 - (SCREEN_UV.x + SCREEN_UV.y) * 0.6;
	float a = max(fade, step(d, w));
	COLOR = vec4(tint.rgb, a * tint.a);
}
