extends Control
## Sélection et ordres du joueur, à la souris (PC) ou au doigt (mobile / navigateur).
##
## Souris (façon Age of Empires) :
##  - clic gauche : sélectionner une unité (Maj = ajouter) ou un de ses bâtiments ; glisser = cadre de sélection
##  - clic droit : ordre contextuel (récolter, capturer un zébu, ramener à l'enclos, déplacer)
##  - touches : 1/2/3 former, E construire un enclos sous la souris, Échap désélectionner
## Tactile :
##  - toucher une de ses unités : la sélectionner
##  - toucher un de ses bâtiments sans unité sélectionnée : le sélectionner (actions dans le HUD)
##  - toucher autre chose avec une sélection : ordre contextuel
##  - glisser un doigt : déplacer la caméra ; pincer : zoomer
##  - boutons du HUD : sélection par type, formation, construction
## Ne modifie jamais le jeu directement : tout passe par CommandBus.

signal selection_changee(unites: Array)
signal mode_construction_change(type_batiment: String)
signal batiment_change(batiment)

const SEUIL_CADRE := 6.0
const SEUIL_GLISSER := 14.0
const MASQUE_SOL := 1
const MASQUE_UNITES := 2
const MASQUE_INTERACTIFS := 4
const COULEUR_CADRE := Color(1.0, 0.85, 0.4)
const TOLERANCE_SOURIS_PX := 18.0   # rayon de « clic approximatif » autour d'une unité
const TOLERANCE_DOIGT_PX := 34.0

var selection: Array = []
var mode_construction := ""     # "" ou un type de bâtiment : le prochain clic / toucher le pose
var batiment_selectionne = null # bâtiment du joueur sélectionné (jamais en même temps que des unités)
var _anneau_batiment: MeshInstance3D

# Souris
var _debut := Vector2.ZERO
var _actuel := Vector2.ZERO
var _appui := false
var _en_cadre := false

# Tactile
var _doigts := {}               # index -> position
var _glisse := false
var _distance_glissee := 0.0
var _ecart_pincement := 0.0

@onready var _camera_rig = get_node_or_null("../../CameraRig")

# Aperçu de construction (bâtiment fantôme vert / rouge)
var _fantome: MeshInstance3D
var _mat_fantome := StandardMaterial3D.new()
var _point_palissade := Vector3.INF   # dernier point du tracé de palissade en cours
var _apercu_palissade: Node3D          # segments fantômes entre le dernier point et le curseur
const PAS_ANGLE_PALISSADE := 15.0      # la direction du tracé s'aimante par pas de 15° (lignes droites faciles)
var _fantome_pose := false      # tactile : un aperçu est affiché, un 2e toucher au même endroit confirme


func _unhandled_input(event: InputEvent) -> void:
	# Les clics « émulés » depuis le tactile sont ignorés : le tactile a sa propre logique.
	# (Les boutons de l'interface, eux, continuent de les recevoir.)
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	var st := event as InputEventScreenTouch
	if st != null:
		_toucher(st)
		return
	var sd := event as InputEventScreenDrag
	if sd != null:
		_glisser_doigt(sd)
		return

	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_appui = true
				_en_cadre = false
				_debut = mb.position
				_actuel = mb.position
			elif _appui:
				_appui = false
				if mode_construction != "":
					_poser_batiment(mb.position)
				elif _en_cadre:
					_selection_cadre(_rect(), mb.shift_pressed)
				else:
					_selection_clic(mb.position, mb.shift_pressed)
				_en_cadre = false
				queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if mode_construction != "":
				definir_mode_construction("")
			else:
				_ordre(mb.position)
		return

	var mm := event as InputEventMouseMotion
	if mm != null:
		if mode_construction != "":
			var sol := _raycast(mm.position, MASQUE_SOL)
			if not sol.is_empty():
				_placer_fantome(sol.position)
				if mode_construction == "palissade":
					_maj_apercu_palissade(sol.position)
		if _appui:
			_actuel = mm.position
			if _debut.distance_to(_actuel) > SEUIL_CADRE:
				_en_cadre = true
			queue_redraw()
		return

	if event.is_action_pressed("former_villageois"):
		former("villageois")
	elif event.is_action_pressed("former_dahalo"):
		former("dahalo")
	elif event.is_action_pressed("former_pisteur"):
		former("pisteur")
	elif event.is_action_pressed("former_lanceur"):
		former("lanceur")
	elif event.is_action_pressed("former_tireur"):
		former("tireur")
	elif event.is_action_pressed("construire_enclos"):
		_construire_sous_souris("enclos")
	elif event.is_action_pressed("annuler"):
		annuler()


func _draw() -> void:
	if _appui and _en_cadre:
		var r := _rect()
		draw_rect(r, Color(COULEUR_CADRE, 0.15), true)
		draw_rect(r, COULEUR_CADRE, false, 1.5)


# --- API utilisée par le HUD (boutons) ---

## role = "guerriers" sélectionne toutes les unités qui combattent.
func selectionner_type(role: String) -> void:
	_vider()
	for u in get_tree().get_nodes_in_group("unites_%d" % GameRules.PLAYER):
		if u.data.role == role or (role == "guerriers" and u.est_combattant()):
			_ajouter(u)
	selection_changee.emit(selection)


## Forme dans le bâtiment sélectionné s'il le peut, sinon dans le premier bâtiment adapté (raccourcis clavier).
func former(role: String) -> void:
	var candidats: Array = get_tree().get_nodes_in_group("batiments_%d" % GameRules.PLAYER)
	if _batiment_valide(batiment_selectionne):
		candidats.push_front(batiment_selectionne)
	for b in candidats:
		if b.has_method("peut_former") and b.peut_former(role):
			CommandBus.emettre({"type": "former", "faction": GameRules.PLAYER, "batiment": b.id, "unite": role})
			return
	EventBus.message.emit("Construisez d'abord une Case des Hommes pour former des guerriers.")


func rechercher(tech: String) -> void:
	CommandBus.emettre({"type": "rechercher", "faction": GameRules.PLAYER, "technologie": tech})


func definir_mode_construction(type_batiment: String) -> void:
	mode_construction = type_batiment
	mode_construction_change.emit(mode_construction)
	_fantome_pose = false
	_point_palissade = Vector3.INF
	_maj_apercu_palissade(Vector3.INF)
	_maj_forme_fantome()
	if type_batiment != "":
		var nom: String = GameRules.NOMS_BATIMENTS.get(type_batiment, type_batiment)
		var cout: Dictionary = GameRules.COUTS_BATIMENTS.get(type_batiment, {})
		var geste := "touchez le sol (2 fois pour confirmer)" if DisplayServer.is_touchscreen_available() \
				else "touchez le sol pour le placer"
		if type_batiment == "palissade":
			geste = "touchez un premier point, puis les suivants : la palissade se trace de point en point"
		EventBus.message.emit("%s (%s) : %s." % [nom, ResourceManager.texte_cout(cout), geste])


# --- Aperçu de construction ---

func _maj_forme_fantome() -> void:
	if _fantome == null:
		_fantome = MeshInstance3D.new()
		_mat_fantome.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_fantome.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_fantome.no_depth_test = true
		_fantome.material_override = _mat_fantome
		_fantome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child.call_deferred(_fantome)
	_fantome.visible = false
	if mode_construction == "":
		return
	var e: Vector2 = GameRules.EMPRISES.get(mode_construction, Vector2(3, 3))
	var boite := BoxMesh.new()
	if mode_construction == "palissade":
		boite.size = Vector3(1.0, 1.4, 1.0)   # piquet : marque le point du tracé
	else:
		boite.size = Vector3(e.x, 0.4, e.y)
	_fantome.mesh = boite


## Place le fantôme en pos (monde) et le colore selon la validité. Renvoie true si valide.
func _placer_fantome(pos: Vector3) -> bool:
	if _fantome == null or mode_construction == "" or CommandBus.monde == null:
		return false
	var valide: bool = CommandBus.monde.raison_emplacement_invalide(GameRules.PLAYER, mode_construction, pos) == ""
	_fantome.position = Vector3(pos.x, 0.3, pos.z)   # parent = racine de la scène, à l'origine
	_fantome.rotation.y = 0.0
	_mat_fantome.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if valide else Color(1.0, 0.25, 0.2, 0.45)
	_fantome.visible = true
	return valide


## Mener le troupeau de l'enclos sélectionné au pâturage (avec un gardien), ou le garder au parc.
func basculer_paturage() -> void:
	var e = batiment_selectionne
	if not _batiment_valide(e) or e.type_batiment != "enclos":
		return
	CommandBus.emettre({"type": "paturage", "faction": GameRules.PLAYER, "enclos": e.id, "actif": not e.paturage})


func commercer(action: String) -> void:
	CommandBus.emettre({"type": "commerce", "faction": GameRules.PLAYER, "action": action})


func annuler() -> void:
	definir_mode_construction("")
	_vider()
	selection_changee.emit(selection)


## Retire les unités disparues et le bâtiment détruit (appelé par le HUD).
func nettoyer() -> void:
	selection = selection.filter(func(u) -> bool: return is_instance_valid(u))
	if batiment_selectionne != null and not _batiment_valide(batiment_selectionne):
		selectionner_batiment(null)


## Sélectionne un bâtiment du joueur (null : aucun). Désélectionne les unités.
func selectionner_batiment(b) -> void:
	if b != null:
		_vider_unites()
		selection_changee.emit(selection)
	if b == batiment_selectionne:
		return
	batiment_selectionne = b
	_maj_anneau_batiment()
	batiment_change.emit(b)


func _batiment_valide(b) -> bool:
	return b != null and is_instance_valid(b) and not b.is_queued_for_deletion() and not b.mort


## Bâtiment du joueur sous le point écran, sinon null.
func _batiment_sous(pos: Vector2):
	var hit := _raycast(pos, MASQUE_INTERACTIFS)
	if hit.is_empty():
		return null
	var c = hit.collider
	if c is Batiment and c.faction == GameRules.PLAYER and _batiment_valide(c):
		return c
	return null


## Anneau doré autour du bâtiment sélectionné (dessiné par-dessus le décor).
func _maj_anneau_batiment() -> void:
	if _anneau_batiment == null:
		_anneau_batiment = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.albedo_color = COULEUR_CADRE
		_anneau_batiment.material_override = mat
		_anneau_batiment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child(_anneau_batiment)
	var b = batiment_selectionne
	_anneau_batiment.visible = b != null
	if b == null:
		return
	var e: Vector2 = GameRules.EMPRISES.get(b.type_batiment, Vector2(3, 3))
	var rayon := maxf(e.x, e.y) * 0.5 + 0.6
	var tore := TorusMesh.new()
	tore.inner_radius = rayon
	tore.outer_radius = rayon + 0.25
	_anneau_batiment.mesh = tore
	_anneau_batiment.global_position = Vector3(b.global_position.x, 0.1, b.global_position.z)


# --- Tactile ---

func _toucher(st: InputEventScreenTouch) -> void:
	if st.pressed:
		if _sur_interface(st.position):
			return  # doigt posé sur un bouton : géré par l'interface
		_doigts[st.index] = st.position
		if _doigts.size() == 1:
			_glisse = false
			_distance_glissee = 0.0
		elif _doigts.size() == 2:
			_glisse = true  # un pincement n'est jamais un « toucher »
			_ecart_pincement = _ecart_doigts()
		return
	# Doigt levé : si c'était un toucher simple (sans glisser), on agit.
	if not _doigts.has(st.index):
		return
	var etait_seul := _doigts.size() == 1
	_doigts.erase(st.index)
	if etait_seul and not _glisse:
		_toucher_simple(st.position)


func _glisser_doigt(sd: InputEventScreenDrag) -> void:
	if not _doigts.has(sd.index):
		return
	_doigts[sd.index] = sd.position
	if _doigts.size() == 1:
		_distance_glissee += sd.relative.length()
		if _distance_glissee > SEUIL_GLISSER:
			_glisse = true
		if _glisse and _camera_rig:
			_camera_rig.glisser(sd.relative)
	elif _doigts.size() == 2 and _camera_rig:
		var ecart := _ecart_doigts()
		if _ecart_pincement > 0.0 and ecart > 0.0:
			_camera_rig.zoomer(_ecart_pincement / ecart)
		_ecart_pincement = ecart


func _toucher_simple(pos: Vector2) -> void:
	if mode_construction != "":
		var sol := _raycast(pos, MASQUE_SOL)
		if sol.is_empty():
			return
		# Tactile : 1er toucher = aperçu ; 2e toucher près de l'aperçu = construire (palissade : direct).
		var proche: bool = _fantome_pose and _fantome != null \
				and _fantome.position.distance_to(Vector3(sol.position.x, 0.3, sol.position.z)) < 3.0
		if mode_construction == "palissade" or proche:
			_poser_batiment(pos)
		else:
			_placer_fantome(sol.position)
			_fantome_pose = true
		return
	var a_moi = _unite_sous(pos, func(u) -> bool: return u is Unite and u.faction == GameRules.PLAYER)
	if a_moi != null:
		_vider()
		_ajouter(a_moi)
		selection_changee.emit(selection)
	elif selection.is_empty():
		selectionner_batiment(_batiment_sous(pos))   # toucher ailleurs : désélectionne
	else:
		_ordre(pos)


func _ecart_doigts() -> float:
	var positions := _doigts.values()
	if positions.size() < 2:
		return 0.0
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	return a.distance_to(b)


func _sur_interface(pos: Vector2) -> bool:
	var hud = get_parent()
	return hud != null and hud.has_method("est_sur_interface") and hud.est_sur_interface(pos)


# --- Sélection ---

func _selection_clic(pos: Vector2, ajouter: bool) -> void:
	if not ajouter:
		_vider()
	var a_moi = _unite_sous(pos, func(u) -> bool: return u is Unite and u.faction == GameRules.PLAYER)
	if a_moi != null:
		_ajouter(a_moi)
	elif not ajouter:
		var b = _batiment_sous(pos)
		if b != null:
			selectionner_batiment(b)
			return
	selection_changee.emit(selection)


func _selection_cadre(rect: Rect2, ajouter: bool) -> void:
	if not ajouter:
		_vider()
	var cam := get_viewport().get_camera_3d()
	for u in get_tree().get_nodes_in_group("unites_%d" % GameRules.PLAYER):
		if rect.has_point(cam.unproject_position(u.global_position)):
			_ajouter(u)
	selection_changee.emit(selection)


func _ajouter(u) -> void:
	selectionner_batiment(null)
	if u in selection:
		return
	selection.append(u)
	u.set_selectionne(true)


func _vider() -> void:
	selectionner_batiment(null)
	_vider_unites()


func _vider_unites() -> void:
	for u in selection:
		if is_instance_valid(u):
			u.set_selectionne(false)
	selection.clear()


# --- Ordres ---

func _ordre(pos: Vector2) -> void:
	nettoyer()
	if selection.is_empty():
		return
	var hit := _cible_sous(pos)
	if hit.is_empty():
		return
	var ids: Array = selection.map(func(u) -> int: return u.id)
	var c = hit.collider
	if c is Node3D and not c.is_visible_in_tree():
		c = null  # caché par le brouillard : on traite le clic comme un déplacement
	var cmd := {"faction": GameRules.PLAYER, "unites": ids}
	if (c is Unite and c.faction != GameRules.PLAYER) \
			or (c is Batiment and c.type_batiment == "palissade" and c.faction != GameRules.PLAYER):
		cmd["type"] = "attaquer"
		cmd["cible_id"] = c.id
	elif c is NoeudRessource:
		cmd["type"] = "recolter"
		cmd["cible_id"] = c.id
	elif c is Zebu:
		cmd["type"] = "capturer"
		cmd["cible_id"] = c.id
	elif c is Batiment and c.type_batiment == "enclos" and c.faction != GameRules.PLAYER:
		cmd["type"] = "piller"
		cmd["cible_id"] = c.id
	elif c is Batiment and c.faction == GameRules.PLAYER:
		cmd["type"] = "deposer"
		cmd["cible_id"] = c.id
	else:
		cmd["type"] = "deplacer"
		cmd["cible"] = hit.position
	CommandBus.emettre(cmd)


func _construire_sous_souris(type_batiment: String) -> void:
	mode_construction = type_batiment
	_poser_batiment(get_viewport().get_mouse_position())


func _poser_batiment(pos: Vector2) -> void:
	var hit := _raycast(pos, MASQUE_SOL)
	if mode_construction == "palissade":
		# Le mode reste actif : on trace de point en point jusqu'à « Aucun » / Échap / clic droit.
		if not hit.is_empty():
			_tracer_palissade(hit.position)
		return
	var type_batiment := mode_construction
	definir_mode_construction("")
	if hit.is_empty() or type_batiment == "":
		return
	CommandBus.emettre({"type": "construire", "faction": GameRules.PLAYER,
			"type_batiment": type_batiment, "position": hit.position})


## Tracé de palissade : le 1er point pose un piquet, chaque point suivant relie le précédent
## par des segments jointifs de 4 m. La direction s'aimante par pas de 15° (lignes droites, angles droits).
func _tracer_palissade(point: Vector3) -> void:
	point.y = 0.0
	if _point_palissade == Vector3.INF:
		_placer_fantome(point)
		_point_palissade = point
		EventBus.message.emit("Premier piquet posé : touchez le point suivant.")
		return
	var segments := _segments_palissade(_point_palissade, point)
	if segments.is_empty():
		return
	for s in segments:
		CommandBus.emettre({"type": "construire", "faction": GameRules.PLAYER, "type_batiment": "palissade",
				"position": s[0], "rotation_y": s[1]})
	_point_palissade = segments[-1][2]
	_placer_fantome(_point_palissade)
	_maj_apercu_palissade(Vector3.INF)


## Segments [position, rotation_y, fin du tracé] de depart vers arrivee (direction aimantée, longueur
## arrondie à un nombre entier de segments de 4 m : la ligne finit exactement sur un piquet).
func _segments_palissade(depart: Vector3, arrivee: Vector3) -> Array:
	var trace := arrivee - depart
	trace.y = 0.0
	var longueur := trace.length()
	var longueur_segment: float = GameRules.EMPRISES["palissade"].x
	var nombre := roundi(longueur / longueur_segment)
	if nombre < 1:
		return []
	var pas_angle := deg_to_rad(PAS_ANGLE_PALISSADE)
	var angle := snappedf(atan2(trace.z, trace.x), pas_angle)
	var direction := Vector3(cos(angle), 0.0, sin(angle))
	var rotation_y := atan2(-direction.z, direction.x)
	var fin := depart + direction * longueur_segment * nombre
	var segments: Array = []
	for i in nombre:
		segments.append([depart + direction * longueur_segment * (i + 0.5), rotation_y, fin])
	return segments


## Aperçu (souris) : segments fantômes entre le dernier piquet et le curseur, verts si on peut les poser,
## rouges sinon (point d'eau, arbre, bâtiment…). Vector3.INF : masquer.
func _maj_apercu_palissade(curseur: Vector3) -> void:
	if _apercu_palissade == null:
		_apercu_palissade = Node3D.new()
		get_tree().current_scene.add_child(_apercu_palissade)
	var segments: Array = []
	if curseur != Vector3.INF and _point_palissade != Vector3.INF and mode_construction == "palissade":
		segments = _segments_palissade(_point_palissade, curseur)
	while _apercu_palissade.get_child_count() < segments.size():
		var boite := BoxMesh.new()
		boite.size = Vector3(GameRules.EMPRISES["palissade"].x - 0.15, 1.2, 0.5)
		var instance := MeshInstance3D.new()
		instance.mesh = boite
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		instance.material_override = mat
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apercu_palissade.add_child(instance)
	for k in _apercu_palissade.get_child_count():
		var instance := _apercu_palissade.get_child(k) as MeshInstance3D
		instance.visible = k < segments.size()
		if not instance.visible:
			continue
		var position: Vector3 = segments[k][0]
		instance.position = Vector3(position.x, 0.6, position.z)
		instance.rotation.y = segments[k][1]
		var valide: bool = CommandBus.monde == null \
				or CommandBus.monde.raison_emplacement_invalide(GameRules.PLAYER, "palissade", position) == ""
		(instance.material_override as StandardMaterial3D).albedo_color = \
				Color(0.3, 1.0, 0.4, 0.4) if valide else Color(1.0, 0.25, 0.2, 0.5)


# --- Ciblage : les unités et zébus passent avant les bâtiments ---
# En vue isométrique, une unité derrière une case reste cliquable : on cherche d'abord les unités
# (le rayon ignore alors les bâtiments), puis l'unité la plus proche du doigt / curseur à l'écran,
# et seulement ensuite les bâtiments, ressources et le sol.

## Unité (ou zébu) visible sous le point écran qui passe le filtre, sinon null.
func _unite_sous(pos: Vector2, filtre: Callable):
	var hit := _raycast(pos, MASQUE_UNITES)
	if not hit.is_empty():
		var c = hit.collider
		if c is Node3D and c.is_visible_in_tree() and filtre.call(c):
			return c
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var tolerance := TOLERANCE_DOIGT_PX if DisplayServer.is_touchscreen_available() else TOLERANCE_SOURIS_PX
	var meilleur = null
	var d_min := tolerance
	for groupe in ["unites", "zebus"]:
		for n in get_tree().get_nodes_in_group(groupe):
			if not n.is_visible_in_tree() or not filtre.call(n):
				continue
			var ecran := cam.unproject_position(n.global_position + Vector3(0.0, 0.9, 0.0))
			var d := ecran.distance_to(pos)
			if d < d_min:
				d_min = d
				meilleur = n
	return meilleur


## Cible d'un ordre : unité/zébu en priorité, puis bâtiment/ressource, puis le sol.
func _cible_sous(pos: Vector2) -> Dictionary:
	var u = _unite_sous(pos, func(_n) -> bool: return true)
	if u != null:
		return {"collider": u, "position": u.global_position}
	return _raycast(pos, MASQUE_SOL | MASQUE_INTERACTIFS)


# --- Utilitaires ---

func _rect() -> Rect2:
	return Rect2(_debut, _actuel - _debut).abs()


func _raycast(pos: Vector2, masque: int) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var origine := cam.project_ray_origin(pos)
	var fin := origine + cam.project_ray_normal(pos) * 500.0
	var requete := PhysicsRayQueryParameters3D.create(origine, fin, masque)
	return cam.get_world_3d().direct_space_state.intersect_ray(requete)
