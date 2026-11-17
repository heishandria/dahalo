// Oiseau en vol (MultiMesh) : les ailes battent (les sommets éloignés du corps montent et descendent).
// INSTANCE_CUSTOM.r = phase du battement, .g = vitesse du battement (vol plané si faible).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 couleur_dos : source_color = vec3(0.08, 0.08, 0.09);
uniform vec3 couleur_ventre : source_color = vec3(0.08, 0.08, 0.09);

varying float dessous;

void vertex() {
	float envergure = abs(VERTEX.x);
	float battement = sin(TIME * INSTANCE_CUSTOM.g + INSTANCE_CUSTOM.r * 6.2832);
	VERTEX.y += battement * envergure * 0.55;
	dessous = COLOR.r;   // 1 sur le plastron (corbeau pie), 0 ailleurs
}

void fragment() {
	ALBEDO = mix(couleur_dos, couleur_ventre, dessous);
	ROUGHNESS = 0.9;
}
