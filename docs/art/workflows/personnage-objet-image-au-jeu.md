# De l'image au jeu : personnages et objets 3D de Dahalo

Procédé en vigueur au 19/11/2026, pour un agent d'IA qui doit créer un personnage animé ou un objet 3D et le
mettre dans le jeu Godot. Tout se fait avec des fichiers, des scripts et Blender en ligne de commande (pas de MCP,
pas d'interface). Lire aussi `CLAUDE.md`, `docs/art/bible-artistique.md` et le skill `game-art-router`.

## 1. Règles qui ne se discutent pas

- **Culture** : le zébu n'est jamais tué ; pas de sang ; pas de motif ni de terme malgache inventé ; tombeaux et objets
  sacrés hors jeu. Un motif ou un accessoire inventé par une image d'IA doit être validé par l'auteur avant
  modélisation (`docs/art/madagascar-references.md`).
- **Budget** : personnage 3 000 à 10 000 triangles (bible §4 ; le chef, 13 094, est une exception à réduire),
  ≤ 3 matériaux, texture 1024 px (2048 seulement pour un héros) ;
  objet de décor ≈ 1 000 à 5 000 triangles, atlas 512 à 1024 px.
- **Repère** : 1 unité = 1 m, origine au sol au centre, avant Blender −Y (= +Z dans Godot), aucune rotation corrective.
- **Versionner** : on n'écrase jamais un fichier source ; chaque étape écrit un nouveau fichier (`_v5_`, `_v6_`…).
- **Regarder** chaque rendu de contrôle avant de dire qu'il est bon. Une planche non regardée ne vaut rien.
- **Licences** : noter toute ressource dans `docs/art/references/RESOURCES.md`. Interdit : contenu Epic/Unreal (réservé
  à Unreal). Hunyuan3D (Tencent) : interdit dans l'UE, au Royaume-Uni et en Corée du Sud, à revoir avant une
  diffusion mondiale.
- **Coordination** : avant de commencer, ajouter une ligne « En cours » dans `docs/art/coordination-agents.md` §6 avec
  les fichiers touchés ; ne pas toucher aux fichiers d'un autre agent ; passer la ligne à « Terminé » à la fin.

## 2. Où sont les choses

| Emplacement | Contenu |
|---|---|
| `~/dahalo-personnages/<nom>/` (hors git) | Travail d'un personnage : `config_personnage.json`, `scripts_claude/` (+ `LISEZMOI.md`), `.blend`, `.glb`, rendus |
| `~/dahalo-personnages/images-reference/` | Photos et planches de référence fournies par l'auteur |
| `~/dahalo-personnages/bibliotheques/` | Animations libres : `ual1/`, `ual2/` (Quaternius, CC0), `mixamo/` (FBX) |
| `.claude/skills/blender-python-pipeline/scripts/` | Outils du kit (tableau §4) |
| `.claude/skills/blender-python-pipeline/gabarits/config_personnage.json` | Gabarit de configuration |
| `assets/models/personnages/`, `assets/models/decor/<objet>/` | GLB du jeu (+ scripts et `LISEZMOI.md` pour le décor) |
| `data/units/*.tres`, `scenes/units/unite.gd` | Données d'unité (modèle, vitesses de calage) et lecture des animations |

## 3. Personnage : les étapes

### 3.1 Références
Demander à l'auteur une image en **A-pose stricte**, sur fond uni clair, de face **et** de dos à la même échelle ;
si possible deux profils et un gros plan du visage. Lister les motifs et accessoires de l'image et les faire valider.

### 3.2 Forme 3D (image → 3D, local)
ComfyUI (Comfy Desktop) avec **Hunyuan3D-2mini** : géométrie seule, environ 3 à 4 min par essai sur le Mac M1 Pro.
Vérifier la mémoire libre avant de lancer (pas sous ~5 Go ; TRELLIS.2 bloque au rangement des UV quand la mémoire
manque). Générer **le corps entier**, puis **la tête seule** (recadrage tête + cou du gros plan) : la tête générée
seule est bien plus nette. Sorties brutes dans `docs/art/essais/bruts/` (ignoré par git).

### 3.3 Configuration
Copier le gabarit dans le dossier du personnage, sous le nom `config_personnage.json`, et le remplir : hauteur, triangles,
photos, scripts de chaque étape, noms de fichiers, budget, actions attendues, liste `bibliotheque`.
Exemples complets : `~/dahalo-personnages/dahalo_chef/config_personnage.json` (tout le pipeline) et
`~/dahalo-personnages/villageoise/config_personnage.json` (étape bibliothèque seulement).

### 3.4 Pipeline
Depuis le dossier du personnage :

```sh
P=~/dahalo/.claude/skills/blender-python-pipeline/scripts/pipeline_personnage.py
python3 $P --etat                               # étapes faites
python3 $P --jusqu-a controle_texture          # puis REGARDER rendus/controle_texture/
python3 $P --depuis rig --jusqu-a controle_anim # puis REGARDER rendus/controle_anim/
python3 $P --etape video                        # vidéo de contrôle, à regarder
python3 $P --etape promouvoir                   # copie dans le jeu (seulement sur demande explicite)
```

`--depuis X` relance X et tout ce qui suit ; un échec arrête la chaîne (journal par étape dans le dossier de
rendus) : corriger puis `--depuis X`. Le script ne demande jamais rien au clavier.

| Étape | Ce qu'elle fait | À vérifier |
|---|---|---|
| `greffe` | Tête générée seule greffée sur le corps (`greffer_tete.py`) | Cou continu, pas de méplat |
| `texture` | Projection des photos (face, dos, profils, gros plan), remaillage voxel, simplification, UV, cuisson | — |
| `controle_texture` | Comparaison aux photos + rendu à la caméra du jeu | Profils (c'est là que ça bave), lisibilité |
| `rig` | Squelette commun de 22 os + poids (script `rig_<nom>.py`) | Pose de test sans déchirure |
| `corpulence` | Épaississement par os (facultatif) | — |
| `accessoire` | Arme ou outil sur un os dédié, texture atlas (facultatif) | Lisible, pas de couleur unie |
| `retouche` | Rouge désaturé vers la brique, poussière de latérite, taille 1024 | Tons passés (bible §3) |
| `anim` | Script d'animation propre au personnage (gestes spécifiques seulement) | — |
| `bibliotheque` | Animations des bibliothèques reciblées sur notre squelette (§3.5) | Outils dans les mains |
| `controle_anim` | Planches par action + vues à la caméra du jeu + audit du GLB | Repos d'abord, dernière image des actions non bouclées |
| `video` | Vidéo repos / marche / course / tir / mort | Pieds qui ne glissent pas |
| `promouvoir` | Copie le GLB dans `assets/`, sauvegarde l'ancien, compare les empreintes | — |

### 3.5 Animations : bibliothèques d'abord
On ne refait **pas** à la main les mouvements génériques. Ordre de recherche :
1. **Quaternius Universal Animation Library 1 et 2** (CC0, `bibliotheques/ual1|ual2/…/Unreal-Godot/*.glb`) :
   repos, marche, trot, sprint, morts, coups reçus, accroupi, épée, lancer, récolter, semer, arroser, couper du bois,
   porter.
2. **Mixamo** (gratuit, usage en jeu autorisé, ne pas redistribuer les fichiers bruts) : armes à feu, lance,
   accroupi, creuser… Téléchargement : FBX Binary, **Without Skin**, **30 i/s**, keyframe reduction none,
   **In Place** coché pour tout déplacement ; ranger dans `bibliotheques/mixamo/`.
3. Fait main (script `anim_<nom>.py`, IK analytique de `ik_deux_os.py`) seulement pour ce qui n'existe nulle part
   (porter un seau…), en partant si possible d'une animation proche.

Chaque entrée de `bibliotheque` dans la config : `{"source": "…glb|.fbx", "action": "Walk_Loop" (ou absent pour un
FBX Mixamo), "nom": "marche_loop", "arme": "Fusil", "attacher": "Houe@Ancienne_action:image", "figer": "…"}`.
- `arme` : l'os de l'arme est replacé à chaque image, poignée dans la main droite, canon vers la main gauche.
- `attacher` : l'os d'un objet suit la main la plus proche, avec la prise relevée dans une action existante.
- `figer` : l'os garde la pose de référence (outil posé au sol).

**Vitesse de calage** : le jeu règle la vitesse de lecture sur ce chiffre (m/s). Le journal de l'étape le donne.
Pour Quaternius, retenir la valeur « déplacement réel » (version `_RM` du pack) ; sinon la mesure « pied au sol ».
La reporter dans `data/units/<unité>.tres` (`vitesse_marche_animation`, `vitesse_course_animation`).

**Noms d'actions reconnus par le jeu** (Godot retire `_loop` et active la boucle) : `<Préfixe>_repos_loop`,
`_marche_loop`, `_course_loop`, `_viser_loop` (en joue entre deux tirs), `_tirer` (à chaque tir), `_mort` (non
bouclée, jouée à la mort ; sans elle l'unité bascule). Gestes de la villageoise : `_seau_vide`, `_seau_plein`,
`_puiser`, `_course_seau_vide|plein`, `_biner`, `_couper_bois`, `_recolter`. Une nouvelle action = code dans
`unite.gd` + spec.

**Mort** : sans animation de bibliothèque convenable, `mort.py` du kit en crée une (chute en avant, contact au sol
calculé, objet tenu lâché) : `blender -b X.blend --python mort.py -- SORTIE.blend SORTIE.glb --prefixe Nom`.

## 4. Outils du kit (`.claude/skills/blender-python-pipeline/scripts/`)

| Outil | Rôle |
|---|---|
| `pipeline_personnage.py` | Enchaîne les étapes d'après la config |
| `rendu_verification.py` | Planches de vues et d'actions ; `--rts` = caméra du jeu (iso 35,26°, taille de vue 18/40/70, densité réelle 1080p) |
| `recibler_bibliotheque.py` | Reciblage UAL/Unreal (.glb) et Mixamo (.fbx) sur notre squelette, A-pose comprise |
| `mort.py` | Animation de mort générique (repli) |
| `audit_glb.py` | Budget d'un GLB : `python3 audit_glb.py X.glb --max-triangles 13500 --max-texture 1024` |
| `ik_deux_os.py` | IK analytique, F-courbes, `vitesse_calage` |
| `exporter_gltf.py`, `inspecter_blend.py`, `blender_lancer.sh` | Export sûr, inventaire, lancement journalisé |

Scripts propres à un personnage (`texture_projection.py`, `rig_chef.py`, `fusil_chef.py`, `retoucher_texture.py`,
`anim_chef.py`, `video_chef.py`…) : dans `~/dahalo-personnages/<nom>/scripts_claude/`, à copier et adapter.

## 5. Objet 3D (décor, bâtiment, accessoire)

1. Brief : usage en jeu, taille réelle, emprise de collision existante (le modèle ne change ni la collision ni la logique).
2. Forme : Hunyuan3D-2mini puis nettoyage Blender (coques parasites, remaillage, simplification), **ou** modélisation
   par script Blender pour les formes simples et répétées (palissade).
3. Matériaux : atlas procédural cuit dans Blender ou textures CC0 ; un matériau à part, uni, pour tout ce que le jeu
   recolore (fanion de faction : objet `Banniere`).
4. Livrer dans `assets/models/decor/<objet>/` : GLB, scripts rejouables, `LISEZMOI.md` (budget mesuré, repère,
   commande de reproduction, contrôles faits). Exemples : `palissade/` (3 variantes, < 1 000 triangles chacune),
   `puits/`.
5. Contrôle : `audit_glb.py … --max-materiaux 3 --strict`, rendus à la caméra du jeu (proche et lointaine), joints et
   variantes ; les regarder.

## 6. Déploiement dans Godot

1. **Promouvoir** (`pipeline_personnage.py --etape promouvoir`, ou copie avec sauvegarde pour un objet). Jamais de
   copie à la main d'un GLB non vérifié.
2. **Réimporter** : `/Applications/Godot.app/Contents/MacOS/Godot --headless --path ~/dahalo --import`. Ce réimport
   extrait les textures du GLB en PNG à côté de lui ; sans lui, une nouvelle texture n'apparaît pas en jeu.
3. **Brancher** : `data/units/<unité>.tres` → `modele` et vitesses de calage ; objets montrés ou cachés par nom de nœud
   (`Seau*`, `Houe`, `Hache`, `Epi_recolte`, `Banniere`) ; calques physiques selon `CLAUDE.md` (1 terrain, 2 unités,
   3 clic, 4 obstacles, 5 arbres, 6 enclos, 7–8 palissades) ; toute action passe par `CommandBus`.
4. **Vérifier** :
   - un petit script `extends SceneTree` lancé en headless (`Godot --headless --path . -s test.gd`) qui instancie
     l'unité et affiche les animations détectées (puis le supprimer) ;
   - partie accélérée : `Godot --headless --path . -- --accelerer --graine=1` (sans `timeout` sur macOS : utiliser
     `perl -e 'alarm 280; exec @ARGV' …`), aucune ligne d'erreur ;
   - le Web (Compatibility) : 16 textures au plus par shader ; l'export Web part par la CI (`.github/workflows/`).
   - ce qui ne se voit pas sans écran (gros plan en jeu) : le dire à l'auteur, ne pas le prétendre vérifié.
5. **Documenter dans le même commit** : spec concernée (`docs/specs/`), `docs/passation.md`, bible si une règle
   change, `LISEZMOI.md` du personnage, ligne de coordination. Messages de commit en français.

## 7. Pièges déjà rencontrés

- GLB du jeu plus ancien que le modèle validé (fusil blanc en jeu) : toujours passer par `promouvoir`.
- Silhouette illisible au repos : un accessoire tenu le long du corps disparaît à la caméra du jeu.
- Projection : liseré blanc des photos (bord érodé) et traînées sur les flancs (remplissage par diffusion).
- Rouge désaturé qui vire au rose sous le soleil : l'assombrir aussi.
- Mesure de vitesse au pied fausse pendant les phases de vol : préférer le déplacement réel.
- Planche d'une action non bouclée sans sa dernière image : l'outil la montre maintenant, la regarder.
- Mort : corps resté plié, appuyé sur un bras ou jambe en l'air ; corriger avant de livrer.
- Blender 5 : pas de nœuds par défaut fiables (créer Principled, Background… explicitement) ; actions à
  emplacements (`ik_deux_os.courbes`, `assigner`) ; références d'os invalides après le mode édition.
- Préfixe des os Mixamo variable (`mixamorig:`, `mixamorig2:`) : géré par l'outil.
- Le module Blender « blender-mcp-ultra » ouvre un port (9876) à chaque lancement : sans effet sur le pipeline.
