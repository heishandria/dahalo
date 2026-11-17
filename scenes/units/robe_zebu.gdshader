// Robe du zébu : unie, pie (grandes plaques) ou tachetée (petites taches), tirée au sort par zébu.
// Le motif est calculé à partir de la position de repos du sommet (UV = (y, 1 - z), UV2.x = x, en mètres ;
// voir assets/models/animaux/zebu_depuis_vache.py) : il suit l'animal quand il bouge.
// COLOR.r = ombrage naturel (bosse, cou, bas des pattes plus sombres).
shader_type spatial;
render_mode diffuse_lambert;

uniform vec3 couleur_base : source_color = vec3(0.55, 0.3, 0.18);
uniform vec3 couleur_taches : source_color = vec3(0.86, 0.82, 0.74);
uniform int motif = 0;          // 0 : unie ; 1 : pie ; 2 : tachetée
uniform float graine = 0.0;
uniform float couverture = 0.5; // part de la robe couverte par les taches (0 à 1)

varying vec3 repos;

float hachage(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float bruit(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hachage(i), hachage(i + vec3(1, 0, 0)), f.x), mix(hachage(i + vec3(0, 1, 0)), hachage(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hachage(i + vec3(0, 0, 1)), hachage(i + vec3(1, 0, 1)), f.x), mix(hachage(i + vec3(0, 1, 1)), hachage(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fractal(vec3 p) {
	return 0.55 * bruit(p) + 0.3 * bruit(p * 2.1 + 7.3) + 0.15 * bruit(p * 4.3 + 1.7);
}

void vertex() {
	repos = vec3(UV2.x, 1.0 - UV.y, UV.x);
}

void fragment() {
	vec3 c = couleur_base;
	if (motif > 0) {
		float echelle = motif == 1 ? 1.6 : 5.5;
		float n = fractal(repos * echelle + vec3(graine));
		// Pie : le ventre et le bas des pattes plus souvent blancs, comme chez les bovins pies.
		if (motif == 1) {
			n += 0.18 * (1.0 - smoothstep(0.35, 0.75, repos.y));
		}
		float seuil = mix(0.72, 0.38, couverture);
		float tache = smoothstep(seuil - 0.025, seuil + 0.025, n);
		c = mix(couleur_base, couleur_taches, tache);
	}
	// Pelage : poils courts couchés dans le sens du corps (bruit étiré le long de l'animal), nuances par zones.
	float poils = bruit(vec3(repos.x * 55.0, repos.y * 55.0, repos.z * 9.0) + vec3(graine));
	poils = mix(poils, bruit(vec3(repos.x * 120.0, repos.y * 120.0, repos.z * 20.0) + vec3(3.1)), 0.4);
	float nuances = fractal(repos * 2.6 + vec3(graine * 0.37));
	c *= 0.72 + 0.45 * poils;
	c *= 0.9 + 0.2 * nuances;
	// Poussière de latérite sur le bas des pattes et le ventre (on vit dans la terre rouge).
	float poussiere = (1.0 - smoothstep(0.08, 0.5, repos.y)) * (0.55 + 0.45 * fractal(repos * 7.0));
	c = mix(c, vec3(0.6, 0.36, 0.22) * (0.8 + 0.3 * poils), poussiere * 0.7);
	ALBEDO = c * COLOR.r;
	// Relief des poils : perturbation de la normale par le gradient du bruit (bump mapping sans texture).
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float hx = dFdx(poils);
	float hy = dFdy(poils);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 gradient = sign(det) * (hx * r1 + hy * r2);
	NORMAL = normalize(abs(det) * NORMAL - 0.006 * gradient);
	ROUGHNESS = mix(0.95, 0.75, poils);
	SPECULAR = 0.25;
}
