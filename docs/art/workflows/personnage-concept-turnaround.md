# Workflow : personnage ou animal, du concept au turnaround

Skills : game-art-router → character-design (ou animal-and-creature-design) → human-anatomy-and-character →
drawing-fundamentals → gesture-and-figure-drawing → visual-reference-research → turnaround-and-production-sheets
→ visual-quality-review.

1. **Brief** (5 lignes) : rôle en jeu, métier/comportement, contexte (sourcé), taille à l'écran, invariants connus.
2. **Références** : planche avec sources ; séparer faits / inspiration (`docs/art/madagascar-references.md`).
3. **Silhouettes** : 6–12 vignettes noires ; test côte à côte avec les unités existantes, à la taille de jeu.
4. **Construction** de la silhouette retenue (masses, articulations, proportions en têtes).
5. **Concept 3/4** ; écrire les invariants d'identité.
6. **Vues face / profil / dos** à la même échelle, mêmes lignes de repère.
   Méthode fiable : blockout 3D + `rendu_verification.py` + paint-over. Génération d'image : exploration seulement.
7. **Callouts** : palette, matériaux, accessoires, zones inconnues marquées.
8. **Revue** (`visual-quality-review`) ; corriger ; revérifier.
9. **Passation** au modèle 3D : budget, éléments séparables, déformations attendues, animations nécessaires.

Contrôles : silhouette lisible à 32–64 px ; repères alignés entre vues ; faits culturels sourcés.
