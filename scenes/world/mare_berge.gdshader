// Berges d'un point d'eau : boue humide et sombre près de l'eau, qui sèche en s'éloignant ; en sécheresse,
// la partie découverte par l'eau qui s'est retirée devient de la boue craquelée.
// UV.x = distance relative au centre (1 = bord de l'eau à plein niveau), UV.y = 0.
shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

uniform sampler2D tex_sol : source_color, filter_linear_mipmap_anisotropic, repeat_enable;       // latérite ou sable
uniform sampler2D tex_craquele : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float niveau = 1.0;            // 1 : eau à plein niveau ; ~0.55 : sécheresse
uniform float taille_motif = 7.0;
uniform vec3 etalonnage : source_color = vec3(1.12, 0.98, 0.86);

varying vec3 position_monde;

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = position_monde.xz / taille_motif;
	float r = UV.x;
	vec3 sol = texture(tex_sol, uv).rgb;
	// Zone découverte par le retrait de l'eau : boue craquelée.
	float decouvert = smoothstep(niveau - 0.05, niveau + 0.05, r) * (1.0 - smoothstep(0.98, 1.08, r));
	vec3 c = mix(sol, texture(tex_craquele, uv * 1.4).rgb * vec3(0.9, 0.82, 0.74), decouvert * (1.0 - niveau) * 2.2);
	// Humidité : très mouillé au bord de l'eau, sec au loin.
	float mouille = 1.0 - smoothstep(niveau, niveau + 0.45, r);
	c *= mix(1.0, 0.55, mouille);
	c = mix(c, c * vec3(0.92, 0.95, 0.85), mouille * 0.5);   // reflet verdâtre de la vase
	// Fondu vers le sol tout autour.
	ALBEDO = c * etalonnage;
	ROUGHNESS = mix(0.95, 0.6, mouille);   // boue mouillée, mais pas un miroir (sinon halo bleu du ciel)
	SPECULAR = mix(0.3, 0.4, mouille);
	ALPHA = 1.0 - smoothstep(1.7, 1.9, r);
}
