# Spec — Carte : génération, rivière, sol et paysage

> Statut : **prototype v0.11** (17/11/2026). Décrit ce qui est **réellement codé**.
> Code : `systems/generateur_carte.gd` (placement), `autoload/terrain.gd` (rivière), `scenes/main.gd` (création),
> `scenes/world/terrain.gdshader` (sol), `scenes/world/paysage.gd` (relief et décor hors zone de jeu).
> Valeurs : `data/game_rules.gd` (`DEMI_CARTE`, `CARTE_*`, `RIVIERE_*`).

## 1. Zone de jeu

- Carré de **240 × 240 m** (±120 m), échelle d'une carte 2 joueurs d'Age of Empires, **plat à y = 0**.
  Unités et bâtiments restent dans ±116 m.
- **Carte aléatoire à graine** (GDD §8) : chaque partie tire une graine ; `-- --graine=N` impose la graine
  (même graine = exactement la même carte). La graine est écrite dans le journal (`[carte] graine N`).

## 2. Génération : équité par symétrie

La carte est **symétrique par rapport au centre** : tout ce qui est placé en *p* l'est aussi en *−p*, et la base de
l'IA est l'image de celle du joueur. Les deux clans ont donc exactement les mêmes chances, quelle que soit la graine.

| Élément | Nombre | Règle de placement |
|---|---|---|
| Bases | 2 | Face à face, à **78 m du centre** (156 m l'une de l'autre), angle tiré au hasard |
| Kit de chaque base | — | Case centrale, enclos, 2 champs mûrs, 3 villageois, 1 Dahalo, 1 Pisteur, **bosquet de 10 épineux**, **point d'eau**, 2 raketa ; même disposition dans le repère de chaque base (« avant » = vers le centre) |
| Lit de rivière à sec | 1 | Traverse toute la carte **entre les deux bases** (perpendiculaire à leur axe), en méandres tirés au hasard ; passe par le centre |
| Trous d'eau | 1 paire | Creusés dans le sable du lit, entre 20 et 60 m du centre |
| Troupeaux sauvages | 3 | 8 zébus au centre (dans le lit) + une paire de 6, à plus de 45 m des bases |
| Bosquets d'épineux neutres | 7 paires | 8 à 14 arbres, à plus de 30 m des bases, hors du lit |
| Raketa | 3 paires | À plus de 22 m des bases, hors du lit |
| Baobabs (décor, obstacles) | 5 paires | À plus de 25 m des bases, hors du lit |
| Points de migration | 5 | Le centre + 2 paires, à plus de 45 m des bases (voir `economie.md` §9) |
| Zones de test | 3 paires | Laissées vides pour les duels du test de fumée (CI) |

Les emplacements ne se chevauchent pas (3 m de marge) et restent à 8 m du bord.

## 3. Lit de rivière à sec (type Menarandra)

- **Largeur 11 m**. Dans le sable, **unités et zébus avancent à 60 %** de leur vitesse : tout raid entre les deux
  bases doit le traverser, à l'aller comme au retour avec les zébus.
- Il ne bloque rien (ni chemin, ni construction pour l'instant).
- **Trous d'eau** dans le lit : points d'eau ordinaires (×0,3 en sécheresse), comme ceux qu'on creuse vraiment dans
  le sable des rivières de l'Androy.
- Rendu : sable clair, plus sombre et humide au milieu hors sécheresse ; berges plus herbeuses. Il se prolonge hors
  de la zone de jeu par une **vallée à fond plat** dans le relief.
- Technique : `Terrain` garde la distance au lit sur une grille de 2 m couvrant ±280 m (zone de jeu + relief) ;
  le shader la lit en texture.

## 4. Sol

- Un seul shader pour le sol de la zone de jeu **et** le relief : raccord sans couture au bord.
- Latérite rouge plus ou moins sombre, plaques de sable, **herbe sèche** ; roche calcaire beige sur les pentes et les
  hauteurs, avec des **strates horizontales** sur les parois.
- **Sécheresse** : l'herbe disparaît presque, tout pâlit et tire vers l'ocre (sol et relief, via `EventBus.meteo_change`).
- Bruit calculé dans le shader, sans texture : même rendu sur PC, Web (Compatibility) et mobile.

## 5. Paysage autour de la zone de jeu (purement visuel)

| Élément | Où | Détail |
|---|---|---|
| Relief | De ±120 m à ±280 m | Collines puis plateau. Côté **proche de la caméra** (bas de l'écran) : collines basses, pour ne pas cacher les unités au bord. Côté **lointain** : **escarpements** jusqu'à ~30 m. Vallée plate le long de la rivière |
| Rochers, fourrés, épineux, baobabs | 170 / 260 / 140 touffes / 10 | Posés sur le relief, hors de la vallée |

- **Aucune collision**, hors du navmesh, invisible pour la mini-carte et le brouillard : aucun effet sur le jeu.
- Paysage tiré avec la **même graine** que la carte.

## 6. Écarts avec le GDD et suite prévue

| GDD | Prototype | Statut |
|---|---|---|
| Carte générée (GDD §8) | Aléatoire à graine, symétrique | **Fait** (17/11) |
| — | Lit de rivière à sec qui ralentit, trous d'eau | **Fait** (17/11) |
| — | Plateaux en paliers infranchissables (falaises), rivière en contrebas | **Décidé** (17/11), à faire |
| — | Eau dans la rivière en saison des pluies, herbe qui reverdit | **Décidé** (17/11), à faire |
| — | Décor en modèles 3D (packs CC0 + modèles sur mesure) | **Décidé** (17/11), à faire |

Questions ouvertes :
1. Interdire la construction dans le lit de rivière ?
2. Les zébus sauvages devraient-ils préférer paître près du lit (herbe des berges) ?
