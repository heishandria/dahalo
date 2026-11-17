extends Node3D
## Scène principale : génère la carte (GenerateurCarte, à graine), crée les entités, gère jour/nuit visuel.
## Graine : tirée au hasard, ou imposée par `-- --graine=N` (rejouer exactement la même carte).

const SCENE_UNITE := preload("res://scenes/units/unite.tscn")
const SCENE_ZEBU := preload("res://scenes/units/zebu.tscn")
const SCENE_RESSOURCE := preload("res://scenes/world/noeud_ressource.tscn")
const SCENES_BATIMENTS := {
	"case_centrale": preload("res://scenes/buildings/case_centrale.tscn"),
	"enclos": preload("res://scenes/buildings/enclos.tscn"),
	"camp_bois": preload("res://scenes/buildings/camp_bois.tscn"),
	"tsena": preload("res://scenes/buildings/tsena.tscn"),
	"case_hommes": preload("res://scenes/buildings/case_hommes.tscn"),
	"palissade": preload("res://scenes/buildings/palissade.tscn"),
	"champ": preload("res://scenes/world/champ.tscn"),
	"puits": preload("res://scenes/world/puits.tscn"),
}
const DONNEES_UNITES := {
	"villageois": preload("res://data/units/villageois.tres"),
	"pisteur": preload("res://data/units/pisteur.tres"),
	"dahalo": preload("res://data/units/dahalo.tres"),
	"lanceur": preload("res://data/units/lanceur.tres"),
	"tireur": preload("res://data/units/tireur.tres"),
}
const LIMITE_CARTE := GameRules.DEMI_CARTE - 4.0
# Bâtiments que les unités contournent (navmesh recalculé à leur construction)
const BATIMENTS_OBSTACLES := ["case_centrale", "case_hommes", "camp_bois", "tsena", "puits", "enclos"]

var _recuisson_demandee := false
var carte := {}   # description de la carte générée (voir GenerateurCarte.generer)
var _test_accelere := false
var _prochain_rapport := 300.0

# Nuit : clair de lune lisible (assez sombre pour sentir la nuit, assez clair pour jouer).
const LUMIERE_JOUR := 1.75   # soleil franc : ombres et relief marqués
const AMBIANCE_JOUR := 0.42  # ambiance basse le jour : contraste ombre / lumière
const SOLEIL_NUIT := 0.45
const AMBIANCE_NUIT := 0.35
const CIEL_NUIT := 0.4
const COULEUR_LUNE := Color(0.8, 0.83, 0.95)   # clair de lune presque neutre (moins bleu)
# Lumière ambiante : couleur fixe (le bleu du ciel désaturait le sol) ; chaude le jour, bleutée la nuit.
const AMBIANCE_JOUR_COULEUR := Color(0.86, 0.78, 0.68)
const AMBIANCE_NUIT_COULEUR := Color(0.62, 0.66, 0.82)

@onready var entites: Node3D = $Entites
@onready var navigation: NavigationRegion3D = $NavigationRegion3D
@onready var soleil: DirectionalLight3D = $Soleil
@onready var environnement: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	GameClock.reinitialiser()
	CommandBus.reinitialiser()
	CommandBus.monde = self
	ResourceManager.initialiser([GameRules.PLAYER, GameRules.AI])
	# Test de fumée (CI) : `godot --headless -- --accelerer` joue une partie en accéléré.
	if "--accelerer" in OS.get_cmdline_user_args():
		accelerer(8.0)
		_test_accelere = true
		print("[test] partie accélérée x8")
		EventBus.partie_terminee.connect(_fin_du_test)
		_lancer_duels.call_deferred()
	# Captures d'écran (CI) : `godot --path . -- --captures=<dossier>` (voir systems/captures.gd).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures"):
			var captures := preload("res://systems/captures.gd").new()
			captures.name = "Captures"
			add_child(captures)
	EventBus.cycle_change.connect(_on_cycle)

	_regler_resolution()
	EventBus.meteo_change.connect(func(secheresse: bool) -> void: Plantes.saison(self, secheresse))
	_generer_carte(_graine())
	# Navmesh cuit APRÈS la carte : il contourne bâtiments, points d'eau, baobabs et clôtures.
	navigation.bake_navigation_mesh(false)
	Vision.initialiser([GameRules.PLAYER, GameRules.AI])
	var brouillard := preload("res://systems/brouillard.gd").new()
	brouillard.name = "Brouillard"
	add_child(brouillard)
	$Vegetation.construire(brouillard.texture_vision())   # après les entités : rien ne pousse dessous
	$Paysage.brancher_vegetation($Vegetation.texture_densite())
	$Paysage.brancher_vision(brouillard.texture_vision())


func _process(_delta: float) -> void:
	if _test_accelere and GameClock.temps_ecoule >= _prochain_rapport:
		_prochain_rapport += 300.0
		_rapport_test()
	_maj_lumiere()


## Accélère le temps de jeu (tests, captures) SANS allonger le pas physique : sinon une unité rapide
## avance de plus d'un mètre par pas, dépasse les points de son chemin et oscille sur place.
static func accelerer(facteur: float) -> void:
	Engine.time_scale = facteur
	Engine.physics_ticks_per_second = int(60.0 * maxf(facteur, 1.0))
	Engine.max_physics_steps_per_frame = int(8.0 * maxf(facteur, 1.0))


# --- Création d'entités (appelées aussi par CommandBus / bâtiments) ---

func donnees_unite(role: String) -> UnitData:
	return DONNEES_UNITES.get(role)


func creer_unite(role: String, faction: int, pos: Vector3) -> Unite:
	var u: Unite = SCENE_UNITE.instantiate()
	u.data = DONNEES_UNITES[role]
	u.faction = faction
	u.position = _borner(pos)
	entites.add_child(u)
	EventBus.unite_creee.emit(u)
	return u


## Crée un bâtiment (Batiment) ou une source construite (champ, puits : NoeudRessource).
func creer_batiment(type_batiment: String, faction: int, pos: Vector3, rotation_y: float = NAN) -> Node3D:
	var b: Node3D = SCENES_BATIMENTS[type_batiment].instantiate()
	b.faction = faction
	b.position = _borner(pos)
	if type_batiment == "palissade":
		b.rotation.y = orientation_palissade(faction, b.position) if is_nan(rotation_y) else rotation_y
	if type_batiment in BATIMENTS_OBSTACLES:
		demander_recuisson()
	entites.add_child(b)
	EventBus.batiment_cree.emit(b)
	return b


func creer_zebu(pos: Vector3, centre: Vector3) -> Zebu:
	var z: Zebu = SCENE_ZEBU.instantiate()
	z.position = _borner(pos)
	z.centre_errance = centre
	entites.add_child(z)
	return z


func creer_ressource(variante: String, pos: Vector3) -> NoeudRessource:
	var r: NoeudRessource = SCENE_RESSOURCE.instantiate()
	r.variante = variante
	match variante:
		"epineux":
			r.quantite = GameRules.ARBRE_BOIS
			r.repousse_s = GameRules.ARBRE_REPOUSSE_S
		"point_eau":
			r.infini = true
			r.rendement_secheresse = GameRules.POINT_EAU_SECHERESSE
		"raketa":
			r.infini = true
			r.rendement = GameRules.RAKETA_RENDEMENT
			r.bonus_eau = GameRules.RAKETA_BONUS_EAU
	r.position = _borner(pos)
	r.position.y = Terrain.hauteur_sol(r.position)   # trous d'eau : au fond du lit
	entites.add_child(r)
	return r


func construire(faction: int, type_batiment: String, pos: Vector3, rotation_y: float = NAN) -> void:
	if not GameRules.COUTS_BATIMENTS.has(type_batiment):
		return
	var nom: String = GameRules.NOMS_BATIMENTS.get(type_batiment, type_batiment)
	if type_batiment == "tsena" and possede(faction, "tsena"):
		if faction == GameRules.PLAYER:
			EventBus.message.emit("Votre clan a déjà un Tsena.")
		return
	var raison := raison_emplacement_invalide(faction, type_batiment, pos)
	# L'IA se décale toute seule, sauf pour une palissade (un segment déplacé ne fermerait rien).
	if raison != "" and faction != GameRules.PLAYER and type_batiment != "palissade":
		pos = _chercher_emplacement(faction, type_batiment, pos)
		raison = "" if pos != Vector3.INF else "aucun emplacement libre"
	if raison != "":
		if faction == GameRules.PLAYER:
			EventBus.message.emit("%s : %s." % [nom, raison])
		return
	var cout: Dictionary = GameRules.COUTS_BATIMENTS[type_batiment]
	if not ResourceManager.payer(faction, cout):
		if faction == GameRules.PLAYER:
			EventBus.message.emit("%s : il faut %s." % [nom, ResourceManager.texte_cout(cout)])
		return
	creer_batiment(type_batiment, faction, pos, rotation_y)
	if faction == GameRules.PLAYER:
		if type_batiment == "palissade":
			pass  # pas de message à chaque segment
		elif type_batiment == "champ":
			EventBus.message.emit("Champ construit : envoyez des villageois pour le cultiver.")
		else:
			EventBus.message.emit("%s construit." % nom)


## Orientée face à l'extérieur du village : perpendiculaire à la direction depuis la Case centrale.
func orientation_palissade(faction: int, pos: Vector3) -> float:
	for c in get_tree().get_nodes_in_group("case_centrale"):
		if c.faction == faction:
			var dir: Vector3 = pos - c.global_position
			return atan2(dir.x, dir.z)
	return 0.0


## "" si l'emplacement est valide, sinon la raison (affichée au joueur).
func raison_emplacement_invalide(faction: int, type_batiment: String, pos: Vector3) -> String:
	var r := _rayon_type(type_batiment)
	if absf(pos.x) > LIMITE_CARTE - r or absf(pos.z) > LIMITE_CARTE - r:
		return "trop près du bord de la carte"
	if not Vision.est_explore(faction, pos):
		return "zone inexplorée"
	if Terrain.sur_colline(pos, r):
		return "on ne construit pas sur une colline"
	if Terrain.distance_riviere(pos) < GameRules.RIVIERE_LARGEUR * 0.5 + r:
		return "on ne construit pas dans le lit de la rivière"
	for groupe in ["batiments", "ressources", "decor"]:
		for n in get_tree().get_nodes_in_group(groupe):
			if not is_instance_valid(n) or n.is_queued_for_deletion():
				continue
			if type_batiment == "palissade" and n.get("type_batiment") == "palissade":
				continue  # les segments de palissade peuvent se toucher
			if pos.distance_to(n.global_position) < (r + _rayon_noeud(n)) * 0.85:
				return "emplacement occupé"
	return ""


func _rayon_type(type_batiment: String) -> float:
	if type_batiment == "palissade":
		return 1.0
	var e: Vector2 = GameRules.EMPRISES.get(type_batiment, Vector2(3, 3))
	return maxf(e.x, e.y) * 0.5


func _rayon_noeud(n: Node) -> float:
	var t = n.get("type_batiment")
	if t is String and t != "":
		return _rayon_type(t)
	if n is NoeudRessource:
		return float(GameRules.RAYONS_SOURCES.get(n.type_ressource, 1.5))
	return 2.0  # décor (baobab)


## Cherche un emplacement libre en spirale autour de pos (IA). Vector3.INF si rien trouvé.
func _chercher_emplacement(faction: int, type_batiment: String, pos: Vector3) -> Vector3:
	for anneau in range(1, 5):
		for k in 8:
			var a := TAU * k / 8.0
			var essai := pos + Vector3(cos(a), 0.0, sin(a)) * anneau * 4.0
			if raison_emplacement_invalide(faction, type_batiment, essai) == "":
				return essai
	return Vector3.INF


## Recalcule le navmesh (regroupé : une seule fois même si plusieurs bâtiments arrivent d'un coup).
func demander_recuisson() -> void:
	if _recuisson_demandee or not is_inside_tree():
		return
	_recuisson_demandee = true
	await get_tree().create_timer(0.3).timeout
	while navigation.is_baking():
		await get_tree().create_timer(0.2).timeout
	_recuisson_demandee = false
	navigation.bake_navigation_mesh(true)


func possede(faction: int, type_batiment: String) -> bool:
	for b in get_tree().get_nodes_in_group(type_batiment):
		if b.faction == faction:
			return true
	return false


## Écrans haute densité (Retina) en Forward+ : la 3D est calculée à 67 % de la résolution puis agrandie
## (FSR), l'interface reste nette. Sans cela, le shader du sol tourne sur plus de 6 millions de pixels.
func _regler_resolution() -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return
	if DisplayServer.screen_get_scale() >= 1.5:
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		get_viewport().scaling_3d_scale = 0.67


# --- Carte aléatoire (spec : docs/specs/carte.md) ---

func _graine() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--graine="):
			return int(arg.trim_prefix("--graine="))
	var hasard := RandomNumberGenerator.new()
	hasard.randomize()
	return hasard.randi_range(1, 999999)


func _generer_carte(graine: int) -> void:
	carte = GenerateurCarte.new().generer(graine)
	Terrain.initialiser(graine, carte["riviere"])
	Terrain.initialiser_collines(carte["plateaux"])
	print("[carte] graine %d" % graine)
	$Paysage.construire()   # sol de la zone de jeu, plateaux, relief et décor (visuel)
	_creer_plateaux_physiques()

	# Bases : même disposition dans le repère de chaque base (avant = vers le centre de la carte).
	for f in [GameRules.PLAYER, GameRules.AI]:
		var repere: Dictionary = carte["reperes"][f]
		var base: Vector3 = repere["base"]
		var avant: Vector3 = repere["avant"]
		var droite: Vector3 = repere["droite"]
		creer_batiment("case_centrale", f, base)
		creer_batiment("enclos", f, base + droite * 10.0)
		for p in [-avant * 9.0 - droite * 2.0, -avant * 9.0 + droite * 5.0]:
			creer_champ_mur(f, base + p)
		for i in 3:
			creer_unite("villageois", f, base + avant * 4.0 + droite * (-2.0 + i * 2.0))
		creer_unite("dahalo", f, base + avant * 5.0 + droite * 4.0)
		creer_unite("pisteur", f, base + avant * 5.0 - droite * 4.0)
	if has_node("CameraRig"):
		$CameraRig.centrer_sur(carte["reperes"][GameRules.PLAYER]["base"])

	for p in carte["arbres"]:
		creer_ressource("epineux", p)
	for p in carte["points_eau"]:
		creer_ressource("point_eau", p)
	for p in carte["raketa"]:
		creer_ressource("raketa", p)
	# Baobabs : décor et repères (on ne les coupe pas).
	for p in carte["baobabs"]:
		_baobab(p)
	for t in carte["troupeaux"]:
		_troupeau(t[0], t[1])


## Collines : là où elles dépassent COLLINES_INFRANCHISSABLE, obstacle (calque 4 : navmesh + collisions).
## Une boîte par suite de cases bloquées sur une même ligne de la grille, sous le visuel construit par Paysage.
func _creer_plateaux_physiques() -> void:
	var corps := StaticBody3D.new()
	corps.name = "Plateaux"
	corps.collision_layer = 8
	corps.collision_mask = 0
	var n := Terrain.N_RELIEF
	var case := Terrain.CASE_RELIEF
	var d := GameRules.DEMI_CARTE
	for j in n:
		var debut := -1
		for i in n + 1:
			var bloquee := i < n and Terrain.infranchissable(Vector3(-d + (i + 0.5) * case, 0.0, -d + (j + 0.5) * case))
			if bloquee and debut < 0:
				debut = i
			elif not bloquee and debut >= 0:
				var forme := CollisionShape3D.new()
				var boite := BoxShape3D.new()
				boite.size = Vector3((i - debut) * case, 3.0, case)
				forme.shape = boite
				forme.position = Vector3(-d + (debut + i) * 0.5 * case, 1.5,
						-d + (j + 0.5) * case)
				corps.add_child(forme)
				debut = -1
	entites.add_child(corps)


func creer_champ_mur(faction: int, pos: Vector3) -> Node3D:
	var champ = SCENES_BATIMENTS["champ"].instantiate()
	champ.faction = faction
	champ.croissance = 1.0
	champ.position = _borner(pos)
	entites.add_child(champ)
	EventBus.batiment_cree.emit(champ)
	return champ


func _baobab(pos: Vector3) -> void:
	var arbre := Node3D.new()
	var modele := MeshInstance3D.new()
	modele.mesh = Plantes.baobab(Plantes.variante_en(pos))
	modele.rotation.y = float(Plantes.variante_en(pos * 3.0)) * 2.1
	arbre.add_child(modele)
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 8   # contourné par le calcul de chemin
	obstacle.collision_mask = 0
	var forme := CollisionShape3D.new()
	var cylindre := CylinderShape3D.new()
	cylindre.radius = 1.2
	cylindre.height = 6.0
	forme.shape = cylindre
	forme.position.y = 3.0
	obstacle.add_child(forme)
	arbre.add_child(obstacle)
	arbre.position = _borner(pos)
	arbre.add_to_group("decor")
	entites.add_child(arbre)


# --- Migration : de nouveaux troupeaux sauvages arrivent à l'aube ---

func _on_cycle(est_nuit: bool) -> void:
	if est_nuit:
		return
	var periode := GameRules.CYCLES_ENTRE_SECHERESSES + GameRules.DUREE_SECHERESSE_CYCLES
	var jour := int(floor(GameClock.temps_ecoule / GameRules.DUREE_JOUR_S))
	if jour <= 0 or jour % periode >= GameRules.CYCLES_ENTRE_SECHERESSES:
		return  # pas d'arrivée le premier matin ni à l'aube d'une sécheresse
	var apres_secheresse := (jour - 1) % periode >= GameRules.CYCLES_ENTRE_SECHERESSES
	var nombre := GameRules.MIGRATION_PLUIES if apres_secheresse else GameRules.MIGRATION_NORMALE
	var sauvages := 0
	for z in get_tree().get_nodes_in_group("zebus"):
		if z.etat == Zebu.Etat.SAUVAGE:
			sauvages += 1
	nombre = mini(nombre, GameRules.ZEBUS_SAUVAGES_MAX - sauvages)
	if nombre <= 0:
		return
	var points: Array = carte["migrations"]
	_troupeau(points[randi() % points.size()], nombre)
	# Le lieu n'est pas révélé : c'est le travail des Pisteurs.
	if apres_secheresse:
		EventBus.message.emit("Les pluies ramènent un grand troupeau sauvage dans la brousse. Envoyez vos Pisteurs !")
	else:
		EventBus.message.emit("Un troupeau sauvage a été aperçu dans la brousse.")


# --- Test de fumée : rapports chiffrés lus par la CI ---

func _rapport_test() -> void:
	var sauvages := 0
	for z in get_tree().get_nodes_in_group("zebus"):
		if z.etat == Zebu.Etat.SAUVAGE:
			sauvages += 1
	var ia := GameRules.AI
	var palissades := 0
	for p in get_tree().get_nodes_in_group("palissade"):
		if p.faction == ia:
			palissades += 1
	print("[test] t=%d min | zebus joueur=%d IA=%d sauvages=%d | IA : age=%d, Ar=%d, unites=%d, batiments=%d, palissades=%d" % [
		int(GameClock.temps_ecoule / 60.0), ResourceManager.nb_zebus(GameRules.PLAYER), ResourceManager.nb_zebus(ia),
		sauvages, ResourceManager.age(ia), int(ResourceManager.quantite(ia, "ariary")),
		get_tree().get_nodes_in_group("unites_%d" % ia).size(),
		get_tree().get_nodes_in_group("batiments_%d" % ia).size() - palissades, palissades])
	# Diagnostic des raids : Dahalo de l'IA par état, zébus sauvages qu'elle a déjà repérés.
	var etats := {}
	for u in get_tree().get_nodes_in_group("unites_%d" % ia):
		if u.data.role == "pisteur":
			etats["pisteur " + String(Unite.Etat.keys()[u.etat])] = 1
		if u.data.role == "dahalo":
			var nom: String = Unite.Etat.keys()[u.etat]
			etats[nom] = int(etats.get(nom, 0)) + 1
	var reperes := 0
	for z in get_tree().get_nodes_in_group("zebus"):
		if z.etat == Zebu.Etat.SAUVAGE and Vision.est_explore(ia, z.global_position):
			reperes += 1
	print("[test]        IA : dahalo %s, zébus sauvages repérés %d" % [etats, reperes])


## Duels du triangle des guerriers, dans les zones vides réservées par le générateur, entre deux clans
## de test (2 et 3) que l'IA et le joueur ignorent. Le résultat est imprimé pour la CI.
const DUELS := [["lanceur", "dahalo"], ["tireur", "lanceur"], ["dahalo", "tireur"]]


func _lancer_duels() -> void:
	var duels: Array = []
	for k in DUELS.size():
		var d: Array = DUELS[k]
		var centre: Vector3 = carte["zones_test"][k]
		var a := creer_unite(d[0], 2, centre + Vector3(-5, 0, 0))
		var b := creer_unite(d[1], 3, centre + Vector3(5, 0, 0))
		duels.append([d[0], a, d[1], b])
	await get_tree().create_timer(40.0).timeout
	for d in duels:
		var a = d[1]
		var b = d[3]
		var a_vit: bool = is_instance_valid(a) and not a.mort
		var b_vit: bool = is_instance_valid(b) and not b.mort
		var vainqueur := "aucun"
		var pv := 0
		if a_vit and not b_vit:
			vainqueur = d[0]
			pv = int(a.pv)
		elif b_vit and not a_vit:
			vainqueur = d[2]
			pv = int(b.pv)
		elif a_vit and b_vit:
			vainqueur = "égalité (aucun mort)"
		print("[test] duel %s contre %s : vainqueur = %s, PV restants %d" % [d[0], d[2], vainqueur, pv])
		# Les survivants quittent la carte : ils ne doivent pas fausser la suite de la partie de test.
		for u in [a, b]:
			if is_instance_valid(u):
				u.queue_free()


func _fin_du_test(gagnant: int) -> void:
	_rapport_test()
	print("[test] fin de partie, gagnant=%d" % gagnant)
	get_tree().quit()


func _troupeau(centre: Vector3, nombre: int) -> void:
	for i in nombre:
		creer_zebu(centre + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0)), centre)


func _borner(pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, -LIMITE_CARTE, LIMITE_CARTE), 0.0, clampf(pos.z, -LIMITE_CARTE, LIMITE_CARTE))


# --- Ambiance : jour/nuit et sécheresse ---

func _maj_lumiere() -> void:
	var t := GameClock.phase_jour()
	var debut_nuit := 1.0 - GameRules.PART_NUIT
	var transition := 0.05
	var lum := 1.0
	if t >= debut_nuit - transition and t < debut_nuit + transition:
		lum = 1.0 - (t - (debut_nuit - transition)) / (2.0 * transition)   # crépuscule
	elif t >= debut_nuit + transition and t < 1.0 - transition:
		lum = 0.0                                                         # nuit
	elif t >= 1.0 - transition:
		lum = (t - (1.0 - transition)) / transition                       # aube
	soleil.light_energy = lerpf(SOLEIL_NUIT, LUMIERE_JOUR, lum)
	soleil.light_color = COULEUR_LUNE.lerp(Color(1.0, 0.92, 0.78), lum)
	environnement.environment.ambient_light_energy = lerpf(AMBIANCE_NUIT, AMBIANCE_JOUR, lum)
	environnement.environment.ambient_light_color = AMBIANCE_NUIT_COULEUR.lerp(AMBIANCE_JOUR_COULEUR, lum)
	environnement.environment.background_energy_multiplier = lerpf(CIEL_NUIT, 1.0, lum)
