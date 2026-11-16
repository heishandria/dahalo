class_name UnitData
extends Resource
## Fiche d'une unité. Une instance .tres par type dans data/units/.
## Pour équilibrer le jeu, modifier les .tres plutôt que le code.

@export var nom := "Villageois"
@export_enum("villageois", "pisteur", "dahalo") var role: String = "villageois"
@export var vitesse := 5.0
@export var pv := 50
@export var vision := 12.0
@export_group("Récolte")
@export var peut_recolter := true
@export var capacite := 10.0
@export var vitesse_recolte := 2.0   # unités de ressource par seconde
@export_group("Raids")
@export var peut_capturer := false
@export_group("Formation")
@export var cout := {}
@export var temps_formation := 6.0
@export_group("Visuel")
@export var couleur := Color(0.85, 0.72, 0.55)
