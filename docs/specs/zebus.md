# Spec — Vie des zébus (comportement et animations)

> Statut : **prototype v0.5** (17/11/2026). Décrit ce qui est **réellement codé**.
> Code : `scenes/units/zebu.gd` ; modèle et animations : `assets/models/animaux/` (`zebu_depuis_vache.py`,
> `zebu_postures.py`) ; décor de l'enclos : `scenes/buildings/maisons.gd` (`_fourrage`, `_auge`).
> Capture, escorte, vol et victoire : voir `defense.md` et `economie.md` §9. Collisions : `interface.md` §2 ter.

## 1. Principe

Le comportement des zébus est **de la vie de troupeau, sans effet sur les règles** : le cheptel en enclos
consomme toujours la nourriture et l'eau du clan (ResourceManager), qu'il soit au fourrage ou couché.
Un zébu escorté ne fait rien d'autre que suivre son meneur. Un zébu capturé ou détaché qui était couché
**se relève d'un bond** (~1 s) avant de suivre.

## 2. Activités

Chaque zébu enchaîne des activités tirées au sort ; la nuit, presque tous se couchent pour dormir.

| Activité | Zébu sauvage (jour) | Zébu en enclos (jour) | Durée |
|---|---|---|---|
| **Brouter** : va au coin d'herbe choisi, puis alterne tête au sol (3–7 s) et quelques pas lents (0,35 m/s) | 60 % | — | 15–35 s |
| **Manger au fourrage** (3 places autour du tas, face à lui) | — | 30 % (si une place est libre) | 10–25 s |
| **Boire à l'auge** (2 places) | — | 15 % (si une place est libre) | 5–10 s |
| **Se coucher et ruminer** (va à une place libre, se couche) | 20 % | 30 % | 20–45 s |
| **Rester debout / changer de place** | 20 % | 25 % | 4–10 s |

- **Nuit** : 80 % dorment (tête posée), 20 % ruminent couchés ; un zébu couché la nuit a 85 % de chances de
  rester couché à chaque réveil (10–20 s). Au jour, il se relève.
- **Herbe** : pour brouter, le zébu sauvage tire 7 points autour du centre de son troupeau et va au meilleur :
  densité d'herbe (`vegetation.gd` : massifs, berges du lit, abords des mares), un peu de hasard, et une légère
  préférence pour les points proches. Jamais au sommet d'une colline. Le troupeau du centre broute donc
  surtout sur les berges, pas dans le sable du lit.
- **Dispersion** : un troupeau sauvage se répartit sur ~22 m (rayon 11 m autour de son centre, contre 6 m
  avant le 17/11) ; les troupeaux sont posés sur ±7 m au départ.
- **Enclos** : le tas de fourrage (paille et raquettes de raketa coupées, données au bétail en saison sèche
  dans le Sud) est au nord-ouest, l'auge (tronc creusé) au nord-est. Les zébus ne marchent pas dedans et ne
  se couchent pas à moins de 2 m du fourrage ni de 1,8 m de l'auge.
- **Allures** : marche 1 m/s, course au-delà de 1,6 m/s (escorte). Le zébu tourne en douceur.

## 3. Animations

| Animation | Origine | Usage |
|---|---|---|
| `Zebu_repos`, `Zebu_marche`, `Zebu_course` | Vache Quaternius (IK cuite à l'export) | Debout, marche, course |
| `Zebu_brouter` | `zebu_postures.py` | Brouter, manger au fourrage, boire (tête au sol, arrache l'herbe, mâche) |
| `Zebu_se_coucher` | `zebu_postures.py` | Se coucher (l'avant s'agenouille d'abord, comme les bovins) ; **jouée à l'envers pour se lever** |
| `Zebu_couche` | `zebu_postures.py` | Couché, tête haute, rumine (respiration, mastication) |
| `Zebu_dort` | `zebu_postures.py` | Couché, menton au sol, respiration lente (la nuit) |

La marque du clan descend avec l'animal couché.

## 4. Écarts avec le GDD et questions ouvertes

- Le GDD ne décrit pas la vie du troupeau : ajout du 17/11 à la demande (zébus trop groupés, sans activité).
- En pratique, dans le Sud, les zébus pâturent le jour avec les bouviers et rentrent au parc la nuit.
  Questions ouvertes :
  1. Les zébus en enclos devraient-ils sortir pâturer le jour (avec un gardien) ?
  2. Le fourrage de l'enclos devrait-il dépendre des réserves (tas vide quand la nourriture manque) ?
  3. Les zébus couchés devraient-ils être plus longs à capturer (il faut les faire lever) ?
