extends Node3D
## Visuel d'un point d'eau (purement visuel ; la ressource et sa collision restent dans NoeudRessource).
## - mare du village : contour irrégulier, berges de boue humide, eau trouble ;
## - trou d'eau creusé dans le sable du lit de rivière : plus petit et plus profond, bourrelet de sable.
## En sécheresse, l'eau se retire en fondu et découvre une auréole de boue craquelée.
## Spec : docs/specs/carte.md

const SEGMENTS := 40
const ANNEAUX := 9
const DUREE_FONDU := 6.0
const NIVEAU_SECHERESSE := 0.55

var dans_le_lit := false
var _berge := ShaderMaterial.new()
var _eau: MeshInstance3D
var _niveau := 1.0
var _rayon := 1.6
var _contour: Array[float] = []   # multiplicateur du rayon par segment (forme irrégulière)
var _fondu: Tween


func _ready() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(Vector2i(roundi(global_position.x * 10.0), roundi(global_position.z * 10.0)))
	_rayon = 0.95 if dans_le_lit else 1.6
	var a := hasard.randf() * TAU
	var b := hasard.randf() * TAU
	var c := hasard.randf() * TAU
	for s in SEGMENTS + 1:
		var t := TAU * s / SEGMENTS
		_contour.append(1.0 + 0.16 * sin(2.0 * t + a) + 0.09 * sin(3.0 * t + b) + 0.05 * sin(5.0 * t + c))
	_berge.shader = preload("res://scenes/world/mare_berge.gdshader")
	var dossier := "res://assets/textures/terrain/"
	_berge.set_shader_parameter("tex_sol", load(dossier + ("gravelly_sand_couleur.jpg" if dans_le_lit else "red_laterite_soil_stones_couleur.jpg")))
	_berge.set_shader_parameter("tex_craquele", load(dossier + "mud_cracked_dry_riverbed_002_couleur.jpg"))
	_creer_berges()
	_creer_eau()


## Hauteur des berges selon la distance relative r (1 = bord de l'eau) : fond sous l'eau, bourrelet, puis le sol.
func _hauteur(r: float) -> float:
	# Le sol (maillage du terrain) passe à y = 0 : l'eau doit rester au-dessus pour être vue. Le trou du lit
	# se lit grâce à son bourrelet de sable, plus haut.
	var fond := -0.02 if dans_le_lit else -0.14
	var levre := 0.22 if dans_le_lit else 0.09
	if r < 1.0:
		return lerpf(fond, 0.0, smoothstep(0.55, 1.0, r))
	if r < 1.25:
		return lerpf(0.0, levre, smoothstep(1.0, 1.25, r))
	return lerpf(levre, 0.01, smoothstep(1.25, 1.9, r))


func _point(segment: int, r: float) -> Vector3:
	var t := TAU * segment / SEGMENTS
	var d := _rayon * _contour[segment] * r
	return Vector3(cos(t) * d, _hauteur(r), sin(t) * d)


func _creer_berges() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rayons: Array[float] = []
	for k in ANNEAUX + 1:
		rayons.append(lerpf(0.5, 1.9, float(k) / ANNEAUX))
	for k in ANNEAUX:
		for s in SEGMENTS:
			var coins := [[s, rayons[k]], [s + 1, rayons[k]], [s + 1, rayons[k + 1]], [s, rayons[k + 1]]]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(float(coins[i][1]), 0.0))
				var segment: int = coins[i][0]
				var rayon: float = coins[i][1]
				st.add_vertex(_point(segment, rayon))
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "Berges"
	instance.mesh = st.commit()
	instance.material_override = _berge
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _creer_eau() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 0.06 if dans_le_lit else 0.03
	for s in SEGMENTS:
		for p in [[s, 0.0], [s, 1.04], [s + 1, 1.04]]:
			var segment: int = p[0]
			var r: float = p[1]
			var t := TAU * segment / SEGMENTS
			var d := _rayon * _contour[segment] * r
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(r, 0.0))
			st.add_vertex(Vector3(cos(t) * d, y, sin(t) * d))
	var materiau := ShaderMaterial.new()
	materiau.shader = preload("res://scenes/world/mare_eau.gdshader")
	if dans_le_lit:
		materiau.set_shader_parameter("couleur_bord", Color(0.46, 0.4, 0.3))
	_eau = MeshInstance3D.new()
	_eau.name = "Eau"
	_eau.mesh = st.commit()
	_eau.material_override = materiau
	_eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_eau)


## Sécheresse : l'eau se retire (fondu) ; la berge découverte devient de la boue craquelée.
func saison(secheresse: bool, immediat := false) -> void:
	var cible := NIVEAU_SECHERESSE if secheresse else 1.0
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	if immediat or not is_inside_tree():
		_appliquer(cible)
		return
	_fondu = create_tween()
	_fondu.tween_method(_appliquer, _niveau, cible, DUREE_FONDU)


func _appliquer(niveau: float) -> void:
	_niveau = niveau
	_berge.set_shader_parameter("niveau", niveau)
	if _eau != null:
		_eau.scale = Vector3(niveau, 1.0, niveau)
		_eau.position.y = (niveau - 1.0) * 0.12   # l'eau baisse aussi un peu
