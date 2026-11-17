// Filet d'eau dans le lit de rivière, en saison normale ; il se retire pendant la sécheresse.
// Posé sur un ruban qui suit le tracé du lit ; la largeur d'eau vient de la distance au milieu du lit.
// Rendu : eau limoneuse transparente au bord (on voit le sable), plus sombre au milieu ; reflet du ciel selon
// l'angle de vue (Fresnel), reflets du soleil sur les rides, mince liseré d'écume le long des rives.
shader_type spatial;
render_mode diffuse_lambert, cull_disabled, depth_draw_opaque;

uniform sampler2D distances_riviere : filter_linear, repeat_disable, hint_default_white;
uniform float etendue = 280.0;
uniform float distance_max = 32.0;
uniform float niveau : hint_range(0.0, 1.0) = 1.0;   // 1 : saison normale ; 0 : lit à sec
uniform float demi_largeur_max = 3.2;                 // demi-largeur du filet d'eau à plein niveau (m)
uniform vec3 couleur_profonde : source_color = vec3(0.13, 0.17, 0.15);   // eau trouble, profonde
uniform vec3 couleur_bord : source_color = vec3(0.5, 0.4, 0.28);        // eau peu profonde, chargée de latérite
uniform vec3 couleur_ciel : source_color = vec3(0.55, 0.68, 0.82);      // reflet du ciel

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
	return bruit(p * 1.6 + vec2(TIME * 0.5, TIME * 0.2)) * 0.6 + bruit(p * 3.9 - vec2(TIME * 0.35, -TIME * 0.45)) * 0.4;
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
	float presence = 1.0 - smoothstep(bord - 0.5, bord + 0.15, d);
	if (presence <= 0.01) {
		discard;
	}
	float profondeur = 1.0 - smoothstep(0.0, max(bord, 0.1), d);
	vec3 c = mix(couleur_bord, couleur_profonde, profondeur);

	// Rides : normale tirée du gradient du bruit.
	float e = 0.06;
	float h = rides(p);
	vec3 n_monde = normalize(vec3(-(rides(p + vec2(e, 0.0)) - h) / e * 0.09, 1.0, -(rides(p + vec2(0.0, e)) - h) / e * 0.09));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_monde, 0.0)).xyz);

	// Reflet du ciel : plus fort sous un angle rasant (Fresnel de Schlick).
	float cos_vue = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - cos_vue, 5.0);
	c = mix(c, couleur_ciel, clamp(fresnel * 2.2 + 0.12, 0.0, 0.6) * profondeur);

	// Écume : mince liseré clair le long des rives.
	float ecume = smoothstep(bord - 0.9, bord - 0.35, d) * (1.0 - smoothstep(bord - 0.35, bord, d));
	c = mix(c, vec3(0.78, 0.74, 0.66), ecume * 0.55 * smoothstep(0.35, 0.7, bruit(p * 2.5 + TIME * 0.3)));

	ALBEDO = c;
	ROUGHNESS = 0.05;
	SPECULAR = 0.65;   // reflets du soleil sur les rides
	ALPHA = presence * mix(0.45, 0.93, profondeur);
}
