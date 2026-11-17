extends Node
## Toutes les actions de jeu passent par ici, sous forme de commandes (dictionnaires).
##
## Le joueur ET l'IA utilisent ce même chemin. C'est la règle d'architecture n°1 :
## plus tard, pour le multijoueur en lockstep, il suffira d'envoyer ces commandes
## sur le réseau et de les exécuter au même « tick » sur chaque machine.
##
## Format : {"type": String, "faction": int, ...}
##   deplacer   : "unites": [ids], "cible": Vector3
##   recolter   : "unites": [ids], "cible_id": id d'un NoeudRessource
##   capturer   : "unites": [ids], "cible_id": id d'un Zebu
##   attaquer   : "unites": [ids], "cible_id": id d'une unité ennemie
##   piller     : "unites": [ids], "cible_id": id d'un enclos adverse (vol automatique, puis retour)
##   deposer    : "unites": [ids], "cible_id": id d'un Batiment
##   former     : "batiment": id, "unite": "villageois" | "dahalo" | "pisteur"
##   construire : "type_batiment": "enclos" | "champ" | "camp_bois" | "puits" | "tsena", "position": Vector3
##                (palissade : "rotation_y" facultatif, pour aligner le segment sur un tracé)
##   rechercher : "technologie": clé de GameRules.TECHNOLOGIES (dans le bâtiment adapté)
##   paturage   : "enclos": id, "actif": bool (mener le troupeau de cet enclos au pâturage le jour, avec un gardien)
##   commerce   : "action": "vendre_zebu" | "vendre_bois" | "vendre_nourriture" | "acheter_bois" | "acheter_nourriture" | "acheter_zebu" (nécessite un Tsena)

var monde = null           # référence vers main.gd (création d'entités)
var entites := {}          # id -> Node
var _prochain_id := 1


func reinitialiser() -> void:
	entites.clear()
	_prochain_id = 1
	monde = null


func enregistrer(e: Node) -> int:
	var id := _prochain_id
	_prochain_id += 1
	entites[id] = e
	e.tree_exiting.connect(func() -> void: entites.erase(id))
	return id


func get_entite(id: int) -> Node:
	var e = entites.get(id)
	return e if is_instance_valid(e) else null


func emettre(cmd: Dictionary) -> void:
	var faction: int = cmd.get("faction", -99)
	match cmd.get("type", ""):
		"deplacer", "recolter", "capturer", "piller", "deposer", "attaquer":
			var rang := 0
			for id in cmd.get("unites", []):
				var u = get_entite(id)
				if u != null and u.faction == faction:
					u.executer(cmd, rang)
					rang += 1
		"former":
			var b = get_entite(cmd.get("batiment", 0))
			if b != null and b.faction == faction:
				b.former(cmd.get("unite", ""))
		"construire":
			if monde != null:
				monde.construire(faction, cmd.get("type_batiment", ""), cmd.get("position", Vector3.ZERO),
						cmd.get("rotation_y", NAN))
		"rechercher":
			var tech: String = cmd.get("technologie", "")
			for b in get_tree().get_nodes_in_group("batiments_%d" % faction):
				if b.has_method("recherche_possible") and b.recherche_possible(tech):
					b.rechercher(tech)
					return
			if faction == GameRules.PLAYER:
				EventBus.message.emit("Il faut le bâtiment adapté pour cette recherche.")
		"paturage":
			var e = get_entite(cmd.get("enclos", 0))
			if e != null and e.faction == faction and e.has_method("mener_au_paturage"):
				e.mener_au_paturage(bool(cmd.get("actif", false)))
		"commerce":
			for t in get_tree().get_nodes_in_group("tsena"):
				if t.faction == faction:
					t.commercer(cmd.get("action", ""))
					return
			if faction == GameRules.PLAYER:
				EventBus.message.emit("Construisez d'abord un Tsena (marché).")
		_:
			push_warning("Commande inconnue : %s" % cmd)
