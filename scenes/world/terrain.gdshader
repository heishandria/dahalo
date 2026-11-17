// Sol de l'Androy : latérite, plaques de sable, herbe sèche ; roche calcaire sur les pentes et les hauteurs.
// Utilisé par le sol de la zone de jeu ET par le relief qui l'entoure (raccord sans couture).
// Bruit calculé dans le shader (aucune texture) : même rendu sur PC, Web et mobile.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float secheresse : hint_range(0.0, 1.0) = 0.0;
uniform vec3 couleur_laterite : source_color = vec3(0.72, 0.36, 0.2);
uniform vec3 couleur_laterite_sombre : source_color = vec3(0.56, 0.27, 0.16);
uniform vec3 couleur_sable : source_color = vec3(0.8, 0.6, 0.42);
uniform vec3 couleur_herbe : source_color = vec3(0.58, 0.52, 0.3);
uniform vec3 couleur_roche : source_color = vec3(0.74, 0.61, 0.46);   // calcaire du plateau Mahafaly
uniform vec3 couleur_lit : source_color = vec3(0.8, 0.63, 0.43);     // sable clair du lit de rivière
// Lit de rivière : distance au milieu du lit (rouge = distance / distance_max), fournie par Terrain.
uniform sampler2D distances_riviere : filter_linear, repeat_disable, hint_default_white;
uniform float etendue = 280.0;
uniform float distance_max = 32.0;
uniform float largeur_riviere = 11.0;

varying vec3 position_monde;
varying vec3 normale_monde;

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

float bruit_fractal(vec2 p) {
	return 0.5 * bruit(p) + 0.3 * bruit(p * 2.1 + 17.0) + 0.2 * bruit(p * 4.3 + 41.0);
}

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = position_monde.xz;
	float grandes = bruit_fractal(p / 22.0);
	float moyennes = bruit_fractal(p / 5.0);
	float grain = bruit(p * 1.7);

	vec3 c = mix(couleur_laterite_sombre, couleur_laterite, smoothstep(0.3, 0.7, grandes));
	// Plaques de sable
	c = mix(c, couleur_sable, smoothstep(0.6, 0.85, moyennes * 0.5 + grandes * 0.5) * 0.4);
	// Herbe sèche, qui disparaît presque pendant la sécheresse
	float herbe = smoothstep(0.55, 0.8, bruit_fractal(p / 12.0 + 5.3)) * (1.0 - 0.8 * secheresse);
	c = mix(c, couleur_herbe, herbe * 0.35);
	// Lit de rivière à sec : sable clair, plus sombre et humide au milieu hors sécheresse ; berges herbeuses.
	float d_riviere = texture(distances_riviere, (p + etendue) / (2.0 * etendue)).r * distance_max;
	float demi = largeur_riviere * 0.5;
	float berge = 1.0 - smoothstep(demi, demi + 6.0, d_riviere);
	c = mix(c, couleur_herbe * 0.9, berge * 0.45 * (1.0 - 0.6 * secheresse));
	vec3 sable = couleur_lit * (0.92 + 0.12 * moyennes);
	sable = mix(sable, sable * 0.78, (1.0 - smoothstep(0.0, demi * 0.6, d_riviere)) * (1.0 - secheresse));
	c = mix(c, sable, 1.0 - smoothstep(demi - 1.0, demi + 0.8, d_riviere + (grain - 0.5) * 1.2));
	// Roche calcaire : pentes raides et hauteurs du relief
	float pente = 1.0 - clamp(normale_monde.y, 0.0, 1.0);
	float roche = clamp(smoothstep(0.15, 0.4, pente) + 0.6 * smoothstep(8.0, 20.0, position_monde.y), 0.0, 1.0);
	// Sur les parois, le bruit est pris à la verticale (sinon il s'étire) : strates calcaires horizontales.
	float paroi = smoothstep(0.2, 0.5, pente);
	float strates = bruit_fractal(vec2(position_monde.x + position_monde.z, position_monde.y * 2.5) / 4.0);
	float texture_roche = mix(moyennes, strates, paroi);
	vec3 c_roche = couleur_roche * (0.8 + 0.35 * texture_roche);
	c_roche *= 0.92 + 0.08 * sin(position_monde.y * 2.2 + strates * 4.0);
	c = mix(c, c_roche, roche);
	// Lecture du relief en vue isométrique : creux plus sombres, hauteurs plus claires
	c *= 0.88 + 0.3 * smoothstep(0.0, 28.0, position_monde.y);
	// Sécheresse : tout pâlit et tire vers l'ocre
	c = mix(c, c * vec3(1.1, 1.02, 0.92) + 0.06, secheresse);

	ALBEDO = c * (0.9 + 0.2 * mix(grain, 0.5, paroi));
	ROUGHNESS = 1.0;
}
