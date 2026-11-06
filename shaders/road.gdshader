shader_type spatial;
// Old, cracked asphalt. UV.x = lateral metres from centre, UV.y = distance metres.
render_mode cull_back;

uniform vec3 asphalt : source_color = vec3(0.075, 0.07, 0.072);
uniform vec3 asphalt_light : source_color = vec3(0.16, 0.15, 0.15);
uniform vec3 line_yellow : source_color = vec3(0.62, 0.45, 0.12);
uniform vec3 line_white : source_color = vec3(0.55, 0.53, 0.5);
uniform float half_width = 3.6;

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV;
	float n = fbm(p * vec2(1.6, 0.9));
	float grit = noise(p * 14.0);
	vec3 col = mix(asphalt, asphalt_light, n * 0.55 + grit * 0.18);

	// Patched repairs (darker rectangles).
	float patch = step(0.72, noise(floor(p * vec2(0.5, 0.18)) + 3.1));
	col = mix(col, asphalt * 0.55, patch * 0.7);

	// Cracks.
	float c = abs(fbm(p * vec2(0.9, 0.45) + 7.0) - 0.5);
	float crack = smoothstep(0.018, 0.0, c) * smoothstep(0.35, 0.6, noise(p * 0.3));
	col *= 1.0 - crack * 0.75;

	// Centre double yellow, worn.
	float wear = smoothstep(0.25, 0.6, noise(p * vec2(3.0, 0.7)));
	float cl = (step(abs(p.x - 0.12), 0.05) + step(abs(p.x + 0.12), 0.05));
	cl *= step(0.35, fract(p.y / 6.0)); // dashed gaps
	col = mix(col, line_yellow, clamp(cl, 0.0, 1.0) * wear * 0.85);
	// Edge lines.
	float el = step(abs(abs(p.x) - (half_width - 0.25)), 0.06);
	col = mix(col, line_white, el * wear * 0.7);

	// Puddles reflect the sky: darker, glossy.
	float puddle = smoothstep(0.62, 0.7, fbm(p * 0.22 + 21.0));
	col = mix(col, col * 0.35, puddle);

	ALBEDO = col;
	ROUGHNESS = mix(0.82, 0.08, puddle) - crack * 0.1;
	SPECULAR = mix(0.35, 0.9, puddle);
	METALLIC = 0.0;
}
