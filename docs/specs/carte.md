# Spec — Carte : génération, rivière, sol et paysage

> Statut : **prototype v0.11** (17/11/2026). Décrit ce qui est **réellement codé**.
> Code : `systems/generateur_carte.gd` (placement, collines, érosion), `autoload/terrain.gd` (rivière, collines),
> `scenes/main.gd` (création, collisions des collines), `scenes/world/terrain.gdshader` (couleurs),
> `scenes/world/paysage.gd` (tout le visuel du terrain). Valeurs : `data/game_rules.gd` (`DEMI_CARTE`, `CARTE_*`,
> `RIVIERE_*`, `PLATEAUX_*`).

## 1. Zone de jeu

- Carré de **240 × 240 m** (±120 m), échelle d'une carte 2 joueurs d'Age of Empires. On joue à y = 0 ;
  le lit de rivière est en contrebas, les collines au-dessus (sommets infranchissables). Unités et bâtiments restent dans ±116 m.
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
| Collines rocheuses érodées | ~10 % de la carte | Voir §3 bis |
| Bosquets d'épineux neutres | 7 paires | 8 à 14 arbres, à plus de 30 m des bases, hors du lit |
| Raketa | 3 paires | À plus de 22 m des bases, hors du lit |
| Baobabs (décor, obstacles) | 5 paires | À plus de 25 m des bases, hors du lit |
| Points de migration | 5 | Le centre + 2 paires, à plus de 45 m des bases (voir `economie.md` §9) |
| Zones de test | 3 paires | Laissées vides pour les duels du test de fumée (CI) |

Les emplacements ne se chevauchent pas (3 m de marge), restent à 8 m du bord et évitent les collines.

## 3. Lit de rivière à sec (type Menarandra)

- **Largeur 11 m**. Dans le sable, **unités et zébus avancent à 60 %** de leur vitesse : tout raid entre les deux
  bases doit le traverser, à l'aller comme au retour avec les zébus.
- Il ne bloque pas les chemins. **On n'y construit pas** (message « on ne construit pas dans le lit de la rivière »).
- **En contrebas** de 0,8 m, berges en pente douce sur ~3,5 m : visuel seulement (unités, zébus et trous d'eau
  descendent à l'écran ; le corps physique et le navmesh restent à y = 0).
- **Trous d'eau** dans le lit : points d'eau ordinaires (×0,3 en sécheresse), comme ceux qu'on creuse vraiment dans
  le sable des rivières de l'Androy.
- Rendu : sable clair, berges plus herbeuses. **En saison normale, un filet d'eau coule au milieu du lit**
  (~6 m de large : eau limoneuse transparente au bord, reflet du ciel selon l'angle, reflets du soleil sur les rides,
  liseré d'écume, sable mouillé autour) ; **en sécheresse il se retire** et le lit est à sec (fondu de 6 s). L'eau est
  purement visuelle : le ralentissement est le même en toute saison. Le lit se prolonge hors de la zone de jeu
  par une **vallée à fond plat** dans le relief.
- Technique : `Terrain` garde la distance au lit sur une grille de 2 m couvrant ±280 m (zone de jeu + relief) ;
  le shader la lit en texture.

## 3 bis. Collines rocheuses érodées (remplacent les plateaux en paliers le 17/11)

- **Forme de départ** : champ de bruit symétrique (même valeur en *p* et *−p*), nul à moins de **42 m des bases**,
  à moins de ~6 m du lit de rivière et autour des emplacements réservés ; dôme arrondi là où il dépasse un seuil
  choisi pour couvrir **10 %** de la carte (îlots de moins de 48 m² supprimés). Hauteur de départ : 14 m au cœur.
- **Érosion** (dans le générateur, à graine) :
  1. **gouttes de pluie** (10 000) : chaque goutte descend la pente, arrache de la matière quand elle va vite et
     la dépose en ralentissant → **ravines** sur les flancs, **cônes d'éboulis** au pied ;
  2. **éboulements** : pente ramenée à 1,5 au plus (~56°) → formes arrondies ;
  3. **symétrisation** (moyenne de *p* et *−p*) pour garder l'équité.
  Résultat : collines jusqu'à ~10 m. Coût : ~1 s au chargement.
- **Jeu** : on marche sur le **pied** des collines ; **au-dessus de 0,9 m, infranchissable** (collision et navmesh :
  boîtes sur le calque 4) ; **on ne construit pas au-dessus de 0,3 m**. Les unités et zébus suivent la hauteur à
  l'écran. Le générateur vérifie (parcours de la grille) que les deux bases et le centre restent reliés ; sinon
  il retire les collines.
- **Rendu** : roche stratifiée sur les pentes, sol caillouteux sombre mêlé de roche sur les hauteurs, rochers
  posés au-dessus de la partie praticable ; assombries par le brouillard dans les zones inexplorées.
- **Mini-carte** : parties infranchissables en ocre clair, lit de rivière en sable, une fois explorés.
- Valeurs : `COLLINES_*` et `PLATEAUX_PART`, `PLATEAUX_DISTANCE_BASES` dans `data/game_rules.gd`.

## 4. Sol

- **Textures photo** (Poly Haven, CC0 ; `assets/textures/terrain/LISEZMOI.md`), un seul shader pour le sol de la
  zone de jeu, les plateaux et le relief (raccords sans couture) :

| Zone | Texture |
|---|---|
| Sol de base | Latérite rouge caillouteuse, variée en grandes plaques |
| Plaques de sable, lit de rivière | Sable graveleux |
| Herbe (plaques, berges) | Herbe verte sur environ la moitié du sol en saison normale (massifs, berges) ; **fanée et plus rare en sécheresse** |
| Lit de rivière en sécheresse | **Boue craquelée** |
| Parois des plateaux, pentes du relief | Falaise stratifiée (Namaqualand) |
| Dessus des plateaux | Sol sec et caillouteux |

- **Sans répétition visible** : chaque texture est lue deux fois (tournée, décalée) et mélangée par plaques.
- **Variations** : grandes plaques de 60 m plus sombres et rouges ou plus claires et ocre ; zones caillouteuses ;
  **sol assombri et verdi sous les massifs de végétation** (carte de densité calculée par `vegetation.gd`, la même
  qui place les touffes : herbe et sol vont ensemble) ; **sable mouillé et sombre** autour du filet d'eau.
- Les masques (où va chaque texture) viennent du bruit et de la distance à la rivière ; textures de relief (normal
  maps) sur la latérite et la falaise. Étalonnage chaud et poussiéreux.
- **Saisons** : fondu de 6 s via `EventBus.meteo_change` (herbe, lit, teinte d'ensemble).
- Le rendu Web limite un shader à 16 textures, moteur compris (3) : le shader du terrain en utilise 13.
- **Performance** : le bruit est lu dans une texture précalculée au chargement (pas recalculé par pixel) ; chaque
  couche (lit de rivière, falaise, sommet des collines, cailloux) n'est calculée que là où elle sert. Sur écran
  Retina en Forward+, la 3D est rendue à 67 % puis agrandie (FSR). Mesuré sur M1 Pro, plein écran : ~20 ips avant
  ces optimisations, 60 ips après (limite de l'écran). Le premier lancement après une modification des shaders
  est lent (compilation des shaders), les suivants non.

## 4 ter. Rendu (direction artistique décidée le 17/11 : « sérieux, un peu réaliste »)

- **PC : Forward+** — soleil chaud et franc, à ~50° de hauteur, venant de la gauche de l'écran (ombres d'environ 0,8 fois la
  hauteur des objets, vers le bas à droite), ambiance basse pour le contraste, occlusion ambiante (SSAO), brume très légère, contraste +12 %. **Mobile** : rendu Mobile ; **Web** : Compatibility (sans SSAO ; brume simple).
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
| Herbes (4 variantes) | 9 000 / ~3 150 | **En massifs** denses, sol nu entre eux ; **bien plus denses sur les berges** ; aucune dans le sable du lit ; aussi sur le dessus des plateaux. **Dorées en sécheresse** (fondu de 6 s) ; elles **ondulent au vent** |
| Fleurs (2 variantes) | 500 / 175 | **Disparaissent en sécheresse**, reviennent avec les pluies |
| Buissons (2 variantes) | 1 100 / 385 | **Regroupés en fourrés** (bush du Sud), rares ailleurs ; hors du lit ; **restent vert terne en sécheresse** |
| Cailloux (5 variantes) | 450 / 157 | |
| Rochers | 140 / 49 | **Seulement sur le dessus des plateaux** (personne n'y marche : pas de collision) |

- **Brouillard** : invisible dans les zones jamais explorées (le shader lit la texture du brouillard). Les
  **plateaux** eux-mêmes sont assombris par le shader du terrain (ils dépassent le voile posé au sol).
- **Rien ne pousse** sous les bâtiments, champs, ressources et baobabs ; quand on construit, la végétation sous
  l'emprise disparaît (`EventBus.batiment_cree`).
- Un MultiMesh par variante de modèle : une quinzaine d'appels de dessin. Densité réduite sur le Web et le mobile.

## 4 sexies. Ciel : nuages et oiseaux (purement visuel ; `scenes/world/ciel.gd`)

- **Nuages** : 8 nuages légers et translucides à ~35 m, contour effiloché, qui dérivent avec le vent (~1,7 m/s)
  et font le tour de la carte. Chacun projette **son ombre au sol** (décalque dans la direction du soleil,
  opacité 26 %), effacée la nuit. **En sécheresse, moins de nuages** (fondu de 8 s). Le rendu Web ne gère pas
  les décalques : nuages sans ombre.
- **Oiseaux** : un vol traverse la carte toutes les 12 à 35 s (3 à la fois au plus), avec battement d'ailes et
  ombre portée :
  - **corbeaux pies** (noirs, collier blanc), 3 à 6, entre 14 et 22 m ;
  - **hérons garde-bœufs** (blancs), 6 à 11, entre 10 et 16 m, battement plus lent.
- Les oiseaux sont **masqués au-dessus des zones inexplorées** (ils ne doivent rien révéler).
- Aucun nom affiché en jeu (termes malgaches à vérifier avant de les introduire).

## 4 septies. Plantes de l'Androy (`scenes/world/plantes.gd`, en attendant les modèles sur mesure)

| Plante | Forme | Saisons |
|---|---|---|
| Baobab (types *za* / *grandidieri*) | **6 variantes en deux familles** : **élancé** (tronc haut et cylindrique de 9 à 11,5 m, couronne plate en ombrelle) et **trapu** (tronc court et massif, pied très évasé en contreforts, grosses branches basses qui montent). Tronc cannelé, écorce photo gris rosé (Poly Haven, CC0), grosses branches coudées et tortueuses, **petites branches le long des grosses**, ramification sur 5 niveaux jusqu'aux brindilles, grappes de feuilles texturées ; 6 000 à 9 000 triangles. Collision : 1,3 m (élancé), 2,1 m (trapu) |
| Épineux (type *Alluaudia*) | 3 à 6 tiges gris-vert dressées, couvertes de petites feuilles | Perd ses feuilles en sécheresse |
| Raketa (figuier de Barbarie) | Raquettes en éventail, fruits rouges | Inchangé |

- 3 variantes de chaque, tirées de la position ; utilisées en jeu (ressources, baobabs) et sur le relief.
- Descriptions pour faire les modèles définitifs (Canva puis Tripo) : `docs/modeles_sur_mesure.md`.

## 4 octies. Bâtiments du village (visuel ; `scenes/buildings/maisons.gd`)

D'après des photos de cases du Sud fournies le 17/11 : petites cases rectangulaires posées sur la terre,
**toit de chaume à deux pentes très raide**, débordant et effiloché, **perches croisées au faîte**, porte en planches.

| Bâtiment | Modèle |
|---|---|
| Case centrale | Murs en **rondins horizontaux** entre poteaux d'angle, pignons en planches |
| Case des Hommes | Murs en **roseaux tressés** tenus par trois lattes, piquet au milieu de chaque mur |
| Camp de bûcherons | Abri ouvert de chaume sur quatre poteaux, **tas de bûches**, billot, branches |
| Tsena | Abri ouvert couvert de **tôle rouillée**, deux étals sur tréteaux avec paniers, sacs |
| Enclos à zébus | D'après une photo fournie le 17/11 : **perches dressées tordues**, espacées au hasard, plus ou moins hautes et penchées, **trois rangs de traverses** tordues (certaines manquent, d'autres se chevauchent), perches en écharpe ; **contour en carré arrondi et cabossé** (±0,35 m) ; **sol piétiné et boueux** au bord fondu, litière de paille. Ouverture de 2 m au sud, poteaux d'entrée plus hauts |

- **Fait main, rien n'est d'équerre** : angles décalés, murs de hauteurs inégales, rondins et poteaux tordus et
  penchés (longueurs, diamètres et jours variables), panneaux tressés bombés, toit affaissé au milieu et bosselé,
  chaume d'épaisseur inégale, bord bas ondulé, mèches de longueurs différentes, porte de planches inégales de
  travers, tôles de récupération mal alignées et rouillées différemment, tenues par des pierres.
- **3 variantes par bâtiment**, tirées de la position : deux cases voisines ne sont jamais identiques.
- **Toit d'une famille pauvre** : paille neuve et vieille (grise) fondue par plaques, zones dégarnies, 0 à 2 trous
  par pan laissant voir les lattes de la charpente, touffes qui dépassent, branches posées en travers pour tenir
  le chaume, parfois (45 %) une tôle rouillée en rapiéçage tenue par des pierres.
- Textures plaquées avec de vraies coordonnées (paille dans le sens de la pente, fil du bois le long des rondins),
  2K pour le chaume et les rondins, filtrage anisotrope.
- Textures photo Poly Haven (CC0), éclaircies (bois délavé) ;
  `assets/textures/batiments/LISEZMOI.md`. Collisions inchangées ; fanion du clan sur un petit mât au pignon.
- Pas encore refaits : palissade, champs, puits. Les collisions de l'enclos restent un carré de 8 × 8 m (le visuel
  s'en écarte de quelques dizaines de centimètres).

## 5. Paysage autour de la zone de jeu (purement visuel)

| Élément | Où | Détail |
|---|---|---|
| Relief | De ±120 m à ±280 m | **Massifs à crêtes et vallées** (bruit « ridged » avec déformation de domaine), hauteurs variées avec des cols ; leur pied avance et recule (±16 m) au lieu de suivre le carré de la carte. Côté **proche de la caméra** (bas de l'écran) : bas (≤ ~11 m), pour ne pas cacher les unités au bord ; côté **lointain** : jusqu'à ~40 m. Roche stratifiée sur les pentes (projetée sur deux plans). Vallée plate le long de la rivière. Maillage de 2,5 m |
| Rochers, buissons (modèles du pack), épineux, baobabs | 170 / 260 / 140 touffes / 10 | Posés sur le relief, hors de la vallée |
| Arbres morts et tordus (pack) | 70 (25 sur Web et mobile) | **Relief lointain seulement** (haut de l'écran) : de près, ils cacheraient le jeu |

- **Aucune collision**, hors du navmesh, invisible pour la mini-carte et le brouillard : aucun effet sur le jeu.
- Paysage tiré avec la **même graine** que la carte.

## 6. Écarts avec le GDD et suite prévue

| GDD | Prototype | Statut |
|---|---|---|
| Carte générée (GDD §8) | Aléatoire à graine, symétrique | **Fait** (17/11) |
| — | Lit de rivière à sec qui ralentit, trous d'eau | **Fait** (17/11) |
| — | Collines rocheuses érodées (pied praticable, sommet infranchissable), rivière en contrebas | **Fait** (17/11) |
| — | Eau dans la rivière en saison normale, herbe qui reverdit | **Fait** (17/11, visuel) |
| — | Végétation dense et décor en modèles 3D (pack CC0 Quaternius) | **Fait** (17/11) |
| — | Modèles sur mesure (baobab, Alluaudia, raketa, cases) | **Décidé** (17/11), à faire (Tripo) |

Questions ouvertes :
1. Les collines devraient-ils bloquer la vue (ou donner une vision accrue à qui les longe) ?
2. Les zébus sauvages devraient-ils préférer paître près du lit (herbe des berges) ?
