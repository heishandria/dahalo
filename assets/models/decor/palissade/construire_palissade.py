# Palissade épineuse de Dahalo : 3 variantes d'un segment de 4 m + bannière, construites par script (sans MCP).
#
#   Blender -b --factory-startup --python-exit-code 1 --python construire_palissade.py -- ATLAS.png SORTIE.glb SORTIE.blend
#
# Repère Blender : X = long du segment (4 m entre piquets d'extrémité, ~4,6 m réels avec les bouts arrondis qui
# recouvrent le voisin), -Y = face « avant » (+Z côté glTF/Godot), Z = haut ; origine au sol au centre.
# Objets exportés : Palissade_a, Palissade_b, Palissade_c (un maillage chacun, 2 matériaux) et Banniere
# (drapeau seul, sur le piquet porte-bannière présent au même endroit dans les trois variantes).
# Matériaux : « Palissade_bois » (opaque) et « Palissade_epines » (alpha en découpe, double face), un seul atlas.
import math
import os
import random
import sys

import bpy
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
ATLAS, SORTIE_GLB, SORTIE_BLEND = (os.path.abspath(a) for a in args[:3])

# Régions de l'atlas (u0, v0, u1, v1), voir generer_atlas.py.
MARGE_UV = 0.003
FAGOT = [(0.0, 0.75, 0.5, 1.0), (0.5, 0.75, 1.0, 1.0)]
CRETE = [(0.0, 0.5, 0.5, 0.75), (0.5, 0.5, 1.0, 0.75)]
ECORCE = (0.0, 0.25, 1.0, 0.5)
MASSE = (0.0, 0.0, 0.5, 0.25)
RAQUETTE = (0.5, 0.0, 0.75, 0.25)
ETOFFE = (0.75, 0.0, 1.0, 0.25)

MAT_BOIS, MAT_EPINES = 0, 1

# Piquet porte-bannière, commun aux trois variantes (le jeu y place le fanion du clan).
PIQUET_BANNIERE = Vector((1.72, 0.02, 0.0))
HAUTEUR_PIQUET_BANNIERE = 1.66
BANNIERE_LARGEUR, BANNIERE_HAUTEUR = 0.40, 0.25


class Maillage:
	"""Accumulateur de géométrie : sommets, faces, UV par coin, matériau et lissage par face."""

	def __init__(self):
		self.sommets, self.faces, self.uvs, self.mats, self.lisse = [], [], [], [], []

	def sommet(self, p):
		self.sommets.append(Vector(p))
		return len(self.sommets) - 1

	def face(self, indices, uvs, mat, lisse=False):
		self.faces.append(tuple(indices))
		self.uvs.append(list(uvs))
		self.mats.append(mat)
		self.lisse.append(lisse)

	def triangles(self):
		return sum(len(f) - 2 for f in self.faces)

	def objet(self, nom, materiaux):
		me = bpy.data.meshes.new(nom)
		me.from_pydata([tuple(v) for v in self.sommets], [], self.faces)
		uv = me.uv_layers.new(name="UVMap")
		k = 0
		for i, poly in enumerate(me.polygons):
			poly.material_index = self.mats[i]
			poly.use_smooth = self.lisse[i]
			for j, _ in enumerate(poly.loop_indices):
				uv.data[poly.loop_start + j].uv = self.uvs[i][j]
				k += 1
		for m in materiaux:
			me.materials.append(m)
		me.validate(clean_customdata=False)
		me.update()
		ob = bpy.data.objects.new(nom, me)
		bpy.context.scene.collection.objects.link(ob)
		return ob


def region_uv(region, u, v):
	u0, v0, u1, v1 = region
	return (u0 + MARGE_UV + (u1 - u0 - 2 * MARGE_UV) * u, v0 + MARGE_UV + (v1 - v0 - 2 * MARGE_UV) * v)


def reperes(points):
	"""Repères (tangente, normale, binormale) le long d'une polyligne, par transport parallèle."""
	tangentes = []
	for i in range(len(points)):
		a = points[max(0, i - 1)]
		b = points[min(len(points) - 1, i + 1)]
		tangentes.append((b - a).normalized())
	ref = Vector((0, 0, 1)) if abs(tangentes[0].z) < 0.9 else Vector((1, 0, 0))
	n = tangentes[0].cross(ref).normalized()
	resultat = []
	for t in tangentes:
		n = (n - t * n.dot(t)).normalized()
		resultat.append((t, n, t.cross(n).normalized()))
	return resultat


def tube(m, points, rayons, cotes, region, u_longueur, chapeau_haut=True, rnd=random):
	"""Branche ou piquet : tube à `cotes` côtés le long de `points`, UV d'écorce (u le long, v autour)."""
	anneaux = []
	rep = reperes(points)
	tourne = rnd.uniform(0, math.tau)
	for p, r, (t, n, b) in zip(points, rayons, rep):
		anneau = []
		for k in range(cotes):
			a = tourne + math.tau * k / cotes
			bosse = 1.0 + rnd.uniform(-0.12, 0.12)
			anneau.append(m.sommet(p + (n * math.cos(a) + b * math.sin(a)) * r * bosse))
		anneaux.append(anneau)
	longueurs = [0.0]
	for i in range(1, len(points)):
		longueurs.append(longueurs[-1] + (points[i] - points[i - 1]).length)
	total = longueurs[-1]
	u_debut = 0.0
	for i in range(len(points) - 1):
		ua = u_debut + u_longueur * longueurs[i] / total
		ub = u_debut + u_longueur * longueurs[i + 1] / total
		for k in range(cotes):
			k2 = (k + 1) % cotes
			va, vb = k / cotes, (k + 1) / cotes
			m.face([anneaux[i][k], anneaux[i][k2], anneaux[i + 1][k2], anneaux[i + 1][k]],
				[region_uv(region, ua, va), region_uv(region, ua, vb), region_uv(region, ub, vb), region_uv(region, ub, va)],
				MAT_BOIS, lisse=True)
	if chapeau_haut:
		# Coupe de bout de piquet, un peu bombée et de travers.
		t = rep[-1][0]
		centre = m.sommet(points[-1] + t * rayons[-1] * 0.5)
		for k in range(cotes):
			k2 = (k + 1) % cotes
			a1, a2 = math.tau * k / cotes, math.tau * k2 / cotes
			m.face([anneaux[-1][k], anneaux[-1][k2], centre],
				[region_uv(region, u_longueur, 0.5 + 0.4 * math.cos(a1)), region_uv(region, u_longueur, 0.5 + 0.4 * math.cos(a2)),
					region_uv(region, u_longueur, 0.5)], MAT_BOIS, lisse=True)


def piquet(m, base, hauteur, rayon, rnd, penche=None):
	"""Perche dressée tordue, enfoncée de 15 cm, penchée au hasard."""
	if penche is None:
		penche = Vector((rnd.uniform(-0.09, 0.09), rnd.uniform(-0.07, 0.07), 0.0))
	points, rayons = [], []
	n = 4
	for i in range(n):
		t = i / (n - 1)
		z = -0.15 + (hauteur + 0.15) * t
		ecart = Vector((rnd.uniform(-0.035, 0.035), rnd.uniform(-0.035, 0.035), 0.0)) if 0 < i < n - 1 else Vector()
		points.append(base + Vector((0, 0, z)) + penche * z + ecart)
		rayons.append(rayon * (1.0 - 0.3 * t))
	tube(m, points, rayons, 5, ECORCE, min(0.95, (hauteur + 0.15) / 2.2), rnd=rnd)


def traverse(m, y, z, rnd):
	"""Perche couchée tenant les fagots, d'un bout à l'autre, un peu affaissée et tordue."""
	points, rayons = [], []
	n = 7
	x0, x1 = -2.05 + rnd.uniform(0, 0.1), 2.05 - rnd.uniform(0, 0.1)
	for i in range(n):
		t = i / (n - 1)
		x = x0 + (x1 - x0) * t
		affaissement = -0.06 * math.sin(math.pi * t)
		points.append(Vector((x, y + rnd.uniform(-0.03, 0.03), z + affaissement + rnd.uniform(-0.03, 0.03))))
		rayons.append(rnd.uniform(0.026, 0.034))
	tube(m, points, rayons, 5, ECORCE, 0.95, chapeau_haut=False, rnd=rnd)


def masse(m, rnd):
	"""Corps de branchages serrés : profil en dôme cabossé, bouts arrondis centrés sur les piquets d'extrémité
	(x = ±2) qui recouvrent le segment voisin quel que soit l'angle. Ouvert dessous (posé au sol)."""
	profil = 7
	anneaux_x = [-2.0 + i * (4.0 / 12) for i in range(13)]
	hauteur_max = 0.8
	anneaux = []      # liste de (x, [(y, z)…])
	for x in anneaux_x:
		demi_largeur = rnd.uniform(0.23, 0.28)
		h = rnd.uniform(0.6, 0.76)
		pts = []
		for k in range(profil):
			a = math.pi * (1.0 - k / (profil - 1))           # de l'avant (-Y) à l'arrière (+Y) par le dessus
			y = math.cos(a) * demi_largeur * rnd.uniform(0.9, 1.1)
			z = max(-0.06, math.sin(a) * h * rnd.uniform(0.92, 1.06) - 0.06)
			if k in (0, profil - 1):
				z = -0.06
			pts.append((y, z))
		anneaux.append((x, pts))

	def anneau_reduit(x, pts, echelle_y, echelle_z):
		return (x, [(y * echelle_y, -0.06 + (z + 0.06) * echelle_z) for (y, z) in pts])

	# bouts arrondis : deux anneaux réduits puis une pointe, de chaque côté
	debut = anneaux[0]
	fin = anneaux[-1]
	anneaux = [anneau_reduit(-2.27, debut[1], 0.55, 0.62), anneau_reduit(-2.15, debut[1], 0.88, 0.9)] + anneaux + \
		[anneau_reduit(2.15, fin[1], 0.88, 0.9), anneau_reduit(2.27, fin[1], 0.55, 0.62)]
	indices = []
	for (x, pts) in anneaux:
		indices.append([m.sommet((x + rnd.uniform(-0.03, 0.03), y, z)) for (y, z) in pts])

	def uv_masse(x, z):
		# u en aller-retour sur 2,4 m (miroir), v selon la hauteur : sombre et poussiéreux au pied
		p = (x + 2.4) / 2.4
		u = p if p <= 1.0 else 2.0 - p
		return region_uv(MASSE, max(0.0, min(1.0, u)), max(0.0, min(1.0, (z + 0.06) / (hauteur_max + 0.06))))

	for i in range(len(anneaux) - 1):
		for k in range(profil - 1):
			a, b = indices[i][k], indices[i][k + 1]
			c, d = indices[i + 1][k + 1], indices[i + 1][k]
			va, vb, vc, vd = (m.sommets[j] for j in (a, b, c, d))
			m.face([a, d, c, b], [uv_masse(va.x, va.z), uv_masse(vd.x, vd.z), uv_masse(vc.x, vc.z), uv_masse(vb.x, vb.z)],
				MAT_BOIS)
	for bout, signe in ((0, -1), (len(anneaux) - 1, 1)):
		x_pointe = signe * 2.33
		pointe = m.sommet((x_pointe, 0.0, 0.12))
		for k in range(profil - 1):
			a, b = indices[bout][k], indices[bout][k + 1]
			va, vb = m.sommets[a], m.sommets[b]
			ordre = [a, b, pointe] if signe > 0 else [b, a, pointe]
			uvs = [uv_masse(m.sommets[j].x, m.sommets[j].z) for j in ordre]
			m.face(ordre, uvs, MAT_BOIS)


def carte(m, centre, longueur, hauteur, lacet, inclinaison, tuile, rnd, retourner=False, cambrure=0.05):
	"""Carte à 4 triangles (pliée au milieu), plan local : X le long, Z en haut ; pied au centre bas.
	`lacet` tourne autour de Z ; `inclinaison` penche le haut vers +Y local (radians)."""
	rot = Matrix.Rotation(lacet, 3, 'Z') @ Matrix.Rotation(inclinaison, 3, 'X')
	coins = []
	for (sx, sz) in ((-0.5, 0), (0.0, 0), (0.5, 0), (-0.5, 1), (0.0, 1), (0.5, 1)):
		bombe = cambrure * (1.0 - abs(sx) * 2) * (1 if sz else 0.4)
		p = Vector((sx * longueur, -bombe, sz * hauteur))
		coins.append(m.sommet(centre + rot @ p))
	bas_g, bas_m, bas_d, haut_g, haut_m, haut_d = coins

	def uv(su, sv):
		return region_uv(tuile, (1.0 - su) if retourner else su, sv)

	m.face([bas_g, bas_m, haut_m, haut_g], [uv(0, 0), uv(0.5, 0), uv(0.5, 1), uv(0, 1)], MAT_EPINES)
	m.face([bas_m, bas_d, haut_d, haut_m], [uv(0.5, 0), uv(1, 0), uv(1, 1), uv(0.5, 1)], MAT_EPINES)


def raquette(m, base, direction, normale, a, b, epaisseur):
	"""Raquette de raketa (Opuntia) : lentille à 8 sommets de bord et 2 centres bombés (16 triangles).
	`base` = point d'attache (bas de la raquette), `direction` = axe long, `normale` = face."""
	cote = direction.cross(normale).normalized()
	centre = base + direction * a
	bord = []
	uvs_bord = []
	for k in range(8):
		ang = math.tau * k / 8
		p = centre + direction * (math.cos(ang) * a) + cote * (math.sin(ang) * b)
		bord.append(m.sommet(p))
		uvs_bord.append(region_uv(RAQUETTE, 0.5 + 0.47 * math.cos(ang), 0.5 + 0.47 * math.sin(ang)))
	avant = m.sommet(centre + normale * epaisseur)
	arriere = m.sommet(centre - normale * epaisseur)
	uc = region_uv(RAQUETTE, 0.5, 0.5)
	for k in range(8):
		k2 = (k + 1) % 8
		m.face([bord[k], bord[k2], avant], [uvs_bord[k], uvs_bord[k2], uc], MAT_BOIS, lisse=True)
		m.face([bord[k2], bord[k], arriere], [uvs_bord[k2], uvs_bord[k], uc], MAT_BOIS, lisse=True)
	return centre


def touffe_raketa(m, pied, nombre, rnd, hauteur_max=1.35, y_max=0.46):
	"""Pied de raketa : raquettes posées les unes sur les autres (attache au bord de la précédente)."""
	file = [(pied, Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), 1.0)).normalized(), 1.0)]
	posees = 0
	while file and posees < nombre:
		base, direction, echelle = file.pop(0)
		a = rnd.uniform(0.16, 0.2) * echelle
		b = a * rnd.uniform(0.68, 0.78)
		# face tournée au hasard autour de l'axe long
		ref = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((1, 0, 0))
		n0 = direction.cross(ref).normalized()
		normale = (Matrix.Rotation(rnd.uniform(0, math.pi), 3, direction) @ n0).normalized()
		sommet_haut = base + direction * 2 * a
		if sommet_haut.z > hauteur_max or abs(sommet_haut.y) > y_max or abs((base + direction * a).y) > y_max:
			continue
		raquette(m, base, direction, normale, a, b, a * 0.18)
		posees += 1
		cote = direction.cross(normale).normalized()
		for _ in range(rnd.choice((1, 2, 2))):
			ang = rnd.uniform(0.5, 1.1) * rnd.choice((-1, 1))
			attache = base + direction * a + direction * (math.cos(ang) * a * 0.95) + cote * (math.sin(ang) * b * 0.95)
			nouvelle = (direction * math.cos(ang * 0.8) + cote * math.sin(ang * 0.8)).normalized()
			nouvelle = (nouvelle + Vector((0, 0, 0.35))).normalized()
			file.append((attache, nouvelle, echelle * rnd.uniform(0.82, 0.95)))


# --- Variantes ----------------------------------------------------------------------------------------------
# Piquets : x, côté (y), hauteur ; les deux d'extrémité sont décalés vers l'intérieur pour qu'aux jonctions
# les deux piquets voisins restent distincts (fait main). Touffes de raketa : (x, y, nombre de raquettes).
VARIANTES = {
	"a": {"graine": 11, "piquets": [(-1.86, -0.12, 1.32), (-0.98, 0.14, 1.18), (-0.05, -0.13, 1.42), (0.88, 0.12, 1.24)],
		"raketa": [(-1.05, -0.3, 8), (0.95, 0.29, 7)]},
	"b": {"graine": 23, "piquets": [(-1.82, 0.12, 1.22), (-0.72, -0.13, 1.38), (0.35, 0.13, 1.15), (0.95, -0.12, 1.3)],
		"raketa": [(0.15, -0.31, 10), (-1.45, 0.3, 6)]},
	"c": {"graine": 37, "piquets": [(-1.9, -0.13, 1.4), (-1.1, 0.12, 1.2), (-0.32, -0.12, 1.26), (0.62, 0.14, 1.36)],
		"raketa": [(-1.55, -0.31, 6), (-0.25, 0.3, 7), (1.15, -0.3, 6)]},
}


def construire_variante(nom, reglages, materiaux):
	rnd = random.Random(reglages["graine"])
	m = Maillage()
	masse(m, rnd)
	for (x, y, h) in reglages["piquets"]:
		piquet(m, Vector((x + rnd.uniform(-0.05, 0.05), y, 0)), h, rnd.uniform(0.038, 0.05), rnd)
	piquet(m, PIQUET_BANNIERE, HAUTEUR_PIQUET_BANNIERE, 0.045, rnd, penche=Vector((0.012, 0.0, 0.0)))
	traverse(m, -0.27, rnd.uniform(0.58, 0.68), rnd)
	traverse(m, 0.27, rnd.uniform(0.42, 0.52), rnd)

	# Fagots couchés sur les deux faces : un rang au pied, hauteurs et lacets inégaux (bord haut déchiqueté).
	for cote in (-1, 1):
		x = -2.2 + rnd.uniform(0, 0.15)
		while x < 2.0:
			longueur = rnd.uniform(1.2, 1.6)
			cx = min(x + longueur / 2, 2.2 - longueur / 2)
			centre = Vector((cx, cote * rnd.uniform(0.19, 0.24), rnd.uniform(-0.02, 0.06)))
			lacet = rnd.uniform(-0.2, 0.2) + (math.pi if cote > 0 else 0.0)
			carte(m, centre, longueur, rnd.uniform(0.42, 0.7), lacet, rnd.uniform(0.08, 0.28), rnd.choice(FAGOT), rnd,
				retourner=rnd.random() < 0.5)
			x += longueur * rnd.uniform(0.55, 0.7)
		# branchages qui sortent de travers
		for _ in range(3):
			centre = Vector((rnd.uniform(-1.7, 1.7), cote * rnd.uniform(0.15, 0.2), rnd.uniform(0.1, 0.3)))
			lacet = rnd.choice((-1, 1)) * rnd.uniform(0.4, 0.7) + (math.pi if cote > 0 else 0.0)
			carte(m, centre, rnd.uniform(0.6, 0.85), rnd.uniform(0.32, 0.45), lacet, rnd.uniform(0.25, 0.45),
				rnd.choice(FAGOT), rnd, retourner=rnd.random() < 0.5)

	# Bouts : un fagot en travers ferme la tranche quand le segment finit une ligne.
	for signe in (-1, 1):
		centre = Vector((signe * 2.12, rnd.uniform(-0.04, 0.04), -0.02))
		carte(m, centre, rnd.uniform(0.5, 0.6), rnd.uniform(0.5, 0.6), math.pi / 2 + rnd.uniform(-0.3, 0.3),
			signe * rnd.uniform(0.1, 0.25), rnd.choice(FAGOT), rnd, retourner=rnd.random() < 0.5)

	# Deux fagots jetés en travers du dessus.
	for cx in (rnd.uniform(-1.4, -0.6), rnd.uniform(0.2, 1.0)):
		cote = rnd.choice((-1, 1))
		centre = Vector((cx, cote * rnd.uniform(0.0, 0.06), rnd.uniform(0.45, 0.55)))
		carte(m, centre, rnd.uniform(1.0, 1.3), rnd.uniform(0.38, 0.46), rnd.uniform(-0.35, 0.35) + (math.pi if cote > 0 else 0.0),
			rnd.uniform(0.6, 0.8), rnd.choice(FAGOT), rnd, retourner=rnd.random() < 0.5)

	# Touffes d'épines dressées en étoile (2 ou 3 cartes croisées) : crête irrégulière de 1,0 à 1,45 m,
	# lisible de face comme de la caméra haute ; une touffe à chaque bout arrondit la jonction avec le voisin.
	x = -2.05
	while x <= 2.06:
		bout = abs(abs(x) - 2.05) < 1e-3
		cartes = 3 if bout or rnd.random() < 0.6 else 2
		lacet0 = rnd.uniform(0, math.pi)
		haut = rnd.uniform(0.5, 0.65) if bout else rnd.uniform(0.55, 0.88)
		base = Vector((x + rnd.uniform(-0.05, 0.05), rnd.uniform(-0.06, 0.06), rnd.uniform(0.42, 0.55)))
		for k in range(cartes):
			carte(m, base, rnd.uniform(0.55, 0.7) if bout else rnd.uniform(0.75, 1.05), haut * rnd.uniform(0.85, 1.05),
				lacet0 + k * math.pi / cartes + rnd.uniform(-0.15, 0.15), rnd.uniform(-0.22, 0.22), rnd.choice(CRETE),
				rnd, retourner=rnd.random() < 0.5, cambrure=0.08)
		if bout and x > 0:
			break
		x = min(2.05, x + rnd.uniform(0.5, 0.68))

	for (x, y, nombre) in reglages["raketa"]:
		touffe_raketa(m, Vector((x, y, -0.03)), nombre, rnd)

	ob = m.objet("Palissade_" + nom, materiaux)
	print("Variante %s : %d triangles" % (nom, m.triangles()))
	return ob


def construire_banniere(materiaux):
	"""Drapeau un peu ondulé et épais (visible des deux côtés même avec un matériau à une face), accroché au
	sommet du piquet porte-bannière, flottant vers le centre du segment. Origine au centre du drapeau."""
	m = Maillage()
	colonnes = 4
	e = 0.012
	haut = HAUTEUR_PIQUET_BANNIERE - 0.04
	x_mat = PIQUET_BANNIERE.x - 0.04
	centre = Vector((x_mat - BANNIERE_LARGEUR / 2, PIQUET_BANNIERE.y, haut - BANNIERE_HAUTEUR / 2))
	faces_av, faces_ar = [], []
	for c in range(colonnes + 1):
		t = c / colonnes
		x = x_mat - BANNIERE_LARGEUR * t
		onde = 0.035 * math.sin(t * math.pi * 1.5) * t
		chute = 0.03 * t * t
		col_av, col_ar = [], []
		for z in (haut - BANNIERE_HAUTEUR - chute, haut - chute * 0.4):
			col_av.append(m.sommet(Vector((x, PIQUET_BANNIERE.y + onde - e, z)) - centre))
			col_ar.append(m.sommet(Vector((x, PIQUET_BANNIERE.y + onde + e, z)) - centre))
		faces_av.append(col_av)
		faces_ar.append(col_ar)
	for c in range(colonnes):
		u0, u1 = c / colonnes, (c + 1) / colonnes
		a0, a1 = faces_av[c], faces_av[c + 1]
		r0, r1 = faces_ar[c], faces_ar[c + 1]
		uv = lambda u, v: region_uv(ETOFFE, u, v)
		m.face([a0[0], a1[0], a1[1], a0[1]], [uv(u0, 0), uv(u1, 0), uv(u1, 1), uv(u0, 1)], MAT_BOIS, lisse=True)
		m.face([r1[0], r0[0], r0[1], r1[1]], [uv(u1, 0), uv(u0, 0), uv(u0, 1), uv(u1, 1)], MAT_BOIS, lisse=True)
		m.face([a0[1], a1[1], r1[1], r0[1]], [uv(u0, 1)] * 4, MAT_BOIS)          # tranche du haut
		m.face([r0[0], r1[0], a1[0], a0[0]], [uv(u0, 0)] * 4, MAT_BOIS)          # tranche du bas
	a, r = faces_av[-1], faces_ar[-1]
	m.face([a[0], r[0], r[1], a[1]], [uv(1, 0)] * 4, MAT_BOIS)                   # bord libre
	a, r = faces_av[0], faces_ar[0]
	m.face([r[0], a[0], a[1], r[1]], [uv(0, 0)] * 4, MAT_BOIS)                   # bord au mât
	ob = m.objet("Banniere", [materiaux[0]])
	ob.location = centre
	print("Banniere : %d triangles, centre %s" % (m.triangles(), tuple(round(c, 3) for c in centre)))
	return ob


def materiaux_atlas(chemin):
	image = bpy.data.images.load(chemin)
	image.name = "palissade_atlas"
	res = []
	for nom, decoupe in (("Palissade_bois", False), ("Palissade_epines", True)):
		mat = bpy.data.materials.new(nom)
		if not mat.node_tree:
			mat.use_nodes = True
		nt = mat.node_tree
		bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
		if bsdf is None:
			bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
			sortie = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None) or nt.nodes.new("ShaderNodeOutputMaterial")
			nt.links.new(bsdf.outputs[0], sortie.inputs["Surface"])
		tex = nt.nodes.new("ShaderNodeTexImage")
		tex.image = image
		nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
		bsdf.inputs["Roughness"].default_value = 0.95
		bsdf.inputs["Metallic"].default_value = 0.0
		if "Specular IOR Level" in bsdf.inputs:
			bsdf.inputs["Specular IOR Level"].default_value = 0.2
		if decoupe:
			arrondi = nt.nodes.new("ShaderNodeMath")
			arrondi.operation = 'ROUND'                       # → alphaMode MASK, seuil 0,5 à l'export glTF
			nt.links.new(tex.outputs["Alpha"], arrondi.inputs[0])
			nt.links.new(arrondi.outputs[0], bsdf.inputs["Alpha"])
			mat.use_backface_culling = False                  # → doubleSided
			if hasattr(mat, "surface_render_method"):
				mat.surface_render_method = 'DITHERED'
		else:
			mat.use_backface_culling = True
		res.append(mat)
	return res


# Scène vide.
for ob in list(bpy.data.objects):
	bpy.data.objects.remove(ob, do_unlink=True)
materiaux = materiaux_atlas(ATLAS)
objets = [construire_variante(nom, r, materiaux) for nom, r in VARIANTES.items()]
banniere = construire_banniere(materiaux)
for ob in objets:
	b = ob.bound_box
	xs, ys, zs = [c[0] for c in b], [c[1] for c in b], [c[2] for c in b]
	print("  %s : x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (ob.name, min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))

os.makedirs(os.path.dirname(SORTIE_BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=SORTIE_BLEND)

for ob in bpy.data.objects:
	ob.select_set(ob in objets or ob == banniere)
bpy.ops.export_scene.gltf(filepath=SORTIE_GLB, export_format='GLB', use_selection=True, export_apply=True,
	export_yup=True, export_materials='EXPORT',
	export_image_format='AUTO', export_animations=False, export_cameras=False, export_lights=False)
print("OK export", SORTIE_GLB)
