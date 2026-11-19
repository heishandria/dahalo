# Palissade épineuse

Trois variantes d'un segment modulaire de 4 m, intégrées dans `scenes/buildings/palissade.tscn`.
Le jeu choisit une variante de façon stable à partir de la position du segment et recolore son fanion selon
la faction. Le modèle ne remplace ni les collisions ni la logique de construction/sabotage.

## Fichiers

- `palissade_a.glb`, `palissade_b.glb`, `palissade_c.glb` : maillage de la variante et objet `Banniere`.
- `palissade_atlas.png` : atlas procédural source, 1024 × 1024 px, intégré aux GLB.
- `generer_atlas.py`, `construire_palissade.py`, `exporter_variantes.py`, `rendre_controle.py` : sources
  rejouables. Les scènes Blender de travail et rendus complets sont conservés hors dépôt dans
  `~/dahalo-personnages/palissade/`.

## Technique et contrôle

- Origine au sol, au centre du segment ; 1 unité = 1 m ; segment le long de X ; avant vers +Z.
- Les bouts du maillage arrondis s'étendent à environ 4,66 m afin de chevaucher les voisins ; la collision de
  jeu reste centrée sur 4 m, comme avant.
- Chaque GLB contient 911–963 triangles de haie, plus 36 triangles de bannière, deux matériaux et une texture
  1024². Les rameaux sont en alpha découpe ; aucun éclairage n'est cuit.
- Contrôle : `audit_glb.py palissade_a.glb palissade_b.glb palissade_c.glb --max-triangles 1500
  --max-texture 1024 --max-materiaux 3 --strict`.
- Rendus de contrôle : caméra RTS proche/lointaine, joint à 90°, joint à 45° et variantes côte à côte dans
  `~/dahalo-personnages/palissade/rendus/astra_20261118/`. Les deux angles, les deux zooms RTS et les vues
  comparatives ont été regardés ; une capture Godot montre aussi la base IA en Compatibility.

## Reproduction

Depuis ce dossier, avec Pillow et Blender 5.x installés :

```sh
python3 generer_atlas.py palissade_atlas.png --graine 7
blender -b --factory-startup --python-exit-code 1 --python construire_palissade.py -- \
  palissade_atlas.png ~/dahalo-personnages/palissade/palissade_v03.glb \
  ~/dahalo-personnages/palissade/palissade_v03.blend
blender -b ~/dahalo-personnages/palissade/palissade_v03.blend --python-exit-code 1 \
  --python exporter_variantes.py -- .
```

Le résultat est un choix artistique générique de branches épineuses, inspiré par l'écorégion de forêt
épineuse du sud de Madagascar. Il ne prétend pas documenter une technique de clôture propre à l'Androy ;
aucun motif, inscription ou terme culturel n'est utilisé. Aucun matériau photographique ou modèle tiers
n'est inclus. Voir `docs/art/madagascar-references.md` §2.
