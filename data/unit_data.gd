class_name UnitData
extends Resource
## Fiche d'une unité. Une instance .tres par type dans data/units/.
## Pour équilibrer le jeu, modifier les .tres plutôt que le code.

@export var nom := "Villageois"
@export_enum("villageois", "pisteur", "dahalo", "lanceur", "tireur") var role: String = "villageois"
@export var vitesse := 5.0
@export var pv := 50
@export var vision := 12.0
@export var facteur_vision_nuit := 0.6   # la nuit, la vision est multipliée par ce facteur
@export_group("Récolte")
@export var peut_recolter := true
@export var capacite := 10.0
@export var vitesse_recolte := 2.0   # unités de ressource par seconde
@export_group("Combat")
@export var arme := ""               # "sagaie", "sagaie_jet", "fusil"… (affichage, effets)
@export var degats := 0.0            # 0 = ne combat pas
@export var portee := 1.8            # > 3 m = attaque à distance
@export var cadence := 1.0           # secondes entre deux attaques
@export var bonus_contre := {}       # rôle visé -> multiplicateur de dégâts (triangle des guerriers)
@export var malus_au_contact := 1.0  # multiplicateur quand la cible est à moins de 3 m (fusil : inutile au corps à corps)
@export var description := ""        # rôle tactique, affiché à la formation
@export_group("Raids")
@export var peut_capturer := false
@export_group("Formation")
@export var cout := {}
@export var temps_formation := 6.0
@export var age_requis := 1          # âge minimum du clan pour former l'unité
@export var requiert := ""           # bâtiment nécessaire pour former l'unité (ex. "tsena" pour les fusils)
@export_group("Visuel")
@export var couleur := Color(0.85, 0.72, 0.55)
## Modèle 3D animé (.glb) ; sans modèle, l'unité reste une capsule colorée.
## Animations sur place : noms finissant par _repos, _marche ou _course ; _loop active la boucle.
## Une animation finissant par _tirer est jouée à chaque tir ; _viser (boucle), à l'arrêt entre deux tirs.
## Une animation finissant par _mort (non bouclée) est jouée à la mort ; sans elle, l'unité bascule.
@export var modele: PackedScene
@export var vitesse_marche_animation := 0.87   # vitesse (m/s) pour laquelle la marche du modèle est calée
@export var acceleration_animation_max := 2.4  # au-delà, la marche ne s'accélère plus (sinon elle s'agite)
@export var vitesse_marche_seau_animation := 0.36  # marche avec le seau (petits pas chargés), si le modèle l'a
@export var vitesse_course_animation := 3.96       # course, si le modèle l'a
@export var vitesse_course_seau_animation := 3.96  # course avec le seau (faite main, v9 : cycle 0,66 s)
@export var seuil_course := 2.2                    # au-delà de cette vitesse réelle (m/s), elle court
