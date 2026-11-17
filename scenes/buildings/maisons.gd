class_name Maisons
extends RefCounted
## Bâtiments du village modélisés par le code, d'après des photos de cases du Sud de Madagascar :
## petites cases rectangulaires posées sur la terre, murs en rondins horizontaux ou en roseaux tressés tenus par
## des lattes, poteaux d'angle, toit de chaume à deux pentes très raide qui déborde, perches croisées au faîte,
## porte en planches. Le Tsena est un abri ouvert couvert de tôle, avec des étals.
## Textures photo CC0 (assets/textures/batiments) en projection triplanaire : pas de coordonnées de texture.
## Repère : faîte le long de X, façade (porte) côté +Z, tournée vers la caméra.
## Fait main : rien n'est d'équerre ni droit (angles décalés, rondins tordus, toit affaissé, porte de travers,
## tôles mal alignées). 3 variantes par bâtiment, tirées de la position.
## Renvoie {"maillage": Mesh, "banniere": Vector3} (emplacement du fanion du clan).

const DOSSIER := "res://assets/textures/batiments/"

static var _cache := {}
static var _materiaux := {}


const VARIANTES := 3


static func modele(type_batiment: String, variante: int = 0) -> Dictionary:
	var cle := "%s_%d" % [type_batiment, variante % VARIANTES]
	if _cache.has(cle):
		return _cache[cle]
	var graine := hash(cle)
	var resultat := {}
	match type_batiment:
		"case_centrale":
			resultat = _case(3.6, 3.2, 2.0, 2.2, false, graine)
		"case_hommes":
			resultat = _case(4.2, 3.0, 1.9, 2.0, true, graine)
		"camp_bois":
			resultat = _abri_bois(graine)
		"tsena":
			resultat = _marche(graine)
	_cache[cle] = resultat
	return resultat


# --- Matériaux ---

static func _materiau(nom: String) -> StandardMaterial3D:
	if _materiaux.has(nom):
		return _materiaux[nom]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # robuste quel que soit le sens des triangles
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 6.0
	m.roughness = 0.95
	var fichiers := {"chaume": "reed_roof_04", "bois": "wood_trunk_wall", "roseaux": "bamboo_wall",
			"planches": "weathered_planks", "tole": "rusty_corrugated_iron"}
	var base: String = fichiers[nom]
	m.albedo_texture = load(DOSSIER + base + "_couleur.jpg")
	if ResourceLoader.exists(DOSSIER + base + "_relief.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(DOSSIER + base + "_relief.jpg")
	var echelles := {"chaume": 0.45, "bois": 0.8, "roseaux": 0.6, "planches": 0.6, "tole": 0.5}
	m.uv1_scale = Vector3.ONE * float(echelles[nom])
	# Les textures photo sont sombres ; le bois des cases du Sud est gris-brun délavé par le soleil.
	var eclairage := {"chaume": Color(1.15, 1.05, 0.92), "bois": Color(1.9, 1.75, 1.55), "roseaux": Color(1.25, 1.15, 1.0),
			"planches": Color(1.6, 1.5, 1.35), "tole": Color(1.7, 1.55, 1.45)}
	m.albedo_color = eclairage[nom]
	if nom == "tole":
		m.metallic = 0.4
		m.roughness = 0.7
	_materiaux[nom] = m
	return m


## Un SurfaceTool par matériau ; assemblés en un seul maillage à surfaces multiples.
class Chantier:
	var surfaces := {}

	func st(nom: String) -> SurfaceTool:
		if not surfaces.has(nom):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[nom] = s
		return surfaces[nom]

	func assembler() -> ArrayMesh:
		var m := ArrayMesh.new()
		for nom in surfaces:
			var s: SurfaceTool = surfaces[nom]
			s.commit(m)
			m.surface_set_material(m.get_surface_count() - 1, Maisons._materiau(nom))
		return m


# --- Case ---

## Case rectangulaire : largeur le long du faîte (X), profondeur (Z), hauteur des murs, hauteur du toit au-dessus.
static func _case(largeur: float, profondeur: float, h_murs: float, h_toit: float, tressee: bool, graine: int) -> Dictionary:
	var h := RandomNumberGenerator.new()
	h.seed = graine
	var c := Chantier.new()
	var demi_x := largeur * 0.5 * h.randf_range(0.92, 1.05)
	var demi_z := profondeur * 0.5 * h.randf_range(0.92, 1.05)
	var bois := Color(0.85, 0.78, 0.7)
	# Angles décalés (rien n'est d'équerre) et hauteur propre à chaque angle.
	var coins := {}
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			coins[Vector2(sx, sz)] = Vector3(sx * demi_x + h.randf_range(-0.12, 0.12), 0, sz * demi_z + h.randf_range(-0.1, 0.1))
	var hauteurs := {}
	for k in coins:
		hauteurs[k] = h_murs + h.randf_range(-0.12, 0.08)
	# Poteaux d'angle tordus et penchés.
	for k in coins:
		var pied: Vector3 = coins[k] + Vector3(0, -0.1, 0)
		var tete := pied + Vector3(h.randf_range(-0.12, 0.12), float(hauteurs[k]) + 0.3, h.randf_range(-0.12, 0.12))
		_tordu(c.st("bois"), pied, tete, h.randf_range(0.07, 0.1), 6, bois * h.randf_range(0.75, 1.0), h, 0.06)
	var cotes := [
		[Vector2(-1, 1), Vector2(1, 1)], [Vector2(1, -1), Vector2(-1, -1)],
		[Vector2(-1, -1), Vector2(-1, 1)], [Vector2(1, 1), Vector2(1, -1)],
	]
	for cote: Array in cotes:
		var a: Vector3 = coins[cote[0]]
		var b: Vector3 = coins[cote[1]]
		var ha: float = hauteurs[cote[0]]
		var hb: float = hauteurs[cote[1]]
		if tressee:
			# Panneau de roseaux tressés, un peu bombé, tenu par des lattes tordues.
			_panneau(c.st("roseaux"), a, b, 0.0, minf(ha, hb), Color(0.92, 0.82, 0.66) * h.randf_range(0.85, 1.05), h)
			var dehors := (b - a).cross(Vector3.UP).normalized() * -0.07
			for y: float in [0.3, 0.55, 0.92]:
				var ya := ha * y + h.randf_range(-0.08, 0.08)
				var yb := hb * y + h.randf_range(-0.08, 0.08)
				_tordu(c.st("bois"), a + Vector3(0, ya, 0) + dehors, b + Vector3(0, yb, 0) + dehors, 0.035, 5,
						bois * h.randf_range(0.7, 0.9), h, 0.05)
			var milieu := a.lerp(b, h.randf_range(0.4, 0.6)) + dehors
			_tordu(c.st("bois"), milieu + Vector3(0, -0.1, 0), milieu + Vector3(h.randf_range(-0.1, 0.1), (ha + hb) * 0.5, 0), 0.05, 5,
					bois * 0.8, h, 0.05)
		else:
			# Rondins tordus, de diamètres et longueurs inégaux, avec des jours entre eux.
			var y := 0.04
			var hmax := minf(ha, hb)
			while y < hmax:
				var r := h.randf_range(0.065, 0.11)
				var dir := (b - a).normalized()
				var pa := a - dir * h.randf_range(0.05, 0.3) + Vector3(0, y + r + h.randf_range(-0.03, 0.03), 0)
				var pb := b + dir * h.randf_range(0.05, 0.3) + Vector3(0, y + r + h.randf_range(-0.03, 0.03), 0)
				_tordu(c.st("bois"), pa, pb, r, 6, bois * h.randf_range(0.65, 1.0), h, 0.05)
				y += r * h.randf_range(1.85, 2.1)
	# Pignons : triangles sous le toit, en planches ou roseaux.
	var faite := h_murs + h_toit
	for sx: float in [-1.0, 1.0]:
		var p0: Vector3 = coins[Vector2(sx, -1)] + Vector3(0, float(hauteurs[Vector2(sx, -1)]), 0)
		var p1: Vector3 = coins[Vector2(sx, 1)] + Vector3(0, float(hauteurs[Vector2(sx, 1)]), 0)
		var sommet := (p0 + p1) * 0.5
		sommet.y = faite - 0.15
		_triangle(c.st("roseaux" if tressee else "planches"), p0, p1, sommet, Color(0.85, 0.76, 0.62) * h.randf_range(0.8, 1.0))
	# Porte de planches inégales, un peu de travers, avec des jours.
	_porte(c, Vector3(h.randf_range(-0.6, 0.3) * demi_x, 0, demi_z + 0.09), h)
	# Toit de chaume épais, débordant, affaissé et bosselé, au bord effiloché.
	_toit_chaume(c, demi_x * 2.0 + h.randf_range(0.6, 0.9), demi_z * 2.0 + h.randf_range(0.9, 1.2), h_murs - 0.1, faite, h)
	# Perches croisées au faîte, inégales, dépassant aux deux pignons.
	for sx: float in [-1.0, 1.0]:
		var x := sx * (demi_x + h.randf_range(0.2, 0.4))
		for sz: float in [-1.0, 1.0]:
			var pied := Vector3(x, faite - 0.5, sz * h.randf_range(0.35, 0.55))
			var bout := Vector3(x + sx * h.randf_range(0.0, 0.12), faite + h.randf_range(0.55, 0.95), -sz * h.randf_range(0.25, 0.45))
			_tordu(c.st("bois"), pied, bout, 0.035, 5, bois * h.randf_range(0.65, 0.85), h, 0.04)
	_tordu(c.st("bois"), Vector3(-demi_x - 0.4, faite + 0.02, 0), Vector3(demi_x + 0.4, faite + 0.04, 0), 0.05, 5, bois * 0.8, h, 0.06)
	return {"maillage": c.assembler(), "banniere": Vector3(demi_x + 0.35, faite + 0.85, 0)}


## Porte faite de 4 planches de largeurs et hauteurs inégales, avec des jours, légèrement de travers.
static func _porte(c: Chantier, centre_bas: Vector3, h: RandomNumberGenerator) -> void:
	var penche := Basis(Vector3.UP, h.randf_range(-0.12, 0.12)) * Basis(Vector3(0, 0, 1), h.randf_range(-0.04, 0.04))
	var x := -0.42
	for k in 4:
		var l := h.randf_range(0.17, 0.24)
		var hauteur := h.randf_range(1.6, 1.78)
		var centre := centre_bas + penche * Vector3(x + l * 0.5, hauteur * 0.5, 0)
		_boite(c.st("planches"), centre, Vector3(l - 0.02, hauteur, 0.05), Color(0.8, 0.68, 0.55) * h.randf_range(0.75, 1.05), penche)
		x += l + h.randf_range(0.0, 0.03)
	# Deux traverses clouées.
	for y: float in [0.35, 1.3]:
		var centre := centre_bas + penche * Vector3(0, y + h.randf_range(-0.05, 0.05), 0.04)
		_boite(c.st("planches"), centre, Vector3(0.82, 0.1, 0.04), Color(0.7, 0.6, 0.48), penche * Basis(Vector3(0, 0, 1), h.randf_range(-0.08, 0.08)))


## Toit de chaume à deux pentes : chaque pan est une grille (affaissée au milieu, bosselée, épaisseur inégale) ;
## le bord bas ondule et pend en mèches de longueurs différentes.
static func _toit_chaume(c: Chantier, longueur: float, profondeur: float, y_bas: float, y_faite: float,
		h: RandomNumberGenerator) -> void:
	var st := c.st("chaume")
	var paille := Color(0.86, 0.76, 0.6)
	var demi_l := longueur * 0.5
	var demi_p := profondeur * 0.5
	var nu := 8
	var nv := 4
	var affaissement := h.randf_range(0.08, 0.2)
	var bruit := FastNoiseLite.new()
	bruit.seed = h.randi()
	bruit.frequency = 0.9
	for sz: float in [-1.0, 1.0]:
		var grille: Array = []
		for i in nu + 1:
			var ligne: Array = []
			var u := float(i) / nu
			for j in nv + 1:
				var v := float(j) / nv
				var x := lerpf(-demi_l, demi_l, u)
				var p := Vector3(x, lerpf(y_faite + 0.12, y_bas - 0.15, v), lerpf(0.0, sz * demi_p, v))
				p.y -= affaissement * sin(PI * u) * (1.0 - 0.4 * v)     # faîte et pan affaissés au milieu
				p.y += bruit.get_noise_2d(x, p.z + sz * 10.0) * 0.07     # bosses du chaume
				if j == nv:
					p.y += bruit.get_noise_2d(x * 2.0, sz * 7.0) * 0.12  # bord bas qui ondule
					p.z += sz * bruit.get_noise_2d(x * 1.5, sz * 3.0) * 0.15
				ligne.append(p)
			grille.append(ligne)
		for i in nu:
			for j in nv:
				var a: Vector3 = grille[i][j]
				var b: Vector3 = grille[i + 1][j]
				var cc: Vector3 = grille[i + 1][j + 1]
				var d: Vector3 = grille[i][j + 1]
				var n := (b - a).cross(d - a).normalized()
				if n.y < 0.0:
					n = -n
				var teinte := paille * (0.82 + 0.25 * (bruit.get_noise_2d(i * 3.0, j * 3.0 + sz * 20.0) * 0.5 + 0.5))
				var epaisseur := -n * h.randf_range(0.22, 0.34)
				_quad(st, a, b, cc, d, n, teinte)
				_quad(st, a + epaisseur, b + epaisseur, cc + epaisseur, d + epaisseur, -n, paille * 0.6)
		# Bords latéraux (pignons) et mèches qui pendent au bord bas.
		for i: int in [0, nu]:
			for j in nv:
				var a: Vector3 = grille[i][j]
				var d: Vector3 = grille[i][j + 1]
				_quad(st, a, d, d + Vector3(0, -0.28, 0), a + Vector3(0, -0.28, 0), Vector3(signf(a.x), 0, 0), paille * 0.75)
		var n_meches := int(longueur / 0.13)
		for k in n_meches:
			var u := (k + h.randf_range(0.0, 0.6)) / n_meches
			var i := mini(int(u * nu), nu - 1)
			var t := u * nu - i
			var bord: Vector3 = (grille[i][nv] as Vector3).lerp(grille[i + 1][nv], t)
			var largeur := h.randf_range(0.08, 0.2)
			var chute := h.randf_range(0.08, 0.45)
			var a := bord + Vector3(-largeur, 0, 0)
			var b := bord + Vector3(largeur, 0, 0)
			var bout := bord + Vector3(h.randf_range(-0.05, 0.05), -chute, sz * h.randf_range(0.02, 0.1))
			_triangle(st, a, b, bout, paille * h.randf_range(0.65, 0.95))


# --- Camp de bûcherons : abri ouvert et tas de bois ---

static func _abri_bois(graine: int) -> Dictionary:
	var h := RandomNumberGenerator.new()
	h.seed = graine
	var c := Chantier.new()
	var bois := Color(0.85, 0.78, 0.7)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pied := Vector3(sx * 1.25 + h.randf_range(-0.1, 0.1), -0.1, sz * 1.1 + h.randf_range(-0.1, 0.1))
			var tete := pied + Vector3(h.randf_range(-0.12, 0.12), (2.0 if sz < 0.0 else 1.6) + h.randf_range(-0.1, 0.1), h.randf_range(-0.1, 0.1))
			_tordu(c.st("bois"), pied, tete, h.randf_range(0.07, 0.1), 6, bois * h.randf_range(0.7, 0.95), h, 0.06)
	_toit_chaume(c, 3.2, 3.0, 1.55, 2.25, h)
	# Tas de bûches coupées (empilées en pyramide le long de X).
	for rang in 4:
		for k in 5 - rang:
			var z := (k - (4 - rang) * 0.5) * 0.24
			var y := 0.11 + rang * 0.2
			var l := h.randf_range(1.4, 1.8)
			var decale := h.randf_range(-0.15, 0.15)
			_tordu(c.st("bois"), Vector3(-l * 0.5 + decale, y, z + h.randf_range(-0.03, 0.03)),
					Vector3(l * 0.5 + decale, y + h.randf_range(-0.03, 0.03), z + h.randf_range(-0.06, 0.06)),
					h.randf_range(0.08, 0.13), 7, Color(0.95, 0.82, 0.66) * h.randf_range(0.7, 1.0), h, 0.03)
	# Billot et quelques branches posées contre l'abri.
	_cylindre(c.st("bois"), Vector3(1.0, -0.05, 1.4), Vector3(1.0, 0.45, 1.4), 0.25, 9, bois)
	for k in 4:
		var x := -1.3 + k * 0.25
		_cylindre(c.st("bois"), Vector3(x, 0, 1.45), Vector3(x + 0.15, 1.8, 1.0), 0.045, 5, bois * 0.7)
	return {"maillage": c.assembler(), "banniere": Vector3(1.25, 2.6, -1.1)}


# --- Tsena : marché couvert de tôle, étals ---

static func _marche(graine: int) -> Dictionary:
	var h := RandomNumberGenerator.new()
	h.seed = graine
	var c := Chantier.new()
	var bois := Color(0.85, 0.78, 0.7)
	# Poteaux et charpente.
	for x: float in [-2.3, 0.0, 2.3]:
		for sz: float in [-1.0, 1.0]:
			var pied := Vector3(x + h.randf_range(-0.12, 0.12), -0.1, sz * 1.8 + h.randf_range(-0.1, 0.1))
			var tete := pied + Vector3(h.randf_range(-0.1, 0.1), (2.35 if sz < 0.0 else 2.05) + h.randf_range(-0.06, 0.06), h.randf_range(-0.08, 0.08))
			_tordu(c.st("bois"), pied, tete, h.randf_range(0.07, 0.1), 6, bois * h.randf_range(0.7, 0.95), h, 0.06)
	# Toit en tôles de récupération mal alignées, de rouilles différentes, tenues par des pierres.
	var tole := Color(0.9, 0.85, 0.82)
	var x0 := -2.75
	while x0 < 2.6:
		var l := h.randf_range(0.85, 1.25)
		var dz := h.randf_range(-0.2, 0.2)
		var torsion := h.randf_range(-0.06, 0.06)
		var a := Vector3(x0, 2.42 + torsion, -2.15 + dz)
		var b := Vector3(x0 + l, 2.42 - torsion, -2.15 + dz + h.randf_range(-0.08, 0.08))
		var cc := Vector3(x0 + l + h.randf_range(-0.05, 0.05), 2.1 - torsion, 2.15 + dz)
		var d := Vector3(x0, 2.1 + torsion, 2.15 + dz)
		var n := (b - a).cross(d - a).normalized()
		if n.y < 0.0:
			n = -n
		_quad(c.st("tole"), a, b, cc, d, n, tole * Color(h.randf_range(0.75, 1.1), h.randf_range(0.7, 1.0), h.randf_range(0.65, 0.95)))
		if h.randf() < 0.6:
			var p := a.lerp(cc, h.randf_range(0.3, 0.7)) + Vector3(0, 0.1, 0)
			_boite(c.st("bois"), p, Vector3(h.randf_range(0.18, 0.3), 0.14, h.randf_range(0.15, 0.25)), Color(0.55, 0.53, 0.5),
					Basis(Vector3.UP, h.randf() * TAU))
		x0 += l - h.randf_range(0.05, 0.15)   # les feuilles se chevauchent
	# Deux étals en planches sur tréteaux, avec des paniers et des tas de produits.
	for x: float in [-1.2, 1.2]:
		_boite(c.st("planches"), Vector3(x, 0.8, 0.3), Vector3(1.8, 0.08, 0.9), Color(0.85, 0.72, 0.58))
		for sx: float in [-1.0, 1.0]:
			_cylindre(c.st("bois"), Vector3(x + sx * 0.75, 0, 0.3), Vector3(x + sx * 0.75, 0.8, 0.3), 0.05, 5, bois * 0.8)
		for k in 3:
			var p := Vector3(x - 0.55 + k * 0.55, 0.84, 0.3 + h.randf_range(-0.15, 0.15))
			var couleur: Color = [Color(0.85, 0.7, 0.45), Color(0.6, 0.3, 0.2), Color(0.75, 0.6, 0.3)][k]
			_cylindre(c.st("roseaux"), p, p + Vector3(0, 0.22, 0), 0.2, 9, couleur)   # panier tressé
	# Sacs posés au sol.
	for k in 3:
		_boite(c.st("planches"), Vector3(-2.0 + k * 0.5, 0.22, -1.2), Vector3(0.4, 0.45, 0.35), Color(0.9, 0.82, 0.68))
	return {"maillage": c.assembler(), "banniere": Vector3(2.3, 2.95, -1.8)}


# --- Briques de construction (normales données explicitement) ---

## Bois tordu : trois tronçons dont les points intermédiaires sont décalés au hasard (branche non équarrie).
static func _tordu(st: SurfaceTool, a: Vector3, b: Vector3, rayon: float, segments: int, couleur: Color,
		h: RandomNumberGenerator, courbure: float) -> void:
	var longueur := a.distance_to(b)
	var ecart := courbure * longueur
	var p1 := a.lerp(b, 0.33) + Vector3(h.randf_range(-ecart, ecart), h.randf_range(-ecart, ecart) * 0.6, h.randf_range(-ecart, ecart))
	var p2 := a.lerp(b, 0.66) + Vector3(h.randf_range(-ecart, ecart), h.randf_range(-ecart, ecart) * 0.6, h.randf_range(-ecart, ecart))
	_cylindre(st, a, p1, rayon, segments, couleur)
	_cylindre(st, p1, p2, rayon * h.randf_range(0.88, 1.0), segments, couleur * h.randf_range(0.92, 1.05))
	_cylindre(st, p2, b, rayon * h.randf_range(0.8, 0.95), segments, couleur)

static func _cylindre(st: SurfaceTool, a: Vector3, b: Vector3, rayon: float, segments: int, couleur: Color) -> void:
	var axe := (b - a).normalized()
	var x := axe.cross(Vector3.UP if absf(axe.y) < 0.9 else Vector3.RIGHT).normalized()
	var z := axe.cross(x)
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var n0 := x * cos(a0) + z * sin(a0)
		var n1 := x * cos(a1) + z * sin(a1)
		var sommets := [[a + n0 * rayon, n0], [a + n1 * rayon, n1], [b + n1 * rayon, n1], [b + n0 * rayon, n0]]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(couleur)
			st.set_normal(sommets[i][1])
			st.add_vertex(sommets[i][0])
	# Bouts (coupes de bûche).
	for extremite: Array in [[a, -axe], [b, axe]]:
		var centre: Vector3 = extremite[0]
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			for p in [centre, centre + (x * cos(a0) + z * sin(a0)) * rayon, centre + (x * cos(a1) + z * sin(a1)) * rayon]:
				st.set_color(couleur * 1.1)
				st.set_normal(extremite[1])
				st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normale: Vector3, couleur: Color) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_color(couleur)
		st.set_normal(normale)
		st.add_vertex(p)


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, couleur: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		st.set_color(couleur)
		st.set_normal(n)
		st.add_vertex(p)


## Panneau tressé de a à b (au sol), de y_bas à y_haut : bombé, bord haut irrégulier, teinte par plaques.
static func _panneau(st: SurfaceTool, a: Vector3, b: Vector3, y_bas: float, y_haut: float, couleur: Color,
		h: RandomNumberGenerator) -> void:
	var dehors := (b - a).cross(Vector3.UP).normalized() * -1.0
	var n := 5
	var points: Array[Vector3] = []
	var hauts: Array[float] = []
	for k in n + 1:
		var t := float(k) / n
		points.append(a.lerp(b, t) + dehors * (sin(PI * t) * h.randf_range(0.03, 0.08)))
		hauts.append(y_haut + h.randf_range(-0.08, 0.04))
	for k in n:
		var teinte := couleur * h.randf_range(0.85, 1.08)
		var bas_a := points[k] + Vector3(0, y_bas, 0)
		var bas_b := points[k + 1] + Vector3(0, y_bas, 0)
		var haut_a := points[k] + Vector3(0, hauts[k], 0)
		var haut_b := points[k + 1] + Vector3(0, hauts[k + 1], 0)
		_quad(st, bas_a, bas_b, haut_b, haut_a, dehors, teinte)


static func _boite(st: SurfaceTool, centre: Vector3, taille: Vector3, couleur: Color, base := Basis.IDENTITY) -> void:
	var d := taille * 0.5
	var faces := [
		[Vector3.UP, Vector3(1, 0, 0), Vector3(0, 0, 1)], [Vector3.DOWN, Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)], [Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f: Array in faces:
		var n: Vector3 = base * (f[0] as Vector3)
		var u: Vector3 = base * (f[1] as Vector3)
		var v: Vector3 = base * (f[2] as Vector3)
		var c := centre + n * absf((f[0] as Vector3).dot(d))
		var du := u * absf((f[1] as Vector3).dot(d))
		var dv := v * absf((f[2] as Vector3).dot(d))
		_quad(st, c - du - dv, c + du - dv, c + du + dv, c - du + dv, n, couleur)
