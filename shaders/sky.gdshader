shader_type sky;
// Blood-red "other world" sky: glowing horizon, black zenith, drifting storm
// clouds lit from below, a sick crimson moon and lightning flashes.

uniform vec3 zenith_color : source_color = vec3(0.012, 0.0, 0.004);
uniform vec3 mid_color : source_color = vec3(0.16, 0.012, 0.014);
uniform vec3 horizon_color : source_color = vec3(0.85, 0.12, 0.05);
uniform vec3 cloud_lit : source_color = vec3(0.55, 0.07, 0.05);
uniform vec3 cloud_dark : source_color = vec3(0.03, 0.0, 0.005);
uniform vec3 moon_dir = vec3(0.25, 0.22, -0.94);
uniform float flash = 0.0;
uniform float time_scale = 0.012;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	// Base gradient.
	float hz = pow(1.0 - clamp(h, 0.0, 1.0), 6.0);
	float mid = pow(1.0 - clamp(h, 0.0, 1.0), 2.0);
	vec3 col = mix(zenith_color, mid_color, mid);
	col = mix(col, horizon_color, hz);
	// Below horizon: dark (hidden by terrain anyway).
	col = mix(col, horizon_color * 0.35, smoothstep(0.0, -0.08, h));

	// Clouds projected on a dome.
	if (h > -0.02) {
		vec2 uv = d.xz / (h + 0.18);
		float t = TIME * time_scale;
		float c = fbm(uv * 1.2 + vec2(t, t * 0.4));
		float c2 = fbm(uv * 2.7 - vec2(t * 1.7, 0.0));
		float dens = smoothstep(0.42, 0.78, c * 0.75 + c2 * 0.35);
		// Clouds near horizon are lit red from below, high ones nearly black.
		vec3 cl = mix(cloud_dark, cloud_lit, clamp(hz * 1.4 + (1.0 - c2) * 0.2, 0.0, 1.0));
		cl += vec3(1.0, 0.5, 0.45) * flash * (0.6 + c2);
		float fade = smoothstep(-0.02, 0.12, h);
		col = mix(col, cl, dens * fade * 0.92);
		// Veins of light in the clouds (the "storm").
		float vein = smoothstep(0.02, 0.0, abs(c2 - 0.5)) * dens;
		col += vec3(0.9, 0.15, 0.08) * vein * (0.12 + flash * 1.5) * fade;
	}

	// Crimson moon with halo.
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	col += vec3(1.0, 0.25, 0.15) * smoothstep(0.9993, 0.9996, m) * 1.6;
	col += vec3(0.6, 0.06, 0.03) * pow(max(m, 0.0), 180.0) * 0.8;
	col += vec3(0.35, 0.03, 0.02) * pow(max(m, 0.0), 14.0) * 0.25;

	col += vec3(0.5, 0.15, 0.15) * flash * 0.25;
	COLOR = col;
}
