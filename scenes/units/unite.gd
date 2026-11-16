class_name Unite
extends CharacterBody3D
## Unité du clan (villageois, pisteur, Dahalo, lanceur, tireur). Le rôle vient de `data` (UnitData).
## Combat : à 0 PV, l'unité meurt : elle lâche son troupeau, tombe au sol puis disparaît
## (spec : docs/specs/combat.md). Les zébus, eux, ne sont jamais tués.
## Machine à états simple ; les ordres arrivent uniquement via executer(), appelé par CommandBus.

enum Etat { INACTIF, DEPLACEMENT, VERS_RESSOURCE, RECOLTE, RETOUR_DEPOT, CAPTURE, PILLAGE, ATTAQUE, MORT }

const DIST_RECOLTE := 2.2
const DIST_DEPOT := 3.5
const DIST_CAPTURE := 2.0
const INTERVALLE_GUET := 0.5     # fréquence de recherche d'ennemis quand l'unité est inactive
const PORTEE_DISTANCE := 3.0     # au-delà, l'attaque est à distance (projectile visible)
const DUREE_CORPS_S := 5.0       # le corps reste au sol avant de disparaître

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

# Combat
var pv := 1.0
var mort := false
var cible_attaque = null     # Unite ennemie
var _recharge := 0.0
var _chrono_guet := 0.0
var _materiau_barre := StandardMaterial3D.new()
var _derniere_trace := Vector3.INF
var ralentissements := 0     # nombre de palissades ennemies traversées en ce moment
var _derniere_alerte := -INF
var _deplacement_demande := false   # avoidance : vrai si _avancer a demandé un pas ce tour-ci

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anneau: MeshInstance3D = $Anneau
@onready var corps: MeshInstance3D = $Corps
@onready var tete: MeshInstance3D = $Tete
@onready var barre_vie: MeshInstance3D = $BarreVie


func _ready() -> void:
	id = CommandBus.enregistrer(self)
	agent.velocity_computed.connect(_on_vitesse_calculee)
	add_to_group("unites")
	add_to_group("unites_%d" % faction)
	anneau.visible = false

	var m := StandardMaterial3D.new()
	m.albedo_color = data.couleur
	corps.material_override = m
	var mt := StandardMaterial3D.new()
	mt.albedo_color = GameRules.couleur_faction(faction)
	tete.material_override = mt

	pv = data.pv
	_materiau_barre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materiau_barre.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_materiau_barre.billboard_keep_scale = true
	_materiau_barre.no_depth_test = true
	barre_vie.material_override = _materiau_barre
	_maj_barre_vie()
	if data.arme == "fusil":
		_ajouter_fusil()



# --- API publique ---

func executer(cmd: Dictionary, rang: int = 0) -> void:
	if mort:
		return
	match cmd.get("type", ""):
		"attaquer":
			var ennemi = CommandBus.get_entite(cmd.get("cible_id", 0))
			if ennemi == null:
				return
			if est_combattant():
				attaquer(ennemi)
			else:
				_deplacer_vers(ennemi.global_position + _decalage(rang))
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
			if data.peut_recolter and charge > 0.0 and b.has_method("accepte") and b.accepte(type_charge):
				_depot = b
				etat = Etat.RETOUR_DEPOT
				agent.target_position = b.global_position
			else:
				_deplacer_vers(b.global_position + _decalage(rang) * 0.5)


func set_selectionne(valeur: bool) -> void:
	anneau.visible = valeur and not mort


func est_combattant() -> bool:
	return data.degats > 0.0


func attaquer(ennemi) -> void:
	if not _ennemi_valide(ennemi):
		return
	cible_attaque = ennemi
	etat = Etat.ATTAQUE
	agent.target_position = ennemi.global_position


## Reçoit des dégâts. À 0 PV : l'unité meurt.
func subir(degats: float, attaquant) -> void:
	if mort:
		return
	pv -= degats
	_maj_barre_vie()
	if faction == GameRules.PLAYER and GameClock.temps_ecoule - _derniere_alerte > 5.0:
		_derniere_alerte = GameClock.temps_ecoule
		EventBus.alerte.emit(global_position)
	if pv <= 0.0:
		_mourir()
		return
	# Riposte si l'unité n'était pas déjà occupée à se battre.
	if est_combattant() and etat != Etat.ATTAQUE and _ennemi_valide(attaquant) and zebus_escortes.is_empty():
		attaquer(attaquant)


func est_inactif() -> bool:
	return etat == Etat.INACTIF


func vitesse_actuelle() -> float:
	var v := data.vitesse
	if not zebus_escortes.is_empty():
		v *= GameRules.MALUS_VITESSE_ESCORTE_RAID_ECLAIR if ResourceManager.a_technologie(faction, "raid_eclair") \
				else GameRules.MALUS_VITESSE_ESCORTE
	if ResourceManager.a_technologie(faction, "marcheurs_androy"):
		v *= GameRules.BONUS_MARCHEURS
	if ralentissements > 0:
		v *= GameRules.PALISSADE_RALENTISSEMENT
	return v


func capacite_transport() -> float:
	var c := data.capacite
	if ResourceManager.a_technologie(faction, "vannerie_cuirs"):
		c *= GameRules.BONUS_VANNERIE
	return c


func degats_actuels() -> float:
	var d := data.degats
	if data.arme in ["sagaie", "sagaie_jet"] and ResourceManager.a_technologie(faction, "sagaies_acerees"):
		d *= GameRules.BONUS_SAGAIES_ACEREES
	return d


func aller_recolter(r) -> void:
	if not _valide(r):
		_stop()
		return
	if not r.peut_etre_recolte_par(faction):
		if faction == GameRules.PLAYER:
			EventBus.message.emit("Ce champ appartient à un autre clan.")
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
	_recharge = maxf(0.0, _recharge - delta)
	match etat:
		Etat.INACTIF:
			_guetter(delta)
			return
		Etat.MORT:
			return
		Etat.ATTAQUE:
			if not _ennemi_valide(cible_attaque) or not Vision.est_visible(faction, cible_attaque.global_position):
				cible_attaque = null
				_stop()
				return
			var distance := global_position.distance_to(cible_attaque.global_position)
			if distance <= data.portee:
				velocity = Vector3.ZERO
				var vers: Vector3 = cible_attaque.global_position - global_position
				vers.y = 0.0
				if vers.length() > 0.05:
					look_at(global_position + vers.normalized(), Vector3.UP)
				if _recharge <= 0.0:
					_frapper(cible_attaque)
				return
			if agent.target_position.distance_to(cible_attaque.global_position) > 1.0:
				agent.target_position = cible_attaque.global_position
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
	if not zebus_escortes.is_empty():
		_laisser_traces()
	if agent.is_navigation_finished():
		if etat == Etat.DEPLACEMENT:
			_stop()
		return
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	# Évitement entre unités (RVO) : l'agent corrige la vitesse voulue, appliquée dans _on_vitesse_calculee.
	_deplacement_demande = true
	agent.max_speed = vitesse_actuelle()
	agent.velocity = dir * vitesse_actuelle()


func _on_vitesse_calculee(vitesse_sure: Vector3) -> void:
	if not _deplacement_demande or mort:
		return
	_deplacement_demande = false
	vitesse_sure.y = 0.0
	velocity = vitesse_sure
	if vitesse_sure.length() > 0.1:
		look_at(global_position + vitesse_sure.normalized(), Vector3.UP)
	move_and_slide()


# --- Récolte ---

func _recolter(delta: float) -> void:
	var perdue: bool = not _valide(cible_ressource) or cible_ressource.epuise()
	if not perdue and not cible_ressource.disponible():
		if cible_ressource.attendre_recolte():
			# Champ qui pousse : on dépose d'abord sa charge, puis on cultive (sans villageois, rien ne pousse).
			if charge > 0.0:
				_aller_deposer()
			elif cible_ressource.has_method("cultiver"):
				cible_ressource.cultiver(delta)
			return
		perdue = true  # arbre coupé (souche) : on cherche ailleurs
	if perdue:
		var voisine = _ressource_voisine(type_charge)
		if charge > 0.0:
			cible_ressource = voisine
			_aller_deposer()
		elif voisine != null:
			aller_recolter(voisine)
		else:
			_stop()
		return

	_timer_recolte += delta
	if _timer_recolte < 1.0:
		return
	_timer_recolte -= 1.0
	type_charge = cible_ressource.type_ressource
	charge += cible_ressource.extraire(data.vitesse_recolte, faction)
	if charge >= capacite_transport():
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
	if _valide(cible_ressource) and not cible_ressource.epuise() \
			and (cible_ressource.disponible() or cible_ressource.attendre_recolte()):
		aller_recolter(cible_ressource)
	elif type_charge != "" and _ressource_voisine(type_charge) != null:
		aller_recolter(_ressource_voisine(type_charge))
	else:
		_stop()


## Dépôt le plus proche qui accepte la charge : Case centrale (tout), camp de bûcherons (bois).
func _trouver_depot():
	var type := type_charge
	var accepte := func(b) -> bool: return b.has_method("accepte") and b.accepte(type)
	return _plus_proche(get_tree().get_nodes_in_group("batiments_%d" % faction), accepte)


func _ressource_voisine(type: String):
	var f := faction
	var non_epuisee := func(n) -> bool:
		return n.peut_etre_recolte_par(f) and not n.epuise() and (n.disponible() or n.attendre_recolte())
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


# --- Combat ---

func _guetter(delta: float) -> void:
	if not est_combattant():
		return
	_chrono_guet += delta
	if _chrono_guet < INTERVALLE_GUET:
		return
	_chrono_guet = 0.0
	var f := faction
	var ennemi_proche := func(u) -> bool:
		return u.faction != f and not u.mort
	var ennemi = _plus_proche(get_tree().get_nodes_in_group("unites"), ennemi_proche)
	if ennemi != null and global_position.distance_to(ennemi.global_position) <= Vision.rayon_unite(self) \
			and Vision.est_visible(faction, ennemi.global_position):
		attaquer(ennemi)


## Un Dahalo qui escorte des zébus volés laisse des traces que les Pisteurs du clan volé peuvent lire.
func _laisser_traces() -> void:
	var victime := GameRules.WILD
	for z in zebus_escortes:
		if is_instance_valid(z) and z.vole:
			victime = z.victime
			break
	if victime == GameRules.WILD:
		return
	if _derniere_trace != Vector3.INF and global_position.distance_to(_derniere_trace) < GameRules.ECART_TRACES_M:
		return
	_derniere_trace = global_position
	var trace := Trace.new()
	trace.faction_volee = victime
	get_tree().current_scene.add_child(trace)
	trace.global_position = Vector3(global_position.x, 0.25, global_position.z)
	trace.rotation.y = rotation.y


func _frapper(ennemi) -> void:
	_recharge = data.cadence
	if data.portee > PORTEE_DISTANCE:
		_tracer_vers(ennemi.global_position)
	ennemi.subir(degats_actuels(), self)


func _mourir() -> void:
	mort = true
	etat = Etat.MORT
	velocity = Vector3.ZERO
	cible_attaque = null
	cible_zebu = null
	cible_enclos = null
	# Le troupeau escorté est lâché sur place : il redevient sauvage et peut être repris.
	for z in zebus_escortes.duplicate():
		if is_instance_valid(z):
			z.liberer()
	zebus_escortes.clear()
	remove_from_group("unites")
	remove_from_group("unites_%d" % faction)
	collision_layer = 0
	anneau.visible = false
	barre_vie.visible = false
	var mat_corps := corps.material_override as StandardMaterial3D
	if mat_corps:
		mat_corps.albedo_color = data.couleur.darkened(0.5)
	if faction == GameRules.PLAYER:
		EventBus.message.emit("%s est tombé au combat." % data.nom)
	# Chute au sol, puis le corps s'efface après quelques secondes (sans effet sanglant).
	var chute := create_tween()
	chute.tween_property(self, "rotation:x", -PI / 2.0, 0.35).set_ease(Tween.EASE_IN)
	chute.parallel().tween_property(self, "position:y", 0.35, 0.35)
	chute.tween_interval(DUREE_CORPS_S)
	chute.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.6)
	chute.tween_callback(queue_free)


## Cible attaquable : unité ennemie vivante, ou palissade ennemie (sabotage).
func _ennemi_valide(u) -> bool:
	return _valide(u) and u.has_method("subir") and u.get("faction") != faction \
			and u.get("faction") != GameRules.WILD and not u.mort


func _maj_barre_vie() -> void:
	var ratio := clampf(pv / maxf(float(data.pv), 1.0), 0.0, 1.0)
	barre_vie.visible = ratio < 1.0 and not mort
	barre_vie.scale = Vector3(ratio, 1.0, 1.0)
	_materiau_barre.albedo_color = Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.3), ratio)


## Trait bref entre le tireur et sa cible (sagaie lancée ou coup de fusil).
func _tracer_vers(cible: Vector3) -> void:
	var depart := global_position + Vector3(0.0, 1.4, 0.0)
	var arrivee := cible + Vector3(0.0, 1.0, 0.0)
	var projectile := MeshInstance3D.new()
	var maillage := BoxMesh.new()
	maillage.size = Vector3(0.05, 0.05, depart.distance_to(arrivee))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5) if data.arme == "fusil" else Color(0.55, 0.4, 0.25)
	maillage.material = mat
	projectile.mesh = maillage
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = (depart + arrivee) * 0.5
	projectile.look_at(arrivee, Vector3.UP)
	get_tree().create_timer(0.12 if data.arme == "fusil" else 0.25).timeout.connect(projectile.queue_free)


func _ajouter_fusil() -> void:
	var fusil := MeshInstance3D.new()
	var maillage := BoxMesh.new()
	maillage.size = Vector3(0.08, 0.08, 1.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.18, 0.15)
	maillage.material = mat
	fusil.mesh = maillage
	fusil.position = Vector3(0.35, 1.2, -0.3)
	add_child(fusil)


# --- Utilitaires ---

func _deplacer_vers(pos: Vector3) -> void:
	etat = Etat.DEPLACEMENT
	agent.target_position = pos


func _stop() -> void:
	etat = Etat.INACTIF
	_deplacement_demande = false
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
