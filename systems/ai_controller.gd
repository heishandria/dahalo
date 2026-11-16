extends Node
## IA du clan rival (version prototype, pour tester la boucle de jeu en solo).
## Elle ne triche pas : elle lit le même état que le joueur et passe par CommandBus.
## Comportement : économie équilibrée -> formation -> enclos -> raids sur les zébus
## sauvages, et pillage des enclos du joueur la nuit (GDD §7).

@export var faction := GameRules.AI
@export var intervalle := 1.5
@export var villageois_max := 9
@export var dahalo_max := 3
@export var taille_raid := 3

const OBJECTIFS := {"bois": 250.0, "eau": 200.0, "nourriture": 250.0}
const POSITIONS_ENCLOS := [Vector3(0, 0, -11), Vector3(-11, 0, -11), Vector3(11, 0, 11), Vector3(0, 0, 11)]

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
	for u in get_tree().get_nodes_in_group("unites_%d" % faction):
		match u.data.role:
			"villageois":
				villageois.append(u)
			"dahalo":
				dahalos.append(u)
	_gerer_economie(villageois)
	_gerer_formation(case, villageois.size(), dahalos.size())
	_gerer_enclos(case)
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
		var r = _plus_proche(v.global_position, get_tree().get_nodes_in_group("ressource_" + type))
		if r == null:
			continue
		affectes[type] += 1
		_cmd({"type": "recolter", "unites": [v.id], "cible_id": r.id})


func _type_prioritaire(affectes: Dictionary) -> String:
	var objectifs := OBJECTIFS.duplicate()
	if GameClock.secheresse:
		objectifs["eau"] = 400.0  # anticipation de la sécheresse (GDD §3)
	var meilleur := "bois"
	var score_min := INF
	for r in objectifs:
		var score: float = ResourceManager.quantite(faction, r) / float(objectifs[r]) + affectes[r] * 0.35
		if score < score_min:
			score_min = score
			meilleur = r
	return meilleur


# --- Formation et enclos ---

func _gerer_formation(case, nb_villageois: int, nb_dahalos: int) -> void:
	if case.en_formation > 0:
		return
	var monde = CommandBus.monde
	if nb_villageois < villageois_max and ResourceManager.peut_payer(faction, monde.donnees_unite("villageois").cout):
		_cmd({"type": "former", "batiment": case.id, "unite": "villageois"})
	elif nb_dahalos < dahalo_max and ResourceManager.peut_payer(faction, monde.donnees_unite("dahalo").cout):
		_cmd({"type": "former", "batiment": case.id, "unite": "dahalo"})


func _gerer_enclos(case) -> void:
	var places := ResourceManager.capacite_zebus(faction) - ResourceManager.nb_zebus(faction)
	if places > 2 or not ResourceManager.peut_payer(faction, GameRules.COUT_ENCLOS):
		return
	var n: int = ResourceManager.enclos.get(faction, 1) - 1
	var decalage: Vector3 = POSITIONS_ENCLOS[n % POSITIONS_ENCLOS.size()]
	_cmd({"type": "construire", "type_batiment": "enclos", "position": case.global_position + decalage})


# --- Raids ---

func _gerer_raids(dahalos: Array) -> void:
	var enclos = _premier_batiment("enclos")
	for d in dahalos:
		if not d.est_inactif():
			continue
		var escorte: int = d.zebus_escortes.size()
		var cible = _zebu_cible(d)
		if escorte > 0 and (escorte >= taille_raid or cible == null):
			if enclos != null:
				_cmd({"type": "deposer", "unites": [d.id], "cible_id": enclos.id})
		elif cible != null:
			_cmd({"type": "capturer", "unites": [d.id], "cible_id": cible.id})


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
		if not _valide(n) or (n is NoeudRessource and n.epuise()):
			continue
		var d := pos.distance_to(n.global_position)
		if d < d_min:
			d_min = d
			meilleur = n
	return meilleur


func _valide(n) -> bool:
	return is_instance_valid(n) and not n.is_queued_for_deletion()
