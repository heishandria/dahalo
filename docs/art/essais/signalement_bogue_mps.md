# Brouillon de signalement — corruption de clés int64 sur MPS dans TRELLIS.2

**Statut :** brouillon interne, non publié. Résumé des constats du
[fichier de coordination](../coordination-agents.md) ; à compléter avec un reproducer minimal et les versions
exactes avant envoi aux développeurs.

## Titre proposé

`[MPS] Incorrect int64 torch.sort results corrupt TRELLIS.2 sparse hash-map lookups`

## Résumé

Sur l'installation locale testée avec Apple MPS, le workflow
`3d_pixal3d_trellis2_image_to_model` produit une géométrie très dégradée. L'investigation a isolé un défaut
dans `comfy/ldm/trellis2/flexgemm.py`, au niveau de `TorchHashMap` : un tri `torch.sort` de clés `int64` sur
MPS renvoie une séquence croissante dont les valeurs ne correspondent pas au tri de référence CPU. Sur
1 700 000 clés, seules 106 992 sont retrouvées par la table de hachage MPS ; le tri CPU retrouve toutes
les clés dans le même test.

## Environnement observé

- ComfyUI 0.45.6 (`45eb6e6f954a532760b2226873a8c1a131043abd`)
- Apple Silicon, backend MPS, macOS 26.3
- Mémoire unifiée du poste : 16 Gio
- Version de PyTorch : **à relever avant publication**
- Modèle sélectionné par défaut dans le workflow : Pixal3D

Ces observations proviennent d'une seule configuration locale ; elles ne suffisent pas à établir que toutes
les versions de PyTorch ou tous les appareils Apple Silicon sont affectés.

## Étapes de reproduction actuellement consignées

1. Sur une installation ComfyUI 0.45.6 utilisant MPS, exécuter le workflow
   `3d_pixal3d_trellis2_image_to_model` jusqu'au décodage du maillage (environ 14 minutes sur le poste testé).
2. Dans le chemin `TorchHashMap` de `comfy/ldm/trellis2/flexgemm.py`, trier sur MPS un tenseur `int64` de
   clés d'environ 1,7 million d'éléments et effectuer les recherches utilisées par la table.
3. Comparer les résultats et le nombre de clés retrouvées au même calcul effectué sur CPU.

**Limite de reproduction :** le script autonome minimal, sa graine et les valeurs exactes de comparaison ne
sont pas encore inclus dans ce signalement. Le script local de comparaison MPS/CPU est en préparation par
l'autre agent ; il faudra en extraire un exemple réduit et publiable avant de soumettre le rapport.

## Résultat attendu

- Le tri MPS de valeurs `int64` renvoie les mêmes valeurs triées que la référence CPU.
- Les valeurs et indices renvoyés par le tri restent cohérents entre eux.
- La table de hachage retrouve toutes les clés insérées, dans les limites du comportement attendu pour les
  clés du test.

## Résultat observé

- `torch.sort` sur MPS renvoie une séquence apparemment croissante, mais avec des valeurs erronées par rapport
  au tri CPU.
- Le chemin `TorchHashMap` ne retrouve que **106 992 clés sur 1 700 000** sur MPS ; le calcul CPU retrouve
  **100 %** des clés dans le test local.
- Le workflow complet donne un maillage de **1 703 316 sommets pour 14 632 triangles** (environ 1 % des
  faces attendues) ; le rendu Blender observé est fragmenté.

## Symptômes connexes à confirmer séparément

Pendant le même workflow, les opérations suivantes échouent aussi :

- `RemeshMesh` : erreur d'indice hors limites (« index N is out of bounds for dimension 0 with size N »).
- `DecimateMesh` : opération non prise en charge pour `torch.int64`.

Ces erreurs sont consignées comme symptômes observés, mais leur lien causal avec le tri incorrect n'est pas
établi ici. Elles devraient être reproduites et diagnostiquées séparément.

## Diagnostic proposé aux mainteneurs

Fournir un test autonome qui :

1. construit un tenseur déterministe de clés `int64` (dont une taille proche de 1,7 million) ;
2. compare `values` **et** `indices` de `torch.sort` sur CPU et MPS, après transfert des résultats sur CPU ;
3. vérifie les recherches de `TorchHashMap` et rapporte les comptes exacts ;
4. indique les versions exactes de macOS, PyTorch et ComfyUI, ainsi que le modèle de puce.

Une fois ce test minimal établi, vérifier le correctif sur MPS et CPU, puis relancer le workflow et comparer
les comptes de sommets/faces avant et après le décodage. Ne pas conclure que les erreurs de remesh ou de
décimation sont corrigées tant que leurs tests spécifiques n'ont pas réussi.

## Publication

Ce fichier est un brouillon non publié. Aucun rapport n'a été soumis. Le correctif local et les nouveaux
résultats de validation pourront être ajoutés avant toute publication par l'utilisateur.
