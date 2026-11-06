shader_type spatial;
// Rain-soaked cracked asphalt. UV.x = lateral metres from centre, UV.y = distance metres.
// The "mirror" is faked: we reflect the view vector off the road, evaluate a cheap
// version of the rift sky analytically, and add vertical light streaks for each
// nearby street lamp (anisotropic, like real wet-road reflections). No extra passes.
render_mode cull_back;

uniform vec3 asphalt : source_color = vec3(0.04, 0.038, 0.042);
uniform vec3 asphalt_light : source_color = vec3(0.1, 0.095, 0.1);
uniform vec3 line_yellow : source_color = vec3(0.62, 0.45, 0.12);
uniform vec3 line_white : source_color = vec3(0.55, 0.53, 0.5);
uniform float half_width = 3.6;
uniform float wetness = 1.0;

// Reflection: must match sky.gdshader roughly.
uniform vec3 sky_zenith : source_color = vec3(0.025, 0.018, 0.03);
uniform vec3 sky_horizon : source_color = vec3(0.16, 0.07, 0.08);
uniform vec3 rift_color : source_color = vec3(1.0, 0.16, 0.06);
uniform vec3 core_color : source_color = vec3(1.0, 0.45, 0.2);
uniform vec3 rift_dir = vec3(0.0, 0.42, -0.91);
uniform float rift_energy = 1.7;
uniform float flash = 0.0;
uniform float reflect_strength = 0.75;
// Street-light streaks (filled every frame from the World light pool).
uniform vec3 lamp_pos[6];
uniform vec4 lamp_col[6];
uniform int lamp_count = 0;

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

vec3 sky_reflect(vec3 r) {
	r.y = abs(r.y);
	float hz = pow(1.0 - clamp(r.y, 0.0, 1.0), 4.0);
	vec3 col = mix(sky_zenith, sky_horizon, hz);
	vec3 rd = normalize(rift_dir);
	vec3 rx = normalize(cross(rd, vec3(0.0, 1.0, 0.0)));
	vec3 ry = cross(rx, rd);
	float facing = dot(r, rd);
	vec2 q = vec2(dot(r, rx), dot(r, ry)) / max(facing, 0.05);
	float rr = length(q * vec2(0.8, 1.25));
	float glow = exp(-rr * rr * 14.0) * smoothstep(0.0, 0.3, facing);
	float halo = exp(-rr * 2.6) * smoothstep(-0.2, 0.4, facing);
	float vein = pow(1.0 - abs(noise(q * 3.0 + TIME * 0.02) * 2.0 - 1.0), 8.0) * exp(-rr * 1.6);
	col += rift_color * (halo * 0.4 + vein * 0.8) * rift_energy * 0.55;
	col += core_color * glow * rift_energy * 0.7;
	col += vec3(0.5, 0.25, 0.3) * flash * 0.3;
	return col;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV;
	float n = fbm(p * vec2(1.6, 0.9));
	float grit = noise(p * 14.0);
	vec3 col = mix(asphalt, asphalt_light, n * 0.55 + grit * 0.18);

	// Patched repairs.
	float patch = step(0.72, noise(floor(p * vec2(0.5, 0.18)) + 3.1));
	col = mix(col, asphalt * 0.7, patch * 0.6);

	// Cracks.
	float c = abs(fbm(p * vec2(0.9, 0.45) + 7.0) - 0.5);
	float crack = smoothstep(0.02, 0.0, c) * smoothstep(0.35, 0.6, noise(p * 0.3));
	col *= 1.0 - crack * 0.7;

	// Centre double yellow + edge lines, worn.
	float wear = smoothstep(0.25, 0.6, noise(p * vec2(3.0, 0.7)));
	float cl = step(abs(p.x - 0.12), 0.05) + step(abs(p.x + 0.12), 0.05);
	col = mix(col, line_yellow, clamp(cl, 0.0, 1.0) * wear * 0.8);
	float el = step(abs(abs(p.x) - (half_width - 0.25)), 0.06);
	col = mix(col, line_white, el * wear * 0.65);

	// Wetness: big sheets of standing water + glossy film everywhere else.
	float puddle = smoothstep(0.5, 0.62, fbm(p * vec2(0.28, 0.12) + 21.0));
	float edge_dry = smoothstep(half_width, half_width - 0.9, abs(p.x));
	float film = smoothstep(0.3, 0.7, fbm(p * vec2(0.6, 0.25) + 5.0));
	float wet = clamp((0.12 + film * 0.38 + puddle * 0.5) * wetness * mix(0.5, 1.0, edge_dry), 0.0, 1.0);
	wet *= 1.0 - crack * 0.6;

	// World-space view + normal (with tiny rain ripples).
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 v = normalize(cam - wpos);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rip_t = TIME * 3.0;
	vec2 rip = vec2(noise(wpos.xz * 3.0 + rip_t), noise(wpos.xz * 3.0 - rip_t + 9.0)) - 0.5;
	nw = normalize(nw + vec3(rip.x, 0.0, rip.y) * mix(0.18, 0.04, puddle));
	vec3 r = reflect(-v, nw);
	float ndv = clamp(dot(nw, v), 0.0, 1.0);
	float fres = 0.03 + 0.97 * pow(1.0 - ndv, 5.0);
	fres = mix(0.03, 0.9, fres);

	vec3 refl = sky_reflect(r);
	// Lamp streaks: tight horizontally, stretched vertically.
	vec3 rh = normalize(vec3(r.x, 0.0, r.z));
	for (int i = 0; i < 6; i++) {
		if (i >= lamp_count) {
			break;
		}
		vec3 l = lamp_pos[i] - wpos;
		float dist = length(l);
		vec3 ld = l / dist;
		vec3 lh = normalize(vec3(ld.x, 0.0, ld.z));
		float h_err = 1.0 - dot(rh, lh);
		float v_err = r.y - ld.y;
		float streak = exp(-h_err * 9000.0 / (1.0 + dist * 0.02)) * exp(-v_err * v_err * 22.0);
		refl += lamp_col[i].rgb * lamp_col[i].a * streak * 1.4 / (1.0 + dist * 0.04);
	}

	ALBEDO = col * (1.0 - wet * 0.55);
	ROUGHNESS = mix(0.8, 0.12, wet);
	SPECULAR = mix(0.3, 0.6, wet);
	METALLIC = 0.0;
	EMISSION = refl * fres * wet * reflect_strength;
}
