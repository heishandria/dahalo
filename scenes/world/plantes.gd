class_name Plantes
extends RefCounted
## Plantes de l'Androy modélisées par le code (en attendant les modèles sur mesure, voir assets/models/decor) :
## - baobab (type Adansonia za, celui du Sud) : tronc en bouteille, couronne de branches courtes au sommet ;
## - épineux (type Alluaudia / Didierea) : plusieurs tiges dressées, couvertes de petites feuilles ;
## - raketa (figuier de Barbarie) : raquettes empilées en éventail, fruits rouges au bord.
## Baobab et épineux perdent leurs feuilles en sécheresse (comme dans la réalité) : voir saison().
## Maillages mis en cache par variante (3 de chaque) ; couleurs par sommet, matériaux partagés.

const VARIANTES := 3
const VARIANTES_BAOBAB := 6   # paires : élancé (allée des Baobabs), impaires : trapu (tronc massif, branches basses)

static var _cache := {}
static var _materiau_bois: StandardMaterial3D
static var _materiau_feuilles: StandardMaterial3D        # grappes de feuilles texturées (baobab)
static var _materiau_ecailles: StandardMaterial3D        # petites feuilles des épineux (couleur seule)
static var _materiau_raketa: StandardMaterial3D
static var _fondu: Tween


static func baobab(variante: int) -> Mesh:
	return _obtenir("baobab", variante % VARIANTES_BAOBAB)


## Rayon du pied du baobab (collision) : bien plus large pour les baobabs trapus.
static func rayon_baobab(variante: int) -> float:
	return 2.1 if variante % 2 == 1 else 1.3


static func epineux(variante: int) -> Mesh:
	return _obtenir("epineux", variante % VARIANTES)


static func raketa(variante: int) -> Mesh:
	return _obtenir("raketa", variante % VARIANTES)


## Variante tirée de la position (stable d'une partie à l'autre pour une même carte).
static func variante_en(pos: Vector3, nombre: int = VARIANTES) -> int:
	return absi(hash(Vector2i(roundi(pos.x * 10.0), roundi(pos.z * 10.0)))) % nombre


## Sécheresse : les feuilles jaunissent et tombent (fondu), elles reviennent avec les pluies.
static func saison(hote: Node, secheresse: bool) -> void:
	_materiaux()
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_fondu = hote.create_tween().set_parallel()
	var cible := Color(1.25, 0.95, 0.5, 0.0) if secheresse else Color(1, 1, 1, 1)
	_fondu.tween_property(_materiau_feuilles, "albedo_color", cible, 6.0)
	_fondu.tween_property(_materiau_ecailles, "albedo_color", cible, 6.0)


static func _obtenir(espece: String, variante: int) -> Mesh:
	var cle := "%s_%d" % [espece, variante]
	if not _cache.has(cle):
		_materiaux()
		var hasard := RandomNumberGenerator.new()
		hasard.seed = hash(cle)
		match espece:
			"baobab":
				_cache[cle] = _construire_baobab(hasard, variante % 2 == 1)
			"epineux":
				_cache[cle] = _construire_epineux(hasard)
			_:
				_cache[cle] = _construire_raketa(hasard)
	return _cache[cle]


static func _materiaux() -> void:
	if _materiau_bois != null:
		return
	_materiau_bois = _materiau(0.85)
	# Écorce photo (Poly Haven, CC0), projetée en triplanaire local : les maillages n'ont pas de coordonnées
	# de texture. La couleur par sommet la teinte (gris rosé du baobab, gris-vert des épineux).
	_materiau_bois.albedo_texture = load("res://assets/textures/plantes/ecorce_couleur.jpg")
	_materiau_bois.normal_enabled = true
	_materiau_bois.normal_texture = load("res://assets/textures/plantes/ecorce_relief.jpg")
	_materiau_bois.uv1_triplanar = true
	_materiau_bois.uv1_triplanar_sharpness = 4.0
	_materiau_bois.uv1_scale = Vector3(0.45, 0.45, 0.45)
	# Feuillage : plans croisés couverts d'une texture de feuilles découpée (pack CC0 Quaternius).
	# Découpe opaque (bien moins chère que la transparence) : les feuilles tombent à mi-chemin du fondu.
	_materiau_feuilles = _materiau(0.9)
	_materiau_feuilles.albedo_texture = load("res://assets/models/decor/quaternius_megakit/Leaves_NormalTree_C.png")
	_materiau_feuilles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_materiau_feuilles.alpha_scissor_threshold = 0.5
	_materiau_feuilles.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materiau_ecailles = _materiau(0.9)
	_materiau_ecailles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_materiau_ecailles.alpha_scissor_threshold = 0.5
	_materiau_feuilles.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materiau_raketa = _materiau(0.6)


static func _materiau(rugosite: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rugosite
	return m


# --- Baobab ---

static func _construire_baobab(h: RandomNumberGenerator, trapu: bool) -> ArrayMesh:
	var bois := SurfaceTool.new()
	bois.begin(Mesh.PRIMITIVE_TRIANGLES)
	var feuilles := SurfaceTool.new()
	feuilles.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Élancé : tronc haut presque cylindrique. Trapu : tronc court et massif, très évasé au pied (contreforts).
	var hauteur := h.randf_range(5.0, 6.5) if trapu else h.randf_range(9.0, 11.5)
	var rayon := h.randf_range(1.5, 1.9) if trapu else h.randf_range(1.0, 1.3)
	var profil: Array[Vector2] = []
	for k in 15:
		var t := k / 14.0
		var r: float
		if trapu:
			r = rayon * (1.35 - 0.35 * smoothstep(0.0, 0.3, t)) * (1.0 - 0.45 * smoothstep(0.4, 1.0, t))
		else:
			r = rayon * (1.18 - 0.18 * smoothstep(0.0, 0.25, t)) * (1.0 - 0.32 * smoothstep(0.55, 1.0, t))
		profil.append(Vector2(t * (hauteur + 0.4) - 0.4, r))   # le pied s'enfonce un peu dans le sol
	var ecorce := func(t: float, a: float) -> Color:
		# Gris rosé à ocre, plus sombre dans le creux des plis et vers le pied.
		var pli := 0.88 + 0.12 * cos(a * 9.0 + t * 2.0)
		return Color(1.25, 1.1, 1.0).lerp(Color(1.02, 0.88, 0.8), 1.0 - t) * pli
	_tour_cannele(bois, profil, 24, ecorce, h.randf() * TAU, 1.6 if trapu else 1.0)
	# Couronne : élancé, plate en ombrelle tout en haut ; trapu, grosses branches basses qui montent en s'étalant.
	var sommet := Vector3(0, hauteur - 0.3, 0)
	var nb := h.randi_range(5, 7)
	for b in nb:
		var angle := TAU * b / nb + h.randf_range(-0.3, 0.3)
		var depart := sommet
		var montee := h.randf_range(0.35, 0.75)
		var longueur := h.randf_range(2.0, 2.8)
		if trapu:
			# Les grosses branches partent à différentes hauteurs du haut du tronc et montent plus.
			depart = Vector3(0, hauteur * h.randf_range(0.72, 1.0) - 0.3, 0)
			montee = h.randf_range(0.6, 1.3)
			longueur = h.randf_range(2.6, 3.6)
		var dir := Vector3(cos(angle), montee, sin(angle)).normalized()
		var r_branche := rayon * (0.36 if trapu else 0.42)
		depart += Vector3(cos(angle), 0, sin(angle)) * rayon * 0.35
		_rameau(bois, feuilles, depart, dir, longueur, r_branche, 0, h, ecorce)
	return _assembler(bois, _materiau_bois, feuilles, _materiau_feuilles)


## Ramification récursive : chaque rameau, un peu coudé, se divise en 2 ou 3 rameaux plus fins et plus courts
## qui s'étalent ; de petites branches poussent aussi le long des grosses. Au bout, brindilles et feuilles.
static func _rameau(bois: SurfaceTool, feuilles: SurfaceTool, pied: Vector3, dir: Vector3, longueur: float,
		r_pied: float, niveau: int, h: RandomNumberGenerator, ecorce: Callable) -> void:
	var r_bout := r_pied * 0.55
	var segments: int = [6, 5, 4, 3, 3][niveau]
	# Grosses branches coudées : deux tronçons, le second dévié (branches tortueuses). Brindilles : un seul.
	var coude := pied + dir * longueur * 0.5
	var dir2 := dir
	var bout: Vector3
	if niveau <= 1:
		var r_milieu := lerpf(r_pied, r_bout, 0.5)
		_branche(bois, pied, dir, longueur * 0.5, r_pied, r_milieu, ecorce, segments)
		dir2 = (dir + Vector3(h.randf_range(-0.35, 0.35), h.randf_range(-0.15, 0.25), h.randf_range(-0.35, 0.35))).normalized()
		bout = _branche(bois, coude, dir2, longueur * 0.5, r_milieu, r_bout, ecorce, segments)
	else:
		bout = _branche(bois, pied, dir, longueur, r_pied, r_bout, ecorce, segments)
	if niveau >= 4:
		if h.randf() < 0.5:
			_grappe(feuilles, bout + Vector3(0, 0.05, 0), h.randf_range(0.25, 0.38), Color(0.6, 0.66, 0.46) * h.randf_range(0.85, 1.05), h)
		return
	# Petites branches le long du rameau (pas seulement au bout).
	if niveau >= 1 and niveau <= 2:
		for k in h.randi_range(1, 2):
			var t := h.randf_range(0.25, 0.9)
			var base := pied.lerp(coude, t * 2.0) if t < 0.5 else coude.lerp(bout, (t - 0.5) * 2.0)
			var lateral := (dir2.cross(Vector3.UP).normalized() * (1.0 if h.randf() < 0.5 else -1.0) \
					+ Vector3(0, h.randf_range(0.3, 0.9), 0)).normalized()
			var l := longueur * h.randf_range(0.25, 0.45)
			var b2 := _branche(bois, base, lateral, l, r_pied * 0.25, r_pied * 0.08, ecorce, 3)
			if h.randf() < 0.4:
				_grappe(feuilles, b2, h.randf_range(0.2, 0.32), Color(0.6, 0.66, 0.46) * h.randf_range(0.85, 1.05), h)
	var enfants := h.randi_range(2, 3) if niveau < 3 else 2
	for k in enfants:
		var horizontal := Vector3(dir2.x, 0.0, dir2.z).normalized()
		var cote := horizontal.cross(Vector3.UP)
		var ecart := (float(k) - (enfants - 1) * 0.5) * h.randf_range(0.5, 0.9)
		# Plus on monte dans la ramification, plus les rameaux s'étalent à l'horizontale (couronne plate).
		var montee := h.randf_range(0.15, 0.6) * (1.0 - 0.2 * niveau)
		var nouvelle := (horizontal + cote * ecart + Vector3(0, montee, 0)).normalized()
		_rameau(bois, feuilles, bout, nouvelle, longueur * h.randf_range(0.55, 0.72), r_bout, niveau + 1, h, ecorce)


## Tronc cannelé : surface de révolution dont le rayon ondule en plis verticaux qui serpentent un peu.
static func _tour_cannele(st: SurfaceTool, profil: Array[Vector2], segments: int, couleur: Callable, phase: float,
		relief: float = 1.0) -> void:
	var anneaux: Array = []
	for k in profil.size():
		var t := float(k) / (profil.size() - 1)
		var anneau: Array = []
		for s in segments + 1:
			var a := TAU * s / segments
			# Plis verticaux, plus marqués au pied (contreforts) chez les baobabs trapus.
			var pied := 1.0 + (relief - 1.0) * (1.0 - smoothstep(0.0, 0.5, t)) * 2.0
			var pli := (0.07 * cos(a * 9.0 + phase + t * 2.0) + 0.04 * sin(a * 4.0 + phase * 2.0 - t * 3.0)) * relief * pied
			pli += 0.06 * (relief - 1.0) * sin(a * 5.0 + phase) * (1.0 - t)   # gros lobes irréguliers
			var r := profil[k].y * (1.0 + pli)
			anneau.append([Vector3(cos(a) * r, profil[k].x, sin(a) * r), couleur.call(t, a)])
		anneaux.append(anneau)
	for k in anneaux.size() - 1:
		for s in segments:
			var quad := [anneaux[k][s], anneaux[k][s + 1], anneaux[k + 1][s + 1], anneaux[k + 1][s]]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(quad[i][1])
				st.add_vertex(quad[i][0])


## Grappe de feuilles : trois plans croisés (étoile) texturés, inclinés au hasard. Vue sous tous les angles.
static func _grappe(st: SurfaceTool, centre: Vector3, taille: float, couleur: Color, h: RandomNumberGenerator) -> void:
	var rotation := Basis(Vector3.UP, h.randf() * TAU) * Basis(Vector3.RIGHT, h.randf_range(-0.4, 0.4))
	for k in 3:
		var plan := rotation * Basis(Vector3.UP, PI * k / 3.0)
		if k == 2:
			plan = rotation * Basis(Vector3.RIGHT, PI * 0.5)   # un plan à plat, vu d'en haut
		var x := plan.x * taille
		var y := plan.y * taille
		var coins := [centre - x - y, centre + x - y, centre + x + y, centre - x + y]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(couleur)
			st.set_uv(uvs[i])
			st.add_vertex(coins[i])


# --- Épineux (Alluaudia) ---

static func _construire_epineux(h: RandomNumberGenerator) -> ArrayMesh:
	var bois := SurfaceTool.new()
	bois.begin(Mesh.PRIMITIVE_TRIANGLES)
	var feuilles := SurfaceTool.new()
	feuilles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tige_couleur := func(t: float, _a: float) -> Color:
		return Color(0.72, 0.8, 0.62).lerp(Color(0.86, 0.92, 0.74), t)
	var nb := h.randi_range(3, 6)
	for k in nb:
		var pied := Vector3(h.randf_range(-0.35, 0.35), 0.0, h.randf_range(-0.35, 0.35))
		var dir := Vector3(pied.x * 0.6 + h.randf_range(-0.12, 0.12), 1.0, pied.z * 0.6 + h.randf_range(-0.12, 0.12)).normalized()
		var longueur := h.randf_range(3.0, 5.2)
		_branche(bois, pied, dir, longueur, 0.16, 0.06, tige_couleur)
		# Petites feuilles le long de la tige (sauf la base) : rangées de petites écailles vertes.
		var n_feuilles := int(longueur * 11.0)
		for f in n_feuilles:
			var t := h.randf_range(0.18, 0.98)
			var p := pied + dir * longueur * t
			var a := h.randf() * TAU
			var vers := Vector3(cos(a), 0.25, sin(a)) * 0.22
			_ecaille(feuilles, p + vers * 0.5, vers, Color(0.26, 0.36, 0.15) * h.randf_range(0.8, 1.15))
	return _assembler(bois, _materiau_bois, feuilles, _materiau_ecailles)


# --- Raketa (figuier de Barbarie) ---

static func _construire_raketa(h: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vert := Color(0.36, 0.5, 0.28)
	# Raquettes posées en éventail : chaque raquette en porte une ou deux au-dessus.
	var a_traiter: Array = [[Vector3(0, 0.0, 0), Vector3.UP, 0]]
	var raquettes := 0
	while not a_traiter.is_empty() and raquettes < 11:
		var r: Array = a_traiter.pop_front()
		var base: Vector3 = r[0]
		var dir: Vector3 = r[1]
		var niveau: int = r[2]
		var taille := h.randf_range(0.55, 0.75) * (1.0 - 0.12 * niveau)
		var centre := base + dir * taille * 0.85
		var face := h.randf() * TAU
		var axes := Basis.looking_at(Vector3(cos(face), 0, sin(face)), dir).orthonormalized()
		var forme := Basis(axes.x * taille * 0.75, dir * taille, axes.z * taille * 0.12)
		_ellipsoide(st, Transform3D(forme, centre), vert * h.randf_range(0.88, 1.12), 10, 6)
		raquettes += 1
		if niveau < 3:
			for k in (2 if niveau < 2 else h.randi_range(1, 2)):
				# Les raquettes s'ouvrent en éventail, de part et d'autre (pas en colonne).
				var cote := 1.0 if k == 0 else -1.0
				var nouvelle := (dir * 0.6 + axes.x * cote * h.randf_range(0.6, 1.1) + Vector3(0, 0.25, 0)).normalized()
				a_traiter.append([centre + dir * taille * 0.8, nouvelle, niveau + 1])
		else:
			# Fruits sur le bord des raquettes du haut.
			for k in h.randi_range(1, 3):
				var p := centre + dir * taille * 0.95 + axes.x * taille * h.randf_range(-0.5, 0.5)
				_ellipsoide(st, Transform3D(Basis().scaled(Vector3.ONE * 0.1), p), Color(0.62, 0.12, 0.22), 6, 4)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _materiau_raketa)
	return m


# --- Briques de construction ---

## Surface de révolution le long de Y (profil : [hauteur, rayon]), légèrement irrégulière.
static func _tour(st: SurfaceTool, t: Transform3D, profil: Array[Vector2], segments: int, couleur: Callable,
		phase: float, bosses: float) -> void:
	var anneaux: Array = []
	for k in profil.size():
		var anneau: Array = []
		for s in segments + 1:
			var a := TAU * s / segments
			var r := profil[k].y * (1.0 + bosses * sin(a * 3.0 + phase + k * 0.7))
			anneau.append([t * Vector3(cos(a) * r, profil[k].x, sin(a) * r), couleur.call(float(k) / (profil.size() - 1), a)])
		anneaux.append(anneau)
	for k in anneaux.size() - 1:
		for s in segments:
			var quad := [anneaux[k][s], anneaux[k][s + 1], anneaux[k + 1][s + 1], anneaux[k + 1][s]]
			for i in [0, 1, 2, 0, 2, 3]:   # sens des aiguilles d'une montre vu de l'extérieur (face avant pour Godot)
				st.set_color(quad[i][1])
				st.add_vertex(quad[i][0])


## Branche conique de pied vers pied + dir * longueur ; renvoie le bout.
static func _branche(st: SurfaceTool, pied: Vector3, dir: Vector3, longueur: float, r_pied: float, r_bout: float,
		couleur: Callable, segments: int = 7) -> Vector3:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var profil: Array[Vector2] = [Vector2(0, r_pied), Vector2(longueur * 0.5, lerpf(r_pied, r_bout, 0.5)), Vector2(longueur, r_bout)]
	_tour(st, Transform3D(Basis(x, y, z), pied), profil, segments, couleur, 0.0, 0.0)
	return pied + y * longueur


## Petite écaille de feuille (losange) orientée vers l'extérieur de la tige.
static func _ecaille(st: SurfaceTool, centre: Vector3, vers: Vector3, couleur: Color) -> void:
	var cote := vers.cross(Vector3.UP).normalized() * 0.09
	var pts := [centre - vers * 0.5, centre + cote, centre + vers * 0.5 + Vector3(0, 0.05, 0), centre - cote]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(couleur)
		st.add_vertex(pts[i])


static func _ellipsoide(st: SurfaceTool, t: Transform3D, couleur: Color, segments: int, anneaux: int) -> void:
	for j in anneaux:
		var v0 := PI * j / anneaux - PI * 0.5
		var v1 := PI * (j + 1) / anneaux - PI * 0.5
		for s in segments:
			var u0 := TAU * s / segments
			var u1 := TAU * (s + 1) / segments
			var p := [Vector3(cos(v0) * cos(u0), sin(v0), cos(v0) * sin(u0)), Vector3(cos(v0) * cos(u1), sin(v0), cos(v0) * sin(u1)),
					Vector3(cos(v1) * cos(u1), sin(v1), cos(v1) * sin(u1)), Vector3(cos(v1) * cos(u0), sin(v1), cos(v1) * sin(u0))]
			for i in [0, 1, 2, 0, 2, 3]:   # sens des aiguilles d'une montre vu de l'extérieur (face avant pour Godot)
				st.set_color(couleur)
				st.add_vertex(t * p[i])


static func _assembler(bois: SurfaceTool, mat_bois: Material, feuilles: SurfaceTool, mat_feuilles: Material) -> ArrayMesh:
	bois.generate_normals()
	var m := bois.commit()
	m.surface_set_material(0, mat_bois)
	feuilles.generate_normals()
	feuilles.commit(m)
	m.surface_set_material(1, mat_feuilles)
	return m
