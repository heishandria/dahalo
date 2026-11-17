extends Node3D
## Tout le visuel du terrain : sol de la zone de jeu (lit de rivière en contrebas), plateaux en paliers
## (contours en « marching squares », parois verticales), relief autour de la zone de jeu et décor.
## Purement visuel : les collisions des plateaux sont créées par main.gd ; le reste n'en a aucune.
## La zone de jeu (±DEMI_CARTE) est à y = 0 ; le relief part de son bord.
## Construit par main.gd après la génération de la carte (le relief suit la vallée de la rivière).
## Spec : docs/specs/carte.md

const ETENDUE := Terrain.ETENDUE   # le relief couvre toute la vue possible de la caméra
const PAS := 4.0                # maillage du relief (DEMI_CARTE doit en être un multiple)
const NOMBRE_ROCHERS := 170
const NOMBRE_FOURRES := 260
const NOMBRE_TOUFFES_EPINEUX := 140   # touffes de 3 à 5 tiges (épineux de type Alluaudia)
const NOMBRE_BAOBABS := 10

const COULEUR_ROCHER := Color(0.6, 0.5, 0.4)
const COULEUR_FOURRE := Color(0.36, 0.38, 0.22)
const COULEUR_TIGE := Color(0.4, 0.42, 0.3)
const COULEUR_BAOBAB := Color(0.55, 0.45, 0.38)
const COULEUR_COURONNE := Color(0.32, 0.38, 0.2)

var _bruit := FastNoiseLite.new()
var _bruit_fin := FastNoiseLite.new()
var _hasard := RandomNumberGenerator.new()
var _materiau_relief := ShaderMaterial.new()


func construire() -> void:
	var graine := Terrain.graine   # même graine que la carte : même partie, même paysage
	_bruit.seed = graine
	_bruit.frequency = 0.018
	_bruit.fractal_octaves = 3
	_bruit_fin.seed = graine + 1
	_bruit_fin.frequency = 0.09
	_hasard.seed = graine
	_materiau_relief.shader = preload("res://scenes/world/terrain.gdshader")
	_materiau_relief.set_shader_parameter("distances_riviere", Terrain.texture_distances())
	_materiau_relief.set_shader_parameter("etendue", Terrain.ETENDUE)
	EventBus.meteo_change.connect(_on_meteo)
	_creer_sol_jeu()
	_creer_plateaux()
	_creer_relief()
	_creer_decor()


## Hauteur du relief : 0 dans la zone de jeu, collines basses près du bord, puis un plateau au loin.
## La caméra regarde vers -X -Z : côté proche (bas de l'écran, +X +Z) le relief reste bas pour ne pas
## cacher les unités, qui circulent jusqu'à ±56 m ; côté lointain (haut de l'écran), de vrais escarpements.
func hauteur(x: float, z: float) -> float:
	var d := maxf(absf(x), absf(z)) - GameRules.DEMI_CARTE
	if d <= 0.0:
		return 0.0
	var n := (_bruit.get_noise_2d(x, z) + 1.0) * 0.5
	var lointain := smoothstep(-40.0, 40.0, -(x + z))   # 1 en haut de l'écran, 0 en bas
	var montee := smoothstep(0.0, 30.0, d)
	var collines := montee * (2.0 + 10.0 * n)
	var escarpement := smoothstep(6.0, 18.0, d) * (10.0 + 12.0 * n) * lointain
	var plateau := smoothstep(30.0, 70.0, d) * 8.0
	var detail := _bruit_fin.get_noise_2d(x, z) * (1.5 + 2.0 * lointain) * montee
	# La rivière sort de la zone de jeu par une vallée à fond plat.
	var d_riviere := Terrain.distance_riviere(Vector3(x, 0.0, z))
	var vallee := smoothstep(GameRules.RIVIERE_LARGEUR * 0.5, GameRules.RIVIERE_LARGEUR * 0.5 + 26.0, d_riviere)
	return maxf(0.0, (collines + escarpement + plateau + detail) * vallee) - Terrain.profondeur_riviere(d_riviere)


# --- Sol de la zone de jeu : grille de 2 m, lit de rivière en contrebas ---

func _creer_sol_jeu() -> void:
	var pas := Terrain.PLATEAUX_CASE
	var cotes := Terrain.PLATEAUX_N + 1
	var d := GameRules.DEMI_CARTE
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	for j in cotes:
		for i in cotes:
			var p := Vector3(-d + i * pas, 0.0, -d + j * pas)
			p.y = Terrain.hauteur_sol(p)
			sommets.append(p)
			var dx := Terrain.hauteur_sol(p + Vector3(1, 0, 0)) - Terrain.hauteur_sol(p - Vector3(1, 0, 0))
			var dz := Terrain.hauteur_sol(p + Vector3(0, 0, 1)) - Terrain.hauteur_sol(p - Vector3(0, 0, 1))
			normales.append(Vector3(-dx, 2.0, -dz).normalized())
	var indices := PackedInt32Array()
	for j in cotes - 1:
		for i in cotes - 1:
			var a := j * cotes + i
			var b := a + cotes
			indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	_ajouter_maillage("SolJeu", sommets, normales, indices)


# --- Plateaux : contours en marching squares sur le champ de Terrain ---

## Couleur de sommet lue par le shader : rouge = dessus de plateau, vert = paroi (sinon : sol).
const ROLE_DESSUS := Color(1, 0, 0)
const ROLE_PAROI := Color(0, 1, 0)


func _creer_plateaux() -> void:
	if Terrain.plateaux_champ.is_empty() or Terrain.plateaux_seuil == INF:
		return
	var h := GameRules.PLATEAUX_HAUTEUR
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var roles := PackedColorArray()
	_palier(Terrain.plateaux_seuil, 0.0, h, sommets, normales, roles)
	_palier(Terrain.plateaux_seuil_haut, h, 2.0 * h, sommets, normales, roles)
	if sommets.is_empty():
		return
	var indices := PackedInt32Array()
	for k in sommets.size():
		indices.append(k)
	_ajouter_maillage("Plateaux", sommets, normales, indices, roles)


## Un palier : dessus plat à y_haut là où le champ dépasse le seuil, parois de y_bas à y_haut sur le contour.
## Chaque case est découpée par le seuil (interpolation sur les arêtes) : contours lisses, pas d'escalier.
func _palier(seuil: float, y_bas: float, y_haut: float, sommets: PackedVector3Array,
		normales: PackedVector3Array, roles: PackedColorArray) -> void:
	var n := Terrain.PLATEAUX_N
	var c := n + 1
	var pas := Terrain.PLATEAUX_CASE
	var d := GameRules.DEMI_CARTE
	var champ := Terrain.plateaux_champ
	for j in n:
		for i in n:
			var coins := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var valeurs: Array[float] = []
			var dedans := 0
			for k in 4:
				var v: float = champ[coins[k].y * c + coins[k].x]
				valeurs.append(v)
				if v > seuil:
					dedans += 1
			if dedans == 0:
				continue
			# Polygone de la partie au-dessus du seuil, et repérage des points de contour.
			var poly: Array[Vector2] = []
			var contour: Array[bool] = []
			for k in 4:
				var k2 := (k + 1) % 4
				var p1 := Vector2(-d + coins[k].x * pas, -d + coins[k].y * pas)
				var p2 := Vector2(-d + coins[k2].x * pas, -d + coins[k2].y * pas)
				if valeurs[k] > seuil:
					poly.append(p1)
					contour.append(false)
				if (valeurs[k] > seuil) != (valeurs[k2] > seuil):
					var t := (seuil - valeurs[k]) / (valeurs[k2] - valeurs[k])
					poly.append(p1.lerp(p2, t))
					contour.append(true)
			# Dessus : éventail de triangles.
			for k in range(1, poly.size() - 1):
				for p in [poly[0], poly[k], poly[k + 1]]:
					sommets.append(Vector3(p.x, y_haut, p.y))
					normales.append(Vector3.UP)
					roles.append(ROLE_DESSUS)
			# Parois : entre deux points de contour consécutifs du polygone.
			for k in poly.size():
				var k2 := (k + 1) % poly.size()
				if not (contour[k] and contour[k2]):
					continue
				var a := poly[k]
				var b := poly[k2]
				var normale := Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
				var milieu := Vector3((a.x + b.x) * 0.5, 0.0, (a.y + b.y) * 0.5)
				if Terrain.valeur_plateau(milieu + normale * 0.3) > Terrain.valeur_plateau(milieu - normale * 0.3):
					normale = -normale   # la paroi regarde vers l'extérieur du plateau
				var quad := [Vector3(a.x, y_bas, a.y), Vector3(b.x, y_bas, b.y), Vector3(b.x, y_haut, b.y),
						Vector3(a.x, y_haut, a.y)]
				for q in [0, 1, 2, 0, 2, 3]:
					sommets.append(quad[q])
					normales.append(normale)
					roles.append(ROLE_PAROI)


func _ajouter_maillage(nom: String, sommets: PackedVector3Array, normales: PackedVector3Array,
		indices: PackedInt32Array, roles := PackedColorArray()) -> void:
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	if roles.is_empty():
		roles.resize(sommets.size())
		roles.fill(Color.BLACK)   # sans couleur, Godot donnerait du blanc : le shader y verrait un plateau
	tableaux[Mesh.ARRAY_COLOR] = roles
	tableaux[Mesh.ARRAY_INDEX] = indices
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	var instance := MeshInstance3D.new()
	instance.name = nom
	instance.mesh = maillage
	instance.material_override = _materiau_relief
	add_child(instance)


func _creer_relief() -> void:
	var cotes := int(2.0 * ETENDUE / PAS) + 1
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	sommets.resize(cotes * cotes)
	normales.resize(cotes * cotes)
	for i in cotes:
		for j in cotes:
			var x := -ETENDUE + i * PAS
			var z := -ETENDUE + j * PAS
			sommets[i * cotes + j] = Vector3(x, hauteur(x, z), z)
			# Normale par différences finies : relief lisse.
			var dx := hauteur(x + 1.0, z) - hauteur(x - 1.0, z)
			var dz := hauteur(x, z + 1.0) - hauteur(x, z - 1.0)
			normales[i * cotes + j] = Vector3(-dx, 2.0, -dz).normalized()
	var indices := PackedInt32Array()
	for i in cotes - 1:
		for j in cotes - 1:
			var x := -ETENDUE + (i + 0.5) * PAS
			var z := -ETENDUE + (j + 0.5) * PAS
			if absf(x) < GameRules.DEMI_CARTE and absf(z) < GameRules.DEMI_CARTE:
				continue  # zone de jeu : c'est le sol de la scène principale
			var a := i * cotes + j
			var b := a + cotes
			indices.append_array([a, b, a + 1, a + 1, b, b + 1])
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_INDEX] = indices
	var noir := PackedColorArray()
	noir.resize(sommets.size())
	noir.fill(Color.BLACK)   # rôle « sol » pour le shader (voir ROLE_DESSUS)
	tableaux[Mesh.ARRAY_COLOR] = noir
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	var relief := MeshInstance3D.new()
	relief.name = "Relief"
	relief.mesh = maillage
	relief.material_override = _materiau_relief
	add_child(relief)


# --- Décor (MultiMesh : quelques appels de dessin pour des centaines d'objets) ---

func _creer_decor() -> void:
	var rocher := SphereMesh.new()
	rocher.radial_segments = 7
	rocher.rings = 3
	var rochers: Array[Transform3D] = []
	for k in NOMBRE_ROCHERS:
		var p := _point_hors_jeu(2.0, 110.0)
		var e := _hasard.randf_range(0.6, 2.6)
		var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e * _hasard.randf_range(0.8, 1.6), e * 0.6, e))
		rochers.append(Transform3D(base, p + Vector3(0, e * 0.15, 0)))
	_ajouter_multimesh("Rochers", rocher, rochers, COULEUR_ROCHER, 0.12)

	var fourre := SphereMesh.new()
	fourre.radial_segments = 6
	fourre.rings = 3
	var fourres: Array[Transform3D] = []
	for k in NOMBRE_FOURRES:
		var p := _point_hors_jeu(3.0, 120.0)
		var e := _hasard.randf_range(0.7, 1.8)
		fourres.append(Transform3D(Basis().scaled(Vector3(e * 1.3, e * 0.7, e * 1.3)), p + Vector3(0, e * 0.25, 0)))
	_ajouter_multimesh("Fourres", fourre, fourres, COULEUR_FOURRE, 0.18)

	# Épineux : touffes de tiges dressées, un peu écartées (silhouette du bush de l'Androy).
	var tige := CylinderMesh.new()
	tige.top_radius = 0.1
	tige.bottom_radius = 0.2
	tige.height = 1.0
	tige.radial_segments = 5
	tige.rings = 1
	var tiges: Array[Transform3D] = []
	for k in NOMBRE_TOUFFES_EPINEUX:
		var centre := _point_hors_jeu(7.0, 120.0)
		# Côté proche de la caméra, des épineux bas : ils ne doivent pas masquer la zone de jeu.
		var proche := smoothstep(-20.0, 60.0, centre.x + centre.z)
		for t in _hasard.randi_range(3, 5):
			var h := _hasard.randf_range(3.0, 6.5) * (1.0 - 0.6 * proche)
			var axe := Vector3(_hasard.randf_range(-1, 1), 0, _hasard.randf_range(-1, 1)).normalized()
			var base := Basis(axe, _hasard.randf_range(0.05, 0.3)).scaled(Vector3(1, h, 1))
			var decalage := Vector3(_hasard.randf_range(-1.2, 1.2), 0, _hasard.randf_range(-1.2, 1.2))
			var pied := centre + decalage
			pied.y = hauteur(pied.x, pied.z)
			tiges.append(Transform3D(base, pied + base.y * 0.5))
	_ajouter_multimesh("Epineux", tige, tiges, COULEUR_TIGE, 0.15)

	# Quelques baobabs, repères lointains.
	var tronc := CylinderMesh.new()
	tronc.top_radius = 0.6
	tronc.bottom_radius = 1.2
	tronc.height = 1.0
	tronc.radial_segments = 8
	var couronne := SphereMesh.new()
	couronne.radial_segments = 8
	couronne.rings = 4
	var troncs: Array[Transform3D] = []
	var couronnes: Array[Transform3D] = []
	for k in NOMBRE_BAOBABS:
		var p := _point_hors_jeu(15.0, 110.0)
		var h := _hasard.randf_range(6.0, 9.0)
		troncs.append(Transform3D(Basis().scaled(Vector3(1, h, 1)), p + Vector3(0, h * 0.5, 0)))
		couronnes.append(Transform3D(Basis().scaled(Vector3(4.5, 1.4, 4.5)), p + Vector3(0, h + 0.3, 0)))
	_ajouter_multimesh("BaobabsTroncs", tronc, troncs, COULEUR_BAOBAB, 0.08)
	_ajouter_multimesh("BaobabsCouronnes", couronne, couronnes, COULEUR_COURONNE, 0.1)


## Point au sol du relief, à une distance du bord de la zone de jeu comprise entre d_min et d_max.
func _point_hors_jeu(d_min: float, d_max: float) -> Vector3:
	var limite := GameRules.DEMI_CARTE
	while true:
		var x := _hasard.randf_range(-limite - d_max, limite + d_max)
		var z := _hasard.randf_range(-limite - d_max, limite + d_max)
		var d := maxf(absf(x), absf(z)) - limite
		var hors_du_lit := Terrain.distance_riviere(Vector3(x, 0.0, z)) > GameRules.RIVIERE_LARGEUR * 0.5 + 3.0
		if d >= d_min and d <= d_max and hors_du_lit:
			return Vector3(x, hauteur(x, z), z)
	return Vector3.ZERO


## variation : écart de teinte aléatoire d'un objet à l'autre.
func _ajouter_multimesh(nom: String, maillage: Mesh, transformations: Array[Transform3D], couleur: Color,
		variation: float) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = maillage
	multi.instance_count = transformations.size()
	for k in transformations.size():
		multi.set_instance_transform(k, transformations[k])
		var v := _hasard.randf_range(-variation, variation)
		multi.set_instance_color(k, Color(couleur.r + v, couleur.g + v, couleur.b + v * 0.7))
	var materiau := StandardMaterial3D.new()
	materiau.vertex_color_use_as_albedo = true
	materiau.vertex_color_is_srgb = true   # couleurs données en sRGB, sinon elles sont délavées
	materiau.roughness = 1.0
	materiau.metallic_specular = 0.1   # mat, sans reflet bleuté du ciel
	var instance := MultiMeshInstance3D.new()
	instance.name = nom
	instance.multimesh = multi
	instance.material_override = materiau
	add_child(instance)


func _on_meteo(secheresse: bool) -> void:
	_materiau_relief.set_shader_parameter("secheresse", 1.0 if secheresse else 0.0)
