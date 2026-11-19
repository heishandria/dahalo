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
- **Villageoise v5 (18/11)** : corps généré par TRELLIS.2 (ComfyUI local, correctif MPS) depuis la photo de
  référence, intégré par `scripts_claude/integrer_ia.py` sur le v4 : mise à l'échelle et centrage sur l'ancien
  corps (A-poses identiques à quelques mm), copie décimée à 9 000 triangles avec nouvelles UV, **couleur recuite**
  du modèle IA (1024 px), **poids transférés** de l'ancien corps (aucun sommet orphelin), squelette et 9 animations
  inchangés → `villageoise_v5_ia.glb` = `villageoise.glb` du jeu. Vérifié par planches (course, puiser) et en jeu.
- **Travail des champs (18/11)** : animations et accessoires faits par **Astra** (`champ_astra_v05/`, construits sur
  l'ancien corps) intégrés au v5 par `scripts_claude/integrer_champ.py` (fichier d'Astra en lecture seule) : os
  `Houe` et `Recolte`, houe et épi, `Villageoise_biner_loop`, `Villageoise_recolter` (jouée en aller-retour),
  `Villageoise_ranger_houe`, `Villageoise_deposer_panier` ; cadence recalée de 24 à 30 i/s (durées conservées) ;
  panier (35 900 triangles, décor) et objets de présentation écartés → `villageoise_v6_champ.glb` = modèle du jeu.
  En jeu (`unite.gd`) : champ en pousse → biner (houe) ; champ mûr → récolter (houe plantée + épi) ; accessoires
  cachés ailleurs. Non utilisés : ranger la houe, déposer dans le panier.
- **Coupe du bois (18/11)** : `scripts_claude/couper_bois.py` ajoute au v6 une petite hache (os `Outil`, enfant de
  `Main_D` ; manche + fer, 40 triangles) et `Villageoise_couper_bois_loop` (1,2 s : armer au-dessus de la tête,
  frappe en arc vers un tronc à hauteur de taille, rebond, remontée ; bras droit par IK, pieds plantés)
  → `villageoise_v7_bois.glb` = modèle du jeu. En jeu : récolte de bois → s'approche (`DIST_COUPE`), se tourne
  vers l'arbre, coupe en boucle, hache visible ; cachée ailleurs.
- **Prise des objets (18/11)** : `scripts_claude/prises_mains.py` ajoute au v7 un os de doigts par main
  (`Doigts_D`, `Doigts_G`, rig « moufle » : toutes les phalanges ensemble, pouce resté sur la main) ; main fermée
  à 80–100° quand elle tient le seau, la houe, la hache ou l'épi, 15° ailleurs ; seau remonté de 3 cm (l'anse
  tombe dans les doigts) → `villageoise_v8_prises.glb` = modèle du jeu (28 os). Pas de doigts séparés : à faire
  si un gros plan l'exige.
- **Locomotion reprise (18/11, v9)** : `scripts_claude/locomotion.py` recrée sur le v8 la marche et les 3 courses.
  En jeu (5 m/s) on voit surtout la course : l'ancienne, calée à 3 m/s, était jouée ×1,7 (≈ 330 pas/min) et
  accroupie (bassin −11 cm au contact, genou d'appui 42–50°). Nouvelle course : cycle 0,66 s, appui 25 % avec phase
  de vol, contact sous le corps, bassin haut, buste penché, bras par IK (coudes en arrière, poings fermés), bras
  libre écarté avec le seau plein ; calage 3,96 m/s (`vitesse_course_animation`) → lecture ×1,26. Marche : pied
  rasant (5 cm au lieu de 11). Corrigé aussi un à-coup à l'image 1 des boucles (pose de l'action précédente lue
  avant mise à jour) → `villageoise_v9_locomotion.glb` = modèle du jeu.
- Manquent : porter une charge (bois, panier), mort ; autres rôles.
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

## Assets 3D intégrés (18/11/2026)

- **Tireur / chef dahalo** : `assets/models/personnages/dahalo_chef.glb`, 13 094 triangles, 23 os,
  texture 2048² ; `Chef_repos`, `Chef_marche`, `Chef_course` et `Chef_tirer` (1,23 s). Vitesses de calage :
  0,965 m/s en marche et 4,408 m/s en course. Le corps est dérivé de Hunyuan3D-2mini ; le fusil est modélisé
  par script Blender. Voir `docs/art/references/RESOURCES.md` pour le rappel de licence applicable.
- **Palissade épineuse** : trois GLB (`assets/models/decor/palissade/palissade_{a,b,c}.glb`), chacun sous
  1 000 triangles, texture atlas 1024², deux matériaux ; variante stable selon la position du segment, bannière
  recolorée par faction. Sources et reproduction : `assets/models/decor/palissade/LISEZMOI.md`.
- Validation Godot 4.7 : réimport headless, test accéléré `--graine=1` et export Web réussis sans erreur.
  Les rendus Blender (dont les angles 45°/90° et la marche/course) ont été regardés ; les captures réelles
  Compatibility ont été générées, dont la base IA à 5 min.
- Limite restante : pas de gros plan en jeu du Tireur. Dans la vidéo Blender, le fusil paraît presque blanc,
  bien que ses facteurs PBR dans le GLB soient brun/gris foncé ; confirmer son apparence dans une capture
  rapprochée du jeu avant validation visuelle finale.
