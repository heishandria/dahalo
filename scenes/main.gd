extends Node3D
## Scène principale : génère la carte de test, crée les entités, gère jour/nuit visuel.
## Carte fixe et symétrique pour le prototype ; la génération procédurale (GDD §8) viendra ensuite.

const SCENE_UNITE := preload("res://scenes/units/unite.tscn")
const SCENE_ZEBU := preload("res://scenes/units/zebu.tscn")
const SCENE_RESSOURCE := preload("res://scenes/world/noeud_ressource.tscn")
const SCENES_BATIMENTS := {
	"case_centrale": preload("res://scenes/buildings/case_centrale.tscn"),
	"enclos": preload("res://scenes/buildings/enclos.tscn"),
}
const DONNEES_UNITES := {
	"villageois": preload("res://data/units/villageois.tres"),
	"pisteur": preload("res://data/units/pisteur.tres"),
	"dahalo": preload("res://data/units/dahalo.tres"),
}
const LIMITE_CARTE := 56.0

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


func creer_batiment(type_batiment: String, faction: int, pos: Vector3) -> Batiment:
	var b: Batiment = SCENES_BATIMENTS[type_batiment].instantiate()
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


func creer_ressource(type_ressource: String, pos: Vector3, quantite: float, infini := false) -> NoeudRessource:
	var r: NoeudRessource = SCENE_RESSOURCE.instantiate()
	r.type_ressource = type_ressource
	r.quantite = quantite
	r.infini = infini
	r.position = _borner(pos)
	entites.add_child(r)
	return r


func construire(faction: int, type_batiment: String, pos: Vector3) -> void:
	if type_batiment != "enclos":
		return
	if not ResourceManager.payer(faction, GameRules.COUT_ENCLOS):
		if faction == GameRules.PLAYER:
			EventBus.message.emit("Pas assez de bois pour un enclos (%d)." % int(GameRules.COUT_ENCLOS["bois"]))
		return
	creer_batiment("enclos", faction, pos)
	if faction == GameRules.PLAYER:
		EventBus.message.emit("Nouvel enclos construit : +%d places." % GameRules.CAPACITE_PAR_ENCLOS)


# --- Carte de test symétrique ---

func _generer_carte() -> void:
	for f in [GameRules.PLAYER, GameRules.AI]:
		# Joueur au sud-ouest, IA au nord-est : positions miroir pour l'équité.
		var s := 1.0 if f == GameRules.PLAYER else -1.0
		var base := Vector3(-35.0, 0.0, 35.0) * s
		creer_batiment("case_centrale", f, base)
		creer_batiment("enclos", f, base + Vector3(10.0, 0.0, 0.0) * s)
		for i in 3:
			creer_unite("villageois", f, base + Vector3(-2.0 + i * 2.0, 0.0, -4.0) * s)
		creer_unite("dahalo", f, base + Vector3(4.0, 0.0, -5.0) * s)
		creer_unite("pisteur", f, base + Vector3(-4.0, 0.0, -5.0) * s)

		for p in [Vector3(-10, 0, -6), Vector3(-13, 0, -2), Vector3(-9, 0, -11), Vector3(-14, 0, -9)]:
			creer_ressource("bois", base + p * s, 250.0)
		creer_ressource("eau", base + Vector3(2.0, 0.0, -13.0) * s, 0.0, true)
		for p in [Vector3(4, 0, 10), Vector3(8, 0, 9)]:
			creer_ressource("nourriture", base + p * s, 200.0)

	# Ressources disputées au centre.
	creer_ressource("eau", Vector3(9.0, 0.0, -9.0), 0.0, true)
	creer_ressource("eau", Vector3(-9.0, 0.0, 9.0), 0.0, true)
	for p in [Vector3(0, 0, 16), Vector3(4, 0, 19), Vector3(0, 0, -16), Vector3(-4, 0, -19)]:
		creer_ressource("bois", p, 400.0)

	# Troupeaux sauvages, à égale distance des deux bases.
	_troupeau(Vector3.ZERO, 8)
	_troupeau(Vector3(-30.0, 0.0, -30.0), 6)
	_troupeau(Vector3(30.0, 0.0, 30.0), 6)


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
	soleil.light_energy = lerpf(0.08, 1.3, lum)
	soleil.light_color = Color(0.5, 0.58, 0.95).lerp(Color(1.0, 0.92, 0.78), lum)
	environnement.environment.ambient_light_energy = lerpf(0.15, 0.7, lum)
	environnement.environment.background_energy_multiplier = lerpf(0.1, 1.0, lum)


func _on_meteo(secheresse: bool) -> void:
	var m := sol.material_override as StandardMaterial3D
	if m:
		m.albedo_color = COULEUR_SOL_SECHERESSE if secheresse else COULEUR_SOL
