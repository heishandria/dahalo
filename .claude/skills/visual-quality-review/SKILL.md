---
name: visual-quality-review
description: "Revue visuelle et correction : critique d'une image, d'une planche, d'un modèle 3D, d'une animation ou d'une capture en jeu, par ordre de priorité, avec sévérité, localisation, correction concrète et revérification. Use for art critique, visual QA, review of renders/animations/screenshots, correction passes."
---

# Revue visuelle

## Règle d'or

On ne juge que ce qu'on a **vu** : image affichée, rendu Blender, capture en jeu. Si l'inspection visuelle est
impossible, le dire et fournir la liste de contrôle au lieu d'un verdict.

## Ordre de revue

1. Conformité au brief, sujet reconnaissable.
2. Silhouette et composition **à la taille de jeu** (réduire l'image ; capture à la caméra de jeu).
3. Construction, anatomie, perspective, équilibre (appuis, articulations, sens de pliage).
4. Valeurs (niveaux de gris), couleur, lumière (direction cohérente, ombres de contact).
5. Cohérence de style avec la bible et les assets approuvés (côte à côte).
6. Exigences techniques (format, budget, nommage, export, comportement en moteur).

## Spécifique 3D et animation

- **Modèle** : rendus face/profil/dos/3/4 + vue de jeu ; normales, ombrage lisse, interpénétrations,
  échelle (comparée à un personnage de référence), pivot au sol.
- **Animation** : planche d'images d'un cycle ; boucle sans saut (première = dernière pose) ; pieds qui ne
  glissent pas à la vitesse réelle du jeu ; pas de genou ou coude inversé ; pas de pénétration du sol ;
  déformations propres aux poses extrêmes.

## Format du rapport

Pour chaque défaut : **sévérité** (bloquant / majeur / mineur) — **où** (zone précise, image n°) —
**constat** (ce qui se voit) — **impact** (lisibilité, production) — **correction** (une action concrète) —
**revérifié** (oui/non, comment).

Pas d'éloge générique ; pas de défaut inventé ; distinguer goût personnel et règle de la bible.

## Boucle

Corriger les bloquants et majeurs, refaire le rendu, revérifier. Arrêter quand il ne reste que des mineurs
acceptés, listés dans la passation.
