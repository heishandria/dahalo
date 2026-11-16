extends Node
## Bus d'événements global : découple les systèmes (HUD, IA, audio…).
## Règle : un système émet ici, les autres écoutent. Pas d'appels croisés directs.

@warning_ignore("unused_signal")
signal ressources_changees(faction: int)
@warning_ignore("unused_signal")
signal zebus_changes(faction: int)
@warning_ignore("unused_signal")
signal cycle_change(est_nuit: bool)
@warning_ignore("unused_signal")
signal meteo_change(secheresse: bool)
@warning_ignore("unused_signal")
signal soif(faction: int, active: bool)
@warning_ignore("unused_signal")
signal partie_terminee(faction_gagnante: int)
@warning_ignore("unused_signal")
signal unite_creee(unite: Node)
@warning_ignore("unused_signal")
signal message(texte: String)
@warning_ignore("unused_signal")
signal vision_maj()
@warning_ignore("unused_signal")
signal alerte(position: Vector3)   # raid, attaque : clignote sur la mini-carte
