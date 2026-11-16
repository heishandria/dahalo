extends Node
## Horloge de partie : temps écoulé, cycle jour/nuit, sécheresse (GDD §7).

var temps_ecoule := 0.0
var est_nuit := false
var secheresse := false
var en_pause := false


func reinitialiser() -> void:
	temps_ecoule = 0.0
	est_nuit = false
	secheresse = false
	en_pause = false


func _process(delta: float) -> void:
	if en_pause:
		return
	temps_ecoule += delta

	var cycle := temps_ecoule / GameRules.DUREE_JOUR_S
	var nuit := phase_jour() >= 1.0 - GameRules.PART_NUIT
	if nuit != est_nuit:
		est_nuit = nuit
		EventBus.cycle_change.emit(est_nuit)
		EventBus.message.emit("La nuit tombe : les Dahalo sortent." if est_nuit else "Le jour se lève.")

	var periode := GameRules.CYCLES_ENTRE_SECHERESSES + GameRules.DUREE_SECHERESSE_CYCLES
	var sec := int(floor(cycle)) % periode >= GameRules.CYCLES_ENTRE_SECHERESSES
	if sec != secheresse:
		secheresse = sec
		EventBus.meteo_change.emit(secheresse)
		EventBus.message.emit("La sécheresse frappe la brousse !" if secheresse else "Les pluies sont revenues.")

	if temps_ecoule >= GameRules.DUREE_PARTIE_S:
		en_pause = true
		ResourceManager.fin_au_temps()


## Position dans le cycle courant, de 0.0 (aube) à 1.0.
func phase_jour() -> float:
	return fmod(temps_ecoule / GameRules.DUREE_JOUR_S, 1.0)


func temps_restant() -> float:
	return maxf(0.0, GameRules.DUREE_PARTIE_S - temps_ecoule)
