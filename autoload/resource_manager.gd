extends Node
## Stocks par faction, cheptel, entretien des zébus et victoire.
## Spec : docs/specs/economie.md

var stocks := {}      # faction -> {"nourriture": float, "eau": float, "bois": float, "ariary": float}
var zebus := {}       # faction -> int (zébus sécurisés dans les enclos)
var enclos := {}      # faction -> int (nombre d'enclos)
var en_manque := {}   # faction -> bool (plus d'eau ou plus de nourriture pour le cheptel)
var _chrono_fuite := {}
var technologies := {}   # faction -> Array des technologies acquises
var ages := {}           # faction -> 1, 2 ou 3
var _chrono_reproduction := {}
var partie_finie := false


func initialiser(factions: Array) -> void:
	partie_finie = false
	stocks.clear()
	zebus.clear()
	enclos.clear()
	en_manque.clear()
	_chrono_fuite.clear()
	technologies.clear()
	ages.clear()
	_chrono_reproduction.clear()
	for f in factions:
		technologies[f] = []
		ages[f] = 1
		_chrono_reproduction[f] = 0.0
		stocks[f] = GameRules.RESSOURCES_DEPART.duplicate()
		zebus[f] = 0
		enclos[f] = 0
		en_manque[f] = false
		_chrono_fuite[f] = 0.0
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


## Texte lisible d'un coût, ex. « 60 bois + 40 Ar ».
static func texte_cout(cout: Dictionary) -> String:
	var parties := PackedStringArray()
	for r in cout:
		var nom: String = "Ar" if r == "ariary" else String(r)
		parties.append("%d %s" % [int(cout[r]), nom])
	return " + ".join(parties)


# --- Technologies ---

func a_technologie(faction: int, tech: String) -> bool:
	var acquises: Array = technologies.get(faction, [])
	return tech in acquises


func acquerir_technologie(faction: int, tech: String) -> void:
	if not technologies.has(faction):
		technologies[faction] = []
	if not a_technologie(faction, tech):
		technologies[faction].append(tech)
	var def: Dictionary = GameRules.TECHNOLOGIES.get(tech, {})
	if def.has("passage_age"):
		ages[faction] = int(def["passage_age"])
	EventBus.technologies_changees.emit(faction)


func age(faction: int) -> int:
	return int(ages.get(faction, 1))


## Technologie que le clan peut lancer maintenant (âge atteint, pas encore acquise).
func technologie_accessible(faction: int, tech: String) -> bool:
	var def: Dictionary = GameRules.TECHNOLOGIES.get(tech, {})
	if def.is_empty() or a_technologie(faction, tech):
		return false
	if def.has("passage_age") and age(faction) >= int(def["passage_age"]):
		return false
	return age(faction) >= int(def.get("age", 1))


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


func zebu_securise(faction: int) -> void:
	zebus[faction] = nb_zebus(faction) + 1
	EventBus.zebus_changes.emit(faction)
	if nb_zebus(faction) >= GameRules.ZEBUS_VICTOIRE:
		terminer(faction)


func zebu_perdu(faction: int) -> void:
	zebus[faction] = maxi(0, nb_zebus(faction) - 1)
	EventBus.zebus_changes.emit(faction)


## Consommation du cheptel par minute (pour l'affichage).
func conso_par_minute(faction: int, ressource: String) -> float:
	var par_zebu := GameRules.CONSO_EAU_ZEBU_S if ressource == "eau" else GameRules.CONSO_NOURRITURE_ZEBU_S
	return nb_zebus(faction) * par_zebu * 60.0


# --- Entretien : seuls les zébus en enclos boivent et mangent ---

func _process(delta: float) -> void:
	if partie_finie:
		return
	for f in stocks:
		var n := nb_zebus(f)
		if n == 0:
			_maj_manque(f, false)
			continue
		stocks[f]["eau"] = maxf(0.0, quantite(f, "eau") - n * GameRules.CONSO_EAU_ZEBU_S * delta)
		stocks[f]["nourriture"] = maxf(0.0, quantite(f, "nourriture") - n * GameRules.CONSO_NOURRITURE_ZEBU_S * delta)
		var manque := quantite(f, "eau") <= 0.0 or quantite(f, "nourriture") <= 0.0
		_maj_manque(f, manque)
		if not manque and a_technologie(f, "pacte_eleveurs"):
			_chrono_reproduction[f] = float(_chrono_reproduction.get(f, 0.0)) + delta
			if _chrono_reproduction[f] >= GameRules.REPRODUCTION_S:
				_chrono_reproduction[f] = 0.0
				_faire_naitre_veaux(f)
		if manque:
			_chrono_fuite[f] = float(_chrono_fuite.get(f, 0.0)) + delta
			if _chrono_fuite[f] >= GameRules.INTERVALLE_FUITE_S:
				_chrono_fuite[f] = 0.0
				_faire_fuir_un_zebu(f)
		else:
			_chrono_fuite[f] = 0.0


func _maj_manque(f: int, manque: bool) -> void:
	if manque == en_manque.get(f, false):
		return
	en_manque[f] = manque
	EventBus.soif.emit(f, manque)
	if f == GameRules.PLAYER:
		if manque:
			EventBus.message.emit("Le cheptel manque d'eau ou de nourriture : les zébus vont s'enfuir !")
		else:
			EventBus.message.emit("Le cheptel est de nouveau nourri et abreuvé.")


## Un zébu affamé ou assoiffé ne meurt pas : il casse l'enclos et retourne à l'état sauvage.
func _faire_fuir_un_zebu(f: int) -> void:
	for z in get_tree().get_nodes_in_group("zebus"):
		if z.etat == Zebu.Etat.ENCLOS and z.proprietaire == f:
			z.fuir()
			zebu_perdu(f)
			if f == GameRules.PLAYER:
				EventBus.message.emit("Un zébu affamé s'est enfui dans la brousse !")
			return


## Pacte des grands éleveurs : un veau naît dans chaque enclos qui a au moins 2 zébus (s'il reste de la place).
func _faire_naitre_veaux(f: int) -> void:
	if CommandBus.monde == null:
		return
	var naissances := 0
	for e in get_tree().get_nodes_in_group("enclos"):
		if e.faction != f or not a_place(f):
			continue
		var presents := 0
		for z in get_tree().get_nodes_in_group("zebus"):
			if z.etat == Zebu.Etat.ENCLOS and z.enclos == e:
				presents += 1
		if presents >= 2:
			var veau = CommandBus.monde.creer_zebu(e.global_position, e.global_position)
			veau.securiser(e)
			naissances += 1
	if naissances > 0 and f == GameRules.PLAYER:
		EventBus.message.emit("%d veau(x) né(s) dans vos enclos !" % naissances)


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
