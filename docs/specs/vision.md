# Spec — Vision, brouillard de guerre et nuit

> Statut : **prototype v0.5** (16/11/2026). Décrit ce qui est **réellement codé**.
> Valeurs : `data/game_rules.gd` (section Vision) et `data/units/*.tres` (`vision`, `facteur_vision_nuit`).
> Code : `autoload/vision.gd` (calcul), `systems/brouillard.gd` + `.gdshader` (affichage), `systems/trace.gd`.

## 1. Principe

Chaque clan ne voit que ce que voient ses unités et ses bâtiments. La carte (120 × 120 m) est découpée
en **60 × 60 cases de 2 m**. Pour chaque clan, deux états par case :
- **exploré** : la case a déjà été vue au moins une fois (définitif) ;
- **visible** : la case est vue en ce moment. Recalculé **5 fois par seconde**.

Décisions (16/11/2026) : la partie démarre **dans le noir** sauf autour de sa base ; les bâtiments ennemis
restent affichés tels qu'on les a vus (comme Age of Empires).

## 2. Rayons de vision

| Source | Jour | Nuit |
|---|---|---|
| Villageois | 12 m | 7,2 m (×0,6) |
| Pisteur | **22 m** | **19,8 m (×0,9)** |
| Dahalo, Lanceur | 14 m | 8,4 m |
| Tireur | 18 m | 10,8 m |
| Bâtiments (case, enclos, champs, puits…) | 12 m | 7,2 m |

La nuit dure ~1 min 25 s par cycle de 4 min : c'est le moment des raids.

## 3. Affichage (joueur)

| Zone | Sol | Ce qui est montré |
|---|---|---|
| Inexplorée | **Noire** | Rien |
| Explorée, hors de vue | Assombrie | Terrain, ressources, décor, **bâtiments ennemis (dernière image)** |
| Visible | Claire | Tout, y compris unités ennemies et zébus |

- Unités ennemies et zébus (sauf les siens) **hors de vue sont invisibles** et ne peuvent pas être ciblés :
  un clic dessus devient un simple déplacement.
- Ses propres unités, bâtiments et zébus sont toujours affichés.
- Débogage : **F9** révèle toute la carte (builds de debug uniquement, pas sur le site).

## 4. Effets sur le combat

- Engagement automatique : un guerrier inactif n'attaque qu'un ennemi **visible** et dans son rayon de vision
  **actuel** (donc plus court la nuit).
- Une attaque en cours s'arrête si la cible sort du champ de vision du clan.

## 5. Traces des voleurs (GDD §5 : rôle du Pisteur)

- Un Dahalo qui escorte des **zébus volés** laisse une empreinte au sol **tous les 3 m**.
- Les traces sont invisibles par défaut. Elles apparaissent au **clan volé** dès qu'un de **ses Pisteurs**
  passe à moins de **15 m**, puis restent affichées.
- Elles s'effacent progressivement en **90 s**. Les zébus sauvages capturés ne laissent pas de traces.

## 6. IA

- **Pas de triche sur la vue** : elle ne défend que contre les intrus **visibles**.
- Elle se **souvient des zones explorées** : elle cible les zébus et les enclos situés dans des zones déjà
  explorées (approximation d'une mémoire ; elle n'a pas à les voir à l'instant).
- Son **Pisteur explore** en boucle 8 points de la carte (troupeaux, centre, base adverse, coins).

## 7. Écarts avec le GDD

| GDD | Prototype | Statut |
|---|---|---|
| La nuit réduit la vue des sentinelles et villageois | ×0,6 pour tous, ×0,9 pour le Pisteur | **Fait** |
| Pisteur : dissipe le brouillard, repère les troupeaux | Vision 22 m, rapide | **Fait** |
| Pisteur : détecte les traces des voleurs | Traces lisibles à 15 m | **Fait** |
| Technique des pisteurs (Âge 2) : pistes sur la mini-carte | Pas de mini-carte | À faire avec la mini-carte |

## 8. Questions ouvertes

1. Bonus de discrétion la nuit pour les Dahalo (vus à distance réduite) ?
2. Tours de guet / sentinelles pour surveiller ses enclos ?
3. Les unités sous les arbres (forêts) moins visibles ?
