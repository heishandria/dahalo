---
name: image-generation-direction
description: "Diriger un générateur d'images (et la retouche d'images) : brief structuré, rôle de chaque référence, invariants et variations permises, itération une variable à la fois, défauts typiques (mains, anatomie, nombre d'objets, texte, vues incohérentes), contrôle visuel et correction. Indépendant du modèle (Canva, Midjourney, DALL·E, Stable Diffusion/Flux, etc.). Use for AI image generation, prompting, image-to-image, inpainting, image editing."
---

# Diriger la génération d'images

## Avant de générer

1. **L'outil existe-t-il dans la session ?** Sinon, livrer un brief/prompt prêt à coller dans l'outil de
   l'utilisateur, et le dire. Ne jamais prétendre avoir généré une image.
2. **Bon outil pour le besoin** : génération = explorations, ambiances, concepts ; **pas** pour des vues
   orthographiques garanties, du texte exact, des mesures, un nombre exact d'objets, des détails culturels
   exacts. Pour ceux-là : 3D, vectoriel, retouche contrôlée.

## Brief (squelette)

[livrable] de [sujet], [rôle/action], [caméra/vue], [composition], [langage de formes], [anatomie/proportions],
[costume/matériaux], [palette], [lumière], [fond], [ancres de style], [invariants], [contraintes négatives
précises], [format/ratio].

- **Invariants** : ce qui ne doit pas changer (identité, costume, couleurs, proportions).
- **Variations permises** : ce qu'on explore cette fois.
- **Références** : une fonction chacune (identité, pose, style, palette, costume, composition) ; le dire.
- **Négatifs** : seulement contre des défauts déjà observés (« pas de texte », « une seule personne »), pas de
  longues listes vagues.
- Pour un modèle 3D à partir d'une image (image→3D) : un seul objet entier, centré, fond uni, lumière douce
  sans ombre portée, vue de 3/4, sans texte.

## Itérer

1. Variantes larges seulement pour les choix non tranchés (composition, silhouette).
2. Choisir une direction, **figer** le reste (graine, références, prompt).
3. Changer **une variable à la fois** ; noter ce qui a changé.

## Contrôle (à chaque image retenue)

Mains (nombre de doigts, articulations), pieds et appuis, membres en trop/fusionnés, symétrie des yeux,
nombre d'objets, perspective, texte parasite, accessoires qui changent, cohérence culturelle (rien d'inventé
présenté comme authentique), artefacts de bord, style conforme à la bible. Utiliser
`../visual-quality-review/SKILL.md`.

## Corriger

Retouche ciblée (masque/inpainting) si disponible, sinon paint-over, vectoriel ou 3D pour les détails de
production. Les corrections se vérifient comme le reste.

## ComfyUI local (sans MCP)

`scripts/comfyui.py` pilote un serveur ComfyUI par son API HTTP (bibliothèque standard, aucun MCP) :

    python3 scripts/comfyui.py etat                         # serveur, matériel, modèles installés
    python3 scripts/comfyui.py modeles-workflow --filtre 3d # modèles de workflow fournis avec ComfyUI
    python3 scripts/comfyui.py executer WORKFLOW.json --image entree.png --sortie DOSSIER \
        --param ID.entree=valeur …

- Accepte les workflows au **format de l'interface** (convertis via `/object_info` : réglages dans l'ordre,
  graines « fixed/randomize » sautées, menus dynamiques `nom.sous_reglage`) ou au format API.
- Envoie l'image, lance, suit la file, télécharge les sorties (images, `.glb`), écrit `journal.json`
  et `prompt_api.json` (pour rejouer). Code de sortie non nul en cas d'échec.
- **Vérifier d'abord `etat`** : on ne peut générer que ce que les modèles installés permettent. Une installation
  sans *checkpoint* ni encodeur de texte ne fait pas de texte→image (seulement image→3D, détourage, etc.).
- Les identifiants de nœuds (`--param 186.target_face_count=20000`) se lisent dans `prompt_api.json`.
- Licences : celle de **chaque modèle** s'applique aux usages (voir la liste des ressources du projet).
- **Limite constatée sur Mac (Apple MPS), ComfyUI 0.45.6, 18/11/2026** : avec TRELLIS.2 / Pixal3D, la génération
  passe (forme et couleurs), mais le maillage décodé n'a qu'une faible part de ses faces (ex. 1,7 M sommets pour
  14 632 triangles : silhouette en fragments) ; `RemeshMesh` et `DecimateMesh` échouent (index hors limites,
  « not supported for torch.int64 »). Toujours auditer la sortie (`audit_glb.py` signale l'incohérence) et faire
  le nettoyage dans Blender (`nettoyer_maillage_ia.py`) plutôt que dans ComfyUI. Graphe « génération seule » :
  `workflows/image_vers_3d_brut_api.json`.
  **Mise à jour du 18/11 (après correctif local de ComfyUI)** : workflow officiel complet réussi sur Mac
  (villageoise : ~59 min). Retenir : **personnage photographié en studio → TRELLIS.2** (`--param 316.value=true`) ;
  Pixal3D y renvoie « coords can't be empty ». Pour un essai rapide, alléger ou retirer les cuissons
  d'occlusion et de normales (≈ 30 min à elles seules) : `241.resolution=512`, `233.samples=16`,
  `224.resolution=1024`. Délai : ne jamais interrompre un calcul long (`comfyui.py` attend sans couper ;
  `recuperer PROMPT_ID`).

## Traçabilité

Conserver : prompt, outil et version, graine si dispo, références utilisées, image retenue, corrections.

## Critères de validation

- L'image suit le brief, tient les invariants, a été regardée et critiquée ; défauts corrigés ou listés.
- Rien n'est présenté comme fait documenté sur la seule foi d'une image générée.
