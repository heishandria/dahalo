# Catalogue de ressources (art, animation, 3D)

Vérification du 18/11/2026 : **✓** = la page répond (HTTP 200) ; **◐** = le site bloque les robots (403/429),
lien connu mais non vérifié automatiquement ; licences des dépôts GitHub lues via l'API GitHub.
Règles d'usage : lier et résumer avec nos mots ; ne pas copier de cours, de livres ni d'images protégées ;
pour tout fichier livré avec le jeu, licence compatible (CC0, domaine public, ou licence achetée) notée ici.
Références culturelles de Madagascar : voir `../madagascar-references.md`.

## 1. Skills d'agents (dépôts existants)

| Dépôt | Licence | Usage pour nous | ✓ |
|---|---|---|---|
| [MengTo/Skills](https://github.com/MengTo/Skills) | MIT | Styles d'illustration, SVG, palettes, kits de dessin | ✓ |
| [anthropics/skills](https://github.com/anthropics/skills) | non indiquée au niveau du dépôt (voir chaque skill) | Exemples officiels de structure de skills | ✓ |
| [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills) | MIT | Workflows Blender 5.x ; vérifier qu'ils n'exigent pas de MCP | ✓ |
| [RobLe3/cc-blender-skill](https://github.com/RobLe3/cc-blender-skill) | MIT | Plugin Blender pour Claude Code ; inspecter les dépendances d'exécution | ✓ |
| [scenario-labs/skills](https://github.com/scenario-labs/skills) | MIT | Production d'assets ; **parties liées à leur service/MCP exclues** | ✓ |
| [gptnius/skills-library](https://github.com/gptnius/skills-library) | NOASSERTION | Index de découverte seulement | ✓ |

## 2. Documentation officielle (technique)

| Ressource | Conditions | ✓ |
|---|---|---|
| [Manuel Blender](https://docs.blender.org/manual/en/latest/) | CC BY-SA (documentation) | ✓ |
| [API Python de Blender](https://docs.blender.org/api/current/) | — | ✓ |
| [Blender en ligne de commande](https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html) | — | ✓ |
| [Export glTF de Blender (manuel 4.2)](https://docs.blender.org/manual/en/4.2/addons/import_export/scene_gltf2.html) | — | ✓ |
| [glTF-Blender-IO](https://github.com/KhronosGroup/glTF-Blender-IO) | Apache-2.0 | ✓ |
| [Spécification glTF 2.0](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html) | — | ✓ |
| [Godot : importer des scènes 3D](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html) | CC BY 3.0 | ✓ |
| [Godot : préparer l'export des modèles](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html) | CC BY 3.0 | ✓ |
| [Godot : LOD des maillages](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html) | CC BY 3.0 | ✓ |
| [Blender Studio](https://studio.blender.org/) (fichiers de production, formations) | Abonnement ; beaucoup de fichiers en CC BY | ✓ |

## 3. Dessin, anatomie, gestes

| Ressource | Type / conditions | ✓ |
|---|---|---|
| [Proko](https://www.proko.com/) | Cours d'anatomie, figure, geste (gratuit et payant) | ✓ |
| [Drawabox](https://drawabox.com/) | Construction, perspective, exercices (gratuit) | ✓ |
| [Anatomy for Sculptors](https://www.anatomy4sculptors.com/) | Livres et références anatomiques (payant) | ✓ |
| [Line of Action](https://line-of-action.com/) | Poses chronométrées : figures, animaux, mains | ✓ |
| [Quickposes](https://www.quickposes.com/) | Poses chronométrées | ✓ |
| [Posemaniacs](https://www.posemaniacs.com/) | Poses et écorchés 3D | ✓ |
| [Chronophotographies de Muybridge](https://commons.wikimedia.org/wiki/Category:Eadweard_Muybridge) | **Domaine public** : marche, course, allures des animaux (bovins, chevaux) | ✓ |

## 4. Illustration, couleur, peinture

| Ressource | Type | ✓ |
|---|---|---|
| [Ctrl+Paint](https://www.ctrlpaint.com/) | Fondamentaux de peinture numérique | ✓ |
| [Marco Bucci (YouTube)](https://www.youtube.com/@marcobucci) | Couleur, lumière, peinture | ✓ |
| [Sinix Design (YouTube)](https://www.youtube.com/@sinixdesign) | Peinture, anatomie, design | ✓ |
| [Schoolism](https://schoolism.com/) | Cours professionnels (payant) | ✓ |
| [CGMA](https://www.cgmasteracademy.com/) | Concept art, personnages, environnements (payant) | ✓ |
| [FZD School](https://www.fzdschool.com/) | Design, environnements, objets | ✓ |
| [The Gnomon Workshop](https://www.thegnomonworkshop.com/) | Production : concept, modélisation, animation (payant) | ✓ |
| [ArtStation Learning](https://www.artstation.com/learning) | Tutoriels ; vérifier l'auteur et la licence | ◐ |

## 5. Mouvement, capture de mouvement

| Ressource | Licence / conditions | ✓ |
|---|---|---|
| [Quaternius Universal Animation Library 1](https://quaternius.com/packs/universalanimationlibrary.html) et [2](https://quaternius.itch.io/universal-animation-library-2) | **CC0** (License.txt des zips, vérifié le 19/11/2026) ; versions « Standard » gratuites (43 + 43 animations) téléchargées dans `~/dahalo-personnages/bibliotheques/` ; squelette type Unreal, reciblé par `recibler_bibliotheque.py` | ✓ |
| [CMU Graphics Lab Motion Capture Database](http://mocap.cs.cmu.edu/) | « Free for all uses » selon le site (ne pas revendre les données brutes : lire la FAQ) | ✓ |
| [Bandai Namco Research Motion Dataset](https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset) | **CC BY-NC 4.0 : pas d'usage commercial** (étude seulement) | ✓ |
| [Mixamo](https://www.mixamo.com/) | Compte Adobe ; personnages et animations libres de droits pour les projets personnels, commerciaux et les jeux vidéo ([FAQ Adobe](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html), lue le 19/11/2026) ; interdit de redistribuer les fichiers bruts | ✓ |
| Animations Epic (mannequin Unreal, Lyra, MetaHumans) | **Exclues** : contenu Epic réservé aux produits Unreal Engine | ✓ |
| [Rokoko](https://rokoko.com/), [DeepMotion](https://www.deepmotion.com/) | Outils commerciaux de capture / capture vidéo | ✓ |

## 6. Textures, matériaux, modèles libres

| Ressource | Licence | ✓ |
|---|---|---|
| [Poly Haven](https://polyhaven.com/license) | **CC0** (textures, HDRI, modèles) — utilisé par le jeu | ✓ |
| [ambientCG](https://ambientcg.com/) | **CC0** | ✓ |
| [Quaternius](https://quaternius.com/) | **CC0** — vache (zébu) et végétation du jeu | ✓ |
| [Kenney](https://kenney.nl/) | **CC0** | ✓ |
| [Textures.com](https://www.textures.com/) | Licence propriétaire (restrictions de redistribution) | ✓ |
| [Sketchfab](https://www.sketchfab.com/) | Licence **par modèle** (vérifier chacun) | ✓ |

## 7. Références naturalistes et musées

| Ressource | Licence | ✓ |
|---|---|---|
| [iNaturalist](https://www.inaturalist.org/) | Licence par observation (souvent CC BY-NC) | ✓ |
| [GBIF](https://www.gbif.org/) | Données d'occurrence ; licences par jeu de données | ◐ |
| [Smithsonian Open Access](https://www.si.edu/openaccess) | CC0 pour les objets marqués | ◐ |
| [The Met Open Access](https://www.metmuseum.org/about-the-met/policies-and-documents/open-access) | CC0 pour les œuvres du domaine public | ◐ |
| [Musée du quai Branly — collections](https://www.quaibranly.fr/fr/explorer-les-collections) | Consultation ; droits réservés | ✓ |

## 8. Génération d'images et image→3D (outils locaux)

**Installé sur le poste (18/11/2026)** : ComfyUI 0.45.6 (`~/ComfyUI-Installs/Heishandria/ComfyUI`, serveur
`http://127.0.0.1:8188`, Apple MPS), piloté par `.claude/skills/image-generation-direction/scripts/comfyui.py`.
Modèles présents (image→3D seulement, **aucun modèle texte→image**) — licences lues sur Hugging Face :

| Modèle | Rôle | Licence |
|---|---|---|
| [TRELLIS.2](https://huggingface.co/Comfy-Org/TRELLIS.2) (Microsoft) | Image → forme + texture 3D | MIT |
| [Pixal3D](https://huggingface.co/Comfy-Org/Pixal3D) | Image → 3D (variante) | MIT |
| [MoGe](https://huggingface.co/Comfy-Org/MoGe) | Estimation de géométrie et de champ de vision | MIT |
| [BiRefNet](https://huggingface.co/Comfy-Org/BiRefNet) | Détourage | MIT |
| [Hunyuan3D-2mini](https://huggingface.co/tencent/Hunyuan3D-2mini) (Tencent) | Image → forme 3D (géométrie seule) | **Tencent Hunyuan 3D 2.0 Community License** : aucun droit dans l'UE, au Royaume-Uni ni en Corée du Sud ; licence à demander au-delà d'1 M d'utilisateurs actifs mensuels ; joindre la licence et la mention « Tencent Hunyuan 3D 2.0 is licensed under the Tencent Hunyuan 3D 2.0 Community License Agreement. » en cas de distribution ; sorties non réutilisables pour entraîner un autre modèle. Décision de l'auteur (18/11/2026) : utilisé pour le chef dahalo, jeu produit et diffusé à Madagascar ; **à revoir avant toute diffusion vers l'UE, le Royaume-Uni ou la Corée du Sud** (ex. Steam mondial) |
| DINOv3 ViT-L (Meta, dans le dépôt Pixal3D) | Encodeur d'image | **Licence propre à Meta** ([fiche](https://huggingface.co/facebook/dinov3-vitl16-pretrain-lvd1689m)) : à lire avant usage commercial |

| Ressource | Licence | ✓ |
|---|---|---|
| [ComfyUI](https://github.com/comfyanonymous/ComfyUI) | GPL-3.0 (non retournée par l'API : à confirmer) | ✓ |
| [diffusers](https://github.com/huggingface/diffusers) | Apache-2.0 (les **modèles** ont leurs propres licences) | ✓ |
| [ControlNet](https://github.com/lllyasviel/ControlNet) | Apache-2.0 — contrôle de pose/contours pour des vues plus cohérentes | ✓ |

## Liens du kit d'origine retirés ou remplacés

- Manuel glTF « latest » (404) → version 4.2 du manuel.
- Aucun lien du kit n'a été retiré pour autre raison ; les sites marqués ◐ restent cités.
