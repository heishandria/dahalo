extends Node
## Stocks par faction, cheptel, consommation d'eau et victoire (GDD §3, §4, §7).

var stocks := {}      # faction -> {"bois": float, "eau": float, "nourriture": float}
var zebus := {}       # faction -> int (zébus sécurisés dans les enclos)
var enclos := {}      # faction -> int (nombre d'enclos)
var population := {}  # faction -> int (villageois)
var assoiffe := {}    # faction -> bool
var partie_finie := false


func initialiser(factions: Array) -> void:
	partie_finie = false
	stocks.clear()
	zebus.clear()
	enclos.clear()
	population.clear()
	assoiffe.clear()
	for f in factions:
		stocks[f] = GameRules.RESSOURCES_DEPART.duplicate()
		zebus[f] = 0
		enclos[f] = 0
		population[f] = 0
		assoiffe[f] = false
		EventBus.ressources_changees.emit(f)
		EventBus.zebus_changes.emit(f)


# --- Ressources ---

func quantite(faction: int, ressource: String) -> float:
	var s: Dictionary = stocks.get(faction, {})
	return s.get(ressource, 0.0)


func ajouter(faction: int, ressource: String, q: float) -> void:
	if not stocks.has(faction):
		return
	stocks[faction][ressource] = maxf(0.0, quantite(faction, ressource) + q)
	EventBus.ressources_changees.emit(faction)


func peut_payer(faction: int, cout: Dictionary) -> bool:
	for r in cout:
		if quantite(faction, r) < float(cout[r]):
			return false
	return true


func payer(faction: int, cout: Dictionary) -> bool:
	if not peut_payer(faction, cout):
		return false
	for r in cout:
		stocks[faction][r] = quantite(faction, r) - float(cout[r])
	EventBus.ressources_changees.emit(faction)
	return true


func multiplicateur_travail(faction: int) -> float:
	return GameRules.MALUS_TRAVAIL_SOIF if assoiffe.get(faction, false) else 1.0


# --- Cheptel ---

func capacite_zebus(faction: int) -> int:
	return int(enclos.get(faction, 0)) * GameRules.CAPACITE_PAR_ENCLOS


func nb_zebus(faction: int) -> int:
	return int(zebus.get(faction, 0))


func a_place(faction: int) -> bool:
	return nb_zebus(faction) < capacite_zebus(faction)


func ajouter_enclos(faction: int) -> void:
	enclos[faction] = int(enclos.get(faction, 0)) + 1
	EventBus.zebus_changes.emit(faction)


func ajouter_villageois(faction: int) -> void:
	population[faction] = int(population.get(faction, 0)) + 1


func zebu_securise(faction: int) -> void:
	zebus[faction] = nb_zebus(faction) + 1
	EventBus.zebus_changes.emit(faction)
	if nb_zebus(faction) >= GameRules.ZEBUS_VICTOIRE:
		terminer(faction)


func zebu_perdu(faction: int) -> void:
	zebus[faction] = maxi(0, nb_zebus(faction) - 1)
	EventBus.zebus_changes.emit(faction)


# --- Consommation d'eau : plus le cheptel est grand, plus il boit ---

func _process(delta: float) -> void:
	if partie_finie:
		return
	for f in stocks:
		var conso: float = (nb_zebus(f) * GameRules.CONSO_EAU_ZEBU_S
				+ int(population.get(f, 0)) * GameRules.CONSO_EAU_VILLAGEOIS_S) * delta
		if conso <= 0.0:
			continue
		stocks[f]["eau"] = maxf(0.0, quantite(f, "eau") - conso)
		var a_soif := quantite(f, "eau") <= 0.0
		if a_soif != assoiffe.get(f, false):
			assoiffe[f] = a_soif
			EventBus.soif.emit(f, a_soif)
			if f == GameRules.PLAYER:
				EventBus.message.emit("Plus d'eau ! Le village travaille au ralenti." if a_soif else "Les réserves d'eau sont reconstituées.")


# --- Fin de partie ---

func fin_au_temps() -> void:
	var gagnant := -1
	var meilleur := -1
	var egalite := false
	for f in zebus:
		var n := nb_zebus(f)
		if n > meilleur:
			meilleur = n
			gagnant = f
			egalite = false
		elif n == meilleur:
			egalite = true
	terminer(-1 if egalite else gagnant)


func terminer(faction_gagnante: int) -> void:
	if partie_finie:
		return
	partie_finie = true
	EventBus.partie_terminee.emit(faction_gagnante)
