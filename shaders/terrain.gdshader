shader_type spatial;
// Dead grass, dirt and gravel. COLOR.r = gravel shoulder weight from the mesh.

uniform vec3 grass_a : source_color = vec3(0.07, 0.065, 0.03);
uniform vec3 grass_b : source_color = vec3(0.13, 0.08, 0.035);
uniform vec3 dirt : source_color = vec3(0.09, 0.055, 0.04);
uniform vec3 gravel : source_color = vec3(0.2, 0.18, 0.16);

varying vec3 wpos;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = noise(p * 0.15);
	float n2 = noise(p * 1.3);
	float n3 = noise(p * 6.0);
	vec3 g = mix(grass_a, grass_b, n1);
	g = mix(g, dirt, smoothstep(0.45, 0.75, n2 * 0.7 + n1 * 0.4));
	g *= 0.75 + n3 * 0.5;
	vec3 gr = gravel * (0.6 + n3 * 0.6 + n2 * 0.2);
	float gw = clamp(COLOR.r + (n2 - 0.5) * 0.4, 0.0, 1.0);
	ALBEDO = mix(g, gr, gw);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
