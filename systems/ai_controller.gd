extends Node
## IA du clan rival (version prototype, pour tester la boucle de jeu en solo).
## Elle ne triche pas : elle lit le même état que le joueur et passe par CommandBus.
## Comportement : économie équilibrée (champs, eau pour le cheptel) -> formation -> enclos
## -> raids sur les zébus sauvages, et pillage des enclos du joueur la nuit (GDD §7).
## Pas encore de Tsena ni de puits pour l'IA (voir docs/specs/economie.md).

@export var faction := GameRules.AI
@export var intervalle := 1.5
@export var villageois_max := 9
@export var dahalo_max := 3
@export var lanceurs_max := 2
@export var rayon_defense := 22.0
@export var taille_raid := 3

const OBJECTIFS := {"bois": 250.0, "eau": 200.0, "nourriture": 250.0}
const POSITIONS_ENCLOS := [Vector3(0, 0, -11), Vector3(-11, 0, -11), Vector3(11, 0, 11), Vector3(0, 0, 11)]
const POSITIONS_CHAMPS := [Vector3(-20, 0, -10), Vector3(-20, 0, -3), Vector3(-20, 0, 4), Vector3(-27, 0, -3)]
const CHAMPS_MAX := 4

var _t := 0.0


func _process(delta: float) -> void:
	if ResourceManager.partie_finie or CommandBus.monde == null:
		return
	_t += delta
	if _t < intervalle:
		return
	_t = 0.0
	_reflechir()


func _reflechir() -> void:
	var case = _premier_batiment("case_centrale")
	if case == null:
		return
	var villageois: Array = []
	var dahalos: Array = []
	var combattants: Array = []
	var nb_lanceurs := 0
	for u in get_tree().get_nodes_in_group("unites_%d" % faction):
		match u.data.role:
			"villageois":
				villageois.append(u)
			"dahalo":
				dahalos.append(u)
			"lanceur":
				nb_lanceurs += 1
		if u.est_combattant():
			combattants.append(u)
	if _defendre(case, combattants):
		dahalos = []  # tout le monde est mobilisé pour la défense ce tour-ci
	_gerer_economie(villageois)
	_gerer_formation(case, villageois.size(), dahalos.size(), nb_lanceurs)
	_gerer_enclos(case)
	_gerer_champs(case, villageois.size())
	_gerer_raids(dahalos)


# --- Économie ---

func _gerer_economie(villageois: Array) -> void:
	var affectes := {"bois": 0, "eau": 0, "nourriture": 0}
	for v in villageois:
		if _valide(v.cible_ressource) and not v.est_inactif():
			affectes[v.cible_ressource.type_ressource] += 1
	for v in villageois:
		if not v.est_inactif():
			continue
		var type := _type_prioritaire(affectes)
		var r = _plus_proche(v.global_position, _sources_recoltables(type))
		if r == null:
			continue
		affectes[type] += 1
		_cmd({"type": "recolter", "unites": [v.id], "cible_id": r.id})


func _type_prioritaire(affectes: Dictionary) -> String:
	var objectifs := OBJECTIFS.duplicate()
	# Plus le cheptel est grand, plus il faut d'eau et de nourriture en réserve.
	var n := ResourceManager.nb_zebus(faction)
	objectifs["eau"] = float(objectifs["eau"]) + 10.0 * n
	objectifs["nourriture"] = float(objectifs["nourriture"]) + 8.0 * n
	if GameClock.secheresse:
		objectifs["eau"] = float(objectifs["eau"]) * 2.0  # anticipation de la sécheresse (GDD §3)
	var meilleur := "bois"
	var score_min := INF
	for r in objectifs:
		var score: float = ResourceManager.quantite(faction, r) / float(objectifs[r]) + affectes[r] * 0.35
		if score < score_min:
			score_min = score
			meilleur = r
	return meilleur


# --- Formation et enclos ---

func _gerer_formation(case, nb_villageois: int, nb_dahalos: int, nb_lanceurs: int) -> void:
	if case.en_formation > 0:
		return
	var monde = CommandBus.monde
	if nb_villageois < villageois_max and ResourceManager.peut_payer(faction, monde.donnees_unite("villageois").cout):
		_cmd({"type": "former", "batiment": case.id, "unite": "villageois"})
	elif nb_dahalos < dahalo_max and ResourceManager.peut_payer(faction, monde.donnees_unite("dahalo").cout):
		_cmd({"type": "former", "batiment": case.id, "unite": "dahalo"})
	elif nb_lanceurs < lanceurs_max and ResourceManager.peut_payer(faction, monde.donnees_unite("lanceur").cout):
		_cmd({"type": "former", "batiment": case.id, "unite": "lanceur"})


func _gerer_enclos(case) -> void:
	var places := ResourceManager.capacite_zebus(faction) - ResourceManager.nb_zebus(faction)
	if places > 2 or not ResourceManager.peut_payer(faction, GameRules.COUTS_BATIMENTS["enclos"]):
		return
	var n: int = ResourceManager.enclos.get(faction, 1) - 1
	var decalage: Vector3 = POSITIONS_ENCLOS[n % POSITIONS_ENCLOS.size()]
	_cmd({"type": "construire", "type_batiment": "enclos", "position": case.global_position + decalage})


func _gerer_champs(case, nb_villageois: int) -> void:
	var champs := 0
	for c in get_tree().get_nodes_in_group("champ"):
		if c.faction == faction:
			champs += 1
	# Un champ pour trois villageois environ, en gardant du bois pour un enclos.
	if champs >= mini(CHAMPS_MAX, 1 + nb_villageois / 3):
		return
	var cout: Dictionary = GameRules.COUTS_BATIMENTS["champ"]
	if ResourceManager.quantite(faction, "bois") < float(cout["bois"]) + 40.0:
		return
	var decalage: Vector3 = POSITIONS_CHAMPS[champs % POSITIONS_CHAMPS.size()]
	_cmd({"type": "construire", "type_batiment": "champ", "position": case.global_position + decalage})


func _sources_recoltables(type: String) -> Array:
	var sources: Array = []
	for n in get_tree().get_nodes_in_group("ressource_" + type):
		if _valide(n) and n.peut_etre_recolte_par(faction) and not n.epuise() \
				and (n.disponible() or n.attendre_recolte()):
			sources.append(n)
	return sources


# --- Défense ---

## Si des unités ennemies approchent du village ou des enclos, tous les guerriers
## (sauf ceux qui escortent un troupeau) attaquent l'intrus le plus proche.
func _defendre(case, combattants: Array) -> bool:
	var points: Array = [case.global_position]
	for e in get_tree().get_nodes_in_group("enclos"):
		if e.faction == faction:
			points.append(e.global_position)
	var intrus: Array = []
	for u in get_tree().get_nodes_in_group("unites"):
		if u.faction == faction:
			continue
		for p in points:
			if u.global_position.distance_to(p) <= rayon_defense:
				intrus.append(u)
				break
	if intrus.is_empty():
		return false
	for c in combattants:
		if not c.zebus_escortes.is_empty() or (c.etat == Unite.Etat.ATTAQUE and c.cible_attaque in intrus):
			continue
		var cible = _plus_proche(c.global_position, intrus)
		if cible != null:
			_cmd({"type": "attaquer", "unites": [c.id], "cible_id": cible.id})
	return true


# --- Raids ---

func _gerer_raids(dahalos: Array) -> void:
	var enclos = _premier_batiment("enclos")
	for d in dahalos:
		if not d.est_inactif():
			continue
		var escorte: int = d.zebus_escortes.size()
		if escorte == 0 and GameClock.est_nuit:
			var proie = _enclos_a_piller()
			if proie != null:
				_cmd({"type": "piller", "unites": [d.id], "cible_id": proie.id})
				continue
		var cible = _zebu_cible(d)
		if escorte > 0 and (escorte >= taille_raid or cible == null):
			if enclos != null:
				_cmd({"type": "deposer", "unites": [d.id], "cible_id": enclos.id})
		elif cible != null:
			_cmd({"type": "capturer", "unites": [d.id], "cible_id": cible.id})


## La nuit, l'IA vise l'enclos adverse le mieux garni (pillage automatique).
func _enclos_a_piller():
	var meilleur = null
	var max_zebus := 0
	for e in get_tree().get_nodes_in_group("enclos"):
		if e.faction == faction or not _valide(e):
			continue
		var n := 0
		for z in get_tree().get_nodes_in_group("zebus"):
			if z.enclos == e and z.etat == Zebu.Etat.ENCLOS:
				n += 1
		if n > max_zebus:
			max_zebus = n
			meilleur = e
	return meilleur


func _zebu_cible(dahalo):
	# Priorité aux zébus sauvages ; la nuit, l'IA tente aussi de piller le joueur.
	var meilleur = null
	var d_min := INF
	for z in get_tree().get_nodes_in_group("zebus"):
		if not z.peut_etre_capture_par(faction):
			continue
		var sauvage: bool = z.proprietaire == GameRules.WILD
		if not sauvage and not GameClock.est_nuit:
			continue
		var d: float = dahalo.global_position.distance_to(z.global_position)
		if not sauvage:
			d *= 1.5
		if d < d_min:
			d_min = d
			meilleur = z
	return meilleur


# --- Utilitaires ---

func _cmd(cmd: Dictionary) -> void:
	cmd["faction"] = faction
	CommandBus.emettre(cmd)


func _premier_batiment(type_batiment: String):
	for b in get_tree().get_nodes_in_group("batiments_%d" % faction):
		if b.type_batiment == type_batiment and _valide(b):
			return b
	return null


func _plus_proche(pos: Vector3, noeuds: Array):
	var meilleur = null
	var d_min := INF
	for n in noeuds:
		if not _valide(n):
			continue
		var d := pos.distance_to(n.global_position)
		if d < d_min:
			d_min = d
			meilleur = n
	return meilleur


func _valide(n) -> bool:
	return is_instance_valid(n) and not n.is_queued_for_deletion()
