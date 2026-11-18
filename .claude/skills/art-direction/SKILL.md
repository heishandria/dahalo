---
name: art-direction
description: "Direction artistique d'un jeu : fixer la cible visuelle, rédiger ou tenir à jour la bible artistique (style, proportions, palette, matériaux, lumière, règles de cohérence), arbitrer entre références, auditer la cohérence entre assets. Use for art direction, style guide, style bible, visual consistency, moodboard, palette decisions."
---

# Direction artistique

Objectif : qu'un autre artiste (ou un autre modèle d'IA) produise un asset compatible **sans deviner le style**.

## Méthode

1. **Reformuler la cible** : public, plateforme, distance caméra, taille des objets à l'écran (en pixels), rôle
   en jeu. Un style se juge à la distance de jeu, pas en gros plan.
2. **Extraire des ancres** de 3 à 5 références approuvées : silhouette, proportions, langage de formes, palette,
   traitement des bords, réponse des matériaux, lumière, densité de détails, ambiance.
3. **Séparer invariants et libertés** : ce qui ne bouge jamais (ex. palette terreuse, pas de couleurs saturées
   hors accents) / ce qui peut varier par asset.
4. **Écrire 3 à 5 règles positives et 3 à 5 anti-règles**, chacune vérifiable (« contraste de valeur
   personnage/sol ≥ 2 paliers sur 5 » plutôt que « lisible »).
5. **Zones de style** si le projet mélange (key art peint, modèles temps réel, interface plate) : dire où chaque
   style est permis ; ne jamais les mélanger dans un même asset.
6. **Planche de calibration** : un personnage, un objet, un élément de décor côte à côte, à la caméra de jeu.
   Toute nouvelle règle de la bible doit s'y vérifier.
7. **Consigner** chaque décision dans la bible (date, raison, exemple approuvé). Une décision non écrite
   n'existe pas pour l'agent suivant.

## Bible artistique

Modèle générique : [modele-bible.md](modele-bible.md). Le projet garde **sa** bible ailleurs (indiqué dans son
`CLAUDE.md`/`AGENTS.md`). Chaque entrée distingue : **décidé** / **à décider** / **fait documenté** (avec source)
/ **choix artistique**.

## Audit de cohérence (périodique ou avant un jalon)

Comparer les assets approuvés sur : complexité de silhouette, exagération des proportions, bords et traits,
palette et plage de valeurs, réponse des matériaux, lumière, densité de détails, échelle relative.
Classer chaque écart : **zone de style voulue** ou **dérive accidentelle** ; corriger les dérives, écrire la
règle manquante avec un contre-exemple.

## Critères de validation

- La bible répond aux questions : proportions ? palette et accents ? matériaux ? lumière jour/nuit ? densité de
  détails ? budget technique ? exemples approuvés ?
- Deux agents différents, même brief, produisent des assets qui tiennent côte à côte sur la planche de calibration.
- Chaque règle est vérifiable sur une image (pas de règle d'intention seule).
