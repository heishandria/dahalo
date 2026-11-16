// Voile du brouillard de guerre, posé juste au-dessus du sol.
// Texture : R = visible maintenant, G = déjà exploré (une case par texel).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D carte_vision : filter_linear;
uniform float demi_carte = 60.0;
uniform float opacite_exploree = 0.55;

void fragment() {
	vec3 monde = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = (monde.xz + demi_carte) / (2.0 * demi_carte);
	vec4 v = texture(carte_vision, uv);
	float alpha = mix(1.0, opacite_exploree, v.g);   // inexploré : noir ; exploré : assombri
	alpha = mix(alpha, 0.0, v.r);                     // visible : clair
	ALBEDO = vec3(0.02, 0.02, 0.04);
	ALPHA = alpha;
}
