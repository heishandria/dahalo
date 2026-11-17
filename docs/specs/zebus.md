# Spec — Vie des zébus (comportement et animations)

> Statut : **prototype v0.5** (17/11/2026). Décrit ce qui est **réellement codé**.
> Code : `scenes/units/zebu.gd` ; modèle et animations : `assets/models/animaux/` (`zebu_depuis_vache.py`,
> `zebu_postures.py`) ; décor de l'enclos : `scenes/buildings/maisons.gd` (`_fourrage`, `_auge`).
> Capture, escorte, vol et victoire : voir `defense.md` et `economie.md` §9. Collisions : `interface.md` §2 ter.

## 1. Principe

Le comportement des zébus est **de la vie de troupeau, sans effet sur les règles** : le cheptel en enclos
consomme toujours la nourriture et l'eau du clan (ResourceManager), qu'il soit au fourrage ou couché.
En revanche, le tas de fourrage et l'auge **montrent l'état des réserves** (§2, Réserves). Seule exception
aux règles : le **pâturage** (§4), décidé par le joueur.
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
- **Réserves** : le tas de fourrage suit la nourriture du clan, l'eau de l'auge suit l'eau. Pleins tant qu'il
  reste au moins 3 minutes de réserve pour tout le cheptel (`GameRules.RESERVE_ENCLOS_PLEIN_MIN`), ils baissent
  ensuite (le tas s'affaisse et rétrécit, l'eau descend de 10 cm) et disparaissent à 0. Tas ou auge vide :
  le zébu tiré pour manger ou boire vient quand même et **attend devant, tête haute** (5–10 s) ; il se couche
  beaucoup moins le jour (10 % au lieu de 30 %) et reste debout ou change de place (45 % au lieu de 25 %). Les fuites en cas de manque sont
  inchangées (`economie.md` §2). Code : `scenes/buildings/enclos.gd` (`remplissage`, `_maj_reserves`).
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

## 4. Pâturage (troupeau mené dehors le jour)

Comme dans le Sud, où les zébus pâturent le jour avec les bouviers et rentrent au parc la nuit.

- **Ordre** : bouton « Mener au pâturage / Garder au parc » dans le panneau de l'enclos (ligne « Troupeau »),
  commande `paturage` (CommandBus). Il reste actif chaque jour jusqu'à ce qu'on l'arrête.
- **Gardien** : l'enclos prend le villageois du clan le plus proche (inoccupé de préférence) ; sans villageois,
  l'ordre est refusé. Le gardien suit le troupeau au pas (1,4 m/s), un peu en retrait côté village, et attend à
  la porte la nuit. S'il reçoit **un autre ordre** ou **tombe**, le pâturage s'arrête et le troupeau rentre.
- **Où** : l'enclos choisit le meilleur coin d'herbe parmi 16 points tirés entre **14 et 28 m** (densité
  d'herbe, un peu de préférence pour le côté de la porte, pas au sommet des collines). Les zébus s'y dispersent
  dans un rayon de **7 m** et broutent, se couchent ou flânent comme un troupeau sauvage.
- **Quand** : ils sortent **5 s après l'aube** et rentrent **30 s avant la nuit**, chacun dans les 6 s
  (départs échelonnés). Ils passent **par la porte** (sud), au pas soutenu de **1,3 m/s**.
- **Effet sur les réserves** : un zébu au pâturage (aller et retour compris) ne prend que **25 %** de sa ration
  de nourriture sur les réserves (`PATURAGE_FACTEUR_NOURRITURE`) ; l'eau est inchangée. Le HUD affiche la
  consommation réelle.
- **Risque** : un zébu au pâturage reste au clan (il compte pour la victoire) mais se vole en **2 s** au lieu de
  4 s (`DUREE_CAPTURE_PATURAGE_S`), avec alerte « vos zébus au pâturage ». L'IA vise un troupeau adverse au
  pâturage **de jour comme de nuit** (les zébus d'enclos, seulement la nuit). Le pillage d'un enclos ne prend que
  les zébus restés dedans.
- Le panneau de l'enclos affiche « Pâturage : N dehors, gardés par un villageois ».
- Constantes : `GameRules.PATURAGE_*`. Code : `enclos.gd` (`mener_au_paturage`, `troupeau_dehors`),
  `zebu.gd` (`dehors`, `_partir`, `_etape_suivante`), `unite.gd` (état `GARDE`).

## 5. Écarts avec le GDD et questions ouvertes

- Le GDD ne décrit pas la vie du troupeau : ajout du 17/11 à la demande (zébus trop groupés, sans activité).
- En pratique, dans le Sud, les zébus pâturent le jour avec les bouviers et rentrent au parc la nuit.
  Questions ouvertes :
  1. ~~Les zébus en enclos devraient-ils sortir pâturer le jour ?~~ Oui (17/11), au choix du joueur : §4.
     Écart : le GDD ne prévoit pas cette commande. L'IA ne mène pas encore son propre troupeau au pâturage.
  2. ~~Le fourrage de l'enclos devrait-il dépendre des réserves ?~~ Oui (17/11) : voir §2, Réserves.
  3. ~~Les zébus couchés devraient-ils être plus longs à capturer ?~~ Non (17/11) : ce serait une règle
     invisible qui freinerait les raids de nuit, cœur du thème ; le zébu met déjà ~1 s à se relever.
