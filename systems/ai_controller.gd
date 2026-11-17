extends Node
## IA du clan rival (version prototype, pour tester la boucle de jeu en solo).
## Elle ne triche pas : elle lit le même état que le joueur et passe par CommandBus.
## Comportement : économie équilibrée (champs, eau pour le cheptel) -> formation -> enclos
## -> raids sur les zébus sauvages, et pillage des enclos du joueur la nuit (GDD §7).
## Tsena : elle en construit un pour vendre quelques zébus quand il lui faut des Ariary (âges, technologies).
## Palissades : elle entoure ses enclos garnis d'un carré d'épines et répare les brèches.
## Pas encore de puits ni de camp de bûcherons pour l'IA.
## Brouillard : l'IA ne voit que ce que voient ses unités ; son Pisteur explore la carte
## et elle « se souvient » des zones explorées (voir docs/specs/vision.md).

@export var faction := GameRules.AI
@export var intervalle := 1.5
@export var villageois_max := 9
@export var dahalo_max := 3
@export var guerriers_max := 6
@export var rayon_defense := 22.0
@export var taille_raid := 3

const OBJECTIFS := {"bois": 250.0, "eau": 200.0, "nourriture": 250.0}
const POSITIONS_ENCLOS := [Vector3(0, 0, -11), Vector3(-11, 0, -11), Vector3(11, 0, 11), Vector3(0, 0, 11)]
const POSITIONS_CHAMPS := [Vector3(-20, 0, -10), Vector3(-20, 0, -3), Vector3(-20, 0, 4), Vector3(-27, 0, -3)]
const CHAMPS_MAX := 4
# Ordre de recherche de l'IA ; elle ne lance une recherche que si elle garde une réserve après paiement.
const PLAN_RECHERCHE := ["cultures_traditionnelles", "vannerie_cuirs", "age_2", "sagaies_acerees",
		"puits_profonds", "marcheurs_androy", "age_3", "pacte_eleveurs", "raid_eclair"]
const RESERVE_RECHERCHE := {"nourriture": 120.0, "bois": 100.0}
# Circuit d'exploration du Pisteur, en fraction de DEMI_CARTE (la carte est aléatoire : on balaie tout).
const POINTS_EXPLORATION := [Vector2(0.4, 0.4), Vector2(0, 0), Vector2(-0.4, -0.4), Vector2(0.5, -0.5),
		Vector2(-0.5, 0.5), Vector2(0.8, 0), Vector2(0, -0.8), Vector2(-0.8, 0), Vector2(0, 0.8),
		Vector2(0.75, 0.75), Vector2(-0.75, -0.75), Vector2(0.75, -0.75), Vector2(-0.75, 0.75)]
# Palissades autour des enclos (spec : docs/specs/defense.md §4)
const PALISSADE_ZEBUS_MIN := 4          # un enclos n'est clôturé qu'à partir de ce nombre de zébus
const PALISSADE_RESERVE_BOIS := 100.0   # bois gardé après chaque segment (enclos et champs passent avant)
const PALISSADE_DEMI_COTE := 6.0        # carré à 2 m de la clôture de l'enclos (8 x 8 m)

var _point_exploration := 0

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
	var pisteurs: Array = []
	for u in get_tree().get_nodes_in_group("unites_%d" % faction):
		match u.data.role:
			"villageois":
				villageois.append(u)
			"dahalo":
				dahalos.append(u)
			"pisteur":
				pisteurs.append(u)
		if u.est_combattant():
			combattants.append(u)
	if _defendre(case, combattants):
		dahalos = []  # tout le monde est mobilisé pour la défense ce tour-ci
	_gerer_economie(villageois)
	_gerer_formation(case, villageois.size(), dahalos.size(), combattants.size(), pisteurs.size())
	_gerer_enclos(case)
	_gerer_champs(case, villageois.size())
	_gerer_palissades()
	_gerer_raids(dahalos)
	_explorer(pisteurs)
	_gerer_recherche()
	_gerer_tsena(case, villageois.size())


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

func _gerer_formation(case, nb_villageois: int, nb_dahalos: int, nb_guerriers: int, nb_pisteurs: int) -> void:
	var monde = CommandBus.monde
	if case.en_formation == 0 and nb_villageois < villageois_max \
			and ResourceManager.peut_payer(faction, monde.donnees_unite("villageois").cout):
		_cmd({"type": "former", "batiment": case.id, "unite": "villageois"})
	# Sans Pisteur, l'IA ne découvre plus rien (brouillard) : elle en reforme un s'il est mort.
	elif case.en_formation == 0 and nb_pisteurs == 0 \
			and ResourceManager.peut_payer(faction, monde.donnees_unite("pisteur").cout):
		_cmd({"type": "former", "batiment": case.id, "unite": "pisteur"})
	# Les guerriers se forment à la Case des Hommes : la construire dès que possible.
	var hommes = _premier_batiment("case_hommes")
	if hommes == null:
		if nb_villageois >= 4 and ResourceManager.peut_payer(faction, GameRules.COUTS_BATIMENTS["case_hommes"]):
			_cmd({"type": "construire", "type_batiment": "case_hommes",
					"position": case.global_position + Vector3(-8, 0, 8)})
		return
	if hommes.en_formation > 0:
		return
	# Toujours quelques Dahalo pour les raids, puis l'unité qui contre l'armée adverse vue.
	if nb_dahalos < 2:
		_former_si_possible(hommes, "dahalo")
		return
	if nb_guerriers >= guerriers_max:
		return
	_former_si_possible(hommes, _contre_armee_adverse())


func _former_si_possible(hommes, role: String) -> void:
	var data: UnitData = CommandBus.monde.donnees_unite(role)
	if ResourceManager.age(faction) < data.age_requis:
		return
	if data.requiert != "" and _premier_batiment(data.requiert) == null:
		return
	if ResourceManager.peut_payer(faction, data.cout):
		_cmd({"type": "former", "batiment": hommes.id, "unite": role})


## Triangle : Dahalo > Tireur > Lanceur > Dahalo. L'IA forme ce qui bat le plus le joueur VU.
func _contre_armee_adverse() -> String:
	var vus := {"dahalo": 0, "lanceur": 0, "tireur": 0}
	for u in get_tree().get_nodes_in_group("unites"):
		if u.faction != faction and u.data.role in vus and Vision.est_explore(faction, u.global_position) \
				and Vision.est_visible(faction, u.global_position):
			vus[u.data.role] += 1
	var dominant := "dahalo"
	for role in vus:
		if vus[role] > vus[dominant]:
			dominant = role
	if vus[dominant] == 0:
		return "lanceur"   # rien vu : de quoi tenir les raids de Dahalo adverses
	match dominant:
		"dahalo":
			return "lanceur"
		"lanceur":
			# Le Tireur bat le Lanceur ; à défaut (âge 1, pas de Tsena), des Dahalo.
			return "tireur" if ResourceManager.age(faction) >= 2 and _premier_batiment("tsena") != null else "dahalo"
		_:
			return "dahalo"


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


# --- Palissades ---

## Pose au plus un segment par réflexion : le premier qui manque autour de l'enclos le plus garni.
## Un segment saboté manque à nouveau, il est donc reconstruit de la même façon.
func _gerer_palissades() -> void:
	var cout: Dictionary = GameRules.COUTS_BATIMENTS["palissade"]
	if ResourceManager.quantite(faction, "bois") < float(cout["bois"]) + PALISSADE_RESERVE_BOIS:
		return
	var monde = CommandBus.monde
	for e in _enclos_par_cheptel():
		for segment in _segments_autour(e.global_position):
			var position: Vector3 = segment[0]
			if _palissade_presente(position) \
					or monde.raison_emplacement_invalide(faction, "palissade", position) != "":
				continue  # déjà là, ou emplacement occupé (champ, arbre) : brèche acceptée
			_cmd({"type": "construire", "type_batiment": "palissade", "position": position,
					"rotation_y": segment[1]})
			return


## Enclos de l'IA qui méritent une palissade, du plus garni au moins garni.
func _enclos_par_cheptel() -> Array:
	var cheptel := {}
	for z in get_tree().get_nodes_in_group("zebus"):
		if z.etat == Zebu.Etat.ENCLOS and _valide(z.enclos) and z.enclos.faction == faction:
			cheptel[z.enclos] = int(cheptel.get(z.enclos, 0)) + 1
	var liste: Array = []
	for e in cheptel:
		if int(cheptel[e]) >= PALISSADE_ZEBUS_MIN:
			liste.append(e)
	liste.sort_custom(func(a, b) -> bool: return int(cheptel[a]) > int(cheptel[b]))
	return liste


## Segments [position, rotation_y] d'un carré de palissade centré sur un enclos.
func _segments_autour(centre: Vector3) -> Array:
	var longueur: float = GameRules.EMPRISES["palissade"].x
	var nombre := int(ceil(2.0 * PALISSADE_DEMI_COTE / longueur))
	var segments: Array = []
	for i in nombre:
		var t := -PALISSADE_DEMI_COTE + longueur * (i + 0.5)
		segments.append([centre + Vector3(t, 0, -PALISSADE_DEMI_COTE), 0.0])
		segments.append([centre + Vector3(t, 0, PALISSADE_DEMI_COTE), 0.0])
		segments.append([centre + Vector3(-PALISSADE_DEMI_COTE, 0, t), PI / 2.0])
		segments.append([centre + Vector3(PALISSADE_DEMI_COTE, 0, t), PI / 2.0])
	return segments


func _palissade_presente(position: Vector3) -> bool:
	for p in get_tree().get_nodes_in_group("palissade"):
		if p.faction == faction and _valide(p) and not p.mort and p.global_position.distance_to(position) < 1.0:
			return true
	return false


# --- Recherche ---

func _gerer_recherche() -> void:
	for tech in PLAN_RECHERCHE:
		if ResourceManager.a_technologie(faction, tech):
			continue
		if not ResourceManager.technologie_accessible(faction, tech):
			return  # on suit le plan dans l'ordre
		var def: Dictionary = GameRules.TECHNOLOGIES[tech]
		var batiment = _premier_batiment(def["batiment"])
		if batiment == null or batiment.en_recherche != "":
			return
		var cout: Dictionary = def["cout"]
		var avec_reserve := cout.duplicate()
		for r in RESERVE_RECHERCHE:
			avec_reserve[r] = float(avec_reserve.get(r, 0.0)) + float(RESERVE_RECHERCHE[r])
		if ResourceManager.peut_payer(faction, avec_reserve):
			_cmd({"type": "rechercher", "technologie": tech})
		return


# --- Tsena : vendre un peu de cheptel pour financer les âges ---

func _gerer_tsena(case, nb_villageois: int) -> void:
	var tsena = _premier_batiment("tsena")
	if tsena == null:
		var cout: Dictionary = GameRules.COUTS_BATIMENTS["tsena"]
		if nb_villageois >= 6 and ResourceManager.quantite(faction, "bois") >= float(cout["bois"]) + 100.0:
			_cmd({"type": "construire", "type_batiment": "tsena", "position": case.global_position + Vector3(-12, 0, 0)})
		return
	var besoin := _ariary_manquants()
	if besoin <= 0.0:
		return
	# D'abord les surplus ; les zébus seulement en dernier recours.
	if ResourceManager.quantite(faction, "bois") > 350.0:
		_cmd({"type": "commerce", "action": "vendre_bois"})
	elif ResourceManager.quantite(faction, "nourriture") > 400.0:
		_cmd({"type": "commerce", "action": "vendre_nourriture"})
	elif ResourceManager.nb_zebus(faction) >= 6 and not GameClock.secheresse:
		_cmd({"type": "commerce", "action": "vendre_zebu"})


## Ariary qui manquent pour la prochaine recherche du plan (0 si rien ne manque).
func _ariary_manquants() -> float:
	for tech in PLAN_RECHERCHE:
		if ResourceManager.a_technologie(faction, tech):
			continue
		var cout: Dictionary = GameRules.TECHNOLOGIES[tech]["cout"]
		return maxf(0.0, float(cout.get("ariary", 0.0)) - ResourceManager.quantite(faction, "ariary"))
	return 0.0


# --- Exploration ---

func _explorer(pisteurs: Array) -> void:
	for p in pisteurs:
		if not p.est_inactif():
			continue
		var fraction: Vector2 = POINTS_EXPLORATION[_point_exploration % POINTS_EXPLORATION.size()]
		var cible := Vector3(fraction.x, 0.0, fraction.y) * GameRules.DEMI_CARTE
		_point_exploration += 1
		_cmd({"type": "deplacer", "unites": [p.id], "cible": cible})


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
		if u.faction == faction or not Vision.est_visible(faction, u.global_position):
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
		if e.faction == faction or not _valide(e) or not Vision.est_explore(faction, e.global_position):
			continue
		var n := 0
		for z in get_tree().get_nodes_in_group("zebus"):
			if z.enclos == e and z.etat == Zebu.Etat.ENCLOS and not z.dehors:
				n += 1
		if n > max_zebus:
			max_zebus = n
			meilleur = e
	return meilleur


func _zebu_cible(dahalo):
	# Priorité aux zébus sauvages ; la nuit, l'IA tente aussi de piller le joueur. Un troupeau adverse au
	# pâturage est une proie de jour comme de nuit.
	var meilleur = null
	var d_min := INF
	for z in get_tree().get_nodes_in_group("zebus"):
		if not z.peut_etre_capture_par(faction) or not Vision.est_explore(faction, z.global_position):
			continue
		var sauvage: bool = z.proprietaire == GameRules.WILD
		var au_paturage: bool = z.etat == Zebu.Etat.ENCLOS and z.dehors
		if not sauvage and not au_paturage and not GameClock.est_nuit:
			continue
		var d: float = dahalo.global_position.distance_to(z.global_position)
		if not sauvage and not au_paturage:
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
