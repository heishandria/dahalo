// Nuage léger vu d'en haut : plaque horizontale translucide, contour effiloché (bruit), éclairée par le soleil
// (sombre la nuit). La texture de forme est commune au nuage et à son ombre au sol (décalque).
shader_type spatial;
render_mode cull_disabled, depth_draw_never, shadows_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D forme : filter_linear, repeat_disable;   // A = densité du nuage
uniform float opacite = 0.32;
uniform float derive_interne = 0.03;   // le nuage « respire » un peu en se déplaçant

void fragment() {
	vec2 uv = UV + vec2(sin(TIME * 0.05), cos(TIME * 0.04)) * derive_interne;
	float d = texture(forme, uv).a;
	ALBEDO = vec3(0.97, 0.96, 0.94);
	ALPHA = d * opacite;
	ROUGHNESS = 1.0;
}
