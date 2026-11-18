---
name: line-art-and-inking
description: "Line art et encrage : hiérarchie des traits, épaisseur selon le plan et la lumière, contours propres, hachures, dessin vectoriel SVG (chemins, courbes de Bézier, groupes), pictogrammes et icônes lisibles. Use for line art, inking, clean lines, SVG vector drawing, icons, hatching."
---

# Line art et encrage

## Méthode

1. **Décider** si le trait fait partie du style ou si les formes se lisent par la valeur seule.
2. **Hiérarchie** : contour extérieur (le plus épais) > lignes de structure (chevauchements, plis majeurs) >
   détails (le plus fin).
3. **Épaisseur variable** : plus épais du côté de l'ombre, aux chevauchements et près du spectateur ; plus fin
   côté lumière et au loin ; affiner les extrémités.
4. **Ne pas tout cerner** : laisser des lignes ouvertes côté lumière.
5. **Raccords** : pas de tangentes, pas de trous accidentels, croisements nets.
6. **Hachures** : suivent la forme (courbes autour d'un cylindre), servent la valeur, jamais décoratives.

## SVG (dessin par code)

- `viewBox` fixe et unités cohérentes ; formes organiques en courbes de Bézier (`C`, `Q`), pas en polygones.
- Groupes nommés (`<g id="tete">`) ; traits `stroke-linecap="round"` / `stroke-linejoin="round"` ;
  épaisseur variable par formes remplies (contour = forme pleine) plutôt que par `stroke` uniforme.
- Palette en variables (CSS `--couleur`) ; pas de texte converti si le texte doit rester modifiable.
- **Toujours rendre en PNG et regarder** à la taille finale : `rsvg-convert`, Inkscape, un navigateur, Blender
  (import SVG), ou sur macOS sans rien installer : `qlmanage -t -s 512 -o dossier_sortie fichier.svg`
  (produit `fichier.svg.png`).

## Icônes

Grille (24/32/48 px), marges égales, une idée par icône, test à la taille réelle et en monochrome.

## Critères de validation

- Silhouette et structure claires à la taille d'affichage ; épaisseurs qui donnent la profondeur.
- SVG valide, propre (pas de chemins dupliqués), rendu vérifié.
