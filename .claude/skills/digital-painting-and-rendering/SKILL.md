---
name: digital-painting-and-rendering
description: "Peinture numérique et rendu : du thumbnail à l'image finie, blocage des masses, plans et formes, gestion des bords, textures peintes, hiérarchie du détail, paint-over de rendus 3D ou d'images générées, textures pour le jeu. Use for digital painting, rendering, paint-over, painted textures, finishing an illustration."
---

# Peinture numérique et rendu

## Passes

1. **Vignette lisible** (composition, valeurs) — voir `../composition-and-visual-storytelling/SKILL.md`.
2. **Blocage** des grandes masses de valeur et des zones de couleur, à gros pinceau, sans détail.
3. **Formes par plans** : décrire les changements de plan (face éclairée / demi-teinte / ombre), pas du bruit.
4. **Bords** : nets au focal et aux contacts, perdus dans les ombres et loin du focal ; varier volontairement.
5. **Texture** seulement là où elle dit la matière ou l'échelle ; plus fine au loin, plus grosse au premier plan.
6. **Détail hiérarchisé** : beaucoup au focal, peu ailleurs (règle 70/20/10 approximative).
7. **Comparer** à la référence et à la bible avant toute finition ; corriger structure > valeurs > couleur > détail.
8. **Fichier réutilisable** : calques nommés, ou procédé reproductible (script, paramètres de génération).

## Paint-over

Sur un rendu 3D ou une image générée : garder la construction, corriger anatomie, perspective, éclairage et
identité ; documenter ce qui a été repeint.

## Textures peintes pour le jeu

Pas d'ombres portées ni de lumière directionnelle cuites dans une texture qui sera éclairée en temps réel
(seulement l'occlusion ambiante légère) ; textures **répétables** (raccords vérifiés en mosaïque 2×2) ;
résolution adaptée à la taille à l'écran.

## Critères de validation

- Hiérarchie de détail claire ; bords maîtrisés ; pas de « bruit » de pinceau sans fonction.
- Lumière cohérente avec la scène ou le moteur ; textures sans raccord visible.
