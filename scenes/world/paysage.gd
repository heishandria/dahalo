extends Node3D
## Tout le visuel du terrain : sol de la zone de jeu (collines érodées, lit de rivière en contrebas),
## relief autour de la zone de jeu et décor.
## Purement visuel : les collisions des collines sont créées par main.gd ; le reste n'en a aucune.
## La zone de jeu (±DEMI_CARTE) est à y = 0 ; le relief part de son bord.
## Construit par main.gd après la génération de la carte (le relief suit la vallée de la rivière).
## Spec : docs/specs/carte.md

const ETENDUE := Terrain.ETENDUE   # le relief couvre toute la vue possible de la caméra
const PAS := 2.5                # maillage du relief (DEMI_CARTE et ETENDUE doivent en être des multiples)
const NOMBRE_ROCHERS := 170
const NOMBRE_FOURRES := 260
const NOMBRE_TOUFFES_EPINEUX := 140   # touffes de 3 à 5 tiges (épineux de type Alluaudia)
const NOMBRE_BAOBABS := 10
const NOMBRE_ARBRES := 40   # arbres morts et tordus du pack, sur le relief lointain

const COULEUR_ROCHER := Color(0.6, 0.5, 0.4)
const COULEUR_FOURRE := Color(0.36, 0.38, 0.22)
const COULEUR_TIGE := Color(0.4, 0.42, 0.3)
const COULEUR_BAOBAB := Color(0.55, 0.45, 0.38)
const COULEUR_COURONNE := Color(0.32, 0.38, 0.2)

var _montagnes := FastNoiseLite.new()   # crêtes et vallées (bruit « ridged » avec déformation de domaine)
var _massifs := FastNoiseLite.new()     # hauteur des massifs à grande échelle (cols plus bas entre eux)
var _bord := FastNoiseLite.new()        # déforme le pied des montagnes : il ne suit pas le carré de la carte
var _hasard := RandomNumberGenerator.new()
var _materiau_relief := ShaderMaterial.new()
# Textures photo du terrain (Poly Haven, CC0) : voir assets/textures/terrain/LISEZMOI.md.
const DOSSIER_TEXTURES := "res://assets/textures/terrain/"
const TEXTURES_TERRAIN := {
	"tex_laterite": "red_laterite_soil_stones_couleur.jpg",
	"tex_laterite_relief": "red_laterite_soil_stones_relief.jpg",
	"tex_herbe_verte": "sparse_grass_couleur.jpg",
	"tex_herbe_seche": "withered_grass_couleur.jpg",
	"tex_sable": "gravelly_sand_couleur.jpg",
	"tex_craquele": "mud_cracked_dry_riverbed_002_couleur.jpg",
	"tex_falaise": "cliff_side_couleur.jpg",
	"tex_falaise_relief": "cliff_side_relief.jpg",
	"tex_dessus": "dry_ground_rocks_couleur.jpg",
}
var _materiau_eau := ShaderMaterial.new()
var _secheresse := 0.0      # 0 : saison normale ; 1 : sécheresse (fondu entre les deux)
var _fondu: Tween
const DUREE_FONDU_SAISON := 6.0


func construire() -> void:
	var graine := Terrain.graine   # même graine que la carte : même partie, même paysage
	_montagnes.seed = graine
	_montagnes.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_montagnes.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_montagnes.fractal_octaves = 5
	_montagnes.frequency = 0.011
	_montagnes.domain_warp_enabled = true
	_montagnes.domain_warp_amplitude = 28.0
	_montagnes.domain_warp_frequency = 0.008
	_massifs.seed = graine + 1
	_massifs.frequency = 0.0045
	_bord.seed = graine + 2
	_bord.frequency = 0.014
	_bord.fractal_octaves = 2
	_hasard.seed = graine
	_materiau_relief.shader = preload("res://scenes/world/terrain.gdshader")
	_materiau_relief.set_shader_parameter("distances_riviere", Terrain.texture_distances())
	_materiau_relief.set_shader_parameter("etendue", Terrain.ETENDUE)
	_materiau_relief.set_shader_parameter("tex_bruit", _texture_bruit(graine))
	for parametre in TEXTURES_TERRAIN:
		_materiau_relief.set_shader_parameter(parametre, load(DOSSIER_TEXTURES + String(TEXTURES_TERRAIN[parametre])))
	EventBus.meteo_change.connect(_on_meteo)
	_creer_sol_jeu()
	_creer_eau()
	_creer_relief()
	_creer_decor()


## Hauteur du relief : 0 dans la zone de jeu ; au-delà, des massifs à crêtes et vallées dont le pied, déformé
## par du bruit, ne suit pas le carré de la carte.
## La caméra regarde vers -X -Z : côté proche (bas de l'écran, +X +Z) les montagnes restent basses pour ne pas
## cacher les unités au bord de la zone de jeu ; côté lointain (haut de l'écran), elles montent jusqu'à ~40 m.
func hauteur(x: float, z: float) -> float:
	var d := maxf(absf(x), absf(z)) - GameRules.DEMI_CARTE
	if d <= 0.0:
		return Terrain.hauteur_sol(Vector3(x, 0.0, z))   # raccord avec la zone de jeu (lit de rivière compris)
	# Pied des montagnes : avance et recule (±16 m) au lieu de suivre le bord de la carte.
	var pied := d + _bord.get_noise_2d(x, z) * 16.0
	var montee := smoothstep(0.0, 4.0, d) * smoothstep(-6.0, 38.0, pied)
	var lointain := smoothstep(-40.0, 40.0, -(x + z))   # 1 en haut de l'écran, 0 en bas
	var amplitude := lerpf(9.0, 38.0, lointain)
	var crete := pow((_montagnes.get_noise_2d(x, z) + 1.0) * 0.5, 1.5)
	var massif := 0.55 + 0.45 * _massifs.get_noise_2d(x, z)
	var h := montee * (1.5 + crete * amplitude * massif)
	# La rivière sort de la zone de jeu par une vallée à fond plat.
	var d_riviere := Terrain.distance_riviere(Vector3(x, 0.0, z))
	var vallee := smoothstep(GameRules.RIVIERE_LARGEUR * 0.5, GameRules.RIVIERE_LARGEUR * 0.5 + 26.0, d_riviere)
	return maxf(0.0, h * vallee) - Terrain.profondeur_riviere(d_riviere)


# --- Sol de la zone de jeu : grille de 2 m, collines érodées, lit de rivière en contrebas ---

func _creer_sol_jeu() -> void:
	var pas := Terrain.CASE_RELIEF
	var cotes := Terrain.N_RELIEF + 1
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


# --- Eau : filet qui coule dans le lit en saison normale (ruban le long du tracé) ---

func _creer_eau() -> void:
	_materiau_eau.shader = preload("res://scenes/world/eau.gdshader")
	_materiau_eau.set_shader_parameter("distances_riviere", Terrain.texture_distances())
	_materiau_eau.set_shader_parameter("etendue", Terrain.ETENDUE)
	var trace := Terrain.riviere
	var demi := GameRules.RIVIERE_LARGEUR * 0.5
	var y := -GameRules.RIVIERE_PROFONDEUR * 0.55
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	for k in trace.size():
		var p := trace[k]
		if absf(p.x) > ETENDUE or absf(p.y) > ETENDUE:
			continue
		var avant := trace[mini(k + 1, trace.size() - 1)] - trace[maxi(k - 1, 0)]
		var cote := Vector2(-avant.y, avant.x).normalized() * demi
		var base := sommets.size()
		sommets.append(Vector3(p.x - cote.x, y, p.y - cote.y))
		sommets.append(Vector3(p.x + cote.x, y, p.y + cote.y))
		normales.append(Vector3.UP)
		normales.append(Vector3.UP)
		if base >= 2:
			indices.append_array([base - 2, base - 1, base, base - 1, base + 1, base])
	if indices.is_empty():
		return
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_INDEX] = indices
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	var eau := MeshInstance3D.new()
	eau.name = "Eau"
	eau.mesh = maillage
	eau.material_override = _materiau_eau
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(eau)


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
	# Normales par différences entre sommets voisins (pas de calcul de hauteur supplémentaire).
	for i in cotes:
		for j in cotes:
			var g := sommets[maxi(i - 1, 0) * cotes + j].y
			var dr := sommets[mini(i + 1, cotes - 1) * cotes + j].y
			var h := sommets[i * cotes + maxi(j - 1, 0)].y
			var b := sommets[i * cotes + mini(j + 1, cotes - 1)].y
			normales[i * cotes + j] = Vector3(g - dr, 2.0 * PAS, h - b).normalized()
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
	noir.fill(Color.BLACK)   # rôle « sol » pour le shader
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
	var f := BibliothequeDecor.facteur_densite()
	# Rochers et buissons : modèles du pack CC0 s'ils sont là (sinon boules générées).
	var rochers_pack := BibliothequeDecor.maillages(["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"])
	var rocher := SphereMesh.new()
	rocher.radial_segments = 7
	rocher.rings = 3
	var rochers: Array[Transform3D] = []
	for k in NOMBRE_ROCHERS:
		var p := _point_hors_jeu(2.0, 110.0)
		var e := _hasard.randf_range(0.6, 2.6)
		if rochers_pack.is_empty():
			var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e * _hasard.randf_range(0.8, 1.6), e * 0.6, e))
			rochers.append(Transform3D(base, p + Vector3(0, e * 0.15, 0)))
		else:
			rochers.append(Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3.ONE * e * 0.4), p - Vector3(0, 0.2, 0)))
	if rochers_pack.is_empty():
		_ajouter_multimesh("Rochers", rocher, rochers, COULEUR_ROCHER, 0.12)
	else:
		_ajouter_variantes("Rochers", rochers_pack, rochers)

	var buissons_pack := BibliothequeDecor.maillages(["Bush_Common"])
	var fourre := SphereMesh.new()
	fourre.radial_segments = 6
	fourre.rings = 3
	var fourres: Array[Transform3D] = []
	for k in int(NOMBRE_FOURRES * (1.0 if buissons_pack.is_empty() else f)):
		var p := _point_hors_jeu(3.0, 120.0)
		var e := _hasard.randf_range(0.7, 1.8)
		if buissons_pack.is_empty():
			fourres.append(Transform3D(Basis().scaled(Vector3(e * 1.3, e * 0.7, e * 1.3)), p + Vector3(0, e * 0.25, 0)))
		else:
			fourres.append(Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3.ONE * e * 0.5), p))
	if buissons_pack.is_empty():
		_ajouter_multimesh("Fourres", fourre, fourres, COULEUR_FOURRE, 0.18)
	else:
		_ajouter_variantes("Fourres", buissons_pack, fourres)

	# Arbres morts et arbres tordus (pack CC0), côté lointain seulement : de près, ils cacheraient le jeu.
	# Arbres morts seulement : les arbres tordus (10 000 triangles et feuillage découpé) coûtaient trop cher.
	var arbres_pack := BibliothequeDecor.maillages(["DeadTree_1", "DeadTree_2", "DeadTree_3"])
	if not arbres_pack.is_empty():
		var arbres: Array[Transform3D] = []
		var essais := 0
		while arbres.size() < int(NOMBRE_ARBRES * f) and essais < NOMBRE_ARBRES * 20:
			essais += 1
			var p := _point_hors_jeu(10.0, 110.0)
			if p.x + p.z > -20.0:
				continue
			var e := _hasard.randf_range(0.3, 0.5)
			arbres.append(Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3.ONE * e), p - Vector3(0, 0.2, 0)))
		_ajouter_variantes("Arbres", arbres_pack, arbres)

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


## Modèles du pack répartis au hasard entre leurs variantes (un MultiMesh par variante, matériaux du pack).
func _ajouter_variantes(nom: String, maillages: Array[Mesh], transformations: Array[Transform3D]) -> void:
	var parts: Array = []
	for m in maillages:
		parts.append([])
	for t in transformations:
		parts[_hasard.randi() % maillages.size()].append(t)
	for k in maillages.size():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = maillages[k]
		multi.instance_count = parts[k].size()
		for i in parts[k].size():
			multi.set_instance_transform(i, parts[k][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s%d" % [nom, k]
		instance.multimesh = multi
		add_child(instance)


## Texture de bruit répétable (fractal, 256 px, ~5 cellules) lue par le shader du terrain à plusieurs échelles.
## Générée par le moteur (rapide), une fois au chargement.
func _texture_bruit(graine: int) -> ImageTexture:
	var bruit := FastNoiseLite.new()
	bruit.seed = graine + 21
	bruit.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	bruit.frequency = 0.02
	bruit.fractal_octaves = 3
	var image := bruit.get_seamless_image(256, 256)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Densité de végétation de la zone de jeu : le sol verdit sous les massifs (voir vegetation.gd).
func brancher_vegetation(texture_densite: Texture2D) -> void:
	_materiau_relief.set_shader_parameter("carte_vegetation", texture_densite)


## Texture du brouillard : les plateaux dépassent le voile posé au sol, le shader les assombrit lui-même.
func brancher_vision(texture_vision: Texture2D) -> void:
	_materiau_relief.set_shader_parameter("carte_vision", texture_vision)
	_materiau_relief.set_shader_parameter("demi_carte", GameRules.DEMI_CARTE)


## Changement de saison en fondu : l'herbe jaunit ou reverdit, l'eau se retire ou revient.
func _on_meteo(secheresse: bool) -> void:
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_fondu = create_tween()
	_fondu.tween_method(_appliquer_saison, _secheresse, 1.0 if secheresse else 0.0, DUREE_FONDU_SAISON)


func _appliquer_saison(valeur: float) -> void:
	_secheresse = valeur
	_materiau_relief.set_shader_parameter("secheresse", valeur)
	_materiau_eau.set_shader_parameter("niveau", 1.0 - valeur)
