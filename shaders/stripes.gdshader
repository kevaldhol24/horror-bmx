shader_type spatial;
// Retro-reflective red/white barricade stripes (catch the headlight).
uniform vec3 red : source_color = vec3(0.75, 0.04, 0.03);
uniform vec3 white : source_color = vec3(0.85, 0.82, 0.78);

void fragment() {
	float st = step(0.5, fract((UV.x * 3.0 + UV.y * 1.0) * 2.5));
	vec3 c = mix(red, white, st);
	ALBEDO = c;
	ROUGHNESS = 0.35;
	SPECULAR = 0.9;
	EMISSION = c * 0.06;
}
