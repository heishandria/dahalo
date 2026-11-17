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
  5. modèles sur mesure (baobab, épineux, raketa, cases, enclos) via Canva → Tripo.
- Direction artistique : choisir UN style pour les personnages (3D stylisée, cohérente avec la carte) ;
  vérifier les cavaliers et les scarifications des fiches Dahalo (culture).
- Mettre le GDD à jour avec les décisions prises ; vérifier les termes malgaches.
