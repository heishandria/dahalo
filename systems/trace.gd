class_name Trace
extends MeshInstance3D
## Trace laissée au sol par un Dahalo qui escorte des zébus volés (GDD §5 : le Pisteur
## « détecte les traces laissées par les voleurs »). Elle n'apparaît au clan volé que si
## un de ses Pisteurs passe à proximité, puis reste visible jusqu'à ce qu'elle s'efface.

var faction_volee := GameRules.WILD
var age := 0.0
var lue := false
var _materiau := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group("traces")
	var empreinte := PlaneMesh.new()
	empreinte.size = Vector2(0.6, 1.0)
	mesh = empreinte
	_materiau.albedo_color = Color(0.25, 0.12, 0.06, 0.8)
	_materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _materiau
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(delta: float) -> void:
	age += delta
	if age >= GameRules.DUREE_TRACES_S:
		queue_free()
		return
	_materiau.albedo_color.a = 0.8 * (1.0 - age / GameRules.DUREE_TRACES_S)


## Appelé par le brouillard : la trace devient visible si un Pisteur du clan volé la lit.
func maj_lecture(faction_joueur: int) -> void:
	if faction_volee != faction_joueur:
		visible = false
		return
	if not lue:
		for u in get_tree().get_nodes_in_group("unites_%d" % faction_joueur):
			if u.data.role == "pisteur" \
					and u.global_position.distance_to(global_position) <= GameRules.PORTEE_LECTURE_TRACES:
				lue = true
				break
	visible = lue
