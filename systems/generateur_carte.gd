class_name GenerateurCarte
extends RefCounted
## Carte aléatoire à graine, façon « random map » d'Age of Empires (GDD §8).
## Équité : la carte est SYMÉTRIQUE PAR RAPPORT AU CENTRE. Tout ce qui est placé en p l'est aussi en -p,
## et la base de l'IA est l'image de celle du joueur. La même graine redonne exactement la même carte
## (indispensable pour le multijoueur en lockstep et pour rejouer une partie de test).
## Ne crée rien : renvoie une description (Dictionary) que main.gd transforme en entités.
## Spec : docs/specs/carte.md

const PAS_RIVIERE := 4.0
const MARGE_BORD := 8.0
const ESSAIS := 80

var _hasard := RandomNumberGenerator.new()
var _occupes: Array = []      # [Vector2 centre, rayon] : emplacements déjà pris
var _bases: Array = []        # Vector2 des deux bases
var _riviere := PackedVector2Array()


## Description renvoyée :
##  graine, riviere (PackedVector2Array),
##  reperes : faction -> {base, avant, droite} (Vector3 ; avant = vers le centre de la carte),
##  arbres, points_eau, raketa, baobabs : Array de Vector3,
##  troupeaux : Array de [Vector3 centre, int nombre], migrations : Array de Vector3,
##  zones_test : Array de Vector3 (emplacements libres pour les duels du test de fumée).
func generer(graine: int) -> Dictionary:
	_hasard.seed = graine
	_occupes.clear()
	var carte := {"graine": graine, "arbres": [], "points_eau": [], "raketa": [], "baobabs": [],
			"troupeaux": [], "migrations": [], "zones_test": [], "reperes": {}}

	# Bases face à face, à un angle tiré au hasard.
	var angle := _hasard.randf() * TAU
	var axe := Vector2(cos(angle), sin(angle))       # du centre vers la base du joueur
	var travers := Vector2(-axe.y, axe.x)
	var base := axe * GameRules.CARTE_DISTANCE_BASES
	_bases = [base, -base]
	carte["reperes"][GameRules.PLAYER] = {"base": _v3(base), "avant": _v3(-axe), "droite": _v3(travers)}
	carte["reperes"][GameRules.AI] = {"base": _v3(-base), "avant": _v3(axe), "droite": _v3(-travers)}
	_occuper_paire(base, GameRules.CARTE_RAYON_BASE_LIBRE * 0.6)

	# Lit de rivière : il traverse toute la carte entre les deux bases. Fonction impaire = symétrique.
	var a1 := _hasard.randf_range(8.0, 16.0)
	var k1 := TAU / _hasard.randf_range(90.0, 140.0)
	var a2 := _hasard.randf_range(2.0, 6.0)
	var k2 := TAU / _hasard.randf_range(30.0, 50.0)
	_riviere = PackedVector2Array()
	var t := -400.0
	while t <= 400.0:
		_riviere.append(travers * t + axe * (a1 * sin(k1 * t) + a2 * sin(k2 * t)))
		t += PAS_RIVIERE
	carte["riviere"] = _riviere

	_kit_de_base(carte, axe, travers)

	# Duels du test de fumée : zones vides, loin des bases et de la rivière.
	for p in [travers * 70.0 + axe * 38.0, travers * -70.0 + axe * 38.0, travers * 25.0 + axe * 40.0]:
		_occuper_paire(p, 9.0)
		carte["zones_test"].append(_v3(p))

	# Trous d'eau creusés dans le sable du lit (pratique réelle dans l'Androy).
	for k in GameRules.RIVIERE_TROUS_EAU:
		for essai in ESSAIS:
			var s := _hasard.randf_range(20.0, 60.0)
			var p := travers * s + axe * (a1 * sin(k1 * s) + a2 * sin(k2 * s))
			if _dans_la_carte(p, 3.0) and _libre(p, 2.5):
				_occuper_paire(p, 2.5)
				_ajouter_paire(carte["points_eau"], p)
				break

	# Troupeaux sauvages : un au centre (dans le lit), puis une paire symétrique.
	var depart: Array = GameRules.ZEBUS_SAUVAGES_DEPART
	carte["troupeaux"].append([Vector3.ZERO, int(depart[0])])
	_occuper(Vector2.ZERO, 6.0)
	var p_troupeau := _placer_paire(6.0, 45.0, 6.0)
	if p_troupeau != Vector2.INF:
		carte["troupeaux"].append([_v3(p_troupeau), int(depart[1])])
		carte["troupeaux"].append([_v3(-p_troupeau), int(depart[1])])

	# Bosquets d'épineux neutres.
	for k in GameRules.CARTE_PAIRES_FORETS:
		var nombre := _hasard.randi_range(GameRules.CARTE_ARBRES_PAR_FORET.x, GameRules.CARTE_ARBRES_PAR_FORET.y)
		var rayon := 3.0 + nombre * 0.3
		var centre := _placer_paire(rayon, GameRules.CARTE_RAYON_BASE_LIBRE, 3.0)
		if centre != Vector2.INF:
			for arbre in _bosquet(centre, nombre, rayon):
				_ajouter_paire(carte["arbres"], arbre)

	for k in GameRules.CARTE_PAIRES_RAKETA:
		var p := _placer_paire(1.5, 22.0, 3.0)
		if p != Vector2.INF:
			_ajouter_paire(carte["raketa"], p)

	for k in GameRules.CARTE_PAIRES_BAOBABS:
		var p := _placer_paire(2.5, 25.0, 4.0)
		if p != Vector2.INF:
			_ajouter_paire(carte["baobabs"], p)

	# Points d'arrivée des migrations : le centre et des paires symétriques (lieux non réservés).
	carte["migrations"].append(Vector3.ZERO)
	for k in GameRules.CARTE_PAIRES_MIGRATION:
		for essai in ESSAIS:
			var p := _point_au_hasard(6.0)
			if _loin_des_bases(p, 45.0) and Terrain.distance_trace(p, _riviere) > 6.0:
				_ajouter_paire(carte["migrations"], p)
				break
	return carte


## Ressources propres à chaque base (bosquet, point d'eau, raketa), placées dans le repère de la base :
## même disposition pour les deux clans, à l'image l'une de l'autre.
func _kit_de_base(carte: Dictionary, axe: Vector2, travers: Vector2) -> void:
	var base: Vector2 = _bases[0]
	var avant := -axe
	var gauche := -travers
	var arriere := axe
	var foret := base + gauche * 15.0 + avant * 3.0
	for arbre in _bosquet(foret, 10, 6.0):
		_ajouter_paire(carte["arbres"], arbre)
	_occuper_paire(foret, 7.0)
	var eau := base + avant * 14.0 + travers * 4.0
	_ajouter_paire(carte["points_eau"], eau)
	_occuper_paire(eau, 3.0)
	for p in [base + gauche * 10.0 + arriere * 7.0, base + gauche * 13.0 + arriere * 11.0]:
		_ajouter_paire(carte["raketa"], p)
		_occuper_paire(p, 1.5)


## Arbres d'un bosquet, répartis en anneaux autour du centre (coordonnées monde).
func _bosquet(centre: Vector2, nombre: int, rayon: float) -> Array:
	var arbres: Array = []
	for i in nombre:
		var a := TAU * i / float(nombre) + _hasard.randf_range(-0.3, 0.3)
		var d := rayon * (0.3 + 0.7 * float(i % 3) / 2.0) * _hasard.randf_range(0.8, 1.0)
		arbres.append(centre + Vector2(cos(a), sin(a)) * d)
	return arbres


## Trouve p tel que p et -p soient libres ; les réserve. Vector2.INF si rien trouvé.
func _placer_paire(rayon: float, distance_bases: float, distance_riviere: float) -> Vector2:
	for essai in ESSAIS:
		var p := _point_au_hasard(rayon + MARGE_BORD)
		if p.length() < rayon + 4.0:
			continue  # p et -p se chevaucheraient
		if not _loin_des_bases(p, distance_bases + rayon):
			continue
		if Terrain.distance_trace(p, _riviere) < GameRules.RIVIERE_LARGEUR * 0.5 + distance_riviere + rayon:
			continue
		if _libre(p, rayon):
			_occuper_paire(p, rayon)
			return p
	return Vector2.INF


func _point_au_hasard(marge: float) -> Vector2:
	var limite := GameRules.DEMI_CARTE - marge
	return Vector2(_hasard.randf_range(-limite, limite), _hasard.randf_range(-limite, limite))


func _dans_la_carte(p: Vector2, marge: float) -> bool:
	var limite := GameRules.DEMI_CARTE - MARGE_BORD - marge
	return absf(p.x) <= limite and absf(p.y) <= limite


func _loin_des_bases(p: Vector2, distance: float) -> bool:
	for b in _bases:
		if p.distance_to(b) < distance or (-p).distance_to(b) < distance:
			return false
	return true


## Vrai si p ET -p sont libres.
func _libre(p: Vector2, rayon: float) -> bool:
	for o in _occupes:
		var c: Vector2 = o[0]
		var r: float = o[1]
		if p.distance_to(c) < rayon + r + 3.0 or (-p).distance_to(c) < rayon + r + 3.0:
			return false
	return true


func _occuper(p: Vector2, rayon: float) -> void:
	_occupes.append([p, rayon])


func _occuper_paire(p: Vector2, rayon: float) -> void:
	_occuper(p, rayon)
	_occuper(-p, rayon)


func _ajouter_paire(liste: Array, p: Vector2) -> void:
	liste.append(_v3(p))
	liste.append(_v3(-p))


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)
