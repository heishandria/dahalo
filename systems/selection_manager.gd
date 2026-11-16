extends Control
## Sélection et ordres du joueur, à la souris (PC) ou au doigt (mobile / navigateur).
##
## Souris (façon Age of Empires) :
##  - clic gauche : sélectionner une unité (Maj = ajouter) ; glisser = cadre de sélection
##  - clic droit : ordre contextuel (récolter, capturer un zébu, ramener à l'enclos, déplacer)
##  - touches : 1/2/3 former, E construire un enclos sous la souris, Échap désélectionner
## Tactile :
##  - toucher une de ses unités : la sélectionner
##  - toucher autre chose avec une sélection : ordre contextuel
##  - glisser un doigt : déplacer la caméra ; pincer : zoomer
##  - boutons du HUD : sélection par type, formation, construction
## Ne modifie jamais le jeu directement : tout passe par CommandBus.

signal selection_changee(unites: Array)
signal mode_construction_change(type_batiment: String)

const SEUIL_CADRE := 6.0
const SEUIL_GLISSER := 14.0
const MASQUE_SOL := 1
const MASQUE_UNITES := 2
const MASQUE_INTERACTIFS := 4
const COULEUR_CADRE := Color(1.0, 0.85, 0.4)

var selection: Array = []
var mode_construction := ""     # "" ou "enclos" : le prochain clic / toucher pose le bâtiment

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

func selectionner_type(role: String) -> void:
	_vider()
	for u in get_tree().get_nodes_in_group("unites_%d" % GameRules.PLAYER):
		if u.data.role == role:
			_ajouter(u)
	selection_changee.emit(selection)


func former(role: String) -> void:
	for b in get_tree().get_nodes_in_group("batiments_%d" % GameRules.PLAYER):
		if b.type_batiment == "case_centrale":
			CommandBus.emettre({"type": "former", "faction": GameRules.PLAYER, "batiment": b.id, "unite": role})
			return


func definir_mode_construction(type_batiment: String) -> void:
	mode_construction = type_batiment
	mode_construction_change.emit(mode_construction)
	if type_batiment != "":
		EventBus.message.emit("Touchez le sol pour placer l'enclos.")


func annuler() -> void:
	definir_mode_construction("")
	_vider()
	selection_changee.emit(selection)


## Retire les unités disparues (appelé par le HUD).
func nettoyer() -> void:
	selection = selection.filter(func(u) -> bool: return is_instance_valid(u))


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
		_poser_batiment(pos)
		return
	var hit := _raycast(pos, MASQUE_SOL | MASQUE_UNITES | MASQUE_INTERACTIFS)
	if hit.is_empty():
		return
	var c = hit.collider
	if c is Unite and c.faction == GameRules.PLAYER:
		_vider()
		_ajouter(c)
		selection_changee.emit(selection)
	elif not selection.is_empty():
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
	var hit := _raycast(pos, MASQUE_UNITES | MASQUE_INTERACTIFS)
	if not hit.is_empty():
		var c = hit.collider
		if c is Unite and c.faction == GameRules.PLAYER:
			_ajouter(c)
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
	if u in selection:
		return
	selection.append(u)
	u.set_selectionne(true)


func _vider() -> void:
	for u in selection:
		if is_instance_valid(u):
			u.set_selectionne(false)
	selection.clear()


# --- Ordres ---

func _ordre(pos: Vector2) -> void:
	nettoyer()
	if selection.is_empty():
		return
	var hit := _raycast(pos, MASQUE_SOL | MASQUE_UNITES | MASQUE_INTERACTIFS)
	if hit.is_empty():
		return
	var ids: Array = selection.map(func(u) -> int: return u.id)
	var c = hit.collider
	var cmd := {"faction": GameRules.PLAYER, "unites": ids}
	if c is NoeudRessource:
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
	var type_batiment := mode_construction
	definir_mode_construction("")
	var hit := _raycast(pos, MASQUE_SOL)
	if hit.is_empty() or type_batiment == "":
		return
	CommandBus.emettre({"type": "construire", "faction": GameRules.PLAYER,
			"type_batiment": type_batiment, "position": hit.position})


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
