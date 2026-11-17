class_name Zebu
extends CharacterBody3D
## Zébu : sauvage (erre autour de son troupeau), escorté (suit un Dahalo),
## ou sécurisé dans un enclos (compte pour la victoire).
## Le zébu est au cœur du jeu et de la culture du Sud : il n'est jamais tué ici,
## seulement capturé, escorté ou repris (GDD §3, §7).

enum Etat { SAUVAGE, SUIT, ENCLOS }

const VITESSE_ERRANCE := 1.0       # pas tranquille d'un zébu qui pâture
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
var rayon_errance := 6.0
var id := 0
var vole := false                 # pris dans l'enclos ou l'escorte d'un autre clan
var victime := GameRules.WILD     # clan à qui il a été volé (pour les traces)
var immobile_jusqua := -INF       # tenu par un Dahalo qui le détache : il ne bouge pas
var date_securisation := -INF     # temps de jeu de la dernière mise en enclos

var _cible_errance := Vector3.ZERO
var _timer := 0.0

@onready var marque: MeshInstance3D = $Marque
var _modele: Node3D
var _animations: AnimationPlayer
var _anims := {}   # "repos" | "marche" | "course" -> nom de l'animation importée


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
		for nom in _animations.get_animation_list():
			for cle in ["repos", "marche", "course"]:
				if cle in nom:
					_anims[cle] = nom
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
	var v := Vector2(velocity.x, velocity.z).length()
	if v < 0.15:
		_jouer("repos", 1.0)
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
	var limite := GameRules.DEMI_CARTE - 5.0
	destination.x = clampf(destination.x, -limite, limite)
	destination.z = clampf(destination.z, -limite, limite)
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
	_suivre_sol()
	_animer()
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
		# File par deux derrière le meneur, espacée à la taille réelle d'un zébu (~2,3 m de long).
		cible = meneur.global_position + arriere * (2.4 + floorf(rang / 2.0) * 2.5) \
				+ cote * (0.75 if rang % 2 == 0 else -0.75)
		vitesse = meneur.vitesse_actuelle() + 0.6
		tolerance = 0.4
	else:
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(2.0, 5.0)
			var a := randf() * TAU
			# Racine carrée : cibles réparties sur toute la surface (sinon le troupeau s'entasse au centre).
			_cible_errance = centre_errance + Vector3(cos(a), 0.0, sin(a)) * sqrt(randf()) * rayon_errance

	var dir := cible - global_position
	dir.y = 0.0
	var ecart := _ecartement()
	if dir.length() < tolerance:
		# Arrivé : il ne bouge que pour laisser de la place à ses voisins (sans se retourner).
		velocity = ecart
		if ecart.length() > 0.05:
			move_and_slide()
			_rester_dans_enclos()
		return
	dir = dir.normalized()
	velocity = (dir * vitesse + ecart) * Terrain.facteur_vitesse(global_position)   # sable du lit de rivière
	look_at(global_position + dir, Vector3.UP)
	move_and_slide()
	_rester_dans_enclos()


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
