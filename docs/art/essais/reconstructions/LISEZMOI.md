# Reconstruction de secours du GLB 901

`901_reconstruction_secours_v01.glb` est un essai technique, pas un modèle prêt pour le jeu.
Il a été reconstruit par conversion du nuage `POSITION` en volume, puis en surface. Les couleurs
`COLOR_0` ont été transférées depuis le point le plus proche.

## Vérification

- Source : [`../bruts/901_brut_colore_00001_.glb`](../bruts/901_brut_colore_00001_.glb), SHA-256
  `c4e778520bf74eeaabaade094728a110387359c20b30e429376526fa354181e6`.
- Le traitement a été exécuté sur une copie bit à bit ; la source est restée inchangée.
- Blender 5.3.0 ; voxel `0.004`, rayon `0.005`, seuil `0.1`.
- Sortie : 77 956 sommets, 155 848 triangles, un matériau, attribut `COLOR_0`, sans texture.
- L’audit GLB ne signale pas d’erreur structurelle ; rendu 1024 × 1024 regardé.

## Limites visuelles et techniques

La surface reste bosselée et les couleurs présentent des plages triangulaires visibles. Le maillage
dépasse largement un budget courant de jeu ; il faut le nettoyer, le retopologiser ou le décimer, puis
refaire un rendu et vérifier l’apparence dans Godot avant toute intégration.

## Reproduction

Depuis la racine du dépôt, utiliser le script
`.claude/skills/blender-python-pipeline/scripts/reconstruire_depuis_sommets.py` avec les paramètres
ci-dessus et une nouvelle sortie versionnée. Le script refuse d’écraser sa source ou une sortie existante.
