shader_type canvas_item;
// Full-screen 80s camcorder look: chromatic fringe, grain, scanlines, vignette,
// occasional tracking glitch. `danger` pulses the edges red.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float aberration = 0.0016;
uniform float grain = 0.055;
uniform float scan = 0.06;
uniform float vignette = 0.55;
uniform float glitch = 0.0;
uniform float danger = 0.0;
uniform float flash = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Tracking glitch: horizontal tear band.
	float band = step(0.985 - glitch * 0.25, rand(vec2(floor(uv.y * 40.0), floor(TIME * 12.0))));
	uv.x += band * (rand(vec2(TIME, uv.y)) - 0.5) * 0.03 * (0.3 + glitch);
	vec2 dir = uv - 0.5;
	float ab = aberration * (1.0 + glitch * 4.0) * (0.4 + length(dir) * 1.6);
	vec3 col;
	col.r = texture(screen_tex, uv + dir * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * ab).b;
	// Scanlines.
	col *= 1.0 - scan * (0.5 + 0.5 * sin(SCREEN_UV.y * 900.0));
	// Grain.
	float g = rand(SCREEN_UV * 731.0 + fract(TIME * 7.13)) - 0.5;
	col += g * grain;
	// Vignette.
	float v = smoothstep(0.85, 0.2, length(dir * vec2(1.15, 1.0)));
	col *= mix(1.0 - vignette, 1.0, v);
	// Danger pulse.
	col = mix(col, vec3(0.55, 0.0, 0.02), danger * (1.0 - v) * 0.85);
	col += vec3(1.0, 0.85, 0.85) * flash;
	// Slight warm film tint.
	col = pow(max(col, vec3(0.0)), vec3(1.02, 1.0, 1.04));
	COLOR = vec4(col, 1.0);
}
