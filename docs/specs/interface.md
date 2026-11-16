# Spec — Interface et confort de jeu

> Statut : **prototype v0.9** (16/11/2026). Décrit ce qui est **réellement codé**.
> Code : `ui/hud.gd`, `ui/mini_carte.gd`, `systems/selection_manager.gd`, `scenes/main.gd` (validité des emplacements).
> Règle : tout est jouable **à la souris ET au doigt** (cible mobile : Safari iOS).

## 1. Écran

| Zone | Contenu |
|---|---|
| Bandeau haut | Nourriture et eau (avec consommation/min du cheptel), bois, Ariary, zébus / capacité, météo, jour/nuit, temps restant, zébus du rival, alerte de manque |
| Haut gauche | **Mini-carte** (§3) |
| Bas gauche | Sélection en cours + aide (souris ou tactile selon l'appareil) |
| Bas droite | Boutons : Choisir, Former, Village, Clan, Tsena |
| Centre haut | Messages (s'effacent en 4 s) |

## 2. Construction : aperçu et emplacements

- Après un bouton de construction, un **bâtiment fantôme** montre l'emprise :
  **vert** = emplacement libre, **rouge** = impossible.
  - **Souris** : le fantôme suit le curseur ; clic gauche pour construire, clic droit pour annuler.
  - **Tactile** : 1er toucher = aperçu ; **2e toucher à moins de 3 m** = construire ; toucher ailleurs = déplacer l'aperçu.
  - **Palissade** : tracée de point en point (un piquet marque le dernier point) ; voir `defense.md`.
- **Emplacement refusé** (message au joueur) si :
  - trop près du bord de la carte ;
  - **zone inexplorée** ;
  - **chevauchement** avec un bâtiment, un champ, un puits, une ressource ou un baobab
    (test par cercles d'emprise ; les segments de palissade peuvent se toucher entre eux).
- Emprises : case 4×4, enclos 8×8, champ 6×6, camp 3×3, puits 2,6×2,6, Tsena 5×4, Case des Hommes 4,5×3,5,
  palissade 4×0,6 m.
- **IA** : si son emplacement prévu est pris, elle cherche un emplacement libre en spirale (jusqu'à 16 m).
- Rien n'est payé si l'emplacement est refusé.

## 2 bis. Sélection et ciblage

- **Priorité aux unités** : un clic ou un toucher cherche d'abord une unité ou un zébu, en ignorant les
  bâtiments placés devant (vue isométrique) ; puis l'unité la plus proche du point à l'écran
  (**18 px** à la souris, **34 px** au doigt) ; et seulement ensuite les bâtiments, ressources et le sol.
- L'**anneau de sélection** est dessiné par-dessus les bâtiments : une unité sélectionnée cachée derrière
  une case reste repérable.
- Les unités cachées par le brouillard ne sont jamais ciblées.

## 2 ter. Déplacements et collisions

| Obstacle | Contourné par le chemin | Collision physique | Remarque |
|---|---|---|---|
| Case centrale, Case des Hommes, camp de bûcherons, Tsena, puits | Oui | Oui | Chemin recalculé à chaque construction |
| Points d'eau, baobabs | Oui | Oui | |
| Clôtures d'enclos | Oui | Non | On entre **par l'ouverture** (côté sud) ; les zébus ne s'y accrochent pas |
| Arbres épineux, raketa | Non | Oui | Les unités butent dessus et glissent ; un arbre abattu n'est plus un obstacle |
| Champs | Non | Non | Le champ se cultive dessus |
| Palissades | Non | **Oui, pour les autres clans seulement** | Bloque l'ennemi jusqu'au sabotage ; son clan et les zébus passent |
| Autres unités | Évitement | Non | Les unités s'écartent les unes des autres (évitement réciproque) |

Les zébus heurtent bâtiments et arbres, mais pas les clôtures ni les autres unités.

## 3. Mini-carte

- 200 × 200 px, toute la carte (120 × 120 m), **respecte le brouillard** : noir = inexploré,
  brun = exploré, ocre clair = visible.
- Affiche : points d'eau découverts (bleu), bâtiments (carrés couleur du clan ; ennemis une fois explorés),
  zébus (blanc ; les siens toujours, les autres s'ils sont visibles), unités (ronds couleur du clan ;
  ennemies seulement si visibles), cadre blanc de la zone vue par la caméra.
- **Alertes** : cercle rouge clignotant 6 s quand un de vos zébus est volé ou qu'une de vos unités est
  attaquée (au plus une alerte toutes les 5 s par unité).
- **Toucher / cliquer / glisser** sur la mini-carte déplace la caméra.
- Rafraîchie 4 fois par seconde.

## 4. À faire

- File de formation visible et point de ralliement.
- Attaque en mouvement, groupes d'unités (Ctrl+1…), sélection des bâtiments.
- Icônes d'activité au-dessus des villageois.
- Menu principal, pause, options.
