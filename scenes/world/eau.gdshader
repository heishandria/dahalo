// Filet d'eau dans le lit de rivière, en saison normale ; il se retire pendant la sécheresse.
// Posé sur un ruban qui suit le tracé du lit ; la largeur d'eau vient de la distance au milieu du lit.
shader_type spatial;
render_mode diffuse_lambert, cull_disabled, depth_draw_opaque;

uniform sampler2D distances_riviere : filter_linear, repeat_disable, hint_default_white;
uniform float etendue = 280.0;
uniform float distance_max = 32.0;
uniform float niveau : hint_range(0.0, 1.0) = 1.0;   // 1 : saison normale ; 0 : lit à sec
uniform float demi_largeur_max = 3.2;                 // demi-largeur du filet d'eau à plein niveau (m)
uniform vec3 couleur_profonde : source_color = vec3(0.16, 0.3, 0.32);
uniform vec3 couleur_bord : source_color = vec3(0.42, 0.46, 0.36);  // eau peu profonde, chargée de sable

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

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = position_monde.xz;
	float d = texture(distances_riviere, (p + etendue) / (2.0 * etendue)).r * distance_max;
	float demi = demi_largeur_max * niveau;
	// Bord irrégulier : le filet serpente un peu dans le sable.
	float bord = demi + (bruit(p * 0.25) - 0.5) * 1.6 * niveau;
	float presence = 1.0 - smoothstep(bord - 0.6, bord + 0.2, d);
	if (presence <= 0.01) {
		discard;
	}
	float profondeur = 1.0 - smoothstep(0.0, max(bord, 0.1), d);
	vec3 c = mix(couleur_bord, couleur_profonde, profondeur);
	// Petites rides qui bougent, reflets du ciel.
	float rides = bruit(p * 1.3 + vec2(TIME * 0.6, TIME * 0.25)) * bruit(p * 2.1 - vec2(TIME * 0.4, 0.0));
	c += vec3(0.35, 0.4, 0.42) * smoothstep(0.55, 0.85, rides) * 0.35;
	ALBEDO = c;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	ALPHA = presence * mix(0.55, 0.85, profondeur);
}
