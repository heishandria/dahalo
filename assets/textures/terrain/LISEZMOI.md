# Textures du terrain

Textures photo de **Poly Haven** (https://polyhaven.com), licence **CC0** : usage commercial libre, sans attribution.
Résolution 1K (JPG). « couleur » = Diffuse ; « relief » = normal map au format OpenGL (nor_gl).

| Fichier | Texture Poly Haven | Rôle (scenes/world/terrain.gdshader) |
|---|---|---|
| red_laterite_soil_stones_* | Red Laterite Soil Stones | Sol de base (latérite rouge) |
| sparse_grass_couleur | Sparse Grass | Herbe, saison normale |
| withered_grass_couleur | Withered Grass | Herbe fanée, sécheresse |
| gravelly_sand_couleur | Gravelly Sand | Plaques de sable, lit de rivière |
| mud_cracked_dry_riverbed_002_couleur | Mud Cracked Dry Riverbed 002 | Lit de rivière craquelé en sécheresse |
| cliff_side_* | Cliff Side (collection Namaqualand) | Parois des plateaux et pentes du relief |
| dry_ground_rocks_couleur | Dry Ground Rocks | Dessus des plateaux |

Le rendu Web limite un shader à 16 textures (moteur compris) : le shader du terrain en utilise 11 au plus.
Téléchargées par l'API publique de Poly Haven le 17/11/2026.
