extends Node3D
## Végétation basse de la zone de jeu : herbes, fleurs, buissons, cailloux, rochers sur les plateaux (visuel).
## Modèles des packs CC0 (BibliothequeDecor), ou formes générées par le code s'ils manquent.
## Un MultiMesh par variante de modèle (une quinzaine d'appels de dessin pour des milliers d'objets).
## - masquée dans les zones jamais explorées (le shader lit la texture du brouillard) ;
## - herbe plus dense sur les berges, absente du lit ; fleurs après les pluies, qui disparaissent en sécheresse ;
## - rien sous les bâtiments et les ressources : retirée quand un bâtiment est construit (EventBus.batiment_cree).
## Densité réduite sur le Web et le mobile (BibliothequeDecor.facteur_densite). Spec : docs/specs/carte.md

const NOMBRE_HERBE := 9000
const NOMBRE_FLEURS := 500
const NOMBRE_BUISSONS := 600
const NOMBRE_CAILLOUX := 450
const NOMBRE_ROCHERS_PLATEAUX := 140
const CASE_EXCLUSION := 4.0

var _materiaux: Array[ShaderMaterial] = []
var _multis: Array[MultiMesh] = []
var _positions: Array[PackedVector3Array] = []   # par MultiMesh : position de chaque instance (pour retirer)
var _hasard := RandomNumberGenerator.new()
var _bruit := FastNoiseLite.new()
var _vision: Texture2D
var _mares: Array[Vector2] = []   # points d'eau du village (hors du lit) : herbe plus dense autour
var _secheresse := 0.0
var _fondu: Tween


func construire(texture_vision: Texture2D) -> void:
	_vision = texture_vision
	_hasard.seed = Terrain.graine + 11
	_bruit.seed = Terrain.graine + 12
	_bruit.frequency = 0.04
	var f := BibliothequeDecor.facteur_densite()
	var exclusions := _exclusions()
	for n in get_tree().get_nodes_in_group("ressource_eau"):
		if n is NoeudRessource and n.variante == "point_eau" and not Terrain.dans_riviere(n.global_position):
			_mares.append(Vector2(n.global_position.x, n.global_position.z))
	# Herbes : surtout les courtes (plus légères), échelle ramenée à ~0,6 m.
	_creer("Herbe", ["Grass_Common_Short", "Grass_Wispy_Short", "Grass_Common_Short", "Grass_Wispy_Short",
			"Grass_Common_Tall", "Grass_Wispy_Tall"], [_maillage_touffe()], int(NOMBRE_HERBE * f),
			{"suit_saison": 1.0, "vent": 1.0, "teinte_secours": Color(0.36, 0.46, 0.17)}, exclusions,
			_placer_herbe.bind(0.38, 0.55))
	_creer("Fleurs", ["Flower_3_Group", "Flower_4_Group"], [], int(NOMBRE_FLEURS * f),
			{"suit_saison": 0.5, "vent": 1.0, "disparait": 1.0}, exclusions, _placer_herbe.bind(0.28, 0.4))
	_creer("Buissons", ["Bush_Common", "Bush_Common", "Bush_Common_Flowers"], [_maillage_buisson()],
			int(NOMBRE_BUISSONS * f), {"suit_saison": 0.8, "vent": 0.3, "teinte_secours": Color(0.38, 0.42, 0.22)},
			exclusions, _placer_buisson)
	_creer("Cailloux", ["Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Square_1", "Pebble_Square_2"],
			[_maillage_caillou()], int(NOMBRE_CAILLOUX * f),
			{"suit_saison": 0.0, "vent": 0.0, "teinte_secours": Color(0.66, 0.6, 0.5)}, exclusions, _placer_caillou)
	_creer("RochersPlateaux", ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"], [],
			int(NOMBRE_ROCHERS_PLATEAUX * f), {"suit_saison": 0.0, "vent": 0.0}, exclusions, _placer_rocher_plateau)
	EventBus.batiment_cree.connect(_on_batiment_cree)
	EventBus.meteo_change.connect(_on_meteo)


# --- Exclusions : rien ne pousse sous les bâtiments, ressources et baobabs ---

## Grille de cases de 4 m -> liste des cercles [Vector2 centre, rayon] qui les touchent.
func _exclusions() -> Dictionary:
	var grille := {}
	for groupe in ["batiments", "ressources", "decor"]:
		for n in get_tree().get_nodes_in_group(groupe):
			if not n is Node3D:
				continue
			var centre := Vector2(n.global_position.x, n.global_position.z)
			var rayon := _rayon(n) + 0.8
			var c_min := Vector2i(((centre - Vector2(rayon, rayon)) / CASE_EXCLUSION).floor())
			var c_max := Vector2i(((centre + Vector2(rayon, rayon)) / CASE_EXCLUSION).floor())
			for cx in range(c_min.x, c_max.x + 1):
				for cz in range(c_min.y, c_max.y + 1):
					var cle := Vector2i(cx, cz)
					if not grille.has(cle):
						grille[cle] = []
					grille[cle].append([centre, rayon])
	return grille


func _rayon(n: Node) -> float:
	var type = n.get("type_batiment")
	if type is String and type != "":
		var e: Vector2 = GameRules.EMPRISES.get(type, Vector2(3, 3))
		return maxf(e.x, e.y) * 0.6
	if n is NoeudRessource:
		return float(GameRules.RAYONS_SOURCES.get(n.type_ressource, 1.5))
	return 2.0


func _exclu(p: Vector3, exclusions: Dictionary) -> bool:
	var p2 := Vector2(p.x, p.z)
	for c in exclusions.get(Vector2i((p2 / CASE_EXCLUSION).floor()), []):
		if p2.distance_to(c[0]) < c[1]:
			return true
	return false


# --- Création : un MultiMesh par variante ---

## noms : modèles des packs (un nom répété = variante plus fréquente) ; secours : formes générées si aucun.
## reglages : suit_saison, vent, disparait, teinte_secours.
func _creer(nom: String, noms: Array, secours: Array, nombre: int, reglages: Dictionary, exclusions: Dictionary,
		placer: Callable) -> void:
	var variantes: Array = []   # [Mesh, est_un_modele_du_pack]
	for n in noms:
		var m := BibliothequeDecor.maillage(n)
		if m != null:
			variantes.append([m, true])
	if variantes.is_empty():
		for m in secours:
			variantes.append([m, false])
	if variantes.is_empty() or nombre <= 0:
		return
	var transformations: Array = []
	for v in variantes:
		transformations.append([])
	var places := 0
	var essais := 0
	while places < nombre and essais < nombre * 8:
		essais += 1
		var t: Transform3D = placer.call()
		if t.origin == Vector3.INF or _exclu(t.origin, exclusions):
			continue
		transformations[_hasard.randi() % variantes.size()].append(t)
		places += 1
	for k in variantes.size():
		var maillage := _avec_materiaux(variantes[k][0], variantes[k][1], reglages)
		_ajouter("%s%d" % [nom, k], maillage, transformations[k])


## Copie du maillage dont chaque surface reçoit le shader de végétation (texture du pack conservée).
func _avec_materiaux(source: Mesh, du_pack: bool, reglages: Dictionary) -> Mesh:
	var m := source.duplicate() as Mesh
	var hauteur := maxf(m.get_aabb().end.y, 0.1)
	for s in m.get_surface_count():
		var materiau := ShaderMaterial.new()
		materiau.shader = preload("res://scenes/world/vegetation.gdshader")
		var origine := source.surface_get_material(s) as BaseMaterial3D
		if du_pack and origine != null:
			if origine.albedo_texture != null:
				materiau.set_shader_parameter("texture_albedo", origine.albedo_texture)
			materiau.set_shader_parameter("teinte", origine.albedo_color)   # l'herbe du pack est teintée par son matériau
			if origine.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				materiau.set_shader_parameter("seuil_alpha", origine.alpha_scissor_threshold)
		else:
			materiau.set_shader_parameter("teinte", reglages.get("teinte_secours", Color.WHITE))
		materiau.set_shader_parameter("carte_vision", _vision)
		materiau.set_shader_parameter("demi_carte", GameRules.DEMI_CARTE)
		materiau.set_shader_parameter("suit_saison", reglages.get("suit_saison", 1.0))
		materiau.set_shader_parameter("disparait_secheresse", reglages.get("disparait", 0.0))
		materiau.set_shader_parameter("vent", reglages.get("vent", 1.0))
		materiau.set_shader_parameter("hauteur", hauteur)
		materiau.set_shader_parameter("secheresse", _secheresse)
		m.surface_set_material(s, materiau)
		_materiaux.append(materiau)
	return m


func _ajouter(nom: String, maillage: Mesh, transformations: Array) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = maillage
	multi.instance_count = transformations.size()
	var positions := PackedVector3Array()
	for k in transformations.size():
		var t: Transform3D = transformations[k]
		multi.set_instance_transform(k, t)
		var v := _hasard.randf_range(0.85, 1.1)
		multi.set_instance_color(k, Color(v, v * _hasard.randf_range(0.96, 1.04), v))
		positions.append(t.origin)
	var instance := MultiMeshInstance3D.new()
	instance.name = nom
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_multis.append(multi)
	_positions.append(positions)


# --- Placement ---

## Point au hasard dans la zone de jeu, au sol ou sur le dessus d'un plateau ; INF sur une paroi.
func _point_au_sol() -> Vector3:
	var limite := GameRules.DEMI_CARTE - 1.0
	var p := Vector3(_hasard.randf_range(-limite, limite), 0.0, _hasard.randf_range(-limite, limite))
	var v := Terrain.valeur_plateau(p)
	var marge := 0.03
	if absf(v - Terrain.plateaux_seuil) < marge or absf(v - Terrain.plateaux_seuil_haut) < marge:
		return Vector3.INF   # bord de falaise
	if v > Terrain.plateaux_seuil_haut:
		p.y = 2.0 * GameRules.PLATEAUX_HAUTEUR
	elif v > Terrain.plateaux_seuil:
		p.y = GameRules.PLATEAUX_HAUTEUR
	else:
		p.y = Terrain.hauteur_sol(p)
	return p


func _rien() -> Transform3D:
	return Transform3D(Basis(), Vector3.INF)


func _placer_herbe(echelle_min: float, echelle_max: float) -> Transform3D:
	var p := _point_au_sol()
	if p == Vector3.INF:
		return _rien()
	var d := Terrain.distance_riviere(p)
	var demi := GameRules.RIVIERE_LARGEUR * 0.5
	if d < demi - 0.5:
		return _rien()   # pas dans le sable du lit
	# Densité : plaques d'herbe (bruit), bien plus fournies sur les berges.
	var densite := 0.25 + 0.75 * smoothstep(-0.1, 0.4, _bruit.get_noise_2d(p.x, p.z))
	if d < demi + 6.0:
		densite = 1.0
	for m in _mares:
		if Vector2(p.x, p.z).distance_to(m) < 7.0:
			densite = 1.0   # herbe plus verte et dense autour des mares
	if _hasard.randf() > densite:
		return _rien()
	var e := _hasard.randf_range(echelle_min, echelle_max)
	return Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e, e * _hasard.randf_range(0.85, 1.2), e)), p)


func _placer_buisson() -> Transform3D:
	var p := _point_au_sol()
	if p == Vector3.INF or Terrain.dans_riviere(p):
		return _rien()
	var e := _hasard.randf_range(0.32, 0.6)
	return Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e, e * 0.9, e)), p)


func _placer_caillou() -> Transform3D:
	var p := _point_au_sol()
	if p == Vector3.INF:
		return _rien()
	var e := _hasard.randf_range(0.7, 1.6)
	return Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e, e, e)), p)


## Rochers : seulement sur le dessus des plateaux (personne n'y marche, pas besoin de collision).
func _placer_rocher_plateau() -> Transform3D:
	var p := _point_au_sol()
	if p == Vector3.INF or Terrain.valeur_plateau(p) < Terrain.plateaux_seuil + 0.06:
		return _rien()
	var e := _hasard.randf_range(0.35, 0.8)
	return Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e, e, e)), p - Vector3(0, 0.15, 0))


# --- Formes de secours (si les modèles des packs manquent) ---

## Touffe : quelques brins en triangle, ouverts en éventail.
func _maillage_touffe() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var brins := 9
	for b in brins:
		var a := TAU * b / brins + 0.4 * sin(b * 2.3)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var cote := Vector3(-dir.z, 0.0, dir.x) * 0.07
		var hauteur := 0.6 + 0.3 * sin(b * 1.7) * sin(b * 1.7)
		var pointe := dir * (0.22 + 0.1 * cos(b * 3.1)) + Vector3(0, hauteur, 0)
		st.set_normal(Vector3.UP)
		st.add_vertex(dir * 0.06 - cote)
		st.add_vertex(dir * 0.06 + cote)
		st.add_vertex(pointe)
	return st.commit()


func _maillage_buisson() -> ArrayMesh:
	var st := SurfaceTool.new()
	var boule := SphereMesh.new()
	boule.radial_segments = 7
	boule.rings = 4
	boule.radius = 0.45
	boule.height = 0.6
	for k in 3:
		var a := TAU * k / 3.0
		var t := Transform3D(Basis().scaled(Vector3(1.0 - 0.15 * k, 1.0 - 0.2 * k, 1.0)), Vector3(cos(a) * 0.25, 0.22, sin(a) * 0.25))
		st.append_from(boule, 0, t)
	return st.commit()


func _maillage_caillou() -> ArrayMesh:
	var boule := SphereMesh.new()
	boule.radial_segments = 6
	boule.rings = 3
	var st := SurfaceTool.new()
	st.append_from(boule, 0, Transform3D(Basis().scaled(Vector3(0.3, 0.12, 0.25)), Vector3.ZERO))
	return st.commit()


# --- Événements ---

## Un bâtiment (ou un champ, un puits) apparaît : la végétation sous son emprise disparaît.
func _on_batiment_cree(batiment: Node3D) -> void:
	var centre := Vector2(batiment.global_position.x, batiment.global_position.z)
	var rayon := _rayon(batiment) + 0.5
	for t in _multis.size():
		var positions := _positions[t]
		for k in positions.size():
			var p := positions[k]
			if p.y > -100.0 and Vector2(p.x, p.z).distance_to(centre) < rayon:
				_multis[t].set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), p))
				positions[k].y = -1000.0   # déjà retirée
		_positions[t] = positions


func _on_meteo(secheresse: bool) -> void:
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_fondu = create_tween()
	_fondu.tween_method(_appliquer_saison, _secheresse, 1.0 if secheresse else 0.0, 6.0)


func _appliquer_saison(valeur: float) -> void:
	_secheresse = valeur
	for m in _materiaux:
		m.set_shader_parameter("secheresse", valeur)
