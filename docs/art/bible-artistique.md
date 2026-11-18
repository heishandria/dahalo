# Bible artistique — Dahalo : Les Seigneurs des Zébus

Statut des entrées : **décidé** (date) · **à décider** · **fait** (source dans `madagascar-references.md`) ·
**choix artistique** (raison). Mettre à jour à chaque décision (journal en fin de page).
Modèle générique : `.claude/skills/art-direction/modele-bible.md`.

## 1. Identité

| Entrée | Contenu | Statut |
|---|---|---|
| Genre | RTS de gestion et de survie, une partie ≈ 30 min | décidé (GDD) |
| Plateformes | PC (Forward+, cible principale Steam), téléphone (Mobile), Web (Compatibility) | décidé |
| Caméra | Vue de dessus inclinée (≈ isométrique), orthographique, zoom ; unités de ~1,6 m vues de loin | décidé |
| Lieu | Grand Sud de Madagascar : Androy, pays mahafaly ; brousse d'épineux, lit de rivière à sec | décidé (GDD) ; faits : `madagascar-references.md` |
| Ton | « Sérieux, un peu réaliste » : survie, chaleur, poussière, sans misérabilisme | décidé (17/11) |

## 2. Famille de style

| Entrée | Contenu | Statut |
|---|---|---|
| Style principal | **Semi-réaliste** : textures photo (Poly Haven, CC0) pour sols et bâtiments, modèles aux proportions réelles, végétation basse légèrement stylisée (Quaternius, CC0) | décidé (17/11) |
| Zones de style | Jeu 3D temps réel (semi-réaliste) ; interface plate et sobre ; illustrations promotionnelles **à décider** (peintes, même palette) | à décider pour les illustrations |
| Langage de formes | Formes organiques, tordues, usées (perches d'enclos, épineux, baobabs) ; peu d'angles droits nets | choix artistique (bois de brousse) |
| Densité de détails | Faible au sol (lisibilité des unités), plus forte sur les bâtiments et repères | décidé |
| Contours | Aucun trait : formes lues par la valeur et la lumière | décidé |

## 3. Couleur et lumière

| Entrée | Contenu | Statut |
|---|---|---|
| Palette dominante | Latérite rouge-orangé, ocres, sable, bois gris délavé, vert olive terne des épineux, verts plus francs près de l'eau | décidé (rendu actuel) |
| Accents | Couleurs de clan (marques sous les unités, fanions) ; eau ; quelques fleurs après les pluies | décidé |
| À éviter | Couleurs saturées hors accents ; verts « européens » ; blanc pur | choix artistique |
| Jour | Soleil chaud et franc à ~50°, venant de la gauche de l'écran ; ombres vers le bas à droite (~0,8 × hauteur) ; ambiance basse ; occlusion ambiante ; brume légère ; contraste +12 % | décidé (`docs/specs/carte.md` §4 ter) |
| Nuit | Ambiance bleutée, vision réduite | décidé |
| Saisons | Normale / sécheresse : herbe dorée, eau qui se retire, moins de nuages (fondus de 6–8 s) | décidé (`carte.md`) |
| Lisibilité | Les unités doivent rester plus contrastées que le sol ; ne jamais distinguer deux clans par le seul rouge/vert | règle |

## 4. Personnages

| Entrée | Contenu | Statut |
|---|---|---|
| Proportions | Réalistes, ~7 têtes ; villageoise ≈ 1,64 m | décidé (modèle actuel) |
| Morphologies | Corps minces et secs, travail physique ; pieds nus fréquents | choix artistique ; **à valider sur références** |
| Vêtements | Étoffe enroulée et nouée (type *lamba*), tons passés, usée et poussiéreuse | fait général (lamba) ; détails régionaux **à vérifier** |
| Coiffures | Petits chignons (villageoise, d'après la photo de référence de l'auteur) | référence fournie ; généralité **à vérifier** |
| Unités | Villageoise (modèle 3D) ; Dahalo, Lanceur, Tireur, Pisteur : **à concevoir** (encore des capsules) | à faire |
| Identité de rôle | Chaque unité lisible en silhouette par son accessoire (seau, bâton, sagaie, fusil, pisteur…) | règle |
| Mort | Les unités tombent puis disparaissent, **sans effet sanglant** | décidé (CLAUDE.md) |
| Budget | 3 000 – 10 000 triangles ; ≤ 3 matériaux ; texture ≤ 2048 (1024 de préférence) | décidé |

## 5. Animaux

| Entrée | Contenu | Statut |
|---|---|---|
| Zébu (*omby*) | Bosse, fanon, oreilles tombantes, cornes en lyre ; ~2,3 m ; 6 robes (rouge-brun, gris, noir, blanc crème, fauve, brun sombre), unie ~55 %, pie ~30 %, tachetée ~15 % ; poussière de latérite sur les pattes | décidé (`assets/models/animaux/LISEZMOI.md`) ; terme *omby* **à confirmer** |
| Règle culturelle | **Le zébu n'est jamais tué** : capturé, escorté, repris, sécurisé | décidé (CLAUDE.md) |
| Comportements | Brouter, manger au fourrage, boire, se coucher, dormir, pâturage avec gardien | décidé (`docs/specs/zebus.md`) |
| Oiseaux | Corbeaux pies, hérons garde-bœufs (vols qui traversent la carte) | décidé ; espèces présentes : sources dans les références |

## 6. Environnements

| Entrée | Contenu | Statut |
|---|---|---|
| Terrain | Latérite, plaques de sable, herbe en massifs (bien plus dense sur les berges), lit de rivière à sec, collines rocheuses | décidé (`carte.md`) |
| Végétation | Baobabs (types *za* / *grandidieri*), épineux (type *Alluaudia*), raketa (figuier de Barbarie), buissons et herbes | décidé ; faits botaniques sourcés |
| Architecture | Cases en planches et chaume, bois gris délavé ; enclos en perches tordues ; puits ; marché (Tsena) | rendu actuel ; **forme exacte des cases antandroy à vérifier** |
| Objets du quotidien | Seau en métal, fourrage (paille, raquettes de raketa), auge en tronc creusé | choix actuels ; usages **à sourcer** |
| Lieux sacrés | Tombeaux (aloalo, cornes de zébus) : **ne pas en faire des objets de jeu** (ni pillables, ni destructibles) ; à n'utiliser qu'en décor lointain et respectueux, ou pas du tout | règle |

## 7. Production

| Entrée | Contenu | Statut |
|---|---|---|
| Moteur | Godot 4.7 ; GLB depuis Blender ; 1 unité = 1 m ; modèles regardant +Z (tournés de 180° par le jeu) | décidé |
| Textures | VRAM compressée + mipmaps obligatoires ; ≤ 16 textures par shader (Web) ; bâtiments 1024 px | décidé (18/11) |
| Animations | Sur place ; suffixe `_loop` pour les boucles ; vitesse de calage notée (marche 0,87, course 3,96, seau 0,36 m/s) | décidé |
| Accessoires | Objets séparés et nommés (`Seau`, `Seau_anse`, `Seau_eau`) montrés/cachés par le jeu | décidé |
| Web | 3D calculée sur ≤ 1,6 Mpx, ombres en 2 découpes, densité de décor réduite | décidé (18/11) |
| Pipelines | Canva → Tripo → GLB (`docs/modeles_sur_mesure.md`) ; scripts Blender du projet (`assets/models/animaux/*.py`, `~/dahalo-personnages/villageoise/scripts_claude/`) ; outils génériques (`.claude/skills/blender-python-pipeline/scripts/`) | décidé |

## 8. À faire / à ne pas faire

**À faire** : vérifier chaque asset à la caméra de jeu ; sourcer tout élément culturel ; garder la poussière et
l'usure ; montrer des gens au travail (eau, champs, bois, troupeaux).
**À ne pas faire** : sang ; zébu blessé ou tué ; « tribal » générique ; motifs ou termes malgaches inventés ;
objets sacrés comme butin ; couleurs vives sans fonction.

## 9. Exemples approuvés

- Zébu 3D (`assets/models/animaux/zebu.glb`) — approuvé en jeu le 17/11.
- Villageoise v5, corps généré par IA (TRELLIS.2 / ComfyUI) depuis la photo de référence, passé par le kit
  (recuisson de la couleur, poids transférés du rig v4, 9 000 triangles, texture 1024) — en jeu le 18/11.
- Enclos (d'après la photo fournie le 17/11) — `scenes/buildings/maisons.gd`.
- Illustration de référence : **à produire** (planche de calibration : villageoise + seau + case + baobab).

## 10. Journal des décisions

| Date | Décision |
|---|---|
| 17/11/2026 | Direction « sérieux, un peu réaliste » ; textures Poly Haven ; végétation Quaternius |
| 17/11/2026 | Zébu tiré de la vache Quaternius ; robes malgaches tirées au sort |
| 18/11/2026 | Textures 3D compressées + mipmaps ; résolution 3D adaptée sur Web |
| 18/11/2026 | Corvée d'eau au seau (animations Copilot) ; course de la villageoise |
| 18/11/2026 | Bible créée ; règles culturelles (lieux sacrés, sources obligatoires) |
| 18/11/2026 | Villageoise v5 : corps image→3D (TRELLIS.2) sur le squelette et les animations existants |
| 18/11/2026 | Villageoise v6 : travail des champs d'Astra (biner à la houe, récolter le maïs) |
| 18/11/2026 | Villageoise v7 : coupe du bois à la petite hache (**choix artistique** : outil courant de l'Androy à sourcer — hache ou coupe-coupe) |
