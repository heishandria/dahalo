// Végétation basse de la zone de jeu (herbes, fleurs, buissons, cailloux), en MultiMesh.
// - masquée tant que la zone n'est pas explorée (texture du brouillard : G = exploré) ;
// - dorée en sécheresse (suit_saison) ; les fleurs disparaissent en sécheresse (disparait_secheresse) ;
// - ondule au vent, d'autant plus qu'on monte vers le haut du modèle.
// Texture : celle du modèle du pack (blanche pour les formes générées, alors teintées par `teinte`).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, hint_default_white;
uniform float seuil_alpha = 0.0;            // > 0 : feuillage découpé (alpha scissor)
uniform vec3 teinte : source_color = vec3(1.0);
uniform sampler2D carte_vision : filter_linear, hint_default_white;
uniform float demi_carte = 120.0;
uniform float secheresse : hint_range(0.0, 1.0) = 0.0;
uniform float suit_saison = 1.0;            // 1 : jaunit en sécheresse ; 0 : cailloux
uniform float disparait_secheresse = 0.0;   // 1 : fleurs, qui ne sont là qu'après les pluies
uniform float vent = 1.0;                   // amplitude du balancement
uniform float hauteur = 1.0;                // hauteur du modèle (m), pour le balancement et l'ombrage
uniform vec3 couleur_doree : source_color = vec3(0.74, 0.6, 0.3);

varying vec3 position_monde;
varying float hauteur_relative;

void vertex() {
	hauteur_relative = clamp(VERTEX.y / hauteur, 0.0, 1.0);
	VERTEX *= 1.0 - disparait_secheresse * secheresse;
	vec3 origine = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = TIME * 1.7 + origine.x * 0.35 + origine.z * 0.2;
	VERTEX.x += sin(phase) * 0.08 * vent * hauteur_relative * hauteur;
	VERTEX.z += cos(phase * 0.8) * 0.06 * vent * hauteur_relative * hauteur;
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_carte = (position_monde.xz + demi_carte) / (2.0 * demi_carte);
	if (texture(carte_vision, uv_carte).g < 0.5) {
		discard;   // zone jamais explorée : rien ne doit trahir le terrain
	}
	vec4 t = texture(texture_albedo, UV);
	if (t.a < seuil_alpha) {
		discard;
	}
	vec3 c = t.rgb * teinte * COLOR.rgb;
	// Sécheresse : la verdure vire à l'or terne (luminance teintée).
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, lum * couleur_doree * 1.9, secheresse * suit_saison);
	c *= mix(0.8, 1.05, hauteur_relative);   // pied à l'ombre, sommet éclairé
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
