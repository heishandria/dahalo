extends CanvasLayer
## HUD (GDD §9) : bandeau des ressources en haut, sélection en bas à gauche,
## boutons d'action en bas à droite (indispensables en tactile), messages, fin de partie.
## Bâtiment sélectionné : panneau contextuel (état, formations, recherches, commerce, avec leurs coûts).
## Spec : docs/specs/interface.md
## Construit en code pour le prototype ; à remplacer par une scène UI dessinée plus tard.

@onready var selection_mgr = $Selection

const TAILLE_BOUTON := Vector2(124, 54)
const AIDE_PC := "Clic gauche : sélectionner une unité ou un bâtiment (glisser = cadre)\n" \
		+ "Clic droit : attaquer, récolter, capturer, piller, ramener à l'enclos, déplacer\n" \
		+ "1 à 5 : former  |  E : enclos sous la souris  |  ZQSD / flèches / bords : caméra  |  Molette : zoom"
const AIDE_TACTILE := "Touchez une unité, puis sa cible (ennemi, ressource, zébu, enclos, sol)\n" \
		+ "Sans sélection, touchez un bâtiment : ses actions\n" \
		+ "Glisser : caméra  |  Pincer : zoom"
const ACTIONS_TSENA := ["vendre_zebu", "acheter_bois", "acheter_nourriture", "vendre_bois", "vendre_nourriture", "acheter_zebu"]
const NOMS_COURTS := {"nourriture": "nourr.", "bois": "bois", "eau": "eau", "ariary": "Ar"}
const COULEUR_TROP_CHER := Color(1.0, 0.62, 0.55)

var _barre: Label
var _info: Label
var _message: Label
var _actions: PanelContainer
var _mini_carte: Control
var _boutons_construction := {}   # type_batiment -> Button
# Panneau contextuel du bâtiment sélectionné
var _contexte: VBoxContainer
var _contexte_titre: Label
var _contexte_etat: Label
var _contexte_boutons: VBoxContainer
var _boutons_dynamiques: Array = []   # [Button, Callable] : le Callable renvoie {texte, actif, payable}
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
	selection_mgr.batiment_change.connect(_on_batiment_change)


func _process(delta: float) -> void:
	_maj_barre()
	_maj_selection()
	_maj_contexte()
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


func _maj_selection() -> void:
	selection_mgr.nettoyer()
	var aide := AIDE_TACTILE if _tactile else AIDE_PC
	var sel: Array = selection_mgr.selection
	var b = selection_mgr.batiment_selectionne
	if b != null:
		_info.text = "Bâtiment : %s\n%s" % [_nom_batiment(b.type_batiment), aide]
		return
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
		_remplir_contexte()


func _on_batiment_change(_batiment) -> void:
	_remplir_contexte()


# --- Panneau contextuel du bâtiment sélectionné ---

## Recrée les boutons du bâtiment sélectionné (au changement de bâtiment ou de technologies).
func _remplir_contexte() -> void:
	for c in _contexte_boutons.get_children():
		_contexte_boutons.remove_child(c)
		c.queue_free()
	_boutons_dynamiques.clear()
	var b = selection_mgr.batiment_selectionne
	_contexte.visible = b != null
	if b == null:
		return
	_contexte_titre.text = _nom_batiment(b.type_batiment)
	var roles: Array = GameRules.FORMATIONS.get(b.type_batiment, [])
	if not roles.is_empty():
		var ligne := _ligne_contexte("Former")
		for role in roles:
			var data: UnitData = CommandBus.monde.donnees_unite(role)
			_bouton_contexte(ligne, selection_mgr.former.bind(role), _etat_formation.bind(role), data.description)
	if b.type_batiment == "tsena":
		var ligne := _ligne_contexte("Marché")
		for action in ACTIONS_TSENA:
			_bouton_contexte(ligne, selection_mgr.commercer.bind(action), _etat_commerce.bind(action), "")
	var ligne_recherche: HBoxContainer = null
	for tech in GameRules.TECHNOLOGIES:
		var def: Dictionary = GameRules.TECHNOLOGIES[tech]
		if def["batiment"] != b.type_batiment or not ResourceManager.technologie_accessible(GameRules.PLAYER, tech):
			continue
		if ligne_recherche == null:
			ligne_recherche = _ligne_contexte("Recherche")
		var infobulle := "%s : %s (%d s)" % [def["nom"], def["effet"], int(def["temps"])]
		_bouton_contexte(ligne_recherche, selection_mgr.rechercher.bind(tech), _etat_recherche.bind(tech), infobulle)
	_maj_contexte()


## Met à jour l'état et les boutons (textes, prix, disponibilité) à chaque image.
func _maj_contexte() -> void:
	var b = selection_mgr.batiment_selectionne
	if b == null:
		if _contexte.visible:
			_remplir_contexte()
		return
	_contexte_etat.text = _texte_etat(b)
	_contexte_etat.visible = _contexte_etat.text != ""
	for entree in _boutons_dynamiques:
		var bouton: Button = entree[0]
		var etat: Dictionary = entree[1].call()
		bouton.text = etat["texte"]
		bouton.disabled = not etat["actif"]
		bouton.modulate = Color.WHITE if etat.get("payable", true) else COULEUR_TROP_CHER


func _texte_etat(b) -> String:
	var f := GameRules.PLAYER
	var lignes := PackedStringArray()
	match b.type_batiment:
		"case_centrale":
			lignes.append("Dépôt de toutes les ressources")
		"camp_bois":
			lignes.append("Dépôt de bois : les villageois y déposent le bois coupé")
		"enclos":
			var ici := 0
			for z in get_tree().get_nodes_in_group("zebus"):
				if z.enclos == b and z.etat == Zebu.Etat.ENCLOS:
					ici += 1
			lignes.append("Zébus dans cet enclos : %d   |   Cheptel : %d / %d" % [ici, ResourceManager.nb_zebus(f),
					ResourceManager.capacite_zebus(f)])
		"palissade":
			lignes.append("Solidité : %d / %d" % [int(b.pv), int(GameRules.PALISSADE_PV)])
	if b.en_formation > 0:
		var prochaine := INF
		for fin in b.fins_formation:
			prochaine = minf(prochaine, fin)
		lignes.append("Formation : %d en cours (prochaine dans %d s)" % [b.en_formation,
				maxi(0, ceili(prochaine - GameClock.temps_ecoule))])
	if b.en_recherche != "":
		var def: Dictionary = GameRules.TECHNOLOGIES[b.en_recherche]
		lignes.append("Recherche : %s (%d s)" % [def["nom"], maxi(0, ceili(b.fin_recherche - GameClock.temps_ecoule))])
	return "\n".join(lignes)


func _etat_formation(role: String) -> Dictionary:
	var f := GameRules.PLAYER
	var data: UnitData = CommandBus.monde.donnees_unite(role)
	var texte := "+ %s\n" % data.nom
	if ResourceManager.age(f) < data.age_requis:
		return {"texte": texte + "Âge %d" % data.age_requis, "actif": false}
	if data.requiert != "" and not CommandBus.monde.possede(f, data.requiert):
		return {"texte": texte + "Il faut un %s" % _nom_batiment(data.requiert), "actif": false}
	return {"texte": texte + _cout_court(data.cout), "actif": true, "payable": ResourceManager.peut_payer(f, data.cout)}


func _etat_recherche(tech: String) -> Dictionary:
	var f := GameRules.PLAYER
	var def: Dictionary = GameRules.TECHNOLOGIES[tech]
	var texte := String(def["court"]) + "\n"
	var b = selection_mgr.batiment_selectionne
	var occupe: String = b.en_recherche if b != null else ""
	if occupe == tech:
		return {"texte": texte + "en cours…", "actif": false}
	var cout: Dictionary = def["cout"]
	# Une seule recherche à la fois par bâtiment.
	return {"texte": texte + _cout_court(cout), "actif": occupe == "", "payable": ResourceManager.peut_payer(f, cout)}


func _etat_commerce(action: String) -> Dictionary:
	var f := GameRules.PLAYER
	var ariary := ResourceManager.quantite(f, "ariary")
	match action:
		"vendre_zebu":
			return {"texte": "Vendre zébu\n+%d Ar" % int(GameRules.prix_zebu_actuel(false, f)), "actif": true,
					"payable": ResourceManager.nb_zebus(f) > 0}
		"acheter_bois", "acheter_nourriture":
			var r := action.trim_prefix("acheter_")
			var offre: Dictionary = GameRules.ACHATS[r]
			var prix := GameRules.prix_achat(f, float(offre["prix"]))
			return {"texte": "+%d %s\n%d Ar" % [int(offre["quantite"]), NOMS_COURTS[r], int(prix)], "actif": true,
					"payable": ariary >= prix}
		"vendre_bois", "vendre_nourriture":
			var r := action.trim_prefix("vendre_")
			var offre: Dictionary = GameRules.VENTES[r]
			var prix := GameRules.prix_vente_surplus(f, float(offre["prix"]))
			return {"texte": "Vendre %d %s\n+%d Ar" % [int(offre["quantite"]), NOMS_COURTS[r], int(prix)], "actif": true,
					"payable": ResourceManager.quantite(f, r) >= float(offre["quantite"])}
		"acheter_zebu":
			if not ResourceManager.a_technologie(f, "maitres_tsena"):
				return {"texte": "Acheter zébu\nMaîtres du Tsena", "actif": false}
			return {"texte": "Acheter zébu\n%d Ar" % int(GameRules.PRIX_ZEBU_REPRODUCTEUR), "actif": true,
					"payable": ariary >= GameRules.PRIX_ZEBU_REPRODUCTEUR and ResourceManager.a_place(f)}
	return {"texte": action, "actif": false}


## « 100 nourr. 50 bois 40 Ar » : tient sur la 2e ligne d'un bouton.
func _cout_court(cout: Dictionary) -> String:
	var parties := PackedStringArray()
	for r in cout:
		parties.append("%d %s" % [int(cout[r]), NOMS_COURTS.get(r, r)])
	return " ".join(parties)


func _nom_batiment(type_batiment: String) -> String:
	return GameRules.NOMS_BATIMENTS.get(type_batiment, type_batiment)


func _ligne_contexte(titre: String) -> HBoxContainer:
	var ligne := _ligne_boutons(titre, [])
	_contexte_boutons.add_child(ligne)
	return ligne


func _bouton_contexte(ligne: HBoxContainer, action: Callable, etat: Callable, infobulle: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = TAILLE_BOUTON
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = infobulle
	b.pressed.connect(action)
	ligne.add_child(b)
	_boutons_dynamiques.append([b, etat])


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
	_contexte = VBoxContainer.new()
	_contexte.visible = false
	lignes.add_child(_contexte)
	_contexte_titre = Label.new()
	_contexte_titre.add_theme_font_size_override("font_size", 20)
	_contexte_titre.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_contexte.add_child(_contexte_titre)
	_contexte_etat = Label.new()
	_contexte_etat.add_theme_font_size_override("font_size", 15)
	_contexte.add_child(_contexte_etat)
	_contexte_boutons = VBoxContainer.new()
	_contexte.add_child(_contexte_boutons)
	_contexte.add_child(HSeparator.new())
	lignes.add_child(_ligne_boutons("Choisir", [
		["Villageois", selection_mgr.selectionner_type.bind("villageois")],
		["Dahalo", selection_mgr.selectionner_type.bind("dahalo")],
		["Guerriers", selection_mgr.selectionner_type.bind("guerriers")],
		["Pisteur", selection_mgr.selectionner_type.bind("pisteur")],
		["Aucun", selection_mgr.annuler],
	]))
	_ajouter_ligne_construction(lignes, "Village", [["enclos", "Enclos"], ["champ", "Champ"],
			["camp_bois", "Camp bois"], ["puits", "Puits"]])
	_ajouter_ligne_construction(lignes, "Clan", [["tsena", "Tsena"],
			["case_hommes", "Case\nHommes"], ["palissade", "Palissade"]])

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
