class_name Batiment
extends StaticBody3D
## Bâtiment générique. La Case centrale forme les unités et sert de dépôt (GDD §5).

@export_enum("case_centrale", "enclos", "camp_bois", "tsena", "case_hommes", "palissade") var type_batiment: String = "case_centrale"
var faction := GameRules.PLAYER
var id := 0
var en_formation := 0   # nombre d'unités en cours de formation
var en_recherche := ""  # technologie en cours de recherche
var mort := false       # bâtiments détruits (palissade) : jamais vrai pour les autres pour l'instant


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


## Dépôt de ressources : la Case centrale prend tout, le camp de bûcherons seulement le bois.
func accepte(type_ressource: String) -> bool:
	match type_batiment:
		"case_centrale":
			return true
		"camp_bois":
			return type_ressource == "bois"
		_:
			return false


## Formation d'une unité (prototype : depuis la Case centrale, sans file d'attente visible).
## TODO GDD : les Dahalo devront être formés à la Case des Hommes.
func peut_former(role: String) -> bool:
	var roles: Array = GameRules.FORMATIONS.get(type_batiment, [])
	return role in roles


func former(role: String) -> void:
	if not peut_former(role) or CommandBus.monde == null:
		return
	var data: UnitData = CommandBus.monde.donnees_unite(role)
	if data == null:
		return
	if data.requiert != "" and not CommandBus.monde.possede(faction, data.requiert):
		if faction == GameRules.PLAYER:
			var nom: String = GameRules.NOMS_BATIMENTS.get(data.requiert, data.requiert)
			EventBus.message.emit("%s : il faut d'abord un %s (les fusils s'achètent aux marchands)." % [data.nom, nom])
		return
	if not ResourceManager.payer(faction, data.cout):
		if faction == GameRules.PLAYER:
			EventBus.message.emit("%s : il faut %s." % [data.nom, ResourceManager.texte_cout(data.cout)])
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


func recherche_possible(tech: String) -> bool:
	var def: Dictionary = GameRules.TECHNOLOGIES.get(tech, {})
	return def.get("batiment", "") == type_batiment


func rechercher(tech: String) -> void:
	if not recherche_possible(tech):
		return
	var def: Dictionary = GameRules.TECHNOLOGIES[tech]
	var nom: String = def["nom"]
	if ResourceManager.a_technologie(faction, tech) or en_recherche == tech:
		_message("%s : déjà acquise ou en cours." % nom)
		return
	if en_recherche != "":
		_message("Une recherche est déjà en cours dans ce bâtiment.")
		return
	var cout: Dictionary = def["cout"]
	if not ResourceManager.payer(faction, cout):
		_message("%s : il faut %s." % [nom, ResourceManager.texte_cout(cout)])
		return
	en_recherche = tech
	_message("Recherche en cours : %s (%d s)" % [nom, int(def["temps"])])
	await get_tree().create_timer(float(def["temps"]), false).timeout
	en_recherche = ""
	if not is_inside_tree():
		return
	ResourceManager.acquerir_technologie(faction, tech)
	_message("Technologie acquise : %s !" % nom)


func _message(texte: String) -> void:
	if faction == GameRules.PLAYER:
		EventBus.message.emit(texte)
