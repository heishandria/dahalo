// Sol de l'Androy en textures photo (Poly Haven, CC0 ; voir assets/textures/terrain/LISEZMOI.md) :
// latérite rouge, plaques de sable, herbe (verte en saison normale, fanée en sécheresse), lit de rivière
// (sable, craquelé en sécheresse), plateaux (dessus caillouteux, parois de falaise) et relief autour.
// Les masques (où mettre quoi) sont calculés ici avec du bruit ; les textures donnent la matière.
// Utilisé par le sol de la zone de jeu, les plateaux et le relief : raccords sans couture.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;   // parois des plateaux : sens des triangles indifférent

uniform float secheresse : hint_range(0.0, 1.0) = 0.0;

// Textures (couleur ; relief = normal map au format OpenGL). Le rendu Web (Compatibility) limite un shader
// à 16 textures, moteur compris (3) : en garder 13 au plus ici (le sable et le dessus reprennent le relief de la latérite).
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

// Densité de végétation de la zone de jeu (R = herbe, G = fourrés), calculée par scenes/world/vegetation.gd :
// le sol verdit et s'assombrit sous les massifs, il reste nu entre eux (plus d'effet « poivre et sel »).
uniform sampler2D carte_vegetation : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D tex_bruit : filter_linear_mipmap, repeat_enable, hint_default_white;

// Brouillard sur les plateaux : ils dépassent le voile posé au sol, ils sont donc assombris ici.
uniform sampler2D carte_vision : filter_linear, hint_default_white;   // R = visible, G = exploré
uniform float demi_carte = 120.0;
uniform float opacite_exploree = 0.45;   // comme le voile du brouillard (systems/brouillard.gdshader)

varying vec3 position_monde;
varying vec3 normale_monde;
varying vec2 role;   // couleur de sommet (réservée ; 0 partout aujourd'hui)

// Bruit : texture précalculée au chargement (scenes/world/paysage.gd), lue au lieu d'être calculée pixel par
// pixel (beaucoup moins cher sur les grands écrans). Une unité de x ≈ une « cellule » de bruit.
float bruit(vec2 x) {
	return texture(tex_bruit, x * 0.2).r;
}

// Texture sans répétition visible : deuxième lecture tournée et décalée, mélangée par plaques.
vec3 sans_repetition(sampler2D t, vec2 uv) {
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.93 + vec2(0.43, 0.17);
	float m = smoothstep(0.3, 0.7, bruit(uv * 0.45 + 3.1));
	return mix(texture(t, uv).rgb, texture(t, uv2).rgb, m);
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
	float grandes = bruit(p / 22.0);
	float moyennes = bruit(p / 5.0);
	float pente = 1.0 - clamp(normale_monde.y, 0.0, 1.0);
	float paroi_relief = smoothstep(0.2, 0.5, pente);
	vec3 haut = vec3(0.0, 1.0, 0.0);
	vec3 axe_x = vec3(1.0, 0.0, 0.0);
	vec3 axe_z = vec3(0.0, 0.0, 1.0);

	// Sol de base : latérite sans répétition visible.
	vec3 laterite = mix(sans_repetition(tex_laterite, uv), texture(tex_laterite, uv_large).rgb, 0.3);
	// Variations à grande échelle (60 m) : terre plus sombre et rouge, ou plus claire et ocre.
	float macro = bruit(p / 60.0 + 11.0);
	vec3 c = laterite * mix(vec3(0.8, 0.68, 0.62), vec3(1.1, 0.98, 0.82), smoothstep(0.3, 0.7, macro));
	// Zones caillouteuses (gravier, pierres) en plaques moyennes.
	float cailloux = smoothstep(0.6, 0.78, bruit(p / 18.0 + 27.0));
	if (cailloux > 0.01) {
		c = mix(c, texture(tex_dessus, uv * 0.9).rgb * vec3(0.95, 0.85, 0.78), cailloux * 0.75);
	}
	vec3 n = relief(tex_laterite_relief, uv, axe_x, axe_z, haut, force_relief);

	// Plaques de sable
	float sable_plaques = smoothstep(0.62, 0.85, moyennes * 0.5 + grandes * 0.5) * 0.75;
	vec3 sable = texture(tex_sable, uv * 0.8).rgb;
	c = mix(c, sable, sable_plaques);

	// Herbe : verte et plus étendue en saison normale, fanée et clairsemée en sécheresse.
	// Couverture : environ un tiers du sol en saison normale (le Sud n'est pas un désert), bien moins en sécheresse.
	float herbe = smoothstep(0.38 + 0.2 * secheresse, 0.66, bruit(p / 12.0 + 5.3)) * (1.0 - 0.5 * secheresse);
	// Herbe verte un peu plus franche en saison normale (le Sud reverdit après les pluies).
	vec3 teinte_herbe;
	if (secheresse < 0.01) {
		teinte_herbe = (texture(tex_herbe_verte, uv * 1.2).rgb * vec3(0.78, 1.18, 0.58) + vec3(0.0, 0.035, 0.0));
	} else if (secheresse > 0.99) {
		teinte_herbe = texture(tex_herbe_seche, uv * 1.2).rgb;
	} else {
		teinte_herbe = mix((texture(tex_herbe_verte, uv * 1.2).rgb * vec3(0.78, 1.18, 0.58) + vec3(0.0, 0.035, 0.0)),
				texture(tex_herbe_seche, uv * 1.2).rgb, secheresse);
	}
	// Zone de jeu : l'herbe du sol suit les massifs de végétation (mêmes plaques que les touffes).
	bool dans_le_jeu = abs(p.x) < demi_carte && abs(p.y) < demi_carte;
	vec2 vege = dans_le_jeu ? texture(carte_vegetation, (p + demi_carte) / (2.0 * demi_carte)).rg : vec2(0.0);
	if (dans_le_jeu) {
		herbe = max(herbe * 0.45, vege.r * (1.0 - 0.45 * secheresse));
	}

	// Lit de rivière et berges (plus herbeuses).
	float d_riviere = texture(distances_riviere, (p + etendue) / (2.0 * etendue)).r * distance_max;
	float demi = largeur_riviere * 0.5;
	float berge = 1.0 - smoothstep(demi, demi + 6.0, d_riviere);
	herbe = max(herbe, berge * 0.7 * (1.0 - 0.5 * secheresse));
	c = mix(c, teinte_herbe, herbe * 0.92);
	// Sous les fourrés : sol plus sombre (ombre, litière), un peu plus vert.
	c *= 1.0 - 0.15 * vege.g;
	c = mix(c, teinte_herbe * 0.8, vege.g * 0.5);
	if (d_riviere < demi + 2.0) {   // le lit et ses abords seulement (calcul évité partout ailleurs)
		float lit = 1.0 - smoothstep(demi - 1.0, demi + 0.8, d_riviere + (bruit(p * 1.7) - 0.5) * 1.2);
		vec3 fond_lit = sable;
		if (secheresse > 0.01) {
			fond_lit = mix(sable, texture(tex_craquele, uv * 0.7).rgb, secheresse * smoothstep(0.0, demi, demi - d_riviere + 1.0));
		}
		c = mix(c, fond_lit, lit);
		// Sable mouillé autour du filet d'eau (saison normale) : plus sombre, comme une berge détrempée.
		float mouille = (1.0 - secheresse) * (1.0 - smoothstep(3.0, 5.2, d_riviere + (bruit(p * 0.9) - 0.5) * 1.4));
		c *= 1.0 - 0.38 * mouille;
		n = normalize(mix(n, vec3(0.0, 1.0, 0.0), lit * 0.4));   // sable lissé par l'eau
	}

	// Parois : pentes raides des collines et du relief. Texture de falaise posée à la verticale, projetée
	// sur deux plans (X-Y et Z-Y) mélangés selon l'orientation de la pente : pas d'étirement en bandes.
	// Collines de la zone de jeu : roche dès que la pente se raidit un peu en hauteur (collines rocheuses).
	float roche_colline = smoothstep(0.03, 0.12, pente) * smoothstep(0.3, 1.2, position_monde.y);
	float paroi = clamp(max(paroi_relief, roche_colline) + 0.6 * smoothstep(8.0, 20.0, position_monde.y), 0.0, 1.0);
	float sur_hauteur = smoothstep(0.5, 1.6, position_monde.y) * (1.0 - paroi);
	if (paroi + sur_hauteur > 0.01) {   // collines et relief seulement (calcul évité sur le sol plat)
		vec2 uv_paroi = vec2(position_monde.x + position_monde.z, position_monde.y) / taille_falaise;
		vec2 uv_px = vec2(position_monde.z, position_monde.y) / taille_falaise;
		vec2 uv_pz = vec2(position_monde.x, position_monde.y) / taille_falaise;
		float poids_x = abs(normale_monde.x) / max(abs(normale_monde.x) + abs(normale_monde.z), 0.001);
		vec3 falaise = mix(texture(tex_falaise, uv_pz).rgb, texture(tex_falaise, uv_px).rgb, poids_x);
		vec3 n_falaise = relief(tex_falaise_relief, uv_paroi, normalize(vec3(0.7071, 0.0, 0.7071)), haut, normale_monde, force_relief);
		c = mix(c, falaise, paroi);
		n = normalize(mix(n, n_falaise, paroi));
		// Sur les collines : sol caillouteux assombri, mêlé de roche (pas une plaque de sable claire).
		vec3 dessus = mix(texture(tex_dessus, uv).rgb * vec3(0.78, 0.7, 0.64), falaise * 0.85, 0.35);
		dessus = mix(dessus, teinte_herbe, herbe * 0.35);
		c = mix(c, dessus, sur_hauteur);
	}

	// Lecture du relief en vue isométrique : creux plus sombres, hauteurs plus claires.
	c *= 0.9 + 0.22 * smoothstep(0.0, 28.0, position_monde.y);
	// Sécheresse : tout pâlit un peu et tire vers l'ocre.
	c = mix(c, c * vec3(1.08, 1.02, 0.92) + 0.03, secheresse);
	c *= etalonnage;

	// Brouillard sur les collines de la zone de jeu : elles dépassent le voile posé au sol (y = 0,2).
	if (dans_le_jeu && position_monde.y > 0.18) {
		vec4 v = texture(carte_vision, (p + demi_carte) / (2.0 * demi_carte));
		float voile = mix(1.0, opacite_exploree, v.g);
		voile = mix(voile, 0.0, v.r);
		c = mix(c, vec3(0.05, 0.035, 0.03), voile);
	}
	ALBEDO = c;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 0.95;
}
