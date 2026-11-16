extends CanvasLayer
## HUD (GDD §9) : bandeau des ressources en haut, sélection en bas à gauche,
## boutons d'action en bas à droite (indispensables en tactile), messages, fin de partie.
## Construit en code pour le prototype ; à remplacer par une scène UI dessinée plus tard.

@onready var selection_mgr = $Selection

const TAILLE_BOUTON := Vector2(124, 54)
const AIDE_PC := "Clic gauche : sélectionner (glisser = cadre)  |  Clic droit : attaquer, récolter, capturer, piller, ramener à l'enclos, déplacer\n" \
		+ "1 à 5 : former  |  E : enclos sous la souris  |  ZQSD / flèches / bords : caméra  |  Molette : zoom"
const AIDE_TACTILE := "Touchez une unité puis une cible (ennemi, ressource, zébu, enclos, sol)  |  Glisser : caméra  |  Pincer : zoom"

var _barre: Label
var _info: Label
var _message: Label
var _actions: PanelContainer
var _mini_carte: Control
var _boutons_construction := {}   # type_batiment -> Button
var _bouton_vente: Button
var _ligne_recherche: HBoxContainer
var _fin: PanelContainer
var _fin_texte: Label
var _duree_message := 0.0
var _tactile := false


func _ready() -> void:
	_tactile = DisplayServer.is_touchscreen_available()
	_construire_ui()
	EventBus.message.connect(_afficher_message)
	EventBus.partie_terminee.connect(_on_fin)
	selection_mgr.mode_construction_change.connect(_on_mode_construction)
	EventBus.technologies_changees.connect(_on_technologies_changees)


func _process(delta: float) -> void:
	_maj_barre()
	_maj_selection()
	if _duree_message > 0.0:
		_duree_message -= delta
		_message.modulate.a = clampf(_duree_message, 0.0, 1.0)


## Utilisé par la sélection tactile pour ne pas traverser les boutons.
func est_sur_interface(pos: Vector2) -> bool:
	for c in [_actions, _fin, _mini_carte]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	return false


func _maj_barre() -> void:
	var f := GameRules.PLAYER
	var restant := int(GameClock.temps_restant())
	var alerte := "   |   CHEPTEL EN MANQUE !" if ResourceManager.en_manque.get(f, false) else ""
	_barre.text = ("Âge %d   |   Nourriture %d (-%d/min)   Eau %d (-%d/min)   Bois %d   Ariary %d   |   Zébus %d/%d   |   %s · %s   |   %02d:%02d   |   Rival : %d zébus%s") % [
		ResourceManager.age(f),
		int(ResourceManager.quantite(f, "nourriture")),
		int(ResourceManager.conso_par_minute(f, "nourriture")),
		int(ResourceManager.quantite(f, "eau")),
		int(ResourceManager.conso_par_minute(f, "eau")),
		int(ResourceManager.quantite(f, "bois")),
		int(ResourceManager.quantite(f, "ariary")),
		ResourceManager.nb_zebus(f),
		ResourceManager.capacite_zebus(f),
		"Sécheresse" if GameClock.secheresse else "Saison normale",
		"Nuit" if GameClock.est_nuit else "Jour",
		restant / 60, restant % 60,
		ResourceManager.nb_zebus(GameRules.AI),
		alerte,
	]
	_bouton_vente.text = "Vendre zébu\n%d Ar" % int(GameRules.prix_zebu_actuel(false, f))


func _maj_selection() -> void:
	selection_mgr.nettoyer()
	var aide := AIDE_TACTILE if _tactile else AIDE_PC
	var sel: Array = selection_mgr.selection
	if sel.is_empty():
		_info.text = "Aucune sélection\n" + aide
		return
	var comptes := {}
	var escorte := 0
	for u in sel:
		comptes[u.data.nom] = comptes.get(u.data.nom, 0) + 1
		escorte += u.zebus_escortes.size()
	var parties := PackedStringArray()
	for nom in comptes:
		parties.append("%d %s" % [comptes[nom], nom])
	var texte := "Sélection : " + ", ".join(parties)
	if escorte > 0:
		texte += "  |  Zébus escortés : %d" % escorte
	_info.text = texte + "\n" + aide


func _afficher_message(texte: String) -> void:
	_message.text = texte
	_duree_message = 4.0
	_message.modulate.a = 1.0


func _on_technologies_changees(faction: int) -> void:
	if faction == GameRules.PLAYER:
		_maj_ligne_recherche()


## Ligne « Recherche » : uniquement ce qui est accessible à l'âge actuel (et le passage à l'âge suivant).
func _maj_ligne_recherche() -> void:
	for i in range(_ligne_recherche.get_child_count() - 1, 0, -1):
		_ligne_recherche.get_child(i).queue_free()
	var f := GameRules.PLAYER
	for tech in GameRules.TECHNOLOGIES:
		if not ResourceManager.technologie_accessible(f, tech):
			continue
		var def: Dictionary = GameRules.TECHNOLOGIES[tech]
		var b := Button.new()
		b.text = String(def["court"])
		b.custom_minimum_size = Vector2(TAILLE_BOUTON.x * 0.82, TAILLE_BOUTON.y)
		b.add_theme_font_size_override("font_size", 15)
		b.focus_mode = Control.FOCUS_NONE
		var batiment: String = GameRules.NOMS_BATIMENTS.get(def["batiment"], def["batiment"])
		b.tooltip_text = "%s : %s (%s, %s, %d s)" % [def["nom"], def["effet"], ResourceManager.texte_cout(def["cout"]),
				batiment, int(def["temps"])]
		b.pressed.connect(_lancer_recherche.bind(tech))
		_ligne_recherche.add_child(b)


func _lancer_recherche(tech: String) -> void:
	selection_mgr.rechercher(tech)


func _on_mode_construction(type_batiment: String) -> void:
	for t in _boutons_construction:
		_boutons_construction[t].modulate = Color(1.0, 0.85, 0.4) if t == type_batiment else Color.WHITE


func _on_fin(faction_gagnante: int) -> void:
	if faction_gagnante == GameRules.PLAYER:
		_fin_texte.text = "Victoire !\nVotre clan est le seigneur incontesté de la brousse."
	elif faction_gagnante == GameRules.AI:
		_fin_texte.text = "Défaite…\nLe clan rival possède le plus grand cheptel."
	else:
		_fin_texte.text = "Égalité.\nLes deux clans ont le même cheptel."
	_fin.visible = true
	get_tree().paused = true


func _rejouer() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- Construction de l'interface ---

func _construire_ui() -> void:
	# Bandeau supérieur
	var haut := PanelContainer.new()
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(haut)
	haut.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_barre = Label.new()
	_barre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_barre.add_theme_font_size_override("font_size", 18)
	haut.add_child(_barre)

	# Mini-carte (haut gauche, sous le bandeau)
	_mini_carte = preload("res://ui/mini_carte.gd").new()
	add_child(_mini_carte)
	_mini_carte.position = Vector2(8, 46)

	# Infos de sélection (bas gauche)
	var bas := PanelContainer.new()
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bas)
	bas.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bas.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 16)
	bas.add_child(_info)

	# Boutons d'action (bas droite)
	_actions = PanelContainer.new()
	add_child(_actions)
	_actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var lignes := VBoxContainer.new()
	_actions.add_child(lignes)
	lignes.add_child(_ligne_boutons("Choisir", [
		["Villageois", selection_mgr.selectionner_type.bind("villageois")],
		["Dahalo", selection_mgr.selectionner_type.bind("dahalo")],
		["Guerriers", selection_mgr.selectionner_type.bind("guerriers")],
		["Pisteur", selection_mgr.selectionner_type.bind("pisteur")],
		["Aucun", selection_mgr.annuler],
	]))
	lignes.add_child(_ligne_boutons("Former", [
		["+ Villageois", selection_mgr.former.bind("villageois")],
		["+ Dahalo", selection_mgr.former.bind("dahalo")],
		["+ Pisteur", selection_mgr.former.bind("pisteur")],
		["+ Lanceur", selection_mgr.former.bind("lanceur")],
		["+ Tireur", selection_mgr.former.bind("tireur")],
	]))
	_ajouter_ligne_construction(lignes, "Village", [["enclos", "Enclos"], ["champ", "Champ"],
			["camp_bois", "Camp bois"], ["puits", "Puits"]])
	_ajouter_ligne_construction(lignes, "Clan", [["tsena", "Tsena"],
			["case_hommes", "Case\nHommes"], ["palissade", "Palissade"]])
	_ligne_recherche = _ligne_boutons("Recherche", [])
	lignes.add_child(_ligne_recherche)
	_maj_ligne_recherche()
	var ligne_tsena := _ligne_boutons("Tsena", [
		["Vendre zébu", selection_mgr.commercer.bind("vendre_zebu")],
		["+50 bois\n30 Ar", selection_mgr.commercer.bind("acheter_bois")],
		["+50 nourr.\n30 Ar", selection_mgr.commercer.bind("acheter_nourriture")],
		["Acheter\nzébu", selection_mgr.commercer.bind("acheter_zebu")],
	])
	lignes.add_child(ligne_tsena)
	_bouton_vente = ligne_tsena.get_child(1)

	# Messages d'alerte
	_message = Label.new()
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 24)
	_message.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_message.offset_top = 56.0
	_message.offset_bottom = 100.0
	_message.modulate.a = 0.0

	# Fin de partie
	_fin = PanelContainer.new()
	_fin.visible = false
	add_child(_fin)
	_fin.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_fin.offset_left = -280.0
	_fin.offset_right = 280.0
	_fin.offset_top = -120.0
	_fin.offset_bottom = 120.0
	var boite := VBoxContainer.new()
	boite.alignment = BoxContainer.ALIGNMENT_CENTER
	boite.add_theme_constant_override("separation", 24)
	_fin.add_child(boite)
	_fin_texte = Label.new()
	_fin_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fin_texte.add_theme_font_size_override("font_size", 26)
	boite.add_child(_fin_texte)
	var rejouer := Button.new()
	rejouer.text = "Rejouer"
	rejouer.custom_minimum_size = TAILLE_BOUTON
	rejouer.add_theme_font_size_override("font_size", 22)
	rejouer.pressed.connect(_rejouer)
	boite.add_child(rejouer)


func _ajouter_ligne_construction(lignes: VBoxContainer, titre: String, batiments: Array) -> HBoxContainer:
	var defs: Array = []
	for b in batiments:
		defs.append([b[1], selection_mgr.definir_mode_construction.bind(b[0])])
	var ligne := _ligne_boutons(titre, defs)
	lignes.add_child(ligne)
	for i in batiments.size():
		var bouton: Button = ligne.get_child(i + 1)
		var cout: Dictionary = GameRules.COUTS_BATIMENTS[batiments[i][0]]
		bouton.tooltip_text = ResourceManager.texte_cout(cout)
		_boutons_construction[batiments[i][0]] = bouton
	return ligne


func _ligne_boutons(titre: String, boutons: Array) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	var etiquette := Label.new()
	etiquette.text = titre
	etiquette.custom_minimum_size = Vector2(80, 0)
	etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiquette.add_theme_font_size_override("font_size", 18)
	ligne.add_child(etiquette)
	for def in boutons:
		var b := Button.new()
		b.text = def[0]
		b.custom_minimum_size = TAILLE_BOUTON
		b.add_theme_font_size_override("font_size", 16)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(def[1])
		ligne.add_child(b)
	return ligne
