---
name: perspective-and-spatial-design
description: "Perspective et espace : ligne d'horizon, points de fuite (1, 2, 3 points), caméra isométrique ou orthographique de jeu, échelle, plan de sol, objets posés sur leurs surfaces, profondeur atmosphérique. Use for perspective drawing, isometric/orthographic views, scale, environment and prop construction in space."
---

# Perspective et espace

## Méthode

1. **Choisir la caméra** : hauteur des yeux (= ligne d'horizon), focale (grand angle = fuites fortes),
   perspective à 1, 2 ou 3 points, ou **projection orthographique/isométrique** (pas de fuite) pour la plupart
   des jeux de stratégie vus de haut et pour les planches de modèle.
2. **Plan de sol** : le tracer d'abord (grille), y poser les boîtes englobantes des objets à la bonne échelle.
3. **Échelle** : un personnage de référence (taille connue, ex. 1,65 m) placé à plusieurs profondeurs ; tout
   objet se mesure contre lui. En perspective, les têtes de personnages de même taille debout sur un sol plat
   restent sur la ligne d'horizon si la caméra est à hauteur d'yeux.
4. **Verticales** : parallèles en 1 et 2 points ; elles convergent en 3 points (plongée ou contre-plongée).
5. **Formes complexes** : les construire dans des boîtes ; répartir les éléments répétés (poteaux, fenêtres)
   par division en diagonales, pas « à l'œil ».
6. **Profondeur** : chevauchement, diminution de taille, perspective atmosphérique (contraste et saturation
   baissent, teinte vers la couleur du ciel/de la poussière avec la distance), valeurs regroupées par plan.
7. **Contact au sol** : ombre de contact sombre et étroite sous chaque objet ; sans elle, l'objet flotte.

## Caméra isométrique de jeu (cas RTS)

- Angle de plongée constant ; les longueurs ne raccourcissent pas avec la distance : la profondeur se lit par
  chevauchement, ombres portées et brume, pas par la taille.
- Concevoir les objets pour être lisibles **vus du dessus à ~45–60°** : toits, sommets, ombres comptent plus
  que les façades.
- Vérifier chaque asset **dans la caméra du jeu**, à la distance réelle.

## Planches orthographiques

Pas de fuite ; vues alignées sur une même ligne de sol et une même échelle ; repères horizontaux communs
(yeux, épaules, taille, genoux) qui traversent toutes les vues.

## Critères de validation

- Arêtes majeures cohérentes avec la caméra choisie (pas de mélange de projections).
- Les objets reposent sur leurs surfaces (ombre de contact), l'échelle relative est juste.
- La profondeur se lit en niveaux de gris.
