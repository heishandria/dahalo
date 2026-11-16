extends NoeudRessource
## Champ de maïs / sorgho (façon ferme d'Age of Empires). Spec : docs/specs/economie.md
## Cycle : en culture -> mûr (récoltable) -> vide -> resemé automatiquement (bois) ou en friche.
## Le champ ne pousse QUE si des villageois y travaillent (1 à 3 ; chacun accélère la pousse).

enum EtatChamp { POUSSE, MUR, FRICHE }

const INTERVALLE_RESEMIS := 2.0
const VERT := Color(0.35, 0.6, 0.2)
const DORE := Color(0.9, 0.75, 0.3)

var etat_champ := EtatChamp.POUSSE
var croissance := 0.0          # 0 -> 1
var _chrono_resemis := 0.0
var _cultivateurs_ce_tour := 0
var nb_cultivateurs := 0       # villageois qui ont travaillé au dernier tour physique
var _materiau_culture := StandardMaterial3D.new()

@onready var culture: MeshInstance3D = $Culture
@onready var etiquette: Label3D = $Etiquette


func _ready() -> void:
	type_ressource = "nourriture"
	type_batiment = "champ"
	quantite = 0.0
	super()
	_quantite_max = GameRules.CHAMP_RECOLTE
	culture.material_override = _materiau_culture
	if croissance >= 1.0:
		_murir()
	_maj_visuel()


func _physics_process(_delta: float) -> void:
	nb_cultivateurs = _cultivateurs_ce_tour
	_cultivateurs_ce_tour = 0


func _process(delta: float) -> void:
	match etat_champ:
		EtatChamp.POUSSE, EtatChamp.MUR:
			_maj_visuel()
		EtatChamp.FRICHE:
			_chrono_resemis += delta
			if _chrono_resemis >= INTERVALLE_RESEMIS:
				_chrono_resemis = 0.0
				_essayer_resemer(false)


## Appelé chaque tour par un villageois qui travaille sur le champ en culture.
func cultiver(delta: float) -> void:
	if etat_champ != EtatChamp.POUSSE:
		return
	_cultivateurs_ce_tour += 1
	if _cultivateurs_ce_tour > GameRules.MAX_CULTIVATEURS:
		return
	var vitesse := GameRules.POUSSE_SECHERESSE if GameClock.secheresse else 1.0
	croissance = minf(1.0, croissance + delta * vitesse / GameRules.CHAMP_POUSSE_S)
	if croissance >= 1.0:
		_murir()


func disponible() -> bool:
	return etat_champ == EtatChamp.MUR and quantite > 0.0


func epuise() -> bool:
	return false


func attendre_recolte() -> bool:
	return etat_champ == EtatChamp.POUSSE


func _sur_epuisement() -> void:
	_essayer_resemer(true)


func _murir() -> void:
	etat_champ = EtatChamp.MUR
	croissance = 1.0
	quantite = GameRules.CHAMP_RECOLTE
	if ResourceManager.a_technologie(faction, "cultures_traditionnelles"):
		quantite *= GameRules.BONUS_CULTURES
	_maj_visuel()


func _essayer_resemer(premier_essai: bool) -> void:
	if ResourceManager.payer(faction, GameRules.CHAMP_RESEMIS):
		etat_champ = EtatChamp.POUSSE
		croissance = 0.0
		quantite = 0.0
	else:
		if premier_essai and faction == GameRules.PLAYER:
			EventBus.message.emit("Champ en friche : il faut %s pour le resemer."
					% ResourceManager.texte_cout(GameRules.CHAMP_RESEMIS))
		etat_champ = EtatChamp.FRICHE
	_maj_visuel()


func _maj_visuel() -> void:
	if culture == null:
		return
	culture.visible = etat_champ != EtatChamp.FRICHE
	var hauteur := 0.1 + croissance * 0.9
	culture.scale = Vector3(1.0, hauteur, 1.0)
	culture.position.y = 0.6 * hauteur * 0.5
	_materiau_culture.albedo_color = DORE if etat_champ == EtatChamp.MUR else VERT.lerp(DORE, croissance * 0.5)
	if etiquette == null:
		return
	match etat_champ:
		EtatChamp.POUSSE:
			if nb_cultivateurs == 0:
				etiquette.text = "En culture %d %%\nEnvoyez des villageois" % int(croissance * 100.0)
			else:
				etiquette.text = "En culture %d %%\n%d villageois" % [int(croissance * 100.0), mini(nb_cultivateurs, GameRules.MAX_CULTIVATEURS)]
		EtatChamp.MUR:
			etiquette.text = "Mûr : %d nourriture" % int(quantite)
		EtatChamp.FRICHE:
			etiquette.text = "En friche (%s)" % ResourceManager.texte_cout(GameRules.CHAMP_RESEMIS)
