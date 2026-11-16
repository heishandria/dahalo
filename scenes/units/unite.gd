class_name Unite
extends CharacterBody3D
## Unité du clan (villageois, pisteur, Dahalo). Le rôle vient de `data` (UnitData).
## Machine à états simple ; les ordres arrivent uniquement via executer(), appelé par CommandBus.

enum Etat { INACTIF, DEPLACEMENT, VERS_RESSOURCE, RECOLTE, RETOUR_DEPOT, CAPTURE, PILLAGE }

const DIST_RECOLTE := 2.2
const DIST_DEPOT := 3.5
const DIST_CAPTURE := 2.0

@export var data: UnitData
var faction := GameRules.PLAYER
var id := 0
var etat := Etat.INACTIF

# Récolte
var cible_ressource = null   # NoeudRessource
var type_charge := ""
var charge := 0.0
var _depot = null            # Batiment (case centrale)
var _timer_recolte := 0.0

# Raids
var cible_zebu = null        # Zebu
var zebus_escortes: Array = []
var cible_enclos = null     # Batiment (enclos adverse) pendant un pillage

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anneau: MeshInstance3D = $Anneau
@onready var corps: MeshInstance3D = $Corps
@onready var tete: MeshInstance3D = $Tete


func _ready() -> void:
	id = CommandBus.enregistrer(self)
	add_to_group("unites")
	add_to_group("unites_%d" % faction)
	anneau.visible = false

	var m := StandardMaterial3D.new()
	m.albedo_color = data.couleur
	corps.material_override = m
	var mt := StandardMaterial3D.new()
	mt.albedo_color = GameRules.couleur_faction(faction)
	tete.material_override = mt

	if data.role == "villageois":
		ResourceManager.ajouter_villageois(faction)


# --- API publique ---

func executer(cmd: Dictionary, rang: int = 0) -> void:
	match cmd.get("type", ""):
		"deplacer":
			_deplacer_vers(cmd.get("cible", global_position) + _decalage(rang))
		"recolter":
			var r = CommandBus.get_entite(cmd.get("cible_id", 0))
			if r == null:
				return
			if data.peut_recolter:
				aller_recolter(r)
			else:
				_deplacer_vers(r.global_position + _decalage(rang))
		"capturer":
			var z = CommandBus.get_entite(cmd.get("cible_id", 0))
			if z == null:
				return
			if data.peut_capturer:
				cible_zebu = z
				etat = Etat.CAPTURE
				agent.target_position = z.global_position
			else:
				_deplacer_vers(z.global_position + _decalage(rang))
		"piller":
			var e = CommandBus.get_entite(cmd.get("cible_id", 0))
			if e == null:
				return
			if data.peut_capturer:
				cible_enclos = e
				etat = Etat.PILLAGE
				_prochain_zebu_a_piller()
			else:
				_deplacer_vers(e.global_position + _decalage(rang))
		"deposer":
			var b = CommandBus.get_entite(cmd.get("cible_id", 0))
			if b == null:
				return
			if data.peut_recolter and charge > 0.0 and b.type_batiment == "case_centrale":
				_depot = b
				etat = Etat.RETOUR_DEPOT
				agent.target_position = b.global_position
			else:
				_deplacer_vers(b.global_position + _decalage(rang) * 0.5)


func set_selectionne(valeur: bool) -> void:
	anneau.visible = valeur


func est_inactif() -> bool:
	return etat == Etat.INACTIF


func vitesse_actuelle() -> float:
	var v := data.vitesse
	if not zebus_escortes.is_empty():
		v *= GameRules.MALUS_VITESSE_ESCORTE
	return v


func aller_recolter(r) -> void:
	if not _valide(r):
		_stop()
		return
	if charge > 0.0 and type_charge != r.type_ressource:
		charge = 0.0  # on lâche la charge d'un autre type
	type_charge = r.type_ressource
	cible_ressource = r
	etat = Etat.VERS_RESSOURCE
	agent.target_position = r.global_position


# --- Boucle ---

func _physics_process(delta: float) -> void:
	match etat:
		Etat.INACTIF:
			return
		Etat.RECOLTE:
			_recolter(delta)
			return
		Etat.VERS_RESSOURCE:
			if not _valide(cible_ressource):
				_stop()
				return
			if _proche(cible_ressource, DIST_RECOLTE):
				etat = Etat.RECOLTE
				_timer_recolte = 0.0
				return
		Etat.RETOUR_DEPOT:
			if not _valide(_depot):
				_depot = _trouver_depot()
				if _depot == null:
					_stop()
					return
				agent.target_position = _depot.global_position
			if _proche(_depot, DIST_DEPOT):
				_deposer()
				return
		Etat.PILLAGE:
			if not _valide(cible_zebu) or not cible_zebu.peut_etre_capture_par(faction):
				_prochain_zebu_a_piller()
				return
			if _proche(cible_zebu, DIST_CAPTURE):
				cible_zebu.suivre(self)
				_prochain_zebu_a_piller()
				return
			if agent.target_position.distance_to(cible_zebu.global_position) > 1.0:
				agent.target_position = cible_zebu.global_position
		Etat.CAPTURE:
			if not _valide(cible_zebu) or not cible_zebu.peut_etre_capture_par(faction):
				_stop()
				return
			if _proche(cible_zebu, DIST_CAPTURE):
				_capturer(cible_zebu)
				return
			# Le zébu bouge : on remet à jour la cible s'il s'est éloigné.
			if agent.target_position.distance_to(cible_zebu.global_position) > 1.0:
				agent.target_position = cible_zebu.global_position
	_avancer()


func _avancer() -> void:
	if agent.is_navigation_finished():
		if etat == Etat.DEPLACEMENT:
			_stop()
		return
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	velocity = dir * vitesse_actuelle()
	look_at(global_position + dir, Vector3.UP)
	move_and_slide()


# --- Récolte ---

func _recolter(delta: float) -> void:
	if not _valide(cible_ressource) or cible_ressource.epuise():
		var voisine = _ressource_voisine(type_charge)
		if charge > 0.0:
			cible_ressource = voisine
			_aller_deposer()
		elif voisine != null:
			aller_recolter(voisine)
		else:
			_stop()
		return

	_timer_recolte += delta * ResourceManager.multiplicateur_travail(faction)
	if _timer_recolte < 1.0:
		return
	_timer_recolte -= 1.0
	type_charge = cible_ressource.type_ressource
	charge += cible_ressource.extraire(data.vitesse_recolte)
	if charge >= data.capacite:
		_aller_deposer()


func _aller_deposer() -> void:
	_depot = _trouver_depot()
	if _depot == null:
		_stop()
		return
	etat = Etat.RETOUR_DEPOT
	agent.target_position = _depot.global_position


func _deposer() -> void:
	if charge > 0.0 and type_charge != "":
		ResourceManager.ajouter(faction, type_charge, charge)
	charge = 0.0
	if _valide(cible_ressource) and not cible_ressource.epuise():
		aller_recolter(cible_ressource)
	else:
		_stop()


func _trouver_depot():
	var est_case := func(b) -> bool: return b.type_batiment == "case_centrale"
	return _plus_proche(get_tree().get_nodes_in_group("batiments_%d" % faction), est_case)


func _ressource_voisine(type: String):
	var non_epuisee := func(n) -> bool: return not n.epuise()
	var r = _plus_proche(get_tree().get_nodes_in_group("ressource_" + type), non_epuisee)
	if r != null and global_position.distance_to(r.global_position) > 30.0:
		return null
	return r


# --- Raids ---

func _capturer(z) -> void:
	if zebus_escortes.size() >= GameRules.MAX_ZEBUS_ESCORTE:
		if faction == GameRules.PLAYER:
			EventBus.message.emit("Ce Dahalo escorte déjà %d zébus : ramenez-les à l'enclos." % zebus_escortes.size())
		_stop()
		return
	z.suivre(self)
	if faction == GameRules.PLAYER:
		EventBus.message.emit("Zébu capturé (%d/%d). Clic droit sur votre enclos pour le ramener."
				% [zebus_escortes.size(), GameRules.MAX_ZEBUS_ESCORTE])
	_stop()


## Pillage : vide l'enclos adverse zébu par zébu, puis rentre seul à l'enclos du clan.
func _prochain_zebu_a_piller() -> void:
	if zebus_escortes.size() < GameRules.MAX_ZEBUS_ESCORTE and _valide(cible_enclos):
		var dans_enclos := func(z) -> bool:
			return z.etat == Zebu.Etat.ENCLOS and z.enclos == cible_enclos and z.peut_etre_capture_par(faction)
		var proie = _plus_proche(get_tree().get_nodes_in_group("zebus"), dans_enclos)
		if proie != null:
			cible_zebu = proie
			etat = Etat.PILLAGE
			agent.target_position = proie.global_position
			return
	_ramener_troupeau()


func _ramener_troupeau() -> void:
	cible_enclos = null
	cible_zebu = null
	if zebus_escortes.is_empty():
		if faction == GameRules.PLAYER:
			EventBus.message.emit("Aucun zébu à prendre dans cet enclos.")
		_stop()
		return
	var est_enclos := func(b) -> bool: return b.type_batiment == "enclos"
	var maison = _plus_proche(get_tree().get_nodes_in_group("batiments_%d" % faction), est_enclos)
	if maison == null:
		_stop()
		return
	if faction == GameRules.PLAYER:
		EventBus.message.emit("Raid réussi : %d zébus en route vers votre enclos !" % zebus_escortes.size())
	_deplacer_vers(maison.global_position)


# --- Utilitaires ---

func _deplacer_vers(pos: Vector3) -> void:
	etat = Etat.DEPLACEMENT
	agent.target_position = pos


func _stop() -> void:
	etat = Etat.INACTIF
	velocity = Vector3.ZERO
	agent.target_position = global_position


func _decalage(rang: int) -> Vector3:
	# Petite grille 4 x n autour de la cible pour éviter que tout le groupe s'empile.
	if rang == 0:
		return Vector3.ZERO
	var cote := 4
	return Vector3((rang % cote) - 1.5, 0.0, floorf(rang / float(cote)) - 0.5) * 1.6


func _proche(n, distance: float) -> bool:
	return global_position.distance_to(n.global_position) < distance


func _valide(n) -> bool:
	return is_instance_valid(n) and not n.is_queued_for_deletion()


func _plus_proche(noeuds: Array, filtre: Callable):
	var meilleur = null
	var d_min := INF
	for n in noeuds:
		if not _valide(n) or not filtre.call(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < d_min:
			d_min = d
			meilleur = n
	return meilleur
