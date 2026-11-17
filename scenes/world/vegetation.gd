extends Node3D
## Végétation basse de la zone de jeu : touffes d'herbe, buissons, cailloux (purement visuel).
## Un MultiMesh par type (3 appels de dessin pour des milliers d'objets, tenable sur mobile).
## - masquée dans les zones jamais explorées (le shader lit la texture du brouillard) ;
## - herbe plus dense sur les berges, absente du lit, présente aussi sur le dessus des plateaux ;
## - rien sous les bâtiments et les ressources : retirée quand un bâtiment est construit (EventBus.batiment_cree).
## Formes générées par le code en attendant des modèles (packs CC0) : voir assets/models/decor/LISEZMOI.md.
## Spec : docs/specs/carte.md

const NOMBRE_HERBE := 11000
const NOMBRE_BUISSONS := 700
const NOMBRE_CAILLOUX := 450

var _materiaux: Array[ShaderMaterial] = []
var _multis: Array[MultiMesh] = []
var _positions: Array[PackedVector3Array] = []   # par type : position de chaque instance (pour retirer)
var _hasard := RandomNumberGenerator.new()
var _bruit := FastNoiseLite.new()
var _fondu: Tween


func construire(texture_vision: Texture2D) -> void:
	_hasard.seed = Terrain.graine + 11
	_bruit.seed = Terrain.graine + 12
	_bruit.frequency = 0.04
	var exclusions := _exclusions()
	_creer("Herbe", _maillage_touffe(), NOMBRE_HERBE, 1.0, 1.0, texture_vision, exclusions, _placer_herbe)
	_creer("Buissons", _maillage_buisson(), NOMBRE_BUISSONS, 0.0, 0.25, texture_vision, exclusions, _placer_buisson)
	_creer("Cailloux", _maillage_caillou(), NOMBRE_CAILLOUX, 0.0, 0.0, texture_vision, exclusions, _placer_caillou)
	_materiaux[1].set_shader_parameter("couleur_fixe", Color(0.38, 0.42, 0.22))
	_materiaux[2].set_shader_parameter("couleur_fixe", Color(0.66, 0.6, 0.5))
	EventBus.batiment_cree.connect(_on_batiment_cree)
	EventBus.meteo_change.connect(_on_meteo)


# --- Placement ---

const CASE_EXCLUSION := 4.0

## Où rien ne pousse : bâtiments, ressources, baobabs déjà sur la carte. Grille de cases de 4 m ->
## liste des cercles [Vector2 centre, rayon] qui les touchent (test rapide pour des milliers d'instances).
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


func _creer(nom: String, maillage: Mesh, nombre: int, suit_saison: float, vent: float, texture_vision: Texture2D,
		exclusions: Dictionary, placer: Callable) -> void:
	var transformations: Array[Transform3D] = []
	var essais := 0
	while transformations.size() < nombre and essais < nombre * 6:
		essais += 1
		var t: Transform3D = placer.call()
		if t.origin == Vector3.INF or _exclu(t.origin, exclusions):
			continue
		transformations.append(t)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = maillage
	multi.instance_count = transformations.size()
	var positions := PackedVector3Array()
	for k in transformations.size():
		multi.set_instance_transform(k, transformations[k])
		var v := _hasard.randf_range(0.82, 1.12)
		multi.set_instance_color(k, Color(v, v * _hasard.randf_range(0.95, 1.05), v))
		positions.append(transformations[k].origin)
	var materiau := ShaderMaterial.new()
	materiau.shader = preload("res://scenes/world/vegetation.gdshader")
	materiau.set_shader_parameter("carte_vision", texture_vision)
	materiau.set_shader_parameter("demi_carte", GameRules.DEMI_CARTE)
	materiau.set_shader_parameter("suit_saison", suit_saison)
	materiau.set_shader_parameter("vent", vent)
	materiau.set_shader_parameter("secheresse", 0.0)
	var instance := MultiMeshInstance3D.new()
	instance.name = nom
	instance.multimesh = multi
	instance.material_override = materiau
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_materiaux.append(materiau)
	_multis.append(multi)
	_positions.append(positions)


func _exclu(p: Vector3, exclusions: Dictionary) -> bool:
	var p2 := Vector2(p.x, p.z)
	for c in exclusions.get(Vector2i((p2 / CASE_EXCLUSION).floor()), []):
		if p2.distance_to(c[0]) < c[1]:
			return true
	return false


## Point au hasard dans la zone de jeu, à la hauteur du sol ou du dessus d'un plateau ; INF si sur une paroi.
func _point_au_sol() -> Vector3:
	var limite := GameRules.DEMI_CARTE - 1.0
	var p := Vector3(_hasard.randf_range(-limite, limite), 0.0, _hasard.randf_range(-limite, limite))
	var v := Terrain.valeur_plateau(p)
	var marge := 0.03
	if v > Terrain.plateaux_seuil - marge and v < Terrain.plateaux_seuil + marge:
		return Vector3.INF   # bord de falaise
	if v > Terrain.plateaux_seuil_haut - marge and v < Terrain.plateaux_seuil_haut + marge:
		return Vector3.INF
	if v > Terrain.plateaux_seuil_haut:
		p.y = 2.0 * GameRules.PLATEAUX_HAUTEUR
	elif v > Terrain.plateaux_seuil:
		p.y = GameRules.PLATEAUX_HAUTEUR
	else:
		p.y = Terrain.hauteur_sol(p)
	return p


func _placer_herbe() -> Transform3D:
	var p := _point_au_sol()
	if p == Vector3.INF:
		return Transform3D(Basis(), Vector3.INF)
	var d := Terrain.distance_riviere(p)
	var demi := GameRules.RIVIERE_LARGEUR * 0.5
	if d < demi - 0.5:
		return Transform3D(Basis(), Vector3.INF)   # pas dans le sable du lit
	# Densité : plaques d'herbe (bruit), bien plus fournies sur les berges.
	var densite := 0.25 + 0.75 * smoothstep(-0.1, 0.4, _bruit.get_noise_2d(p.x, p.z))
	if d < demi + 6.0:
		densite = 1.0
	if _hasard.randf() > densite:
		return Transform3D(Basis(), Vector3.INF)
	var e := _hasard.randf_range(0.7, 1.4)
	return Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e, e * _hasard.randf_range(0.8, 1.3), e)), p)


func _placer_buisson() -> Transform3D:
	var p := _point_au_sol()
	if p == Vector3.INF or Terrain.dans_riviere(p):
		return Transform3D(Basis(), Vector3.INF)
	var e := _hasard.randf_range(0.5, 1.2)
	return Transform3D(Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e, e * 0.8, e)), p)


func _placer_caillou() -> Transform3D:
	var p := _point_au_sol()
	if p == Vector3.INF:
		return Transform3D(Basis(), Vector3.INF)
	var e := _hasard.randf_range(0.15, 0.55)
	var base := Basis(Vector3.UP, _hasard.randf() * TAU).scaled(Vector3(e * _hasard.randf_range(1.0, 1.6), e * 0.6, e))
	return Transform3D(base, p + Vector3(0, e * 0.1, 0))


# --- Formes (en attendant les modèles des packs) ---

## Touffe : quelques brins en triangle, ouverts en éventail. UV.y = 0 au pied, 1 à la pointe.
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
		st.set_uv(Vector2(0, 0))
		st.add_vertex(dir * 0.06 - cote)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(dir * 0.06 + cote)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(pointe)
	return st.commit()


## Buisson : trois boules aplaties fondues en une forme irrégulière.
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
	var m := st.commit()
	return _avec_uv_hauteur(m, 0.0, 0.6)


## Caillou : boule à facettes, très aplatie.
func _maillage_caillou() -> ArrayMesh:
	var boule := SphereMesh.new()
	boule.radial_segments = 6
	boule.rings = 3
	var st := SurfaceTool.new()
	st.append_from(boule, 0, Transform3D())
	return _avec_uv_hauteur(st.commit(), -0.5, 0.5)


## UV.y = hauteur relative (pour l'ombrage pied / sommet du shader).
func _avec_uv_hauteur(m: ArrayMesh, y_min: float, y_max: float) -> ArrayMesh:
	var tableaux := m.surface_get_arrays(0)
	var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	for s in sommets:
		uv.append(Vector2(0.0, clampf((s.y - y_min) / (y_max - y_min), 0.0, 1.0)))
	tableaux[Mesh.ARRAY_TEX_UV] = uv
	var resultat := ArrayMesh.new()
	resultat.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	return resultat


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
	var depart := float(_materiaux[0].get_shader_parameter("secheresse"))
	_fondu.tween_method(func(v: float) -> void: _materiaux[0].set_shader_parameter("secheresse", v),
			depart, 1.0 if secheresse else 0.0, 6.0)
