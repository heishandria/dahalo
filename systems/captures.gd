extends Node
## Captures d'écran automatiques (CI) : `godot --path . -- --captures=<dossier>` joue un court scénario
## et enregistre des images PNG, puis quitte. Le joueur ne joue pas ; l'IA, si.
## Il faut un vrai rendu (pas --headless) : la CI utilise un écran virtuel (xvfb) et le rendu Compatibility.
## Outil de vérification seulement : sélection et caméra, aucune action de jeu.

const ACCELERATION := 8.0

var dossier := "user://captures"
var _numero := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			dossier = arg.trim_prefix("--captures=")
	if DisplayServer.get_name() == "headless":
		push_error("Captures impossibles sans rendu (--headless) : lancer avec un écran, même virtuel (xvfb).")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dossier)
	print("[captures] dossier : ", ProjectSettings.globalize_path(dossier))
	_scenario.call_deferred()


func _scenario() -> void:
	var monde := get_parent()
	var rig = monde.get_node("CameraRig")
	var selection = monde.find_child("Selection", true, false)
	var base_joueur: Vector3 = monde.carte["reperes"][GameRules.PLAYER]["base"]
	var base_ia: Vector3 = monde.carte["reperes"][GameRules.AI]["base"]
	rig.defilement_bord = false   # la souris ne doit pas déplacer la caméra pendant le scénario

	await _attendre_temps_de_jeu(1.0)
	rig.centrer_sur(base_joueur)
	await _capturer("depart")
	# Bord de carte le plus proche de la base : raccord entre la zone de jeu et le relief.
	var bord := base_joueur
	if absf(bord.x) > absf(bord.z):
		bord.x = signf(bord.x) * (GameRules.DEMI_CARTE + 2.0)
	else:
		bord.z = signf(bord.z) * (GameRules.DEMI_CARTE + 2.0)
	rig.centrer_sur(bord)
	await _capturer("bordure_relief")
	# Lit de rivière, autour du trou d'eau le plus proche du centre (carte révélée le temps de la capture).
	var trou = null
	for r in get_tree().get_nodes_in_group("ressource_eau"):
		if Terrain.dans_riviere(r.global_position) and (trou == null or r.global_position.length() < trou.global_position.length()):
			trou = r
	if trou != null:
		Vision.revele_tout = true
		rig.centrer_sur(trou.global_position)
		await _attendre_brouillard()
		await _capturer("riviere")
		Vision.revele_tout = false
	rig.centrer_sur(base_joueur)

	for b in get_tree().get_nodes_in_group("case_centrale"):
		if b.faction == GameRules.PLAYER:
			selection.selectionner_batiment(b)
	await _capturer("panneau_case_centrale")
	selection.annuler()

	# Nuit : elle commence à 65 % du premier cycle.
	get_parent().accelerer(ACCELERATION)
	await _attendre_temps_de_jeu(GameRules.DUREE_JOUR_S * (1.0 - GameRules.PART_NUIT) + 10.0)
	get_parent().accelerer(1.0)
	selection.annuler()
	await _capturer("nuit")

	# Base de l'IA après 5 minutes, carte révélée (débogage).
	get_parent().accelerer(ACCELERATION)
	await _attendre_temps_de_jeu(300.0)
	get_parent().accelerer(1.0)
	Vision.revele_tout = true
	selection.annuler()
	rig.centrer_sur(base_ia)
	await _attendre_brouillard()
	await _capturer("base_ia_5min")

	rig.centrer_sur(Vector3.ZERO)
	rig.zoomer(rig.zoom_max / rig.camera.size)
	await _attendre_images(10)
	await _capturer("vue_ensemble_5min")

	print("[captures] %d images" % _numero)
	get_tree().quit()


func _attendre_temps_de_jeu(secondes: float) -> void:
	while GameClock.temps_ecoule < secondes:
		await get_tree().process_frame


## Le brouillard n'est recalculé que toutes les FREQUENCE_VISION_S : on lui laisse le temps.
func _attendre_brouillard() -> void:
	await get_tree().create_timer(GameRules.FREQUENCE_VISION_S * 3.0).timeout
	await _attendre_images(5)


func _attendre_images(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capturer(nom: String) -> void:
	await _attendre_images(5)   # laisser l'interface et le brouillard se mettre à jour
	await RenderingServer.frame_post_draw
	_numero += 1
	var chemin := "%s/%02d_%s.png" % [dossier, _numero, nom]
	var erreur := get_viewport().get_texture().get_image().save_png(chemin)
	print("[captures] %s%s" % [chemin, "" if erreur == OK else " : ÉCHEC (%d)" % erreur])
