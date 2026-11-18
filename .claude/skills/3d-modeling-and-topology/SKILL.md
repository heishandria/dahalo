---
name: 3d-modeling-and-topology
description: "Modélisation 3D pour le jeu : blockout à l'échelle, modélisation par volumes, sculpt, retopologie, boucles d'arêtes aux articulations, budgets de triangles, normales et ombrage, modèles issus d'image→3D (Tripo, Meshy) à nettoyer, décimation. Use for 3D modelling, blockout, sculpting, retopology, topology for deformation, polycount, cleaning AI-generated meshes."
---

# Modélisation 3D et topologie

## Méthode

1. **Brief technique** : taille réelle (m), distance caméra, taille à l'écran, budget (triangles, matériaux,
   textures), déformation (rig ou non), nombre d'exemplaires à l'écran.
2. **Blockout** à l'échelle 1 unité = 1 m avec un personnage de référence (1,65 m) à côté ; valider la
   silhouette **à la caméra de jeu** avant tout détail.
3. **Volumes principaux** (primitives, extrusions, modificateurs : miroir, subdivision, solidifier, biseau) ;
   détails secondaires ensuite.
4. **Sculpt** (si besoin de formes organiques) : grandes formes → formes secondaires → détails ; le détail fin
   ira dans une normal map, pas dans la géométrie de jeu.
5. **Retopologie** pour ce qui se déforme : quads, boucles d'arêtes autour des yeux, de la bouche et **aux
   articulations** (2 à 3 boucles par coude/genou, épaules et hanches avec boucles en éventail), densité
   régulière, pôles hors des zones qui plient.
6. **Décimation** acceptable pour le statique ou l'éloigné (vérifier l'ombrage après) ; pour le déformable,
   décimer avec prudence et tester en pose extrême.
7. **Normales** : ombrage lisse + arêtes vives marquées ou « auto smooth » ; recalculer vers l'extérieur ;
   pas de faces internes, pas de sommets dupliqués, pas de faces de surface nulle.
8. **Pivot et orientation** : pivot au sol au centre de l'emprise ; avant selon la convention du moteur (noter
   la rotation à appliquer à l'import) ; transformations appliquées (échelle 1, rotation 0).

## Budgets indicatifs (temps réel, caméra de stratégie)

| Asset | Triangles |
|---|---|
| Unité humaine | 3 000 – 10 000 |
| Animal moyen (bovin) | 3 000 – 8 000 |
| Bâtiment | 1 000 – 8 000 |
| Plante / rocher (répété en masse) | 50 – 1 500 (instanciés) |
| Accessoire tenu (seau, outil) | 100 – 800 |

Le budget dépend surtout du **nombre à l'écran** et de la plateforme (Web/mobile plus serrés).

## Modèles issus d'image→3D

Toujours : vérifier échelle et orientation, supprimer les faces cachées et le sol fusionné, refaire les normales,
décimer au budget, contrôler la texture (lumière cuite à retirer), refaire les zones fausses (mains, pieds,
dos inventé), retopologiser si rig.

## Contrôle

Rendus face/profil/dos/3/4 + vue de jeu (`../blender-python-pipeline/scripts/rendu_verification.py`) ;
statistiques (`inspecter_blend.py`) ; comparaison d'échelle avec la référence humaine.

## Critères de validation

- Silhouette juste à la caméra de jeu ; échelle juste ; budget respecté.
- Ombrage propre (pas de facettes involontaires, pas de normales inversées).
- Pour le déformable : boucles aux articulations, poses extrêmes sans écrasement.
