// Eau d'un point d'eau : trouble et limoneuse (mares du Sud), reflets du ciel, petites rides animées.
// UV.x = distance relative au centre (1 = bord) : l'eau est plus claire et transparente sur les bords peu profonds.
shader_type spatial;
render_mode diffuse_lambert, cull_disabled, depth_draw_opaque;

uniform vec3 couleur_profonde : source_color = vec3(0.16, 0.17, 0.12);
uniform vec3 couleur_bord : source_color = vec3(0.4, 0.33, 0.24);   // eau peu profonde, chargée de latérite

varying vec3 position_monde;

float hachage(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hachage(i), hachage(i + vec2(1.0, 0.0)), u.x),
			mix(hachage(i + vec2(0.0, 1.0)), hachage(i + vec2(1.0, 1.0)), u.x), u.y);
}

float rides(vec2 p) {
	return bruit(p * 2.2 + vec2(TIME * 0.35, TIME * 0.2)) * 0.6 + bruit(p * 4.7 - vec2(TIME * 0.25, -TIME * 0.3)) * 0.4;
}

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = position_monde.xz;
	float profondeur = 1.0 - smoothstep(0.35, 1.0, UV.x);
	ALBEDO = mix(couleur_bord, couleur_profonde, profondeur);
	// Rides : la normale suit le gradient du bruit.
	float e = 0.05;
	float h = rides(p);
	vec3 n_monde = normalize(vec3(-(rides(p + vec2(e, 0.0)) - h) / e * 0.06, 1.0, -(rides(p + vec2(0.0, e)) - h) / e * 0.06));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_monde, 0.0)).xyz);
	ROUGHNESS = 0.06;
	SPECULAR = 0.55;
	ALPHA = mix(0.55, 0.92, profondeur) * (1.0 - smoothstep(0.92, 1.0, UV.x));
}
