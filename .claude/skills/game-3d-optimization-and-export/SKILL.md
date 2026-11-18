---
name: game-3d-optimization-and-export
description: "Optimisation et export 3D vers le moteur de jeu : budgets, LOD, instanciation, nombre de matériaux et d'appels de dessin, export glTF/GLB depuis Blender (actions, échantillonnage, échelle, axes), import Godot (noms d'animation, boucles, textures extraites, compression, mipmaps), contrôle en jeu et sur Web/mobile. Use for exporting to Godot/Unity, glTF/GLB settings, LOD, draw calls, texture compression, performance budgets."
---

# Optimisation et export vers le moteur

## Optimiser

1. **Budget par plateforme** : PC > mobile > Web (WebGL/Compatibility : moins de textures par shader, CPU plus
   lent). Viser le cas le plus faible si le jeu tourne partout.
2. **Matériaux** : le moins possible par modèle (1–3) ; chaque matériau = un appel de dessin.
3. **Instanciation** pour ce qui est répété (herbe, rochers, arbres) : un maillage, des milliers d'instances.
4. **LOD** ou modèle simplifié pour ce qui est loin ; densité de décor réduite sur Web/mobile.
5. **Animations** : pas de pistes inutiles (échelle constante, os immobiles) ; suspendre l'animation des objets
   hors écran côté moteur.
6. **Textures** : résolution adaptée, compression GPU + mipmaps (indispensable), atlas.

## Exporter depuis Blender (glTF/GLB)

- Format **GLB** (binaire, textures incluses) ; sélection explicite des objets à exporter.
- `export_animation_mode='ACTIONS'` pour exporter toutes les actions ; actions marquées « fake user ».
- **`export_force_sampling=True`** si des contraintes (IK, Copy Rotation…) pilotent des os ; sinon les jambes
  restent raides en moteur.
- Transformations appliquées ; +Y haut côté glTF (le convertisseur gère l'axe de Blender) ; 1 unité = 1 m.
- Les noms d'objets et d'actions passent tels quels : les choisir pour le moteur.

## Importer dans Godot (4.x)

- Le suffixe **`_loop`** d'un nom d'animation active la boucle et est **retiré** du nom à l'import : chercher
  les animations par leur nom sans suffixe.
- Textures intégrées extraites à côté du `.glb` : régler leur import (**VRAM compressée + mipmaps**) ; Godot ne
  le devine pas toujours si les matériaux sont créés par le code.
- Animations : `AnimationPlayer` trouvé dans la scène importée ; vitesse de lecture calée sur la vitesse réelle.
- Recharger l'import (éditeur ou `--headless --editor --quit`) après remplacement d'un `.glb`.

## Contrôler

1. `../blender-python-pipeline/scripts/audit_glb.py` : triangles, matériaux, textures, os, animations
   (noms, durées), alertes de budget.
2. Capture **en jeu** à la caméra réelle, et sur la cible la plus faible (Web/mobile) si possible.
3. Mesure de performance avant/après (images par seconde, temps par image) quand l'asset est répété.

## Critères de validation

- Budget respecté et mesuré (sortie de `audit_glb.py`).
- Animations, boucles et accessoires corrects en moteur (capture).
- Textures compressées avec mipmaps ; pas de régression de performance mesurable.
