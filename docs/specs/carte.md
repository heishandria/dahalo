# Spec — Carte : zone de jeu, sol et paysage

> Statut : **prototype v0.10** (17/11/2026). Décrit ce qui est **réellement codé**.
> Code : `scenes/main.gd` (disposition), `scenes/world/terrain.gdshader` (sol), `scenes/world/paysage.gd` (relief et décor).

## 1. Zone de jeu

- Carré de **120 × 120 m** (±60 m, `GameRules.DEMI_CARTE`), **plat à y = 0**. Les unités et bâtiments restent
  dans ±56 m (`LIMITE_CARTE`).
- Disposition fixe et symétrique (joueur au sud-ouest, IA au nord-est) : voir `_generer_carte()` dans `main.gd`.
  La génération procédurale (GDD §8) n'est pas encore faite.

## 2. Sol

- Un seul shader pour le sol de la zone de jeu **et** le relief : raccord sans couture au bord.
- Latérite rouge plus ou moins sombre, plaques de sable, **herbe sèche** ; roche calcaire beige sur les pentes et les
  hauteurs, avec des **strates horizontales** sur les parois.
- **Sécheresse** : l'herbe disparaît presque, tout pâlit et tire vers l'ocre (sol et relief, via `EventBus.meteo_change`).
- Bruit calculé dans le shader, sans texture : même rendu sur PC, Web (Compatibility) et mobile.

## 3. Paysage autour de la zone de jeu (purement visuel)

| Élément | Où | Détail |
|---|---|---|
| Relief | De ±60 m à ±200 m | Collines puis plateau. Côté **proche de la caméra** (bas de l'écran, +X +Z) : collines basses, pour ne pas cacher les unités au bord. Côté **lointain** (haut de l'écran) : **escarpements** jusqu'à ~30 m |
| Rochers | 170 | Calcaire, posés sur le relief |
| Fourrés | 260 | Buissons bas vert olive |
| Épineux | 140 touffes de 3 à 5 tiges | Silhouettes du bush de l'Androy ; plus bas côté proche de la caméra |
| Baobabs | 10 | Repères lointains |

- **Aucune collision**, hors du navmesh, invisible pour la mini-carte et le brouillard : le paysage n'a **aucun effet
  sur le jeu**. On ne peut pas y aller (les unités restent dans ±56 m).
- Paysage **identique à chaque partie** (graine fixe), pour des captures comparables.
- Rendu léger : un maillage pour le relief (~18 000 triangles) et un MultiMesh par type de décor.

## 4. Écarts avec le GDD et questions ouvertes

| GDD | Prototype | Statut |
|---|---|---|
| Carte générée (GDD §8) | Disposition fixe et symétrique | À faire |
| — | Relief et décor autour de la zone de jeu | **Fait** (17/11) |

1. Faut-il un lit de rivière à sec (type Menarandra) traversant la zone de jeu, purement décoratif ?
2. Le relief doit-il être assombri hors de la zone de jeu pour mieux la cadrer ?
