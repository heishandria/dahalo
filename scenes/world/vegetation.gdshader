// Végétation basse de la zone de jeu (touffes d'herbe, buissons, cailloux), en MultiMesh.
// - masquée tant que la zone n'est pas explorée (texture du brouillard : G = exploré) ;
// - herbe verte en saison normale, dorée en sécheresse ; elle ondule au vent.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D carte_vision : filter_linear, hint_default_white;
uniform float demi_carte = 120.0;
uniform float secheresse : hint_range(0.0, 1.0) = 0.0;
uniform float suit_saison = 1.0;     // 1 : herbe (change avec la saison) ; 0 : cailloux, buissons
uniform float vent = 1.0;            // amplitude du balancement (0 : immobile)
uniform vec3 couleur_verte : source_color = vec3(0.36, 0.46, 0.17);
uniform vec3 couleur_doree : source_color = vec3(0.74, 0.6, 0.3);
uniform vec3 couleur_fixe : source_color = vec3(0.6, 0.55, 0.45);

varying vec3 position_monde;
varying float hauteur_relative;   // 0 au pied, 1 à la pointe (UV.y)

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hauteur_relative = UV.y;
	// Balancement : seulement le haut des brins, déphasé selon la position.
	vec3 origine = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = TIME * 1.7 + origine.x * 0.35 + origine.z * 0.2;
	VERTEX.x += sin(phase) * 0.07 * vent * UV.y;
	VERTEX.z += cos(phase * 0.8) * 0.05 * vent * UV.y;
}

void fragment() {
	vec2 uv = (position_monde.xz + demi_carte) / (2.0 * demi_carte);
	if (texture(carte_vision, uv).g < 0.5) {
		discard;   // zone jamais explorée : rien ne doit trahir le terrain
	}
	vec3 saison = mix(couleur_verte, couleur_doree, secheresse);
	vec3 c = mix(couleur_fixe, saison, suit_saison) * COLOR.rgb;
	c *= mix(0.6, 1.1, hauteur_relative);   // pied à l'ombre, pointe éclairée
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
