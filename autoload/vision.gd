extends Node
## Brouillard de guerre : ce que chaque clan voit (maintenant) et a déjà exploré.
## Grille de cases carrées sur toute la carte, recalculée plusieurs fois par seconde.
## Spec : docs/specs/vision.md

const N := 120   # = 2 × GameRules.DEMI_CARTE / GameRules.TAILLE_CASE_VISION (vérifié dans initialiser)

var vu := {}        # faction -> PackedByteArray (1 = visible maintenant)
var explore := {}   # faction -> PackedByteArray (1 = déjà exploré)
var revele_tout := false   # triche de débogage (touche F9, builds de debug uniquement)
var _chrono := 0.0


func initialiser(factions: Array) -> void:
	assert(N == int(2.0 * GameRules.DEMI_CARTE / GameRules.TAILLE_CASE_VISION), "Vision.N incohérent avec GameRules")
	vu.clear()
	explore.clear()
	revele_tout = false
	for f in factions:
		var a := PackedByteArray()
		a.resize(N * N)
		var b := PackedByteArray()
		b.resize(N * N)
		vu[f] = a
		explore[f] = b
	_calculer()


func _process(delta: float) -> void:
	_chrono += delta
	if _chrono < GameRules.FREQUENCE_VISION_S:
		return
	_chrono = 0.0
	_calculer()


# --- Requêtes ---

func est_visible(faction: int, pos: Vector3) -> bool:
	if faction == GameRules.PLAYER and revele_tout:
		return true
	if not vu.has(faction):
		return true
	var grille: PackedByteArray = vu[faction]
	return grille[_indice(pos)] == 1


func est_explore(faction: int, pos: Vector3) -> bool:
	if faction == GameRules.PLAYER and revele_tout:
		return true
	if not explore.has(faction):
		return true
	var grille: PackedByteArray = explore[faction]
	return grille[_indice(pos)] == 1


## Rayon de vision actuel d'une unité (réduit la nuit, moins pour le Pisteur).
func rayon_unite(u) -> float:
	var r: float = u.data.vision
	if GameClock.est_nuit:
		r *= u.data.facteur_vision_nuit
	return r


func rayon_batiment() -> float:
	var r := GameRules.VISION_BATIMENT
	if GameClock.est_nuit:
		r *= GameRules.VISION_NUIT
	return r


# --- Calcul ---

func _calculer() -> void:
	for f in vu.keys():
		var grille_vu := PackedByteArray()
		grille_vu.resize(N * N)
		var grille_explore: PackedByteArray = explore[f]
		for u in get_tree().get_nodes_in_group("unites_%d" % f):
			_reveler(grille_vu, grille_explore, u.global_position, rayon_unite(u))
		for b in get_tree().get_nodes_in_group("batiments_%d" % f):
			_reveler(grille_vu, grille_explore, b.global_position, rayon_batiment())
		vu[f] = grille_vu
		explore[f] = grille_explore
	EventBus.vision_maj.emit()


func _reveler(grille_vu: PackedByteArray, grille_explore: PackedByteArray, pos: Vector3, rayon: float) -> void:
	var t := GameRules.TAILLE_CASE_VISION
	var cx := int((pos.x + GameRules.DEMI_CARTE) / t)
	var cz := int((pos.z + GameRules.DEMI_CARTE) / t)
	var r := rayon / t
	var rc := int(ceil(r))
	var r2 := r * r
	for dz in range(-rc, rc + 1):
		var z := cz + dz
		if z < 0 or z >= N:
			continue
		for dx in range(-rc, rc + 1):
			var x := cx + dx
			if x < 0 or x >= N or dx * dx + dz * dz > r2:
				continue
			var i := z * N + x
			grille_vu[i] = 1
			grille_explore[i] = 1


func _indice(pos: Vector3) -> int:
	var t := GameRules.TAILLE_CASE_VISION
	var x := clampi(int((pos.x + GameRules.DEMI_CARTE) / t), 0, N - 1)
	var z := clampi(int((pos.z + GameRules.DEMI_CARTE) / t), 0, N - 1)
	return z * N + x
