shader_type sky;
// "The rift": dark bruised storm clouds over the town, torn open ahead by a
// glowing red-orange wound with branching veins, lighting the cloud undersides.

uniform vec3 zenith_color : source_color = vec3(0.04, 0.035, 0.05);
uniform vec3 horizon_color : source_color = vec3(0.16, 0.07, 0.08);
uniform vec3 cloud_dark : source_color = vec3(0.04, 0.035, 0.05);
uniform vec3 cloud_light : source_color = vec3(0.3, 0.26, 0.32);
uniform vec3 rift_color : source_color = vec3(1.0, 0.16, 0.06);
uniform vec3 core_color : source_color = vec3(1.0, 0.45, 0.2);
uniform vec3 rift_dir = vec3(0.0, 0.42, -0.91);
uniform float rift_size = 1.0;
uniform float rift_energy = 1.7;
uniform float flash = 0.0;
uniform float time_scale = 0.01;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Ridged noise -> thin bright lines (the veins).
float ridged(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		float n = 1.0 - abs(noise(p) * 2.0 - 1.0);
		v += a * n * n;
		p = p * 2.1 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float t = TIME * time_scale;

	// Base: dark bruised gradient, slightly warm at the horizon.
	float hz = pow(1.0 - clamp(h, 0.0, 1.0), 4.0);
	vec3 col = mix(zenith_color, horizon_color, hz);

	// Rift-local coordinates (tangent plane around rift_dir).
	vec3 rd = normalize(rift_dir);
	vec3 rx = normalize(cross(rd, vec3(0.0, 1.0, 0.0)));
	vec3 ry = cross(rx, rd);
	float facing = dot(d, rd);
	vec2 q = vec2(dot(d, rx), dot(d, ry)) / max(facing, 0.05);
	q /= rift_size;
	float r = length(q * vec2(0.8, 1.25));
	float glow = exp(-r * r * 45.0) * smoothstep(0.0, 0.3, facing);
	float halo = exp(-r * 2.6) * smoothstep(-0.2, 0.4, facing);

	if (h > -0.05) {
		float fade = smoothstep(-0.05, 0.1, h);
		// Billowing storm clouds on a dome.
		vec2 uv = d.xz / (h + 0.25);
		vec2 warp = vec2(fbm(uv * 0.8 + t), fbm(uv * 0.8 - t + 5.0));
		float c = fbm(uv * 1.3 + warp * 1.4 + vec2(t * 0.5, 0.0));
		float dens = smoothstep(0.28, 0.7, c);
		vec3 lit = mix(cloud_dark, cloud_light, c * c * 1.4);

		// Vein network: sharp single-octave ridges in a warped space, two scales.
		vec2 vw = vec2(fbm(q * 1.7 + t * 2.0), fbm(q * 1.7 + 7.3 - t * 2.0)) - 0.5;
		vec2 pq = q + vw * 0.9;
		float n1 = 1.0 - abs(noise(pq * 3.2) * 2.0 - 1.0);
		float n2 = 1.0 - abs(noise(pq * 7.5 + 4.0) * 2.0 - 1.0);
		float n3 = 1.0 - abs(noise(pq * 15.0 + 9.0) * 2.0 - 1.0);
		float region = exp(-r * 2.7) * smoothstep(0.05, 0.35, facing);
		// Break the web up so it branches out of the core instead of tiling.
		region *= smoothstep(0.35, 0.65, fbm(q * 1.1 + vec2(3.0, t)) + 0.35 * exp(-r * 3.0));
		float veins = pow(n1, 30.0) + pow(n2, 40.0) * 0.6 * smoothstep(0.9, 0.15, r) + pow(n3, 48.0) * 0.4 * smoothstep(0.6, 0.05, r);
		veins *= 0.35 + 0.65 * dens;
		// Thicker, softer glow around the veins lights the clouds red.
		float vglow = (pow(n1, 5.0) * 0.6 + pow(n2, 6.0) * 0.4) * region;

		// Cloud undersides take the rift's light.
		lit = mix(lit, rift_color * 0.42, clamp((halo * 0.85 + vglow * 1.3) * (1.0 - c * 0.35), 0.0, 1.0));
		col = mix(col, lit, dens * fade);
		col += rift_color * vglow * 0.35 * fade;
		col += mix(rift_color, core_color, 0.3) * veins * region * rift_energy * 2.0 * (1.0 + flash * 1.5) * fade;
		// Small molten core where the veins converge.
		col += core_color * glow * rift_energy * (0.8 + 0.2 * sin(TIME * 0.7));
	} else {
		col = horizon_color * 0.4;
	}

	// Lightning flash lights the whole sky briefly.
	col += vec3(0.55, 0.25, 0.3) * flash * 0.35 * (1.0 - hz * 0.5);
	COLOR = col;
}
