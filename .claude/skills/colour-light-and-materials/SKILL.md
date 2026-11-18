---
name: colour-light-and-materials
description: "Couleur, valeurs, lumière, ombres et matériaux : regroupement des valeurs, palettes limitées, couleur locale contre couleur de lumière, lumière principale, d'appoint, de contre-jour et rebonds, ombres propres et portées, lecture des matériaux (rugosité, reflets), lumière de jour et de nuit, lisibilité daltoniens. Use for colour theory, value structure, lighting, shadows, materials, palettes, day/night lighting."
---

# Couleur, lumière et matériaux

## Valeurs d'abord

1. Résoudre l'image ou l'asset en **niveaux de gris** (5 paliers suffisent) avant la couleur.
2. Grouper : les zones éclairées dans une plage, les zones d'ombre dans une autre ; **ne pas mélanger** les
   valeurs des deux familles (une couleur claire dans l'ombre reste plus sombre que la même au soleil).
3. Le contraste de valeur le plus fort va au point focal (en jeu : aux unités et objets interactifs).

## Couleur

- **Palette limitée** : 1 dominante, 1 complémentaire ou analogue, 1 accent rare. Définir la teinte du « noir »
  et du « blanc » de la palette (jamais 0 % / 100 % purs en peinture).
- **Couleur locale ≠ couleur de lumière** : au soleil chaud, les zones éclairées tirent vers le jaune-orange, les
  ombres reçoivent le bleu du ciel ; à l'aube/au crépuscule, contraste chaud/froid plus fort ; la nuit,
  désaturer et bleuir, garder une source chaude (feu) pour le focal.
- **Saturation** : la plus forte dans les demi-teintes près de la limite ombre/lumière ; basse dans les hautes
  lumières et les ombres profondes.
- **Perspective atmosphérique** : le lointain prend la couleur de l'air (bleu, ou ocre en climat poussiéreux).

## Lumière et ombres

- Lumière **principale** (direction fixée par la bible), **d'ambiance** (ciel), **rebond** (sol coloré : un sol
  rouge renvoie du rouge dans les ombres), **contre-jour** éventuel pour détacher la silhouette.
- Ombre propre (côté du volume non éclairé, bord adouci sur les formes rondes) et ombre portée (bord net près
  du contact, plus flou loin) ; **ombre de contact** la plus sombre.
- Une seule direction de lumière par scène, cohérente sur tous les objets.

## Matériaux (indices visuels)

| Matériau | Indices |
|---|---|
| Bois sec, délavé | Valeur moyenne-claire, grain fin, pas de reflet, arêtes usées plus claires |
| Métal | Reflets nets, couleur du reflet = couleur du milieu, peu de couleur propre (sauf rouille, cuivre) |
| Peau | Diffusion sous la surface : transitions ombre/lumière chaudes (rouge), reflets doux sur front, nez, pommettes |
| Tissu | Pas de reflet net ; épais = plis larges ; usé = couleur passée sur les reliefs |
| Terre, latérite | Mate, grain, plus sombre et saturée quand elle est humide |
| Eau | Reflète le ciel ; transparence près du bord ; trouble (limon) = couleur du sol |

En 3D/PBR : traduire en couleur de base, rugosité, métallique (`../uv-and-texturing/SKILL.md`).

## Accessibilité

Ne pas distinguer des factions ou des états **uniquement** par rouge/vert ; ajouter forme, motif ou valeur.

## Critères de validation

- L'image ou la scène se lit en niveaux de gris ; le focal y reste le plus contrasté.
- Direction de lumière cohérente partout ; ombres de contact présentes.
- Les matériaux se distinguent sans légende.
