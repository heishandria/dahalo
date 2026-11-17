// Sol de l'Androy en textures photo (Poly Haven, CC0 ; voir assets/textures/terrain/LISEZMOI.md) :
// latérite rouge, plaques de sable, herbe (verte en saison normale, fanée en sécheresse), lit de rivière
// (sable, craquelé en sécheresse), plateaux (dessus caillouteux, parois de falaise) et relief autour.
// Les masques (où mettre quoi) sont calculés ici avec du bruit ; les textures donnent la matière.
// Utilisé par le sol de la zone de jeu, les plateaux et le relief : raccords sans couture.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;   // parois des plateaux : sens des triangles indifférent

uniform float secheresse : hint_range(0.0, 1.0) = 0.0;

// Textures (couleur ; relief = normal map au format OpenGL). Le rendu Web (Compatibility) limite un shader
// à 16 textures, moteur compris : en garder 11 au plus ici (le sable et le dessus reprennent le relief de la latérite).
uniform sampler2D tex_laterite : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_laterite_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_herbe_verte : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_herbe_seche : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_sable : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_craquele : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_falaise : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_falaise_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dessus : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float taille_motif = 7.0;        // mètres couverts par une répétition des textures de sol
uniform float taille_falaise = 6.0;
uniform float force_relief = 0.8;
uniform vec3 etalonnage : source_color = vec3(1.12, 0.98, 0.86);   // teinte d'ensemble (poussière chaude)

// Lit de rivière : distance au milieu du lit (rouge = distance / distance_max), fournie par Terrain.
uniform sampler2D distances_riviere : filter_linear, repeat_disable, hint_default_white;
uniform float etendue = 280.0;
uniform float distance_max = 32.0;
uniform float largeur_riviere = 11.0;

// Brouillard sur les plateaux : ils dépassent le voile posé au sol, ils sont donc assombris ici.
uniform sampler2D carte_vision : filter_linear, hint_default_white;   // R = visible, G = exploré
uniform float demi_carte = 120.0;
uniform float opacite_exploree = 0.45;   // comme le voile du brouillard (systems/brouillard.gdshader)

varying vec3 position_monde;
varying vec3 normale_monde;
varying vec2 role;   // x = dessus de plateau, y = paroi (couleur de sommet ; 0 pour le sol et le relief)

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

// Normal map (OpenGL) -> normale dans le monde, pour un plan dont on donne les axes.
vec3 relief(sampler2D carte, vec2 uv, vec3 tangente, vec3 bitangente, vec3 normale, float force) {
	vec3 n = texture(carte, uv).rgb * 2.0 - 1.0;
	n.xy *= force;
	return normalize(tangente * n.x + bitangente * n.y + normale * n.z);
}

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	role = COLOR.rg;
}

void fragment() {
	vec2 p = position_monde.xz;
	vec2 uv = p / taille_motif;
	vec2 uv_large = p / (taille_motif * 2.3) + vec2(0.37, 0.71);   // seconde échelle : casse la répétition
	float grandes = bruit_fractal(p / 22.0);
	float moyennes = bruit_fractal(p / 5.0);
	float pente = 1.0 - clamp(normale_monde.y, 0.0, 1.0);
	float paroi_relief = smoothstep(0.2, 0.5, pente);
	vec3 haut = vec3(0.0, 1.0, 0.0);
	vec3 axe_x = vec3(1.0, 0.0, 0.0);
	vec3 axe_z = vec3(0.0, 0.0, 1.0);

	// Sol de base : latérite, variée par une terre rouge plus fine en grandes plaques.
	vec3 laterite = mix(texture(tex_laterite, uv).rgb, texture(tex_laterite, uv_large).rgb, 0.35);
	// Variation en grandes plaques : la même latérite, à une autre échelle, plus sombre et plus rouge.
	vec3 variation = texture(tex_laterite, uv * 0.43 + vec2(0.21, 0.63)).rgb * vec3(0.88, 0.74, 0.68);
	vec3 c = mix(laterite, variation, smoothstep(0.45, 0.7, grandes) * 0.6);
	vec3 n = relief(tex_laterite_relief, uv, axe_x, axe_z, haut, force_relief);

	// Plaques de sable
	float sable_plaques = smoothstep(0.62, 0.85, moyennes * 0.5 + grandes * 0.5) * 0.75;
	vec3 sable = texture(tex_sable, uv * 0.8).rgb;
	c = mix(c, sable, sable_plaques);

	// Herbe : verte et plus étendue en saison normale, fanée et clairsemée en sécheresse.
	float herbe = smoothstep(0.5 + 0.1 * secheresse, 0.78, bruit_fractal(p / 12.0 + 5.3)) * (1.0 - 0.5 * secheresse);
	vec3 teinte_herbe = mix(texture(tex_herbe_verte, uv * 1.2).rgb, texture(tex_herbe_seche, uv * 1.2).rgb, secheresse);

	// Lit de rivière et berges (plus herbeuses).
	float d_riviere = texture(distances_riviere, (p + etendue) / (2.0 * etendue)).r * distance_max;
	float demi = largeur_riviere * 0.5;
	float berge = 1.0 - smoothstep(demi, demi + 6.0, d_riviere);
	herbe = max(herbe, berge * 0.7 * (1.0 - 0.5 * secheresse));
	c = mix(c, teinte_herbe, herbe * 0.8);
	float lit = 1.0 - smoothstep(demi - 1.0, demi + 0.8, d_riviere + (bruit(p * 1.7) - 0.5) * 1.2);
	vec3 fond_lit = mix(sable, texture(tex_craquele, uv * 0.7).rgb, secheresse * smoothstep(0.0, demi, demi - d_riviere + 1.0));
	c = mix(c, fond_lit, lit);
	n = normalize(mix(n, relief(tex_laterite_relief, uv * 0.8, axe_x, axe_z, haut, force_relief * 0.6), lit));

	// Parois : plateaux (role.y) et pentes raides du relief. Texture de falaise posée à la verticale, projetée
	// sur deux plans (X-Y et Z-Y) mélangés selon l'orientation de la pente : pas d'étirement en bandes.
	vec2 uv_paroi = vec2(position_monde.x + position_monde.z, position_monde.y) / taille_falaise;
	vec2 uv_px = vec2(position_monde.z, position_monde.y) / taille_falaise;
	vec2 uv_pz = vec2(position_monde.x, position_monde.y) / taille_falaise;
	float poids_x = abs(normale_monde.x) / max(abs(normale_monde.x) + abs(normale_monde.z), 0.001);
	vec3 falaise = mix(texture(tex_falaise, uv_pz).rgb, texture(tex_falaise, uv_px).rgb, poids_x);
	float paroi = clamp(max(role.y, paroi_relief + 0.6 * smoothstep(8.0, 20.0, position_monde.y)), 0.0, 1.0);
	vec3 n_falaise = relief(tex_falaise_relief, uv_paroi, normalize(vec3(0.7071, 0.0, 0.7071)), haut, normale_monde, force_relief);
	c = mix(c, falaise, paroi);
	n = normalize(mix(n, n_falaise, paroi));

	// Dessus des plateaux : sol sec et caillouteux, un peu d'herbe.
	vec3 dessus = mix(texture(tex_dessus, uv).rgb, teinte_herbe, herbe * 0.5);
	vec3 n_dessus = relief(tex_laterite_relief, uv * 1.1, axe_x, axe_z, haut, force_relief);
	c = mix(c, dessus, role.x);
	n = normalize(mix(n, n_dessus, role.x));

	// Lecture du relief en vue isométrique : creux plus sombres, hauteurs plus claires.
	c *= 0.9 + 0.22 * smoothstep(0.0, 28.0, position_monde.y);
	// Sécheresse : tout pâlit un peu et tire vers l'ocre.
	c = mix(c, c * vec3(1.08, 1.02, 0.92) + 0.03, secheresse);
	c *= etalonnage;

	if (role.x + role.y > 0.01) {
		vec4 v = texture(carte_vision, (p + demi_carte) / (2.0 * demi_carte));
		float voile = mix(1.0, opacite_exploree, v.g);
		voile = mix(voile, 0.0, v.r);
		c = mix(c, vec3(0.05, 0.035, 0.03), voile);
	}
	ALBEDO = c;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 0.95;
}
