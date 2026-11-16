extends Node3D
## Scène principale : génère la carte de test, crée les entités, gère jour/nuit visuel.
## Carte fixe et symétrique pour le prototype ; la génération procédurale (GDD §8) viendra ensuite.

const SCENE_UNITE := preload("res://scenes/units/unite.tscn")
const SCENE_ZEBU := preload("res://scenes/units/zebu.tscn")
const SCENE_RESSOURCE := preload("res://scenes/world/noeud_ressource.tscn")
const SCENES_BATIMENTS := {
	"case_centrale": preload("res://scenes/buildings/case_centrale.tscn"),
	"enclos": preload("res://scenes/buildings/enclos.tscn"),
	"camp_bois": preload("res://scenes/buildings/camp_bois.tscn"),
	"tsena": preload("res://scenes/buildings/tsena.tscn"),
	"champ": preload("res://scenes/world/champ.tscn"),
	"puits": preload("res://scenes/world/puits.tscn"),
}
const DONNEES_UNITES := {
	"villageois": preload("res://data/units/villageois.tres"),
	"pisteur": preload("res://data/units/pisteur.tres"),
	"dahalo": preload("res://data/units/dahalo.tres"),
}
const LIMITE_CARTE := 56.0

# Nuit : clair de lune lisible (assez sombre pour sentir la nuit, assez clair pour jouer).
const SOLEIL_NUIT := 0.4
const AMBIANCE_NUIT := 0.45
const CIEL_NUIT := 0.35
const COULEUR_LUNE := Color(0.6, 0.68, 1.0)

const COULEUR_SOL := Color(0.72, 0.36, 0.2)
const COULEUR_SOL_SECHERESSE := Color(0.82, 0.5, 0.3)

@onready var entites: Node3D = $Entites
@onready var navigation: NavigationRegion3D = $NavigationRegion3D
@onready var sol: MeshInstance3D = $NavigationRegion3D/Sol
@onready var soleil: DirectionalLight3D = $Soleil
@onready var environnement: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	GameClock.reinitialiser()
	CommandBus.reinitialiser()
	CommandBus.monde = self
	ResourceManager.initialiser([GameRules.PLAYER, GameRules.AI])
	EventBus.meteo_change.connect(_on_meteo)

	# Navmesh cuit au lancement à partir du sol (obstacles ajoutés plus tard).
	navigation.bake_navigation_mesh(false)
	_generer_carte()


func _process(_delta: float) -> void:
	_maj_lumiere()


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
func creer_batiment(type_batiment: String, faction: int, pos: Vector3) -> Node3D:
	var b: Node3D = SCENES_BATIMENTS[type_batiment].instantiate()
	b.faction = faction
	b.position = _borner(pos)
	entites.add_child(b)
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
	entites.add_child(r)
	return r


func construire(faction: int, type_batiment: String, pos: Vector3) -> void:
	if not GameRules.COUTS_BATIMENTS.has(type_batiment):
		return
	var nom: String = GameRules.NOMS_BATIMENTS.get(type_batiment, type_batiment)
	if type_batiment == "tsena" and _possede(faction, "tsena"):
		if faction == GameRules.PLAYER:
			EventBus.message.emit("Votre clan a déjà un Tsena.")
		return
	var cout: Dictionary = GameRules.COUTS_BATIMENTS[type_batiment]
	if not ResourceManager.payer(faction, cout):
		if faction == GameRules.PLAYER:
			EventBus.message.emit("%s : il faut %s." % [nom, ResourceManager.texte_cout(cout)])
		return
	creer_batiment(type_batiment, faction, pos)
	if faction == GameRules.PLAYER:
		EventBus.message.emit("%s construit." % nom)


func _possede(faction: int, type_batiment: String) -> bool:
	for b in get_tree().get_nodes_in_group(type_batiment):
		if b.faction == faction:
			return true
	return false


# --- Carte de test symétrique ---

func _generer_carte() -> void:
	for f in [GameRules.PLAYER, GameRules.AI]:
		# Joueur au sud-ouest, IA au nord-est : positions miroir pour l'équité.
		var s := 1.0 if f == GameRules.PLAYER else -1.0
		var base := Vector3(-35.0, 0.0, 35.0) * s
		creer_batiment("case_centrale", f, base)
		creer_batiment("enclos", f, base + Vector3(10.0, 0.0, 0.0) * s)
		for p in [Vector3(-2, 0, 9), Vector3(5, 0, 9)]:
			creer_champ_mur(f, base + p * s)
		for i in 3:
			creer_unite("villageois", f, base + Vector3(-2.0 + i * 2.0, 0.0, -4.0) * s)
		creer_unite("dahalo", f, base + Vector3(4.0, 0.0, -5.0) * s)
		creer_unite("pisteur", f, base + Vector3(-4.0, 0.0, -5.0) * s)

		_foret(base + Vector3(-13.0, 0.0, -8.0) * s, 9)
		creer_ressource("point_eau", base + Vector3(3.0, 0.0, -13.0) * s)
		for p in [Vector3(-10, 0, 6), Vector3(-12, 0, 10)]:
			creer_ressource("raketa", base + p * s)

	# Ressources disputées au centre.
	creer_ressource("point_eau", Vector3(9.0, 0.0, -9.0))
	creer_ressource("point_eau", Vector3(-9.0, 0.0, 9.0))
	_foret(Vector3(2.0, 0.0, 17.0), 10)
	_foret(Vector3(-2.0, 0.0, -17.0), 10)
	for p in [Vector3(14, 0, 4), Vector3(-14, 0, -4)]:
		creer_ressource("raketa", p)

	# Baobabs : décor et repères (on ne les coupe pas).
	for p in [Vector3(-20, 0, 20), Vector3(20, 0, -20), Vector3(-45, 0, 5), Vector3(45, 0, -5),
			Vector3(-5, 0, 45), Vector3(5, 0, -45), Vector3(25, 0, 25), Vector3(-25, 0, -25)]:
		_baobab(p)

	# Troupeaux sauvages, à égale distance des deux bases.
	_troupeau(Vector3.ZERO, 8)
	_troupeau(Vector3(-30.0, 0.0, -30.0), 6)
	_troupeau(Vector3(30.0, 0.0, 30.0), 6)


func creer_champ_mur(faction: int, pos: Vector3) -> Node3D:
	var champ = SCENES_BATIMENTS["champ"].instantiate()
	champ.faction = faction
	champ.croissance = 1.0
	champ.position = _borner(pos)
	entites.add_child(champ)
	return champ


func _foret(centre: Vector3, nombre: int) -> void:
	for i in nombre:
		var a := TAU * i / float(nombre) + randf_range(-0.3, 0.3)
		var d := 2.0 + (i % 3) * 2.2
		creer_ressource("epineux", centre + Vector3(cos(a), 0.0, sin(a)) * d)


func _baobab(pos: Vector3) -> void:
	var arbre := Node3D.new()
	var tronc := MeshInstance3D.new()
	var m_tronc := CylinderMesh.new()
	m_tronc.top_radius = 0.7
	m_tronc.bottom_radius = 1.2
	m_tronc.height = 6.0
	var mat_tronc := StandardMaterial3D.new()
	mat_tronc.albedo_color = Color(0.55, 0.45, 0.38)
	m_tronc.material = mat_tronc
	tronc.mesh = m_tronc
	tronc.position.y = 3.0
	arbre.add_child(tronc)
	var couronne := MeshInstance3D.new()
	var m_couronne := SphereMesh.new()
	m_couronne.radius = 2.0
	m_couronne.height = 1.2
	var mat_couronne := StandardMaterial3D.new()
	mat_couronne.albedo_color = Color(0.32, 0.38, 0.2)
	m_couronne.material = mat_couronne
	couronne.mesh = m_couronne
	couronne.position.y = 6.3
	arbre.add_child(couronne)
	arbre.position = _borner(pos)
	entites.add_child(arbre)


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
	soleil.light_energy = lerpf(SOLEIL_NUIT, 1.3, lum)
	soleil.light_color = COULEUR_LUNE.lerp(Color(1.0, 0.92, 0.78), lum)
	environnement.environment.ambient_light_energy = lerpf(AMBIANCE_NUIT, 0.7, lum)
	environnement.environment.background_energy_multiplier = lerpf(CIEL_NUIT, 1.0, lum)


func _on_meteo(secheresse: bool) -> void:
	var m := sol.material_override as StandardMaterial3D
	if m:
		m.albedo_color = COULEUR_SOL_SECHERESSE if secheresse else COULEUR_SOL
