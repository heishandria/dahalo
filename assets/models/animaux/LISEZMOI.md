# Animaux

## zebu.glb

Zébu malgache (omby) obtenu en transformant la vache du **Farm Animals Pack de Quaternius** (CC0,
https://opengameart.org/content/lowpoly-animated-farm-animal-pack ; licence : `LICENSE_Quaternius_CC0.txt`).

Transformation (script `zebu_depuis_vache.py`, Blender 5) : maillage lissé, bosse graisseuse sur le garrot,
fanon, pis retiré, oreilles tombantes, cornes en lyre, corps affiné ; robe blanche ombrée par couleurs de
sommets, teintée par zébu dans le jeu (`scenes/units/zebu.gd`). ~3 500 triangles, ~2,3 m de long.

Animations (sur place) : `Zebu_repos_loop`, `Zebu_marche_loop`, `Zebu_course_loop` (Godot retire `_loop` à
l'import). La mort et le saut de la vache sont retirés : le zébu n'est jamais tué dans le jeu.
