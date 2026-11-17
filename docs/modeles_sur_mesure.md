# Modèles sur mesure — descriptions pour Canva puis Tripo

Circuit (voir `docs/passation.md`) : **Canva** génère une image de référence → **Tripo** (ou Meshy) en fait un modèle
3D → export **`.glb`** dans `assets/models/` → Claude l'intègre à la place de la version générée par le code.

Ton commun à tous les prompts : **3D réaliste stylisée, couleurs naturelles ternes et poussiéreuses, sud aride de
Madagascar**. Toujours : un seul objet, entier, centré, **fond blanc uni**, lumière douce sans ombre portée, vue de
trois quarts légèrement plongeante, aucun texte ni logo, aucune personne.

Réglages Tripo conseillés : « low poly » / version allégée, **5 000 à 15 000 triangles**, texture 1024 px.
Pour les plantes, pas d'auto-rig.

## 1. Baobab (`assets/models/decor/baobab_1.glb`, 2 variantes)

> Photorealistic stylized 3D render of a single Madagascar baobab tree (Adansonia za) from the dry south of
> Madagascar, thick bottle-shaped grey-pink trunk with smooth bark, short thick branches forming a small crown at
> the very top, sparse small green leaves, standing alone, full tree visible from roots to crown, plain white
> background, soft diffuse lighting, three-quarter view slightly from above, no people, no text.

Variante 2 : remplacer « sparse small green leaves » par « leafless bare branches (dry season) ».

## 2. Épineux de l'Androy (`epineux_1.glb`, 3 variantes)

> Photorealistic stylized 3D render of a single Alluaudia procera plant from the spiny forest of southern
> Madagascar, several tall grey-green spiny stems growing straight up from the base, stems covered with rows of
> tiny round green leaves and small spines, about 4 meters tall, plain white background, soft diffuse lighting,
> three-quarter view slightly from above, no people, no text.

Variantes : « three stems », « five stems, one leaning », « young plant, two short stems ».

## 3. Raketa — figuier de Barbarie (`raketa_1.glb`, 2 variantes)

> Photorealistic stylized 3D render of a single prickly pear cactus (Opuntia) as found in southern Madagascar,
> flat oval green pads branching out in a fan shape, small spines, a few red-purple fruits on the edges of the top
> pads, about 1.5 meters tall, plain white background, soft diffuse lighting, three-quarter view, no people, no text.

## 4. Case du village (`assets/models/batiments/case.glb`)

> Photorealistic stylized 3D render of a small traditional house from the Androy region of southern Madagascar,
> rectangular wooden plank walls, steep two-sided roof, small wooden door, raised slightly on a packed earth base,
> weathered dusty wood, plain white background, soft diffuse lighting, three-quarter view slightly from above,
> no people, no text.

À vérifier avant de valider (culture) : forme et matériaux des cases antandroy (planches de bois, toiture).

## 5. Enclos à zébus (`assets/models/batiments/enclos.glb`)

> Photorealistic stylized 3D render of a square cattle enclosure from southern Madagascar, fence made of tightly
> packed vertical thorny wooden branches and posts, about 8 by 8 meters, one narrow opening on one side, empty,
> dry red earth inside, plain white background, soft diffuse lighting, view from above at 45 degrees, no animals,
> no people, no text.

## 6. Palissade épineuse (`assets/models/batiments/palissade.glb`)

> Photorealistic stylized 3D render of a straight 4 meter section of thorny hedge fence made of dry spiny
> branches woven between short wooden posts, about 1.3 meters high, plain white background, soft diffuse lighting,
> side three-quarter view, no people, no text.

Le segment doit être droit et faire 4 m de long (les segments sont mis bout à bout).

## Personnages

Voir `docs/passation.md` (A-pose, mains vides, Canva refuse les armes). Même ton : réaliste stylisé,
couleurs ternes. Personnages inventés, jamais copiés de vraies photos.
