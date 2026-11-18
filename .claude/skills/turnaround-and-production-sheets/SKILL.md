---
name: turnaround-and-production-sheets
description: "Planches de production : turnaround (face, profil, dos, trois-quarts), cohérence entre les vues, character sheet, planches d'expressions et de poses, callouts de matériaux, notes pour le modeleur 3D et le rig. Use for turnarounds, model sheets, character sheets, orthographic views, multi-view consistency."
---

# Turnarounds et planches de production

## Méthode

1. **Vues** : face, profil (côté d'action), dos, 3/4 ; dessus/dessous seulement si utile (coiffe, sabots).
2. **Même échelle, même ligne de sol, pose neutre** (A-pose bras à ~45° ou T-pose pour le rig ; pieds à
   largeur de hanches). La pose neutre est différente de la pose « beauté » : les séparer.
3. **Lignes de repère horizontales** traversant toutes les vues : sommet du crâne, yeux, menton, épaules,
   poitrine, taille, entrejambe, genoux, chevilles, sol. Chaque repère doit tomber au même niveau partout.
4. **Verrouiller les invariants** (character-design §8) avant de produire les autres vues ; les vues sont
   **dérivées** de la même construction, jamais réinventées une par une.
5. **Callouts** : couleurs (pastilles + valeurs), matériaux, accessoires en gros plan (mains, pieds, coiffe,
   outils), zones cachées marquées « inconnu » plutôt qu'inventées.
6. **Notes 3D** : symétrie, pivots, zones qui doivent se déformer (épaules, coudes, hanches, genoux, tissu),
   budget, éléments séparables (accessoires détachables, seau, arme).

## Obtenir des vues cohérentes

- **Méthode fiable** : construire un blockout 3D (ou un modèle) puis rendre les vues orthographiques
  (`../blender-python-pipeline/scripts/rendu_verification.py`) et peindre par-dessus.
- **Génération d'images** : utile pour explorer, **pas** pour garantir face/profil/dos identiques ; vérifier
  chaque repère, corriger à la main ou par 3D.
- **Contrôle** : superposer les vues avec les lignes de repère ; mesurer en têtes.

## Critères de validation

- Un modeleur peut construire sans deviner : repères alignés, proportions identiques entre vues.
- Aucun détail ne change de côté, de forme ou de couleur d'une vue à l'autre.
- Les zones inconnues sont signalées, pas inventées.
