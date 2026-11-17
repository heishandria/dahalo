class_name Zebu
extends CharacterBody3D
## Zébu : sauvage (erre autour de son troupeau), escorté (suit un Dahalo),
## ou sécurisé dans un enclos (compte pour la victoire).
## Le zébu est au cœur du jeu et de la culture du Sud : il n'est jamais tué ici,
## seulement capturé, escorté ou repris (GDD §3, §7).

enum Etat { SAUVAGE, SUIT, ENCLOS }

const VITESSE_ERRANCE := 1.0       # pas tranquille d'un zébu qui pâture
const VITESSE_PAS_BROUTE := 0.35   # quelques pas lents, tête basse, d'une touffe à l'autre
const RAYON_PATURAGE := 11.0       # un troupeau sauvage se disperse sur ~22 m autour de son centre
# Modèle 3D (assets/models/animaux/LISEZMOI.md) : vitesses auxquelles ses animations sont calées.
const MODELE := preload("res://assets/models/animaux/zebu.glb")
# (vitesse du sabot au sol, mesurée par zebu_depuis_vache.py : marche 0,23 m/s, course 1,81 m/s).
const VITESSE_MARCHE_MODELE := 0.23
const VITESSE_COURSE_MODELE := 1.81
const SEUIL_COURSE := 1.6
# Espace vital : le corps du zébu est vu comme un segment (épaules -> croupe) ; on mesure l'écart entre segments,
# pour que deux zébus ne se traversent pas, même placés en croix.
const DEMI_CORPS := 0.85           # demi-longueur du segment du corps (le zébu fait ~2,3 m avec la tête)
const ECART_ZEBUS := 0.85          # distance minimale entre les axes de deux zébus (largeur du corps + marge)
const ECART_PERSONNES := 0.75      # distance minimale entre l'axe d'un zébu et une personne
const FORCE_ECART := 2.6
const DEMI_ENCLOS := 3.35          # les deux bouts du corps restent dans ce carré (clôture à ~3,95 m du centre)
# Robes courantes des zébus malgaches : rouge-brun, gris, noir, blanc crème, fauve, brun sombre.
const ROBES := [Color(0.55, 0.3, 0.18), Color(0.62, 0.6, 0.56), Color(0.13, 0.12, 0.11), Color(0.86, 0.82, 0.74),
		Color(0.72, 0.55, 0.36), Color(0.36, 0.24, 0.17)]
const BLANC := Color(0.88, 0.85, 0.78)
# Motifs : unie ~55 %, pie (grandes plaques) ~30 %, tachetée ~15 % (scenes/units/robe_zebu.gdshader).
const PART_PIE := 0.3
const PART_TACHETEE := 0.15

var proprietaire := GameRules.WILD
var etat := Etat.SAUVAGE
var meneur = null            # Unite qui l'escorte
var enclos = null            # Batiment où il est sécurisé
var centre_errance := Vector3.ZERO
var rayon_errance := RAYON_PATURAGE
var id := 0
var vole := false                 # pris dans l'enclos ou l'escorte d'un autre clan
var victime := GameRules.WILD     # clan à qui il a été volé (pour les traces)
var immobile_jusqua := -INF       # tenu par un Dahalo qui le détache : il ne bouge pas
var date_securisation := -INF     # temps de jeu de la dernière mise en enclos

var _cible_errance := Vector3.ZERO

@onready var marque: MeshInstance3D = $Marque
var _modele: Node3D
var _animations: AnimationPlayer
var _anims := {}   # "repos", "marche", "course", "brouter", "se_coucher", "couche", "dort" -> nom importé

enum Activite { DEBOUT, BROUTE, MANGE, BOIT, COUCHE }
enum Posture { DEBOUT, DESCEND, COUCHE, SE_LEVE }
var activite := Activite.DEBOUT
var _posture := Posture.DEBOUT
var _horloge := 0.0            # temps propre du zébu (suit l'accélération du jeu)
var _fin_activite := 0.0
var _fin_posture := 0.0
var _prochain_pas := 0.0       # en broutant : prochain changement tête basse / quelques pas
var _pas_de_broute := false    # en broutant : il fait quelques pas (sinon, tête au sol)
var _vers_herbe := false       # en broutant : il marche encore vers le coin d'herbe choisi
var _arrive := false           # arrivé à sa cible
var _dort := false             # couché pour la nuit (tête posée) plutôt que pour ruminer
var _regard := Vector3.ZERO    # point à regarder une fois arrivé (fourrage, auge)
var _limite_marche := 0.0      # pour se coucher : au-delà, il se couche où il est


func _ready() -> void:
	id = CommandBus.enregistrer(self)
	add_to_group("zebus")
	_cible_errance = global_position
	_creer_modele()
	_maj_marque()
	# Les villageois et guerriers contournent les zébus (évitement de leurs agents de navigation).
	var obstacle := NavigationObstacle3D.new()
	obstacle.radius = 1.0
	obstacle.avoidance_enabled = true
	add_child(obstacle)


## Modèle animé à la place des formes de la scène ; robe tirée de l'identifiant (stable pendant la partie).
func _creer_modele() -> void:
	_modele = MODELE.instantiate() as Node3D
	_modele.rotation.y = PI   # le modèle regarde vers +Z, le zébu avance vers -Z
	var e := randf_range(0.92, 1.06)
	_modele.scale = Vector3.ONE * e
	add_child(_modele)
	for nom in ["Corps", "Bosse", "Tete"]:
		(get_node(nom) as Node3D).visible = false
	marque.position = Vector3(0, 1.55, -0.45)
	var robe_mat := _robe_aleatoire()
	for mi in _modele.find_children("*", "MeshInstance3D", true, false):
		var maillage: Mesh = (mi as MeshInstance3D).mesh
		for s in maillage.get_surface_count():
			var m := maillage.surface_get_material(s)
			if m != null and m.resource_name == "Robe":
				(mi as MeshInstance3D).set_surface_override_material(s, robe_mat)
	_animations = _modele.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if _animations != null:
		# Noms importés « Zebu_repos », « Zebu_se_coucher »… (Godot retire « _loop »).
		for nom in _animations.get_animation_list():
			_anims[nom.get_slice("/", nom.get_slice_count("/") - 1).trim_prefix("Zebu_")] = nom
		_jouer("repos", 1.0)
		_animations.seek(randf() * 3.0, true)


## Robe tirée au sort : unie, pie (plaques blanches sur couleur, ou l'inverse) ou tachetée.
func _robe_aleatoire() -> ShaderMaterial:
	var h := RandomNumberGenerator.new()
	h.seed = hash(id * 7919 + 13)
	var m := ShaderMaterial.new()
	m.shader = preload("res://scenes/units/robe_zebu.gdshader")
	var base: Color = ROBES[h.randi() % ROBES.size()] * h.randf_range(0.92, 1.08)
	var tirage := h.randf()
	var motif := 0
	var taches := BLANC
	if tirage < PART_TACHETEE:
		motif = 2
		taches = BLANC if base.get_luminance() < 0.5 else ROBES[h.randi_range(0, 2)]
	elif tirage < PART_TACHETEE + PART_PIE:
		motif = 1
		if base.get_luminance() > 0.6:   # robe claire : plaques sombres
			taches = ROBES[[0, 2, 5][h.randi() % 3]]
	m.set_shader_parameter("couleur_base", base)
	m.set_shader_parameter("couleur_taches", taches)
	m.set_shader_parameter("motif", motif)
	m.set_shader_parameter("graine", h.randf_range(0.0, 100.0))
	m.set_shader_parameter("couverture", h.randf_range(0.3, 0.65))
	return m


func _jouer(cle: String, vitesse: float) -> void:
	if _animations == null or not _anims.has(cle):
		return
	if _animations.current_animation != _anims[cle]:
		_animations.play(_anims[cle], 0.25)
	_animations.speed_scale = vitesse


func _animer() -> void:
	match _posture:
		Posture.COUCHE:
			_jouer("dort" if _dort else "couche", 1.0)
			return
		Posture.DESCEND, Posture.SE_LEVE:
			return
	var v := Vector2(velocity.x, velocity.z).length()
	if v < 0.15:
		var tete_basse := etat != Etat.SUIT and _arrive and activite in [Activite.MANGE, Activite.BOIT]
		tete_basse = tete_basse or (etat != Etat.SUIT and activite == Activite.BROUTE and not _pas_de_broute and not _vers_herbe)
		_jouer("brouter" if tete_basse else "repos", 1.0)
	elif v < SEUIL_COURSE:
		_jouer("marche", clampf(v / VITESSE_MARCHE_MODELE, 0.6, 5.0))
	else:
		_jouer("course", clampf(v / VITESSE_COURSE_MODELE, 0.8, 3.0))


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
	_fin_activite = _horloge + randf_range(1.0, 4.0)
	activite = Activite.DEBOUT
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
	var limite := GameRules.DEMI_CARTE - 5.0
	destination.x = clampf(destination.x, -limite, limite)
	destination.z = clampf(destination.z, -limite, limite)
	etat = Etat.SAUVAGE
	enclos = null
	meneur = null
	vole = false
	proprietaire = GameRules.WILD
	centre_errance = destination
	rayon_errance = RAYON_PATURAGE
	_cible_errance = destination
	activite = Activite.DEBOUT
	_fin_activite = _horloge + 20.0   # il file d'abord loin du village
	_maj_marque()


## Lâché par son escorte (Dahalo tué) : redevient sauvage sur place.
func liberer() -> void:
	_relacher()


func _relacher() -> void:
	etat = Etat.SAUVAGE
	meneur = null
	proprietaire = GameRules.WILD
	centre_errance = global_position
	rayon_errance = RAYON_PATURAGE
	_fin_activite = _horloge
	_maj_marque()


## Dans le lit de rivière (en contrebas), le visuel descend ; le corps physique reste à y = 0.
var _hauteur_visuelle := 0.0


func _suivre_sol() -> void:
	var h := Terrain.hauteur_sol(global_position)
	if absf(h - _hauteur_visuelle) < 0.01:
		return
	for n in [marque, _modele]:
		if n != null:
			n.position.y += h - _hauteur_visuelle
	_hauteur_visuelle = h


func _physics_process(delta: float) -> void:
	_horloge += delta
	_suivre_sol()
	_maj_posture()
	_animer()
	var tenu := etat != Etat.SUIT and GameClock.temps_ecoule < immobile_jusqua
	if etat == Etat.SUIT or tenu:
		_se_lever(true)   # capturé ou détaché : il se relève aussitôt
	else:
		_comportement()
	if tenu or _posture != Posture.DEBOUT:
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
		# File par deux derrière le meneur, espacée à la taille réelle d'un zébu (~2,3 m de long).
		cible = meneur.global_position + arriere * (2.4 + floorf(rang / 2.0) * 2.5) \
				+ cote * (0.75 if rang % 2 == 0 else -0.75)
		vitesse = meneur.vitesse_actuelle() + 0.6
		tolerance = 0.4
	elif activite == Activite.BROUTE and _pas_de_broute and not _vers_herbe:
		vitesse = VITESSE_PAS_BROUTE

	var dir := cible - global_position
	dir.y = 0.0
	var ecart := _ecartement()
	if dir.length() < tolerance:
		# Arrivé : il ne bouge que pour laisser de la place à ses voisins ; à la mangeoire, il fait face au fourrage.
		_arrive = true
		if _regard != Vector3.ZERO:
			var vers := _regard - global_position
			vers.y = 0.0
			if vers.length() > 0.3:
				_tourner_vers(vers, 0.15)
		velocity = ecart
		if ecart.length() > 0.05:
			move_and_slide()
			_rester_dans_enclos()
		return
	_arrive = false
	dir = dir.normalized()
	velocity = (dir * vitesse + ecart) * Terrain.facteur_vitesse(global_position)   # sable du lit de rivière
	_tourner_vers(dir, 0.25 if etat == Etat.SUIT else 0.1)
	move_and_slide()
	_rester_dans_enclos()


## Oriente le zébu vers `dir` (au sol), en douceur : `part` de l'écart rattrapé à chaque image physique.
func _tourner_vers(dir: Vector3, part: float) -> void:
	var voulu := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, voulu, part)


# --- Comportement : brouter, manger au fourrage, boire, rester debout, se coucher, dormir ---

## Choisit et déroule l'activité du moment (zébu sauvage ou en enclos). Pas d'effet sur les règles : le
## cheptel consomme toujours la nourriture et l'eau du clan (ResourceManager) ; c'est la vie du troupeau.
func _comportement() -> void:
	if _horloge >= _fin_activite:
		_choisir_activite()
		return
	match activite:
		Activite.BROUTE:
			# Il marche d'abord jusqu'au coin d'herbe choisi ; puis il alterne : tête au sol quelques secondes,
			# quelques pas lents vers la touffe voisine.
			if _vers_herbe:
				if _arrive:
					_vers_herbe = false
					_pas_de_broute = false
					_prochain_pas = _horloge + randf_range(3.0, 7.0)
			elif _pas_de_broute:
				if _arrive or _horloge >= _prochain_pas:
					_pas_de_broute = false
					_prochain_pas = _horloge + randf_range(3.0, 7.0)
					_cible_errance = global_position
			elif _horloge >= _prochain_pas:
				_pas_de_broute = true
				_prochain_pas = _horloge + 4.0
				var avant := -global_transform.basis.z
				var pas := avant.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(0.5, 1.1)
				_cible_errance = _borne_troupeau(global_position + pas)
				_arrive = false
		Activite.COUCHE:
			# Couché une fois à sa place (ou s'il n'y arrive pas, bousculé par les autres).
			if _posture == Posture.DEBOUT and (_arrive or _horloge > _limite_marche):
				_se_coucher()
		_:
			pass


func _choisir_activite() -> void:
	_regard = Vector3.ZERO
	_pas_de_broute = false
	_vers_herbe = false
	if _posture == Posture.COUCHE or _posture == Posture.DESCEND:
		# Couché : il se relève le matin, sinon seulement après un bon moment.
		if GameClock.est_nuit and randf() < 0.85:
			_fin_activite = _horloge + randf_range(10.0, 20.0)
			return
		_se_lever(false)
	var nuit := GameClock.est_nuit
	var tirage := randf()
	if etat == Etat.ENCLOS and is_instance_valid(enclos):
		if nuit:
			_activite_couche(tirage < 0.8)
		elif tirage < 0.3 and _prendre_poste(enclos.global_position + Maisons.FOURRAGE_ENCLOS, 3, 1.9):
			activite = Activite.MANGE
			_fin_activite = _horloge + randf_range(10.0, 25.0)
		elif tirage < 0.45 and _prendre_poste(enclos.global_position + Maisons.AUGE_ENCLOS, 2, 1.25):
			activite = Activite.BOIT
			_fin_activite = _horloge + randf_range(5.0, 10.0)
		elif tirage < 0.75:
			_activite_couche(false)
		else:
			_activite_debout()
		return
	# Sauvage : surtout brouter le jour, en cherchant l'herbe la plus dense autour du troupeau.
	if nuit:
		_activite_couche(tirage < 0.8)
	elif tirage < 0.6:
		activite = Activite.BROUTE
		_fin_activite = _horloge + randf_range(15.0, 35.0)
		_cible_errance = _meilleure_herbe()
		_vers_herbe = true
		_arrive = false
	elif tirage < 0.8:
		_activite_couche(false)
	else:
		_activite_debout()


func _activite_debout() -> void:
	activite = Activite.DEBOUT
	_fin_activite = _horloge + randf_range(4.0, 10.0)
	var a := randf() * TAU
	_cible_errance = _borne_troupeau(centre_errance + Vector3(cos(a), 0.0, sin(a)) * sqrt(randf()) * rayon_errance)


## Se coucher : d'abord il va à une place libre (un peu à l'écart), puis se couche ; de nuit, il dort.
func _activite_couche(longtemps: bool) -> void:
	activite = Activite.COUCHE
	_dort = longtemps
	_fin_activite = _horloge + (randf_range(40.0, 70.0) if longtemps else randf_range(20.0, 45.0))
	# Une place à l'écart du fourrage et de l'auge (dans l'enclos), sinon n'importe où autour du troupeau.
	for essai in 6:
		var a := randf() * TAU
		_cible_errance = _borne_troupeau(centre_errance + Vector3(cos(a), 0.0, sin(a)) * sqrt(randf()) * rayon_errance * 0.9)
		if etat != Etat.ENCLOS or not is_instance_valid(enclos):
			break
		var local: Vector3 = _cible_errance - enclos.global_position
		if Vector2(local.x, local.z).distance_to(Vector2(Maisons.FOURRAGE_ENCLOS.x, Maisons.FOURRAGE_ENCLOS.z)) > 2.0 \
				and Vector2(local.x, local.z).distance_to(Vector2(Maisons.AUGE_ENCLOS.x, Maisons.AUGE_ENCLOS.z)) > 1.8:
			break
	_arrive = false
	_limite_marche = _horloge + 10.0


## Place autour d'un point (fourrage, auge) : `places` emplacements à `distance` du point, face à lui, du côté
## du centre de l'enclos. Faux si toutes les places sont prises par d'autres zébus.
func _prendre_poste(point: Vector3, places: int, distance: float) -> bool:
	var vers_centre: Vector3 = enclos.global_position - point
	vers_centre.y = 0.0
	vers_centre = vers_centre.normalized()
	var libres: Array[Vector3] = []
	for k in places:
		var angle := (k - (places - 1) * 0.5) * (1.0 if places == 3 else 0.55)
		var poste: Vector3 = point + vers_centre.rotated(Vector3.UP, angle) * distance
		var occupe := false
		for z in get_tree().get_nodes_in_group("zebus"):
			if z != self and z.etat == Etat.ENCLOS and z._cible_errance.distance_to(poste) < 0.4:
				occupe = true
				break
		if not occupe:
			libres.append(poste)
	if libres.is_empty():
		return false
	_cible_errance = libres[randi() % libres.size()]
	_regard = point
	return true


## Coin d'herbe pour brouter : le meilleur de quelques points tirés autour du troupeau (herbe dense des
## massifs, des berges et des mares ; pas au sommet des collines).
func _meilleure_herbe() -> Vector3:
	var meilleur := global_position
	var note_max := -INF
	var vegetation := _vegetation()
	for k in 7:
		var a := randf() * TAU
		var p := _borne_troupeau(centre_errance + Vector3(cos(a), 0.0, sin(a)) * sqrt(randf()) * rayon_errance)
		if Terrain.infranchissable(p):
			continue
		var herbe: float = vegetation.densite_herbe(p) if vegetation != null else 0.5
		# Un peu de hasard, et une préférence pour ne pas traverser tout le pâturage.
		var note := herbe + randf() * 0.3 - p.distance_to(global_position) * 0.015
		if note > note_max:
			note_max = note
			meilleur = p
	return meilleur


static var _vegetation_cache: Node = null

func _vegetation() -> Node:
	if not is_instance_valid(_vegetation_cache):
		_vegetation_cache = get_tree().get_first_node_in_group("vegetation")
	return _vegetation_cache


func _borne_troupeau(p: Vector3) -> Vector3:
	var limite := GameRules.DEMI_CARTE - 3.0
	return Vector3(clampf(p.x, -limite, limite), 0.0, clampf(p.z, -limite, limite))


# --- Posture : debout, se couche, couché, se relève ---

func _se_coucher() -> void:
	if _posture != Posture.DEBOUT or not _anims.has("se_coucher"):
		return
	_posture = Posture.DESCEND
	_animations.play(_anims["se_coucher"], 0.3)
	_animations.speed_scale = 1.0
	_fin_posture = _horloge + _animations.current_animation_length


## Se relever (l'animation de coucher jouée à l'envers) ; `vite` : capturé ou dérangé, il se lève d'un bond.
func _se_lever(vite: bool) -> void:
	if _posture == Posture.DEBOUT or _posture == Posture.SE_LEVE:
		return
	var vitesse := 2.5 if vite else 1.2
	var nom: String = _anims.get("se_coucher", "")
	if nom == "":
		_posture = Posture.DEBOUT
		return
	var duree: float = _animations.get_animation(nom).length
	var position_anim := duree
	if _posture == Posture.DESCEND:
		position_anim = clampf(duree - (_fin_posture - _horloge), 0.0, duree)
	_animations.play(nom, 0.15)
	_animations.seek(position_anim, true)
	_animations.speed_scale = -vitesse
	_posture = Posture.SE_LEVE
	_fin_posture = _horloge + position_anim / vitesse
	activite = Activite.DEBOUT
	_fin_activite = _horloge + position_anim / vitesse + randf_range(2.0, 5.0)


func _maj_posture() -> void:
	# La marque du clan descend avec l'animal couché.
	var bas := _posture == Posture.COUCHE or _posture == Posture.DESCEND
	marque.position.y = lerpf(marque.position.y, _hauteur_visuelle + (0.95 if bas else 1.55), 0.05)
	if _horloge < _fin_posture:
		return
	match _posture:
		Posture.DESCEND:
			_posture = Posture.COUCHE
		Posture.SE_LEVE:
			_posture = Posture.DEBOUT
			_animations.speed_scale = 1.0


## Poussée qui l'éloigne des zébus et des personnes trop proches (espace vital, sans blocage physique :
## un Dahalo doit pouvoir mener son troupeau au milieu des autres). Distances mesurées depuis l'axe du corps.
func _ecartement() -> Vector3:
	var poussee := Vector3.ZERO
	var axe := _axe_corps()
	for z in get_tree().get_nodes_in_group("zebus"):
		if z == self or not (z is Node3D):
			continue
		if (z.global_position - global_position).length_squared() > 9.0:
			continue
		var autre: Array = z._axe_corps()
		var proches := _points_proches(axe[0], axe[1], autre[0], autre[1])
		poussee += _poussee(proches[0], proches[1], ECART_ZEBUS)
	for u in get_tree().get_nodes_in_group("unites"):
		if u == meneur:
			continue
		var p: Vector3 = u.global_position
		if (p - global_position).length_squared() > 6.0:
			continue
		poussee += _poussee(_point_proche(axe[0], axe[1], p), p, ECART_PERSONNES)
	# Dans l'enclos : on ne marche pas dans le fourrage ni dans l'auge.
	if etat == Etat.ENCLOS and is_instance_valid(enclos):
		var fourrage: Vector3 = enclos.global_position + Maisons.FOURRAGE_ENCLOS
		fourrage.y = 0.0
		poussee += _poussee(_point_proche(axe[0], axe[1], fourrage), fourrage, 1.0)
		var auge: Vector3 = enclos.global_position + Maisons.AUGE_ENCLOS
		auge.y = 0.0
		var bout := Vector3(0.75, 0.0, 0.0)
		var proches := _points_proches(axe[0], axe[1], auge - bout, auge + bout)
		poussee += _poussee(proches[0], proches[1], 0.6)
	return poussee * FORCE_ECART


## Les deux bouts du corps (épaules et croupe), au sol.
func _axe_corps() -> Array:
	var avant := -global_transform.basis.z
	avant.y = 0.0
	avant = avant.normalized() * DEMI_CORPS
	var c := Vector3(global_position.x, 0.0, global_position.z)
	return [c + avant, c - avant]


func _poussee(moi: Vector3, autre: Vector3, distance_mini: float) -> Vector3:
	var d := moi - autre
	d.y = 0.0
	var l := d.length()
	if l >= distance_mini:
		return Vector3.ZERO
	if l < 0.001:
		return Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	return d / l * (distance_mini - l) / distance_mini


static func _point_proche(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return a + ab * t


## Points les plus proches entre les segments [a, b] et [c, d] (au sol).
static func _points_proches(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> Array:
	var u := b - a
	var v := d - c
	var w := a - c
	var aa := u.dot(u)
	var bb := u.dot(v)
	var cc := v.dot(v)
	var dd := u.dot(w)
	var ee := v.dot(w)
	var den := aa * cc - bb * bb
	var s := 0.0 if den < 1e-6 else clampf((bb * ee - cc * dd) / den, 0.0, 1.0)
	var t := clampf((bb * s + ee) / cc, 0.0, 1.0)
	s = clampf((bb * t - dd) / aa, 0.0, 1.0)
	return [a + u * s, c + v * t]


## Dans l'enclos, les deux bouts du corps restent à l'intérieur de la clôture (carré arrondi, non tourné).
func _rester_dans_enclos() -> void:
	if etat != Etat.ENCLOS:
		return
	var axe := _axe_corps()
	var centre := Vector3(centre_errance.x, 0.0, centre_errance.z)
	var a: Vector3 = axe[0] - centre
	var b: Vector3 = axe[1] - centre
	var correction := Vector3.ZERO
	correction.x = minf(0.0, DEMI_ENCLOS - maxf(a.x, b.x)) + maxf(0.0, -DEMI_ENCLOS - minf(a.x, b.x))
	correction.z = minf(0.0, DEMI_ENCLOS - maxf(a.z, b.z)) + maxf(0.0, -DEMI_ENCLOS - minf(a.z, b.z))
	global_position += correction


func _maj_marque() -> void:
	marque.visible = proprietaire != GameRules.WILD
	if marque.visible:
		var m := StandardMaterial3D.new()
		m.albedo_color = GameRules.couleur_faction(proprietaire)
		marque.material_override = m
