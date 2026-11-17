class_name Maisons
extends RefCounted
## Bâtiments du village modélisés par le code, d'après des photos de cases du Sud de Madagascar :
## petites cases rectangulaires posées sur la terre, murs en rondins horizontaux ou en roseaux tressés tenus par
## des lattes, poteaux d'angle, toit de chaume à deux pentes très raide qui déborde, perches croisées au faîte,
## porte en planches. Le Tsena est un abri ouvert couvert de tôle, avec des étals.
## Textures photo CC0 (assets/textures/batiments) en projection triplanaire : pas de coordonnées de texture.
## Repère : faîte le long de X, façade (porte) côté +Z, tournée vers la caméra.
## Renvoie {"maillage": Mesh, "banniere": Vector3} (emplacement du fanion du clan).

const DOSSIER := "res://assets/textures/batiments/"

static var _cache := {}
static var _materiaux := {}


static func modele(type_batiment: String) -> Dictionary:
	if _cache.has(type_batiment):
		return _cache[type_batiment]
	var resultat := {}
	match type_batiment:
		"case_centrale":
			resultat = _case(3.6, 3.2, 2.0, 2.2, false, 11)
		"case_hommes":
			resultat = _case(4.2, 3.0, 1.9, 2.0, true, 23)
		"camp_bois":
			resultat = _abri_bois()
		"tsena":
			resultat = _marche()
	_cache[type_batiment] = resultat
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
	var demi_x := largeur * 0.5
	var demi_z := profondeur * 0.5
	var bois := Color(0.85, 0.78, 0.7)
	# Poteaux d'angle, un peu irréguliers, dépassant sous le toit.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pied := Vector3(sx * demi_x, -0.1, sz * demi_z)
			var tete := pied + Vector3(h.randf_range(-0.05, 0.05), h_murs + 0.25, h.randf_range(-0.05, 0.05))
			_cylindre(c.st("bois"), pied, tete, 0.085, 7, bois * h.randf_range(0.8, 1.0))
	# Murs.
	var cotes := [
		[Vector3(-demi_x, 0, demi_z), Vector3(demi_x, 0, demi_z)],    # façade (+Z)
		[Vector3(demi_x, 0, -demi_z), Vector3(-demi_x, 0, -demi_z)],  # arrière
		[Vector3(-demi_x, 0, -demi_z), Vector3(-demi_x, 0, demi_z)],  # pignon -X
		[Vector3(demi_x, 0, demi_z), Vector3(demi_x, 0, -demi_z)],    # pignon +X
	]
	for cote: Array in cotes:
		var a: Vector3 = cote[0]
		var b: Vector3 = cote[1]
		if tressee:
			# Panneau de roseaux tressés + trois lattes horizontales et un piquet au milieu.
			_panneau(c.st("roseaux"), a, b, 0.0, h_murs, Color(0.92, 0.82, 0.66))
			var dehors := (b - a).cross(Vector3.UP).normalized() * -0.06
			for y: float in [0.35, h_murs * 0.55, h_murs - 0.15]:
				_cylindre(c.st("bois"), a + Vector3(0, y, 0) + dehors, b + Vector3(0, y, 0) + dehors, 0.035, 5, bois * 0.85)
			var milieu := (a + b) * 0.5 + dehors
			_cylindre(c.st("bois"), milieu + Vector3(0, -0.1, 0), milieu + Vector3(0, h_murs, 0), 0.05, 5, bois * 0.8)
		else:
			# Rondins horizontaux empilés, de diamètres un peu différents.
			var y := 0.06
			while y < h_murs:
				var r := h.randf_range(0.07, 0.095)
				var deborde := (b - a).normalized() * h.randf_range(0.08, 0.2)
				_cylindre(c.st("bois"), a - deborde + Vector3(0, y + r, 0), b + deborde + Vector3(0, y + r, 0), r, 6,
						bois * h.randf_range(0.72, 1.0))
				y += r * 1.9
	# Pignons : triangles sous le toit, du même matériau que les murs.
	var faite := h_murs + h_toit
	for sx: float in [-1.0, 1.0]:
		_triangle(c.st("roseaux" if tressee else "planches"), Vector3(sx * demi_x, h_murs, -demi_z),
				Vector3(sx * demi_x, h_murs, demi_z), Vector3(sx * demi_x, faite - 0.1, 0), Color(0.85, 0.76, 0.62))
	# Porte en planches sur la façade, décalée.
	var porte_x := h.randf_range(-0.6, 0.3)
	_boite(c.st("planches"), Vector3(porte_x, 0.85, demi_z + 0.07), Vector3(0.85, 1.7, 0.06), Color(0.8, 0.68, 0.55))
	# Toit de chaume épais, débordant, au bord effiloché.
	_toit_chaume(c, largeur + 0.7, profondeur + 1.0, h_murs - 0.05, faite, h)
	# Perches croisées au faîte, dépassant aux deux pignons.
	for sx: float in [-1.0, 1.0]:
		var x := sx * (demi_x + 0.3)
		for sz: float in [-1.0, 1.0]:
			var pied := Vector3(x, faite - 0.45, sz * 0.45)
			var bout := Vector3(x + sx * 0.05, faite + 0.75, -sz * 0.35)
			_cylindre(c.st("bois"), pied, bout, 0.035, 5, bois * 0.75)
	_cylindre(c.st("bois"), Vector3(-demi_x - 0.4, faite + 0.08, 0), Vector3(demi_x + 0.4, faite + 0.08, 0), 0.05, 5, bois * 0.8)
	return {"maillage": c.assembler(), "banniere": Vector3(demi_x + 0.35, faite + 0.85, 0)}


## Toit de chaume à deux pentes : chaque pan est une plaque épaisse ; le bord bas est dentelé (effiloché).
static func _toit_chaume(c: Chantier, longueur: float, profondeur: float, y_bas: float, y_faite: float,
		h: RandomNumberGenerator) -> void:
	var st := c.st("chaume")
	var paille := Color(0.86, 0.76, 0.6)
	var demi_l := longueur * 0.5
	var demi_p := profondeur * 0.5
	var epaisseur := 0.28
	for sz: float in [-1.0, 1.0]:
		var haut := Vector3(0, y_faite + 0.12, 0)
		var bas := Vector3(0, y_bas - 0.15, sz * demi_p)
		var pente := (bas - haut).normalized()
		var normale := Vector3(1, 0, 0).cross(pente).normalized()
		if normale.y < 0.0:
			normale = -normale
		var dessous := -normale * epaisseur
		# Dessus et dessous du pan.
		var p := [haut + Vector3(-demi_l, 0, 0), haut + Vector3(demi_l, 0, 0), bas + Vector3(demi_l, 0, 0), bas + Vector3(-demi_l, 0, 0)]
		_quad(st, p[0], p[1], p[2], p[3], normale, paille)
		_quad(st, p[0] + dessous, p[1] + dessous, p[2] + dessous, p[3] + dessous, -normale, paille * 0.7)
		# Bords latéraux (pignons).
		for k in [[0, 3], [1, 2]]:
			_quad(st, p[k[0]], p[k[1]], p[k[1]] + dessous, p[k[0]] + dessous, Vector3(signf(p[k[0]].x), 0, 0), paille * 0.8)
		# Bord bas dentelé : mèches de paille qui pendent.
		var n := int(longueur / 0.18)
		for i in n:
			var x0 := -demi_l + longueur * i / n
			var x1 := -demi_l + longueur * (i + 1) / n
			var pointe := (x0 + x1) * 0.5
			var chute := h.randf_range(0.12, 0.38)
			var a := bas + Vector3(x0, 0, 0)
			var b := bas + Vector3(x1, 0, 0)
			var t := bas + Vector3(pointe, -chute, sz * 0.05) + dessous * 0.5
			_triangle(st, a, b, t, paille * h.randf_range(0.75, 0.95))
			_triangle(st, a + dessous, b + dessous, t, paille * 0.65)


# --- Camp de bûcherons : abri ouvert et tas de bois ---

static func _abri_bois() -> Dictionary:
	var h := RandomNumberGenerator.new()
	h.seed = 37
	var c := Chantier.new()
	var bois := Color(0.85, 0.78, 0.7)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pied := Vector3(sx * 1.25, -0.1, sz * 1.1)
			_cylindre(c.st("bois"), pied, pied + Vector3(0, 2.0 if sz < 0.0 else 1.6, 0), 0.08, 6, bois * 0.85)
	_toit_chaume(c, 3.2, 3.0, 1.55, 2.25, h)
	# Tas de bûches coupées (empilées en pyramide le long de X).
	for rang in 4:
		for k in 5 - rang:
			var z := (k - (4 - rang) * 0.5) * 0.24
			var y := 0.11 + rang * 0.2
			var l := h.randf_range(1.4, 1.8)
			_cylindre(c.st("bois"), Vector3(-l * 0.5, y, z), Vector3(l * 0.5, y, z), h.randf_range(0.09, 0.12), 7,
					Color(0.95, 0.82, 0.66) * h.randf_range(0.8, 1.0))
	# Billot et quelques branches posées contre l'abri.
	_cylindre(c.st("bois"), Vector3(1.0, -0.05, 1.4), Vector3(1.0, 0.45, 1.4), 0.25, 9, bois)
	for k in 4:
		var x := -1.3 + k * 0.25
		_cylindre(c.st("bois"), Vector3(x, 0, 1.45), Vector3(x + 0.15, 1.8, 1.0), 0.045, 5, bois * 0.7)
	return {"maillage": c.assembler(), "banniere": Vector3(1.25, 2.6, -1.1)}


# --- Tsena : marché couvert de tôle, étals ---

static func _marche() -> Dictionary:
	var h := RandomNumberGenerator.new()
	h.seed = 53
	var c := Chantier.new()
	var bois := Color(0.85, 0.78, 0.7)
	# Poteaux et charpente.
	for x: float in [-2.3, 0.0, 2.3]:
		for sz: float in [-1.0, 1.0]:
			var pied := Vector3(x, -0.1, sz * 1.8)
			_cylindre(c.st("bois"), pied, pied + Vector3(0, 2.35 if sz < 0.0 else 2.05, 0), 0.08, 6, bois * 0.85)
	# Toit en tôle à une pente, en trois feuilles un peu décalées.
	var tole := Color(0.9, 0.85, 0.82)
	for k in 3:
		var x0 := -2.7 + k * 1.8
		var dy := h.randf_range(-0.03, 0.03)
		var a := Vector3(x0, 2.42 + dy, -2.15)
		var b := Vector3(x0 + 1.95, 2.42 + dy, -2.15)
		var cc := Vector3(x0 + 1.95, 2.1 + dy, 2.15)
		var d := Vector3(x0, 2.1 + dy, 2.15)
		var n := (b - a).cross(d - a).normalized()
		if n.y < 0.0:
			n = -n
		_quad(c.st("tole"), a, b, cc, d, n, tole * h.randf_range(0.85, 1.0))
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


## Panneau vertical de a à b (au sol), de y_bas à y_haut, épaisseur 6 cm.
static func _panneau(st: SurfaceTool, a: Vector3, b: Vector3, y_bas: float, y_haut: float, couleur: Color) -> void:
	var dehors := (b - a).cross(Vector3.UP).normalized() * -1.0
	var e := dehors * 0.03
	var bas_a := a + Vector3(0, y_bas, 0)
	var bas_b := b + Vector3(0, y_bas, 0)
	var haut_a := a + Vector3(0, y_haut, 0)
	var haut_b := b + Vector3(0, y_haut, 0)
	_quad(st, bas_a + e, bas_b + e, haut_b + e, haut_a + e, dehors, couleur)
	_quad(st, bas_a - e, bas_b - e, haut_b - e, haut_a - e, -dehors, couleur * 0.75)


static func _boite(st: SurfaceTool, centre: Vector3, taille: Vector3, couleur: Color) -> void:
	var d := taille * 0.5
	var faces := [
		[Vector3.UP, Vector3(1, 0, 0), Vector3(0, 0, 1)], [Vector3.DOWN, Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)], [Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := centre + n * d
		var du := u * d
		var dv := v * d
		_quad(st, c - du - dv, c + du - dv, c + du + dv, c - du + dv, n, couleur)
