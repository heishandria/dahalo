---
name: locomotion-animation
description: "Locomotion bipède et quadrupède pour le jeu : cycles de marche et de course (phases d'appui et d'oscillation, bassin, contre-rotation, bras), allures des quadrupèdes (pas, trot, galop, ordre de pose des pattes), animations sur place, génération procédurale par trajectoire des pieds et cinématique inverse, calage sur la vitesse de déplacement du jeu. Use for walk cycles, run cycles, quadruped gaits, locomotion, foot sliding fixes, IK-based procedural animation."
---

# Locomotion (bipèdes et quadrupèdes)

## Bipède : marche

- Cycle ≈ 1,0–1,2 s (2 pas). **Appui ≈ 60 %** du cycle par pied, double appui au contact.
- Phases d'un pied : contact (talon, orteils relevés) → amorti (genou fléchi, bassin au plus bas) → appui
  moyen (bassin au plus haut) → poussée (talon levé, rotation sur les orteils) → oscillation (pied qui revient,
  ~10 cm au-dessus du sol).
- Bassin : monte/descend (~2–4 cm), bascule et tourne (lacet ±4–6°) ; épaules en contre-rotation ; bras
  opposés aux jambes ; tête stabilisée.

## Bipède : course

- Cycle ≈ 0,6–0,7 s. **Appui ≈ 30–40 %** : il y a une **phase de vol** (aucun pied au sol).
- Contact sur le milieu du pied, sous le corps (pas loin devant) ; genou souple à l'impact.
- Bassin : plus bas à l'appui, plus haut en vol ; buste penché vers l'avant (≈ 5–10°).
- Bras pliés (~80–100°), balancier ample ; talon qui remonte en oscillation (jusqu'à la hauteur du genou pour
  un trot, plus haut pour un sprint).
- Avec une charge à la main : le bras chargé reste tendu, balancier réduit ; bras libre écarté pour l'équilibre.

## Quadrupède : allures (ongulés)

| Allure | Ordre de pose des pattes | Remarque |
|---|---|---|
| **Pas** | Postérieur gauche → antérieur gauche → postérieur droit → antérieur droit (4 temps) | Toujours 2 ou 3 pieds au sol ; tête qui hoche |
| **Trot** | Diagonales ensemble (AG+PD, puis AD+PG) (2 temps) | Brève phase de vol ; tête stable |
| **Galop** | Postérieur, postérieur, antérieur, antérieur (asymétrique) | Phase de vol pattes groupées ; colonne qui se plie (plus chez les carnivores que chez les ongulés) |

- Le **postérieur se pose à peu près dans l'empreinte de l'antérieur** du même côté au pas.
- Antérieurs : le carpe plie vers l'arrière en oscillation ; postérieurs : le jarret plie, le grasset avance.
- Références de chronophotographie (Muybridge, domaine public) : voir la liste des ressources du projet.

## Animation sur place et calage

1. La racine reste à l'origine ; le pied d'appui recule à vitesse constante pendant l'appui.
2. **Vitesse de calage** = distance parcourue par le pied d'appui / durée de l'appui (m/s). La mesurer dans
   Blender (pied le plus bas à chaque image).
3. Dans le jeu : vitesse de lecture = vitesse réelle / vitesse de calage, bornée (≈ 0,6 à 2,5). Si la vitesse
   réelle dépasse la borne, il faut **une autre allure** (marche → course → galop), pas une accélération
   excessive (pieds qui patinent, mouvement frénétique).
4. Seuils d'allure dans le jeu (ex. course au-delà de 2,2 m/s) avec fondu court.

## Génération procédurale (Blender Python)

Méthode éprouvée : définir la **trajectoire de chaque cheville** (appui : recul linéaire au sol ; oscillation :
courbe de retour levée), placer le bassin (hauteur, bascule, lacet), puis résoudre chaque jambe par
**cinématique inverse analytique à deux os** (cuisse + mollet, genou dans le plan de la jambe, plié vers l'avant
pour un humain) ; abaisser le bassin si une cheville d'appui est hors de portée (jambe à ~98 % de sa longueur
max). Clés à chaque image, interpolation linéaire, boucle fermée. Gabarit : voir
`../blender-python-pipeline/SKILL.md` §Animation.

## Critères de validation

- Ordre de pose des pattes correct pour l'allure ; phase de vol pour la course/le trot.
- Aucun pied ne glisse pendant l'appui à la vitesse réelle du jeu ; aucun pied sous le sol.
- Genoux et coudes pliés dans le bon sens ; boucle sans saut.
