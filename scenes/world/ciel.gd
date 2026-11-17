extends Node3D
## Ambiance du ciel (purement visuel) :
## - nuages légers qui dérivent avec le vent, chacun avec son ombre portée au sol (décalque projeté dans la
##   direction du soleil) ; plus rares en sécheresse, ombres effacées la nuit ;
## - vols d'oiseaux qui traversent la carte de temps en temps : corbeaux pies (noirs, plastron et collier blancs,
##   petits groupes) et hérons garde-bœufs (blancs, bandes plus nombreuses). Masqués au-dessus des zones
##   inexplorées (ils ne doivent rien révéler).
## Les décalques (ombres des nuages) n'existent pas dans le rendu Web : les nuages y sont sans ombre.
## Spec : docs/specs/carte.md

const NB_NUAGES := 8
const ALTITUDE_NUAGES := 34.0
const VENT := Vector3(1.6, 0.0, 0.6)          # m/s
const MARGE := 90.0                            # les nuages font le tour au-delà de la carte
const OPACITE_NUAGE := 0.32
const OPACITE_OMBRE := 0.26
const VOLS_MAX := 3
const ATTENTE_VOL := Vector2(12.0, 35.0)       # secondes entre deux vols

var _hasard := RandomNumberGenerator.new()
var _nuages: Array = []        # [MeshInstance3D nuage, Decal ombre]
var _materiaux_nuages: Array[ShaderMaterial] = []
var _soleil: DirectionalLight3D
var _presence := 1.0           # 1 : saison normale ; ~0,35 : sécheresse (moins de nuages)
var _fondu: Tween
var _vols: Array = []          # vols en cours (Dictionary)
var _attente := 4.0
var _maillage_oiseau: ArrayMesh
var _materiau_corbeau := ShaderMaterial.new()
var _materiau_heron := ShaderMaterial.new()


func _ready() -> void:
	_hasard.seed = Terrain.graine + 31 if Terrain.graine != 0 else 31
	_soleil = get_parent().get_node_or_null("Soleil") as DirectionalLight3D
	_creer_nuages()
	_maillage_oiseau = _creer_maillage_oiseau()
	for m in [_materiau_corbeau, _materiau_heron]:
		m.shader = preload("res://scenes/world/oiseau.gdshader")
	_materiau_corbeau.set_shader_parameter("couleur_dos", Color(0.07, 0.07, 0.08))
	_materiau_corbeau.set_shader_parameter("couleur_ventre", Color(0.9, 0.9, 0.88))
	_materiau_heron.set_shader_parameter("couleur_dos", Color(0.93, 0.92, 0.88))
	_materiau_heron.set_shader_parameter("couleur_ventre", Color(0.93, 0.92, 0.88))
	EventBus.meteo_change.connect(_on_meteo)


func _process(delta: float) -> void:
	_deplacer_nuages(delta)
	_attente -= delta
	if _attente <= 0.0:
		_attente = _hasard.randf_range(ATTENTE_VOL.x, ATTENTE_VOL.y)
		if _vols.size() < VOLS_MAX:
			_lancer_vol()
	for i in range(_vols.size() - 1, -1, -1):
		if not _animer_vol(_vols[i], delta):
			_vols[i]["noeud"].queue_free()
			_vols.remove_at(i)


# --- Nuages ---

func _creer_nuages() -> void:
	var formes: Array[ImageTexture] = []
	var ombres: Array[ImageTexture] = []
	for v in 3:
		var image := _image_nuage(v)
		formes.append(ImageTexture.create_from_image(image))
		var ombre := image.duplicate() as Image
		for y in ombre.get_height():
			for x in ombre.get_width():
				ombre.set_pixel(x, y, Color(0.04, 0.04, 0.06, ombre.get_pixel(x, y).a))
		ombres.append(ImageTexture.create_from_image(ombre))
	var limite := GameRules.DEMI_CARTE + MARGE
	for k in NB_NUAGES:
		var v := k % 3
		var taille := _hasard.randf_range(28.0, 52.0)
		var plan := PlaneMesh.new()
		plan.size = Vector2(taille, taille * 0.7)
		var materiau := ShaderMaterial.new()
		materiau.shader = preload("res://scenes/world/nuage.gdshader")
		materiau.set_shader_parameter("forme", formes[v])
		materiau.set_shader_parameter("opacite", OPACITE_NUAGE)
		_materiaux_nuages.append(materiau)
		var nuage := MeshInstance3D.new()
		nuage.mesh = plan
		nuage.material_override = materiau
		nuage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nuage.position = Vector3(_hasard.randf_range(-limite, limite), ALTITUDE_NUAGES + _hasard.randf_range(-3.0, 5.0),
				_hasard.randf_range(-limite, limite))
		nuage.rotation.y = _hasard.randf() * TAU
		add_child(nuage)
		var ombre := Decal.new()
		ombre.size = Vector3(taille, 140.0, taille * 0.7)
		ombre.texture_albedo = ombres[v]
		ombre.albedo_mix = 1.0
		ombre.modulate = Color(1, 1, 1, OPACITE_OMBRE)
		ombre.upper_fade = 0.0
		ombre.lower_fade = 0.0
		add_child(ombre)
		_nuages.append([nuage, ombre])


## Forme d'un nuage : bruit fractal (contour effiloché) dans une ellipse à bords doux. A = densité.
func _image_nuage(variante: int) -> Image:
	var bruit := FastNoiseLite.new()
	bruit.seed = Terrain.graine + 40 + variante
	bruit.frequency = 0.035
	bruit.fractal_octaves = 4
	var n := 128
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2((x - n * 0.5) / (n * 0.5), (y - n * 0.5) / (n * 0.5)).length()
			var bord := 1.0 - smoothstep(0.35, 0.95, d)
			var densite := clampf((bruit.get_noise_2d(x, y) * 0.5 + 0.5 - 0.42) * 2.6, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, densite * bord))
	return image


func _deplacer_nuages(delta: float) -> void:
	var limite := GameRules.DEMI_CARTE + MARGE
	var direction_soleil := Vector3(0.6, -0.8, 0.2)
	var jour := 1.0
	if _soleil != null:
		direction_soleil = -_soleil.global_transform.basis.z
		jour = clampf((_soleil.light_energy - 0.45) / 1.3, 0.0, 1.0)
	for paire in _nuages:
		var nuage: MeshInstance3D = paire[0]
		var ombre: Decal = paire[1]
		nuage.position += VENT * delta
		if nuage.position.x > limite:
			nuage.position.x -= 2.0 * limite
		if nuage.position.z > limite:
			nuage.position.z -= 2.0 * limite
		# Ombre : projection du nuage sur le sol dans la direction du soleil.
		var vers_sol := direction_soleil * (nuage.position.y / maxf(-direction_soleil.y, 0.2))
		ombre.position = Vector3(nuage.position.x + vers_sol.x, 0.0, nuage.position.z + vers_sol.z)
		ombre.rotation.y = nuage.rotation.y
		ombre.modulate.a = OPACITE_OMBRE * _presence * jour


func _on_meteo(secheresse: bool) -> void:
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_fondu = create_tween()
	_fondu.tween_method(_appliquer_presence, _presence, 0.35 if secheresse else 1.0, 8.0)


func _appliquer_presence(valeur: float) -> void:
	_presence = valeur
	for m in _materiaux_nuages:
		m.set_shader_parameter("opacite", OPACITE_NUAGE * valeur)


# --- Oiseaux ---

## Vol qui entre par un bord de la carte et ressort de l'autre côté.
func _lancer_vol() -> void:
	var corbeaux := _hasard.randf() < 0.55
	var nombre := _hasard.randi_range(3, 6) if corbeaux else _hasard.randi_range(6, 11)
	var limite := GameRules.DEMI_CARTE + 15.0
	var angle := _hasard.randf() * TAU
	var depart := Vector3(cos(angle), 0.0, sin(angle)) * limite * 1.3
	var vise := Vector3(_hasard.randf_range(-60.0, 60.0), 0.0, _hasard.randf_range(-60.0, 60.0))
	var direction := (vise - depart).normalized()
	depart.y = _hasard.randf_range(14.0, 22.0) if corbeaux else _hasard.randf_range(10.0, 16.0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = _maillage_oiseau
	multi.instance_count = nombre
	var decalages: Array[Vector3] = []
	for i in nombre:
		var ecart := 5.0 if corbeaux else 8.0
		decalages.append(Vector3(_hasard.randf_range(-ecart, ecart), _hasard.randf_range(-1.5, 1.5), _hasard.randf_range(-ecart, ecart)))
		var battement := _hasard.randf_range(8.0, 11.0) if corbeaux else _hasard.randf_range(6.0, 7.5)
		multi.set_instance_custom_data(i, Color(_hasard.randf(), battement, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = _materiau_corbeau if corbeaux else _materiau_heron
	add_child(instance)
	_vols.append({"noeud": instance, "multi": multi, "centre": depart, "direction": direction,
			"vitesse": _hasard.randf_range(7.0, 10.0) if corbeaux else _hasard.randf_range(6.0, 8.0),
			"decalages": decalages, "t": 0.0, "echelle": 1.5 if corbeaux else 1.7})


## Avance un vol ; renvoie false quand il a quitté la carte.
func _animer_vol(vol: Dictionary, delta: float) -> bool:
	vol["t"] += delta
	var t: float = vol["t"]
	var direction: Vector3 = vol["direction"]
	var cote := Vector3(-direction.z, 0.0, direction.x)
	var centre: Vector3 = vol["centre"] + direction * float(vol["vitesse"]) * delta + cote * sin(t * 0.3) * 0.04
	vol["centre"] = centre
	var multi: MultiMesh = vol["multi"]
	var decalages: Array[Vector3] = vol["decalages"]
	var base := Basis.looking_at(direction, Vector3.UP).scaled(Vector3.ONE * float(vol["echelle"]))
	var revele := Vision.revele_tout
	for i in decalages.size():
		var p := centre + decalages[i] + Vector3(sin(t * 0.7 + i) * 0.6, sin(t * 1.3 + i * 2.0) * 0.4, cos(t * 0.9 + i) * 0.6)
		var visible := revele or Vision.est_explore(GameRules.PLAYER, Vector3(p.x, 0.0, p.z))
		multi.set_instance_transform(i, Transform3D(base if visible else Basis().scaled(Vector3.ZERO), p))
	var limite := GameRules.DEMI_CARTE + 60.0
	return absf(centre.x) < limite * 1.4 and absf(centre.z) < limite * 1.4 and t < 120.0


## Oiseau stylisé : corps fuselé, ailes en triangles (les sommets éloignés battent dans le shader), queue.
## COLOR.r = 1 sur le plastron et le collier (blancs chez le corbeau pie).
func _creer_maillage_oiseau() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noir := Color(0, 0, 0)
	var blanc := Color(1, 0, 0)
	var triangles := [
		# corps (dessus) et collier
		[Vector3(0, 0.03, -0.32), Vector3(-0.07, 0, -0.05), Vector3(0.07, 0, -0.05), blanc],
		[Vector3(-0.07, 0, -0.05), Vector3(0, 0, 0.22), Vector3(0.07, 0, -0.05), noir],
		# ailes
		[Vector3(-0.06, 0, -0.1), Vector3(-0.5, 0, 0.0), Vector3(-0.06, 0, 0.08), noir],
		[Vector3(-0.5, 0, 0.0), Vector3(-0.28, 0, 0.12), Vector3(-0.06, 0, 0.08), noir],
		[Vector3(0.06, 0, -0.1), Vector3(0.06, 0, 0.08), Vector3(0.5, 0, 0.0), noir],
		[Vector3(0.5, 0, 0.0), Vector3(0.06, 0, 0.08), Vector3(0.28, 0, 0.12), noir],
		# queue
		[Vector3(0, 0, 0.16), Vector3(-0.08, 0, 0.34), Vector3(0.08, 0, 0.34), noir],
	]
	for tri in triangles:
		for k in 3:
			st.set_color(tri[3])
			st.set_normal(Vector3.UP)
			st.add_vertex(tri[k])
	return st.commit()
