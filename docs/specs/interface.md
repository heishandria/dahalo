# Spec — Interface et confort de jeu

> Statut : **prototype v0.11** (17/11/2026). Décrit ce qui est **réellement codé**.
> Code : `ui/hud.gd`, `ui/mini_carte.gd`, `systems/selection_manager.gd`, `scenes/main.gd` (validité des emplacements).
> Règle : tout est jouable **à la souris ET au doigt** (cible mobile : Safari iOS).

## 1. Écran

| Zone | Contenu |
|---|---|
| Bandeau haut | Nourriture et eau (avec consommation/min du cheptel), bois, Ariary, zébus / capacité, météo, jour/nuit, temps restant, zébus du rival, alerte de manque |
| Haut gauche | **Mini-carte** (§3) |
| Bas gauche | Sélection en cours (unités ou bâtiment) + aide (souris ou tactile selon l'appareil) |
| Bas droite | **Panneau du bâtiment sélectionné** (§2 quater), puis boutons toujours visibles : Choisir, Village, Clan |
| Centre haut | Messages (s'effacent en 4 s) |

## 2. Construction : aperçu et emplacements

- Après un bouton de construction, un **bâtiment fantôme** montre l'emprise :
  **vert** = emplacement libre, **rouge** = impossible.
  - **Souris** : le fantôme suit le curseur ; clic gauche pour construire, clic droit pour annuler.
  - **Tactile** : 1er toucher = aperçu ; **2e toucher à moins de 3 m** = construire ; toucher ailleurs = déplacer l'aperçu.
  - **Palissade** : tracée de point en point (un piquet marque le dernier point) ; voir `defense.md`.
- **Emplacement refusé** (message au joueur) si :
  - trop près du bord de la carte ;
  - **sur une colline** (au-dessus de 0,3 m) ou **dans le lit de rivière** (voir `carte.md`) ;
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

## 2 quater. Bâtiment sélectionné : panneau contextuel

- **Sélectionner un bâtiment** : clic gauche dessus (souris) ; au doigt, le toucher **quand aucune unité n'est
  sélectionnée** (avec des unités sélectionnées, toucher son bâtiment reste l'ordre « déposer »). Toucher le sol
  désélectionne. Un **anneau doré** entoure le bâtiment. Sélectionner des unités désélectionne le bâtiment.
- Le panneau s'ouvre en bas à droite, au-dessus des boutons permanents :

| Bâtiment | État affiché | Boutons |
|---|---|---|
| Case centrale | Dépôt de toutes les ressources | Former : Villageois, Pisteur ; Recherche : âges et technologies de la Case |
| Case des Hommes | — | Former : Dahalo, Lanceur, Tireur ; Recherche : Sagaies acérées, Raid éclair |
| Tsena | — | Marché : vendre zébu, acheter bois / nourriture, vendre bois / nourriture, acheter zébu ; Recherche : Maîtres du Tsena |
| Enclos | Zébus dans cet enclos, cheptel / capacité | — |
| Camp de bûcherons | Dépôt de bois | — |
| Palissade | Solidité (PV / 150) | — |

- Partout : **formations en cours** (nombre et secondes avant la prochaine) et **recherche en cours** (secondes restantes).
- Chaque bouton montre **son coût ou son prix actuel** sur la 2e ligne (prix du Tsena : sécheresse et Maîtres du
  Tsena compris). Bouton **grisé** avec la raison quand c'est impossible (« Âge 2 », « Il faut un Tsena »,
  « en cours… », une autre recherche occupe le bâtiment). Bouton **teinté de rouge** quand on n'a pas de quoi payer.
- Les anciennes lignes permanentes « Former », « Recherche » et « Tsena » sont **retirées** : on forme,
  recherche et commerce en touchant le bâtiment. Raccourcis PC inchangés (1 à 5 : former dans le bâtiment
  sélectionné s'il le peut, sinon dans le premier bâtiment adapté).

## 2 ter. Déplacements et collisions

| Obstacle | Contourné par le chemin | Collision physique | Remarque |
|---|---|---|---|
| Case centrale, Case des Hommes, camp de bûcherons, Tsena, puits | Oui | Oui | Chemin recalculé à chaque construction |
| Points d'eau, baobabs | Oui | Oui | |
| Clôtures d'enclos | Oui | Non | On entre **par l'ouverture** (côté sud) ; les zébus ne s'y accrochent pas |
| Arbres épineux, raketa | **Oui** | Oui | Les chemins contournent les bosquets (comme les forêts d'AoE) ; on récolte depuis le bord. Un arbre abattu reste contourné jusqu'au prochain recalcul |
| Lit de rivière | Non (on le traverse) | Non | **Ralentit à 60 %** unités et zébus (sable) |
| Champs | Non | Non | Le champ se cultive dessus |
| Palissades | Non | **Oui, pour les autres clans seulement** | Bloque l'ennemi jusqu'au sabotage ; son clan et les zébus passent |
| Collines (au-dessus de 0,9 m) | Oui | Oui | Infranchissables, pour tous ; le pied est praticable |
| Autres unités | Évitement | Non | Les unités s'écartent les unes des autres (évitement réciproque) |
| Zébus | Évitement | Non | Chaque zébu porte un obstacle d'évitement (rayon 1 m) : villageois et guerriers le contournent |

Les zébus heurtent bâtiments et arbres (boîte 0,75 × 1,3 × 2,1 m, à la taille du modèle), mais pas les clôtures.
Depuis le 17/11 ils gardent un **espace vital** sans blocage physique (un Dahalo doit pouvoir mener son troupeau
au milieu des autres) :
- le corps est vu comme un segment épaules → croupe (1,7 m) ; deux zébus sont repoussés si leurs axes passent à
  moins de **0,85 m** (même placés en croix, ils ne se traversent plus), un zébu et une personne à moins de **0,75 m** ;
- au repos, un zébu ne bouge que pour laisser de la place (sans se retourner) ; son meneur n'est pas repoussé ;
- dans l'enclos, le tas de fourrage (1 m) et l'auge (0,6 m autour du tronc) les repoussent aussi ;
- dans l'enclos, les **deux bouts du corps** restent dans un carré de 3,35 m autour du centre (clôture à ~3,95 m),
  et les points d'errance sont répartis sur toute la surface (rayon 2,8 m) au lieu de s'entasser au centre ;
- en escorte, file par deux espacée à la taille réelle : 2,4 m derrière le meneur puis 2,5 m par rang, ±0,75 m sur le côté.

- **Chemin** : le navmesh lit le sol **et** toutes les entités (groupe `source_navigation` : sol + `Entites`),
  calques 1, 4, 5 et 6, avec une marge de 0,75 m autour des obstacles (le corps d'une unité fait 0,4 m de rayon).
  Avant le 17/11, il ne lisait que le sol : les chemins traversaient bâtiments et bosquets.
- **Blocage** : une unité **en train d'avancer** qui parcourt moins de 1 m en 3 s **abandonne son trajet** et
  redevient inactive (sauf en attaque). Une unité arrivée au bout de son chemin n'est jamais considérée comme
  bloquée ; un villageois en récolte recalcule son chemin et réessaie au lieu d'abandonner.
  Corrigé le 17/11 : la détection arrêtait les villageois arrivés au bord d'un bosquet ou de la Case centrale
  (distances mesurées au centre), qui cessaient alors de travailler.

## 3. Mini-carte

- 200 × 200 px, toute la carte (240 × 240 m), **respecte le brouillard** : noir = inexploré,
  brun = exploré, ocre clair = visible.
- Terrain exploré : collines (parties infranchissables) en ocre clair, lit de rivière en sable.
- Affiche : points d'eau découverts (bleu), bâtiments (carrés couleur du clan ; ennemis une fois explorés),
  zébus (blanc ; les siens toujours, les autres s'ils sont visibles), unités (ronds couleur du clan ;
  ennemies seulement si visibles), cadre blanc de la zone vue par la caméra.
- **Alertes** : cercle rouge clignotant 6 s quand un de vos zébus est volé ou qu'une de vos unités est
  attaquée (au plus une alerte toutes les 5 s par unité).
- **Toucher / cliquer / glisser** sur la mini-carte déplace la caméra.
- Rafraîchie 4 fois par seconde.

## 4. À faire

- File de formation visible et point de ralliement.
- Attaque en mouvement, groupes d'unités (Ctrl+1…).
- Icônes d'activité au-dessus des villageois.
- Menu principal, pause, options.
