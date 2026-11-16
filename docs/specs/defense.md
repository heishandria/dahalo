# Spec — Défense du village : Case des Hommes, palissade, améliorations

> Statut : **prototype v0.10** (16/11/2026). Décrit ce qui est **réellement codé**.
> Valeurs : `data/game_rules.gd` (COUTS_BATIMENTS, FORMATIONS, PALISSADE_*, TECHNOLOGIES).

## 1. Case des Hommes (GDD §5)

- **Coût** : 120 bois. Bouton « Case Hommes » (ligne « Clan »).
- **Forme les guerriers** : Dahalo, Lanceur de sagaies, Tireur. La **Case centrale** ne forme plus que
  les villageois et les pisteurs.
- Sans Case des Hommes, les boutons de guerriers affichent : « Construisez d'abord une Case des Hommes ».
- Le Tireur demande **en plus** un Tsena (fusils achetés aux marchands).
- C'est aussi le lieu des **recherches militaires** (§3).

## 2. Palissade épineuse (GDD §5)

| Propriété | Valeur |
|---|---|
| Coût | 15 bois par segment de 4 m |
| Points de vie | 150 |
| Effet | **Bloque les unités des autres clans.** Son propre clan et les zébus passent librement (pas besoin de porte) |
| Vision | Comme un bâtiment (12 m, 7,2 m la nuit) : elle sert aussi de poste de guet |

- **Tracé de point en point** : bouton « Palissade », toucher un premier point (un piquet apparaît), puis
  les points suivants. Chaque toucher relie le point précédent par des **segments jointifs** (autant de
  segments de 4 m qu'il faut, répartis sans trou, 15 bois chacun). « Aucun », Échap ou clic droit termine.
  Un segment qui tomberait sur un bâtiment ou une ressource n'est pas posé (ni payé).
- **Sabotage automatique** : un **guerrier** adverse arrêté par la palissade l'attaque de lui-même, puis
  **reprend son ordre** (pillage, capture, déplacement) une fois le segment détruit. Un Dahalo seul met
  **12,5 s** par segment (150 PV, 12 dégâts/s) ; trois Dahalo, ~4 s. Villageois et Pisteurs adverses restent bloqués.
- Le joueur peut aussi ordonner le sabotage (clic droit / toucher sur une palissade ennemie).
- **Alerte** dès que votre palissade est frappée : message « Votre palissade est attaquée ! » et cercle rouge
  sur la mini-carte (au plus toutes les 6 s par segment).
- Un raideur enfermé doit aussi percer pour **ressortir** s'il ne repasse pas par sa brèche.
- Les épines **ralentissent** aussi les ennemis à 35 % de leur vitesse dans une bande de 1,3 m de chaque côté
  (y compris dans une brèche, à cause des segments voisins).
- Technique : le chemin calculé ignore les palissades ; c'est la collision (un calque par clan) qui arrête l'unité.

## 2 bis. Temps de capture (raids)

| Action du Dahalo | Durée |
|---|---|
| Passer la corde à un zébu sauvage, ou reprendre un zébu escorté par l'ennemi | **1,5 s** |
| **Détacher un zébu dans un enclos adverse** | **4 s par zébu** (20 s pour un raid complet de 5) |

- Pendant ce temps le Dahalo est immobile, le zébu aussi ; une étiquette « Corde… 60 % » s'affiche au-dessus de lui.
- **L'enclos donne l'alerte dès le début** du détachement (message + mini-carte), pas après le vol.
- Si le Dahalo est frappé et riposte, ou reçoit un autre ordre, la progression est perdue.

## 3. Améliorations

| Technologie | Où | Coût | Durée | Effet |
|---|---|---|---|---|
| **Sagaies acérées** (**Âge 2**) | Case des Hommes | 100 nourriture + 50 bois + 40 Ar | 30 s | **+30 % de dégâts** pour les armes à sagaie (Dahalo, Lanceur) |
| **Raid éclair** (**Âge 3**) | Case des Hommes | 150 nourriture + 80 Ar | 40 s | Escorte presque à pleine vitesse |

Une seule recherche à la fois par bâtiment. Toutes les technologies : voir `ages.md`.

## 4. IA

- Construit sa **Case des Hommes** dès qu'elle a 4 villageois et 120 bois, puis y forme Dahalo et Lanceurs.
- Recherche Sagaies acérées et Raid éclair selon son plan (voir `ages.md`).
- Ses guerriers **sabotent automatiquement** vos palissades quand elles leur barrent la route.
- **Palissades de l'IA** : elle entoure chaque enclos qui contient **au moins 4 zébus** d'un carré de palissade
  à 2 m de la clôture (12 segments, 180 bois), en commençant par l'enclos le plus garni.
  - **Un segment par réflexion** (toutes les 1,5 s), seulement s'il lui reste **100 bois** après paiement :
    enclos, champs et Case des Hommes passent avant.
  - Un segment **saboté est reconstruit** de la même façon (il manque à nouveau dans le carré).
  - Un segment qui tomberait sur un champ, un arbre ou un bâtiment n'est **pas posé** : l'IA ne le décale pas,
    la brèche reste. Sur la carte de test, l'enclos de départ a ainsi une brèche côté champs (11 segments sur 12).
  - Comme l'IA dépose tous ses zébus dans son premier enclos, c'est en pratique le seul clôturé.
  - Valeurs : constantes `PALISSADE_*` en tête de `systems/ai_controller.gd`.

## 5. Écarts avec le GDD

| GDD | Prototype | Statut |
|---|---|---|
| Case des Hommes : convertit des villageois en Dahalo | Forme des guerriers neufs (coût en ressources) | À trancher : conversion de villageois ? |
| Palissade : ralentit l'intrusion des Dahalo | **Bloque** les ennemis jusqu'au sabotage | **Décidé** (16/11) : plus fort que le GDD |
| Dahalo : sabotage de palissades | Tout guerrier la sabote, automatiquement s'il est bloqué | **Fait** |
| « Sagaies acérées » en Âge 2 | Âge 2 | **Fait** (voir `ages.md`) |
| Palissade : défense du joueur | L'IA clôture aussi ses enclos garnis | **Fait** (16/11) |

## 6. Questions ouvertes

2. Les Dahalo doivent-ils saboter **plus vite** que les autres guerriers (bonus d'infiltration) ?
3. Former un guerrier en **convertissant un villageois** (comme le dit le GDD) ?
4. L'IA devrait-elle répartir ses zébus entre ses enclos (et donc clôturer les suivants) ?
