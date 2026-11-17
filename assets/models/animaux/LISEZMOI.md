# Animaux

## zebu.glb

Zébu malgache (omby) obtenu en transformant la vache du **Farm Animals Pack de Quaternius** (CC0,
https://opengameart.org/content/lowpoly-animated-farm-animal-pack ; licence : `LICENSE_Quaternius_CC0.txt`).

Transformation (script `zebu_depuis_vache.py`, Blender 5) : maillage lissé, bosse graisseuse sur le garrot,
fanon, pis retiré, oreilles tombantes, cornes en lyre, corps affiné ; ombrage en couleurs de sommets, position
de repos dans les UV (pour le motif). Robe calculée dans le jeu par `scenes/units/robe_zebu.gdshader` :
unie (~55 %), pie (~30 %) ou tachetée (~15 %), couleurs tirées parmi six robes malgaches. ~3 500 triangles, ~2,3 m de long.
Le shader ajoute le pelage sans texture : poils courts couchés dans le sens du corps (bruit étiré, avec relief par
perturbation de la normale), nuances par zones, et poussière de latérite sur le bas des pattes et le ventre.

Animations (sur place) : `Zebu_repos_loop`, `Zebu_marche_loop`, `Zebu_course_loop` (Godot retire `_loop` à
l'import). Les jambes de la vache sont pilotées par des contraintes IK : l'export doit **échantillonner** les
animations (`export_force_sampling=True`), sinon seules les cibles des sabots sont exportées et les jambes restent
raides dans le jeu (corrigé le 17/11). Calage : sabot au sol à 0,23 m/s (marche) et 1,81 m/s (course). La mort et le saut de la vache sont retirés : le zébu n'est jamais tué dans le jeu.
