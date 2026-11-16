# Dahalo : Les Seigneurs des Zébus — consignes pour Claude Code

RTS de gestion et de survie dans le grand Sud de Madagascar (Androy, pays Mahafaly).
Moteur : **Godot 4.4+**, langage **GDScript**, rendu **Mobile** (cible PC/Steam puis mobile).
Référence de design : le GDD (projet Claude « Dahalo », doc `GDD-Dahalo.md`). Signaler toute incohérence avec lui.

## Règles d'architecture (à respecter dans tout nouveau code)

1. **Toute action de jeu passe par `CommandBus.emettre(cmd)`**, pour le joueur comme pour l'IA.
   Ne jamais appeler directement une méthode d'unité depuis l'UI ou l'IA.
   Raison : préparer le multijoueur en lockstep (on enverra ces commandes sur le réseau).
2. **Équilibrage dans les données** : `data/game_rules.gd` (règles globales) et `data/units/*.tres` (unités).
   Pas de valeurs d'équilibrage codées en dur dans les scènes.
3. **Communication entre systèmes via `EventBus`** (signaux), pas d'appels croisés.
4. **Factions** : `GameRules.PLAYER` (0), `GameRules.AI` (1), `GameRules.WILD` (-1).
   Groupes : `unites_<faction>`, `batiments_<faction>`, `zebus`, `ressource_<type>`.
5. **Toujours jouable à la souris ET au doigt** : toute nouvelle action doit avoir un bouton dans le HUD
   (les raccourcis clavier sont un bonus PC). Cible de test mobile : export Web dans Safari iOS.
6. **Calques physiques** : 1 = terrain, 2 = unités et zébus, 3 = interactifs (bâtiments, ressources).

## Conventions

- Noms de variables, fonctions, nœuds et commentaires en **français**, sans abréviations obscures.
- GDScript typé (`: float`, `-> void`). Attention : `:=` est interdit quand la valeur est un `Variant`
  (accès dictionnaire, objet non typé) ; écrire le type explicitement.
- Indentation par tabulations.
- Une scène = un script du même nom, dans le même dossier.

## Culture

Rester respectueux de la culture malgache et des pratiques autour du zébu.
Le zébu n'est jamais tué dans le jeu : il est capturé, escorté, repris ou sécurisé.
Vérifier les termes malgaches avant de les introduire dans le jeu.
