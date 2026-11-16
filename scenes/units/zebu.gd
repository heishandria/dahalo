class_name Zebu
extends CharacterBody3D
## Zébu : sauvage (erre autour de son troupeau), escorté (suit un Dahalo),
## ou sécurisé dans un enclos (compte pour la victoire).
## Le zébu est au cœur du jeu et de la culture du Sud : il n'est jamais tué ici,
## seulement capturé, escorté ou repris (GDD §3, §7).

enum Etat { SAUVAGE, SUIT, ENCLOS }

const VITESSE_ERRANCE := 1.5

var proprietaire := GameRules.WILD
var etat := Etat.SAUVAGE
var meneur = null            # Unite qui l'escorte
var enclos = null            # Batiment où il est sécurisé
var centre_errance := Vector3.ZERO
var rayon_errance := 6.0
var id := 0
var vole := false                 # pris dans l'enclos ou l'escorte d'un autre clan
var victime := GameRules.WILD     # clan à qui il a été volé (pour les traces)
var immobile_jusqua := -INF       # tenu par un Dahalo qui le détache : il ne bouge pas
var date_securisation := -INF     # temps de jeu de la dernière mise en enclos

var _cible_errance := Vector3.ZERO
var _timer := 0.0

@onready var marque: MeshInstance3D = $Marque


func _ready() -> void:
	id = CommandBus.enregistrer(self)
	add_to_group("zebus")
	_cible_errance = global_position
	_maj_marque()


func peut_etre_capture_par(faction: int) -> bool:
	if etat == Etat.SUIT:
		# Contre-attaque : on peut reprendre un zébu escorté par un clan adverse.
		return is_instance_valid(meneur) and meneur.faction != faction
	return proprietaire != faction


func duree_capture() -> float:
	if etat == Etat.ENCLOS and proprietaire != GameRules.WILD:
		return GameRules.DUREE_DETACHER_S
	return GameRules.DUREE_CAPTURE_SAUVAGE_S


## Un Dahalo commence à le détacher : l'enclos donne l'alerte.
func debut_detachement(_par) -> void:
	if etat == Etat.ENCLOS and is_instance_valid(enclos) and enclos.has_method("signaler_intrusion"):
		enclos.signaler_intrusion()


func suivre(unite) -> void:
	vole = proprietaire != GameRules.WILD and proprietaire != unite.faction
	victime = proprietaire if vole else GameRules.WILD
	if victime == GameRules.PLAYER:
		EventBus.alerte.emit(global_position)
	if etat == Etat.ENCLOS and proprietaire != GameRules.WILD:
		ResourceManager.zebu_perdu(proprietaire)
		if proprietaire == GameRules.PLAYER:
			EventBus.message.emit("Alerte : des Dahalo volent un zébu dans votre enclos !")
	elif etat == Etat.SUIT and is_instance_valid(meneur):
		meneur.zebus_escortes.erase(self)
		if meneur.faction == GameRules.PLAYER:
			EventBus.message.emit("Un zébu de votre escorte a été repris !")
	etat = Etat.SUIT
	enclos = null
	meneur = unite
	proprietaire = unite.faction
	unite.zebus_escortes.append(self)
	_maj_marque()


func securiser(e) -> void:
	if is_instance_valid(meneur):
		meneur.zebus_escortes.erase(self)
	meneur = null
	etat = Etat.ENCLOS
	enclos = e
	proprietaire = e.faction
	centre_errance = e.global_position
	rayon_errance = 2.8
	_timer = 0.0
	date_securisation = GameClock.temps_ecoule
	ResourceManager.zebu_securise(proprietaire)
	if proprietaire == GameRules.PLAYER:
		EventBus.message.emit("Zébu sécurisé dans l'enclos.")
	_maj_marque()


## Au marché, un zébu volé depuis peu se vend au rabais (lutte contre le vol de bétail).
func est_vole_recemment() -> bool:
	return vole and GameClock.temps_ecoule - date_securisation < GameRules.DELAI_ZEBU_VOLE_S


## Affamé ou assoiffé : le zébu quitte l'enclos et redevient sauvage, loin du village.
## (Le décompte du cheptel est fait par ResourceManager.)
func fuir() -> void:
	var a := randf() * TAU
	var destination := global_position + Vector3(cos(a), 0.0, sin(a)) * 22.0
	destination.x = clampf(destination.x, -55.0, 55.0)
	destination.z = clampf(destination.z, -55.0, 55.0)
	etat = Etat.SAUVAGE
	enclos = null
	meneur = null
	vole = false
	proprietaire = GameRules.WILD
	centre_errance = destination
	rayon_errance = 6.0
	_cible_errance = destination
	_timer = 8.0
	_maj_marque()


## Lâché par son escorte (Dahalo tué) : redevient sauvage sur place.
func liberer() -> void:
	_relacher()


func _relacher() -> void:
	etat = Etat.SAUVAGE
	meneur = null
	proprietaire = GameRules.WILD
	centre_errance = global_position
	rayon_errance = 6.0
	_maj_marque()


func _physics_process(delta: float) -> void:
	if etat != Etat.SUIT and GameClock.temps_ecoule < immobile_jusqua:
		velocity = Vector3.ZERO
		return
	var cible := _cible_errance
	var vitesse := VITESSE_ERRANCE
	var tolerance := 0.3

	if etat == Etat.SUIT:
		if not is_instance_valid(meneur):
			_relacher()
			return
		# Position en file derrière le meneur (+Z = derrière, car look_at oriente -Z vers l'avant).
		var rang: int = meneur.zebus_escortes.find(self)
		var arriere: Vector3 = meneur.global_transform.basis.z
		var cote: Vector3 = meneur.global_transform.basis.x
		cible = meneur.global_position + arriere * (2.0 + floorf(rang / 2.0) * 1.2) \
				+ cote * (0.8 if rang % 2 == 0 else -0.8)
		vitesse = meneur.vitesse_actuelle() + 0.6
		tolerance = 0.4
	else:
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(2.0, 5.0)
			var a := randf() * TAU
			_cible_errance = centre_errance + Vector3(cos(a), 0.0, sin(a)) * randf() * rayon_errance

	var dir := cible - global_position
	dir.y = 0.0
	if dir.length() < tolerance:
		velocity = Vector3.ZERO
		return
	dir = dir.normalized()
	velocity = dir * vitesse
	look_at(global_position + dir, Vector3.UP)
	move_and_slide()


func _maj_marque() -> void:
	marque.visible = proprietaire != GameRules.WILD
	if marque.visible:
		var m := StandardMaterial3D.new()
		m.albedo_color = GameRules.couleur_faction(proprietaire)
		marque.material_override = m
