---
name: environment-and-architecture
description: "Environnements de jeu : architecture vernaculaire, villages, paysages et terrains, végétation et écologie, level art (lisibilité, chemins, repères), modularité des kits, éclairage et narration environnementale, vérification à la caméra de jeu. Use for environment design, architecture, villages, landscapes, vegetation, level art, environmental storytelling."
---

# Environnements et architecture

## Méthode

1. **Contexte** : lieu, climat, saison, époque, culture (sourcée), fonction en jeu (base, zone de ressources,
   passage), chemin du joueur, distance caméra.
2. **Références réelles de la région** : architecture (plan, matériaux, toiture, ouvertures, orientation),
   paysage (relief, sols, couleurs), végétation (espèces, densité, saisonnalité). Distinguer faits et choix.
3. **Composition macro** : premier plan / plan moyen / fond, ou, en vue de dessus, zones claires (praticables)
   et zones chargées (obstacles, décor). Le sol jouable doit rester lisible.
4. **Blockout à l'échelle du jeu** : terrain, chemins, bâtiments, repères ; vérifier circulation, lignes de vue,
   repères d'orientation, emprises au sol (collisions = forme visible).
5. **Kit modulaire** : quelques formes de base, toitures, ouvertures, matériaux et objets combinables ;
   variantes par rotation, échelle, usure, plutôt que des modèles uniques.
6. **Végétation à logique écologique** : où il y a de l'eau, plus de vert ; plantes groupées en massifs, pas
   saupoudrées ; ce qui pousse sur une pente, un lit de rivière, une crête. Saisons : feuilles, couleur.
7. **Usure et vie** : traces d'usage là où les gens passent (sol tassé autour des puits et des portes),
   objets du quotidien, réparations. La narration passe par ces détails, après la lisibilité.
8. **Lumière** : direction et couleur de la lumière principale fixées dans la bible ; ombres portées
   lisibles ; variantes jour/nuit/saison seulement quand la base fonctionne.

## Level art (jeu vu de haut / RTS)

- Contraste de valeur entre sol jouable et unités ; pas de texture de sol plus contrastée que les unités.
- Ressources et bâtiments reconnaissables par silhouette vue du dessus ; repères (gros arbres, rochers)
  pour s'orienter.
- Densité de décor plus faible là où se déroulent les combats/déplacements.

## Critères de validation

- Lisible à la caméra de jeu (capture en jeu, pas seulement en éditeur) et en niveaux de gris.
- Architecture et végétation cohérentes avec la région (sources) ou signalées comme choix.
- Kit réutilisable : pièces nommées, échelles cohérentes, pivots au sol.
