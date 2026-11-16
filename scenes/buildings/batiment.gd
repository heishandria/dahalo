class_name Batiment
extends StaticBody3D
## Bâtiment générique. La Case centrale forme les unités et sert de dépôt (GDD §5).

@export_enum("case_centrale", "enclos") var type_batiment: String = "case_centrale"
var faction := GameRules.PLAYER
var id := 0
var en_formation := 0   # nombre d'unités en cours de formation


func _ready() -> void:
	id = CommandBus.enregistrer(self)
	add_to_group("batiments")
	add_to_group("batiments_%d" % faction)
	add_to_group(type_batiment)
	var banniere := get_node_or_null("Banniere") as MeshInstance3D
	if banniere:
		var m := StandardMaterial3D.new()
		m.albedo_color = GameRules.couleur_faction(faction)
		banniere.material_override = m


## Formation d'une unité (prototype : depuis la Case centrale, sans file d'attente visible).
## TODO GDD : les Dahalo devront être formés à la Case des Hommes.
func former(role: String) -> void:
	if type_batiment != "case_centrale" or CommandBus.monde == null:
		return
	var data: UnitData = CommandBus.monde.donnees_unite(role)
	if data == null:
		return
	if not ResourceManager.payer(faction, data.cout):
		if faction == GameRules.PLAYER:
			EventBus.message.emit("Ressources insuffisantes pour former : %s" % data.nom)
		return
	if faction == GameRules.PLAYER:
		EventBus.message.emit("Formation en cours : %s (%d s)" % [data.nom, int(data.temps_formation)])
	en_formation += 1
	await get_tree().create_timer(data.temps_formation, false).timeout
	en_formation -= 1
	if not is_inside_tree() or CommandBus.monde == null:
		return
	var a := randf() * TAU
	CommandBus.monde.creer_unite(role, faction, global_position + Vector3(cos(a), 0.0, sin(a)) * 4.0)
