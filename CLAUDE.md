# Dahalo : Les Seigneurs des Zébus — consignes pour Claude Code

RTS de gestion et de survie dans le grand Sud de Madagascar (Androy, pays Mahafaly).
Moteur : **Godot 4.4+**, langage **GDScript**. Rendu **Forward+ sur PC** (cible principale : Steam),
**Mobile** sur téléphone, **Compatibility** sur le Web (shaders : 16 textures au plus, moteur compris).
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
6. **Calques physiques** : 1 = terrain, 2 = unités et zébus, 3 = interactifs (clic : bâtiments, ressources),
   4 = obstacles (navmesh + collisions : bâtiments, puits, points d'eau, baobabs), 5 = arbres et raketa
   (navmesh + collisions : les chemins contournent les bosquets), 6 = clôtures d'enclos (navmesh seulement), 7 = palissades du joueur, 8 = palissades de l'IA (chaque unité
   bute sur les palissades des autres clans). Navmesh recalculé à chaque construction.

## Specs

Les règles de jeu effectivement codées sont décrites dans `docs/specs/` (une page par système).
**Toute modification de gameplay ou d'équilibrage met à jour la spec concernée dans le même commit**
(chiffres, comportements, tableau des écarts avec le GDD).

## Conventions

- Noms de variables, fonctions, nœuds et commentaires en **français**, sans abréviations obscures.
- GDScript typé (`: float`, `-> void`). Attention : `:=` est interdit quand la valeur est un `Variant`
  (accès dictionnaire, objet non typé) ; écrire le type explicitement.
- Indentation par tabulations.
- Mots réservés à éviter comme noms de variables (Godot 4.7) : `trait`, `class`, `signal`, `match`, `when`…
- Une scène = un script du même nom, dans le même dossier.

## Culture

Rester respectueux de la culture malgache et des pratiques autour du zébu.
Le zébu n'est jamais tué dans le jeu : il est capturé, escorté, repris ou sécurisé.
Les unités peuvent mourir au combat (chute, puis disparition), sans effet sanglant.
Vérifier les termes malgaches avant de les introduire dans le jeu.

## Art

Tout travail artistique (dessin, personnage, animal, environnement, animation, modèle Blender, texture, image)
passe par le skill `game-art-router` (`.claude/skills/`), la bible `docs/art/bible-artistique.md` et les faits
sourcés de `docs/art/madagascar-references.md`. Blender se pilote sans MCP, par scripts en ligne de commande
(`.claude/skills/blender-python-pipeline/`). Guide : `docs/art/README.md`.
