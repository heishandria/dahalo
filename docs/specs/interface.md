# Spec — Interface et confort de jeu

> Statut : **prototype v0.7** (16/11/2026). Décrit ce qui est **réellement codé**.
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
  - **Palissade** : posée directement à chaque toucher, le mode reste actif pour enchaîner les segments.
- **Emplacement refusé** (message au joueur) si :
  - trop près du bord de la carte ;
  - **zone inexplorée** ;
  - **chevauchement** avec un bâtiment, un champ, un puits, une ressource ou un baobab
    (test par cercles d'emprise ; les segments de palissade peuvent se toucher entre eux).
- Emprises : case 4×4, enclos 8×8, champ 6×6, camp 3×3, puits 2,6×2,6, Tsena 5×4, Case des Hommes 4,5×3,5,
  palissade 4×0,6 m.
- **IA** : si son emplacement prévu est pris, elle cherche un emplacement libre en spirale (jusqu'à 16 m).
- Rien n'est payé si l'emplacement est refusé.

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
