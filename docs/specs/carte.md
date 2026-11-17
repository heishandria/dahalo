# Spec — Carte : génération, rivière, sol et paysage

> Statut : **prototype v0.11** (17/11/2026). Décrit ce qui est **réellement codé**.
> Code : `systems/generateur_carte.gd` (placement, plateaux), `autoload/terrain.gd` (rivière, plateaux),
> `scenes/main.gd` (création, collisions des plateaux), `scenes/world/terrain.gdshader` (couleurs),
> `scenes/world/paysage.gd` (tout le visuel du terrain). Valeurs : `data/game_rules.gd` (`DEMI_CARTE`, `CARTE_*`,
> `RIVIERE_*`, `PLATEAUX_*`).

## 1. Zone de jeu

- Carré de **240 × 240 m** (±120 m), échelle d'une carte 2 joueurs d'Age of Empires. On joue à y = 0 ;
  le lit de rivière est en contrebas, les plateaux au-dessus (infranchissables). Unités et bâtiments restent dans ±116 m.
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
| Plateaux en paliers | ~10 % de la carte | Voir §3 bis |
| Bosquets d'épineux neutres | 7 paires | 8 à 14 arbres, à plus de 30 m des bases, hors du lit |
| Raketa | 3 paires | À plus de 22 m des bases, hors du lit |
| Baobabs (décor, obstacles) | 5 paires | À plus de 25 m des bases, hors du lit |
| Points de migration | 5 | Le centre + 2 paires, à plus de 45 m des bases (voir `economie.md` §9) |
| Zones de test | 3 paires | Laissées vides pour les duels du test de fumée (CI) |

Les emplacements ne se chevauchent pas (3 m de marge), restent à 8 m du bord et évitent les plateaux.

## 3. Lit de rivière à sec (type Menarandra)

- **Largeur 11 m**. Dans le sable, **unités et zébus avancent à 60 %** de leur vitesse : tout raid entre les deux
  bases doit le traverser, à l'aller comme au retour avec les zébus.
- Il ne bloque pas les chemins. **On n'y construit pas** (message « on ne construit pas dans le lit de la rivière »).
- **En contrebas** de 0,8 m, berges en pente douce sur ~3,5 m : visuel seulement (unités, zébus et trous d'eau
  descendent à l'écran ; le corps physique et le navmesh restent à y = 0).
- **Trous d'eau** dans le lit : points d'eau ordinaires (×0,3 en sécheresse), comme ceux qu'on creuse vraiment dans
  le sable des rivières de l'Androy.
- Rendu : sable clair, berges plus herbeuses. **En saison normale, un filet d'eau coule au milieu du lit**
  (~6 m de large, rides animées) ; **en sécheresse il se retire** et le lit est à sec (fondu de 6 s). L'eau est
  purement visuelle : le ralentissement est le même en toute saison. Le lit se prolonge hors de la zone de jeu
  par une **vallée à fond plat** dans le relief.
- Technique : `Terrain` garde la distance au lit sur une grille de 2 m couvrant ±280 m (zone de jeu + relief) ;
  le shader la lit en texture.

## 3 bis. Plateaux en paliers (falaises infranchissables)

- **Forme** : champ de bruit symétrique (même valeur en *p* et *−p*), nul à moins de **42 m des bases**, à moins
  de ~6 m du lit de rivière et autour des emplacements réservés (zones de test, troupeau du centre). Plateau là où
  le champ dépasse un seuil choisi pour couvrir **10 %** de la carte ; **second palier** au cœur des plus grands
  (2,5 % de la carte). Les îlots de moins de 12 cases (48 m²) sont supprimés.
- **Relief** : palier de **2,5 m** (second palier : 5 m), parois verticales, contours lisses (« marching squares »
  sur une grille de 2 m). Dessus clair (calcaire, herbe rase), parois de terre brune à strates.
- **Jeu** : **infranchissables** (collision et navmesh : boîtes sur le calque 4) ; **on n'y construit pas**.
  Ils ne bloquent pas la vue pour l'instant.
- **Équité et accès** : symétriques ; le générateur vérifie (parcours de la grille) que la base du joueur rejoint
  celle de l'IA et le centre. Sinon il réduit les plateaux (jusqu'à 5 essais), puis les supprime.
- **Mini-carte** : plateaux en ocre clair, lit de rivière en sable, une fois explorés.

## 4. Sol

- **Textures photo** (Poly Haven, CC0 ; `assets/textures/terrain/LISEZMOI.md`), un seul shader pour le sol de la
  zone de jeu, les plateaux et le relief (raccords sans couture) :

| Zone | Texture |
|---|---|
| Sol de base | Latérite rouge caillouteuse, variée en grandes plaques |
| Plaques de sable, lit de rivière | Sable graveleux |
| Herbe (plaques, berges) | Herbe clairsemée verte ; **herbe fanée en sécheresse** |
| Lit de rivière en sécheresse | **Boue craquelée** |
| Parois des plateaux, pentes du relief | Falaise stratifiée (Namaqualand) |
| Dessus des plateaux | Sol sec et caillouteux |

- Les masques (où va chaque texture) viennent du bruit et de la distance à la rivière ; textures de relief (normal
  maps) sur la latérite et la falaise. Étalonnage chaud et poussiéreux.
- **Saisons** : fondu de 6 s via `EventBus.meteo_change` (herbe, lit, teinte d'ensemble).
- Le rendu Web limite un shader à 16 textures, moteur compris : le shader du terrain en utilise 11.

## 4 ter. Rendu (direction artistique décidée le 17/11 : « sérieux, un peu réaliste »)

- **PC : Forward+** — occlusion ambiante (SSAO), brume de poussière légère, ombres douces (soleil à 1,5°), contraste
  +5 %, saturation −10 %. **Mobile** : rendu Mobile ; **Web** : Compatibility (sans SSAO ; brume simple).
- Lumière ambiante chaude le jour, bleutée la nuit.

## 4 quinquies. Points d'eau (visuel ; `scenes/world/mare.gd`)

- **Mare du village** : contour irrégulier (propre à chaque mare), eau trouble et limoneuse avec reflets et rides,
  berges de boue humide (plus sombre près de l'eau), herbe plus dense autour.
- **Trou d'eau du lit** : plus petit, entouré d'un bourrelet de sable creusé, un peu d'eau au fond. En saison
  normale il est sous le filet d'eau de la rivière ; il se voit surtout en sécheresse.
- **Sécheresse** : l'eau se retire (fondu de 6 s, 55 % du rayon) et découvre une auréole de boue craquelée.
- Purement visuel : la collision (rayon 1 m) et la récolte restent celles de la ressource (voir `economie.md`).

## 4 bis. Végétation basse de la zone de jeu (purement visuel)

Modèles du pack **Quaternius Stylized Nature MegaKit** (CC0, voir `assets/models/decor/LISEZMOI.md`) ;
si un modèle manque, formes générées par le code.

| Élément | Nombre (PC / Web et mobile) | Détail |
|---|---|---|
| Herbes (4 variantes) | 9 000 / ~3 150 | Par plaques ; **bien plus denses sur les berges** ; aucune dans le sable du lit ; aussi sur le dessus des plateaux. **Dorées en sécheresse** (fondu de 6 s) ; elles **ondulent au vent** |
| Fleurs (2 variantes) | 500 / 175 | **Disparaissent en sécheresse**, reviennent avec les pluies |
| Buissons (2 variantes) | 600 / 210 | Vert olive, hors du lit |
| Cailloux (5 variantes) | 450 / 157 | |
| Rochers | 140 / 49 | **Seulement sur le dessus des plateaux** (personne n'y marche : pas de collision) |

- **Brouillard** : invisible dans les zones jamais explorées (le shader lit la texture du brouillard). Les
  **plateaux** eux-mêmes sont assombris par le shader du terrain (ils dépassent le voile posé au sol).
- **Rien ne pousse** sous les bâtiments, champs, ressources et baobabs ; quand on construit, la végétation sous
  l'emprise disparaît (`EventBus.batiment_cree`).
- Un MultiMesh par variante de modèle : une quinzaine d'appels de dessin. Densité réduite sur le Web et le mobile.

## 5. Paysage autour de la zone de jeu (purement visuel)

| Élément | Où | Détail |
|---|---|---|
| Relief | De ±120 m à ±280 m | Collines puis plateau. Côté **proche de la caméra** (bas de l'écran) : collines basses, pour ne pas cacher les unités au bord. Côté **lointain** : **escarpements** jusqu'à ~30 m. Vallée plate le long de la rivière |
| Rochers, buissons (modèles du pack), épineux, baobabs | 170 / 260 / 140 touffes / 10 | Posés sur le relief, hors de la vallée |
| Arbres morts et tordus (pack) | 70 (25 sur Web et mobile) | **Relief lointain seulement** (haut de l'écran) : de près, ils cacheraient le jeu |

- **Aucune collision**, hors du navmesh, invisible pour la mini-carte et le brouillard : aucun effet sur le jeu.
- Paysage tiré avec la **même graine** que la carte.

## 6. Écarts avec le GDD et suite prévue

| GDD | Prototype | Statut |
|---|---|---|
| Carte générée (GDD §8) | Aléatoire à graine, symétrique | **Fait** (17/11) |
| — | Lit de rivière à sec qui ralentit, trous d'eau | **Fait** (17/11) |
| — | Plateaux en paliers infranchissables (falaises), rivière en contrebas | **Fait** (17/11) |
| — | Eau dans la rivière en saison normale, herbe qui reverdit | **Fait** (17/11, visuel) |
| — | Végétation dense et décor en modèles 3D (pack CC0 Quaternius) | **Fait** (17/11) |
| — | Modèles sur mesure (baobab, Alluaudia, raketa, cases) | **Décidé** (17/11), à faire (Tripo) |

Questions ouvertes :
1. Les plateaux devraient-ils bloquer la vue (ou donner une vision accrue à qui les longe) ?
2. Les zébus sauvages devraient-ils préférer paître près du lit (herbe des berges) ?
