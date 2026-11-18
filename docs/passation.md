# Passation — état du projet et décisions en cours

Note de reprise pour une nouvelle session Claude (VS Code, Claude Code sur PC).
Lire aussi `CLAUDE.md` (règles d'architecture) et `docs/specs/` (règles codées).

## Où en est le prototype (v0.11)

- Solo contre IA jouable : économie (bois, eau, nourriture, Ariary), champs, Tsena,
  zébus sauvages et migrations, capture / escorte / pillage d'enclos, palissades,
  brouillard de guerre, 3 âges et technologies, mini-carte.
- Combat : villageois, pisteur, et triangle des guerriers Dahalo > Tireur > Lanceur > Dahalo
  (voir `docs/specs/combat.md`). Les unités meurent (chute puis disparition) ; les zébus jamais.
- Victoire : 40 zébus. Partie de 30 min.
- CI : `.github/workflows/export-web.yml` exporte le build Web vers GitHub Pages
  (https://heishandria.github.io/dahalo/) et lance un test accéléré sans écran
  (`-- --accelerer`), dont le rapport sort en annotations.
  Elle prend aussi 7 **captures d'écran** (départ, bord du relief, rivière, panneau de la Case centrale, nuit, base de l'IA à 5 min,
  vue d'ensemble ; graine 1) sous écran virtuel, publiées sur https://heishandria.github.io/dahalo/captures/
  (scénario : `systems/captures.gd` ; en local : `Godot --path . -- --captures=<dossier>`).
- Graphismes : formes primitives (capsules, boîtes). Tout est à remplacer.
- **Carte aléatoire à graine** de 240 × 240 m, symétrique (équité), avec un lit de rivière à sec qui ralentit
  les raids et des trous d'eau ; sol par shader, relief et décor autour (`docs/specs/carte.md`).
  Graine imposée : `-- --graine=N`. Le navmesh contourne enfin bâtiments et bosquets (il ne lisait que le sol).
- Test accéléré : l'accélération garde un pas physique normal (sinon les unités rapides oscillaient sur place,
  ce qui faussait les anciens résultats de l'IA). Avec la nouvelle carte, l'IA seule atteint 40 zébus vers 25 min.
- Interface contextuelle : toucher un bâtiment ouvre ses actions avec leurs coûts (`docs/specs/interface.md` §2 quater).
- L'IA clôture son enclos garni de palissades et répare les brèches (voir `docs/specs/defense.md` §4).
- Lancer en local (Mac) : `open -a Godot --args --path ~/dahalo` ; test accéléré :
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --accelerer`.
  Les résultats de l'IA varient beaucoup d'une partie à l'autre (11 à 38 zébus à 30 min ; certaines parties,
  aucune capture avant 15 min) : comparer plusieurs parties avant de conclure.

## Personnages 3D : état (17/11)

- **Villageoise intégrée** (`assets/models/personnages/villageoise.glb`) pour le rôle villageois : modèle fait par
  Copilot dans Blender (`dahalo-personnages/villageoise/`), corrigé par Claude (`villageoise_v2_claude.*` et
  `scripts_claude/`) : vraie marche calculée (foulée, talon, déroulé), boucles, ~7 400 triangles.
- Branchement : `UnitData.modele` (.tres) ; `unite.gd` remplace la capsule, tourne le modèle de 180° (il regarde
  vers +Z), joue …marche… (vitesse calée sur la vitesse réelle, plafonnée à ×2,4) ou …repos…, et pose un disque
  à la couleur du clan sous les pieds. Attention : à l'import, Godot retire le suffixe `_loop` des animations.
- Vitesse des villageois (5 m/s) contre marche calée pour 0,87 m/s : réglé par la course (18/11). Texture à refaire en vues multiples (dos et côtés flous, éclairage figé) : voir la conversation du 17/11.
- **Corvée d'eau (18/11)** : animations de Copilot (`villageoise_seau_eau_v01.blend` : marche seau vide / plein,
  puiser, poser le seau) réunies avec la marche et le repos v2 par `scripts_claude/integrer_seau.py` →
  `villageoise_v3_seau.glb` (= `villageoise.glb` du jeu, 6 animations, ~8 200 triangles avec le seau). Seau, anse
  et eau sont des objets séparés (`Seau`, `Seau_anse`, `Seau_eau`) que `unite.gd` montre ou cache. Marche au seau
  calée sur 0,36 m/s (`UnitData.vitesse_marche_seau_animation`) : avec 5 m/s de déplacement, les pieds glissent
  (plafond ×2,4). « Poser le seau » n'est pas encore utilisé (le dépôt est instantané).
- **Course (18/11)** : `scripts_claude/course.py` (même méthode que `marche.py`) ajoute au modèle v3 trois courses
  calées sur 3,0 m/s (cycle 0,6 s, phase de vol, buste penché) : sans seau, seau vide, seau plein (bras libre
  écarté) → `villageoise_v4_course.glb` = `villageoise.glb` du jeu, 9 animations. Au-delà de 2,2 m/s
  (`UnitData.seuil_course`), la villageoise court ; à 5 m/s l'animation tourne à ×1,67 : plus de glissade.
  Le gardien du pâturage (1,4 m/s) marche.
- Manquent : animations de travail (bois, champ, porter), mort ; autres rôles.
- **Zébu 3D** (`assets/models/animaux/zebu.glb`) : vache CC0 de Quaternius transformée par script Blender (bosse,
  fanon, cornes en lyre, oreilles tombantes, pis retiré), animations repos / marche / course, robe tirée au sort
  parmi 6 robes malgaches. Encore sans texture de pelage (aspect lisse) : à affiner.

## Pipeline des personnages 3D (décidé)

1. **Canva** : image du personnage en **A-pose**, de face, mains vides, fond blanc ou transparent,
   corps entier, aucun logo ni texte. Canva refuse les armes : ne jamais en mettre dans le prompt.
2. **Tripo** (ou Meshy) : image → modèle 3D, avec **auto-rig** et animations (idle, marche, course,
   attaque, mort). Version allégée (« low poly », ~10 000 triangles, texture 1024 px).
   Offre gratuite pour tester ; mois payant pour les modèles définitifs (droits commerciaux Steam).
3. Export **`.glb`** dans `assets/models/personnages/`.
4. **Intégration Godot (Claude)** : remplacer la capsule « Corps » de `scenes/units/unite.tscn`
   en gardant les noms de nœuds ; brancher les animations sur les états de `unite.gd` ;
   armes modélisées par le code et accrochées à l'os de la main (`BoneAttachment3D`) ;
   couleur du clan sur les rayures du pagne (matériau séparé).
5. **Blender** seulement si un modèle a un défaut non corrigeable dans Godot (BlenderMCP possible).

### Images déjà générées

- Planche Canva « Androy Malagasy RTS warrior » : villageois (p. 3), ancien au bâton → pisteur
  (p. 5, 7), guerrier lance + bouclier → dahalo (p. 1), lanciers → lanceur (p. 9, 10).
  Poses à refaire en A-pose. La p. 2 (t-shirt, jean) est à trancher selon la direction artistique.
- Dahalo contemporain en A-pose (débardeur orange, casquette, pagne imprimé sur short, tongs) :
  média Canva `MAHbHcW_hiA`. Premier candidat pour tester Tripo.

### Direction artistique à trancher (à reporter dans le GDD)

Mélange possible : villageois en tenue traditionnelle, dahalo en tenue contemporaine
(maillots délavés, casquettes), fusil de chasse pour le tireur. Rendu « 3D réaliste stylisé »,
couleurs ternes et poussiéreuses. Les personnages sont inventés, jamais copiés de vraies photos.

## Tâches proposées, pas encore lancées

- Carte aléatoire, plateaux, rivière, saisons et végétation : fusionnés dans `main` et publiés le 17/11.
- Équilibrage à surveiller sur la grande carte : selon la graine, les troupeaux sont loin de l'enclos de l'IA
  (raids longs) ; l'IA seule finit entre 15 et 40 zébus.
- Carte « façon maquette » (référence de style fournie le 17/11 : terrain en paliers, eau, végétation dense),
  version **aride qui reverdit** :
  1. ~~plateaux en paliers infranchissables, rivière en contrebas~~ (fait, branche `carte-aleatoire`) ;
  2. ~~eau dans la rivière en saison normale, herbe qui reverdit~~ (fait) ;
  3. ~~végétation dense~~ (fait, formes générées par le code) ;
  4. ~~modèles CC0 pour le décor~~ : **Quaternius Stylized Nature MegaKit** (version Standard, déposée par
     l'auteur sur OpenGameArt) intégré : herbes, fleurs, buissons, cailloux, rochers, arbres morts et tordus
     (`assets/models/decor/LISEZMOI.md`). Comparatif des autres sources : page « Sources du décor Dahalo » ;
  5. modèles sur mesure (baobab, épineux, raketa, cases, enclos, palissade) via Canva → Tripo :
     descriptions prêtes dans `docs/modeles_sur_mesure.md`. En attendant, plantes générées par le code
     (`scenes/world/plantes.gd`).
- **Direction artistique décidée (17/11)** : la richesse de la référence « maquette » (paliers, eau, végétation
  dense) mais en **sérieux, un peu réaliste** : textures photo, couleurs ternes et poussiéreuses. **PC d'abord**
  (Forward+), mobile et Web allégés. Les personnages devront suivre ce ton (plutôt l'image réaliste du villageois
  que les fiches manga). Le pack Quaternius (stylisé) reste un bouche-trou à remplacer par des modèles plus réalistes ;
  vérifier les cavaliers et les scarifications des fiches Dahalo (culture).
- Gaea (terrain érodé, Windows, licence payante pour un jeu vendu) : piste pour le relief de fond, plus tard.
- Mettre le GDD à jour avec les décisions prises ; vérifier les termes malgaches.
