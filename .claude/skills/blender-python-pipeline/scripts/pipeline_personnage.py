#!/usr/bin/env python3
"""Pipeline personnage image→jeu, piloté par config_personnage.json (gabarit : ../gabarits/).

À lancer depuis le dossier du personnage :
    python3 ~/dahalo/.claude/skills/blender-python-pipeline/scripts/pipeline_personnage.py [options]

Options :
    --etat               état des étapes, rien n'est lancé
    --depuis ETAPE       relance ETAPE et toutes les suivantes (même déjà faites)
    --jusqu-a ETAPE      s'arrête après ETAPE (ex. controle_texture : regarder avant de continuer)
    --etape ETAPE        cette étape seulement
    --seche              affiche les commandes sans les lancer

Étapes, dans l'ordre (celles désactivées dans config["etapes"] sont sautées) :
    greffe            tête générée seule greffée sur le corps
    texture           projection des photos de référence, cuisson
    controle_texture  comparaison aux photos + rendu RTS de la géométrie texturée → À REGARDER
    rig               squelette et poids
    corpulence        épaississement par os
    accessoire        os et objet d'accessoire (fusil, sagaie…)
    retouche          direction artistique de la texture (désaturation, poussière, taille)
    anim              animations + export GLB
    bibliotheque      animations reprises d'une bibliothèque (config["bibliotheque"]) qui remplacent ou complètent
                      celles du script d'animation (Quaternius UAL, Mixamo) → fichiers final_blend / final_glb
    controle_anim     RTS par animation (repos d'abord) + audit du GLB → À REGARDER
    video             vidéo de contrôle
    promouvoir        copie le GLB dans le jeu (empreintes comparées) — seulement avec --etape promouvoir

L'état est écrit dans .etat_pipeline.json. Un échec arrête la chaîne : corriger, puis --depuis ETAPE.
"""
import hashlib, json, os, shutil, subprocess, sys, time

ETAPES = ["greffe", "texture", "controle_texture", "rig", "corpulence", "accessoire", "retouche", "anim",
          "bibliotheque", "controle_anim", "video", "promouvoir"]
KIT = os.path.dirname(os.path.abspath(__file__))
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
FICHIER_ETAT = ".etat_pipeline.json"


def option(nom):
    return sys.argv[sys.argv.index(nom) + 1] if nom in sys.argv else None


def chemin(p):
    return os.path.expanduser(p)


def empreinte(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


c = json.load(open("config_personnage.json"))
f, s, g = c["fichiers"], c["scripts"], c["geometrie"]
BIB = c.get("bibliotheque", [])
FINAL_BLEND = f.get("final_blend") if BIB else f["anim_blend"]
FINAL_GLB = f.get("final_glb") if BIB else f["anim_glb"]
photos = {k: chemin(v) for k, v in c["photos_reference"].items() if not k.startswith("_")}
actives = c["etapes"]
etat = json.load(open(FICHIER_ETAT)) if os.path.exists(FICHIER_ETAT) else {}

if "--etat" in sys.argv:
    for e in ETAPES:
        print("%-17s %s" % (e, etat.get(e, "—")))
    sys.exit(0)


def blender(entree, script, *arguments):
    commande = [BLENDER, "-b"] + ([entree] if entree else []) + ["--python-exit-code", "1", "--python", script, "--"]
    return commande + [str(a) for a in arguments]


def commandes(e):
    """Liste de commandes de l'étape e (une étape peut en enchaîner plusieurs)."""
    if e == "greffe":
        gr = c["greffe"]
        return [blender(None, s["greffe"], f["corps_glb"], f["tete_glb"], photos["face"], gr["recalage"],
                        gr["recadrage_tete"], f["greffe_glb"], "--tete-triangles", gr.get("tete_triangles", 150000))]
    if e == "texture":
        # Greffe déjà faite et étape désactivée : on repart quand même de la tête greffée si elle existe.
        greffe_dispo = actives.get("greffe") or os.path.exists(f.get("greffe_glb", ""))
        entree = f["greffe_glb"] if greffe_dispo else f["corps_glb"]
        a = [entree, photos["face"], f["texture_blend"], f["texture_glb"], "--hauteur", g["hauteur_m"],
             "--voxel", g["voxel_remaillage"], "--texture", c["texture"]["px"], "--triangles", g["triangles"]]
        if g.get("triangles_tete"):
            a += ["--triangles-tete", g["triangles_tete"]]
        for cle, opt in (("dos", "--dos"), ("profils", "--profils")):
            if photos.get(cle):
                a += [opt, photos[cle]]
        if photos.get("gros_plan") and c.get("greffe", {}).get("recalage"):
            a += ["--gros-plan", photos["gros_plan"], "--recalage", c["greffe"]["recalage"]]
        return [blender(None, s["texture"], *a, *c["texture"].get("arguments", []))]
    if e == "controle_texture":
        d = os.path.join(f["rendus"], "controle_texture")
        return [blender(f["texture_blend"], s["comparer"], photos["face"], photos["dos"],
                        os.path.join(d, "comparaison.png")),
                blender(f["texture_blend"], os.path.join(KIT, "rendu_verification.py"), "--sortie", d,
                        "--vues", "face,profil,dos", "--rts")]
    if e == "rig":
        return [blender(f["texture_blend"], s["rig"], f["rig_blend"])]
    if e == "corpulence":
        return [blender(f["rig_blend"], s["corpulence"], f["corpulence_blend"])]
    if e == "accessoire":
        entree = f["corpulence_blend"] if actives.get("corpulence") else f["rig_blend"]
        return [blender(entree, s["accessoire"], f["accessoire_blend"])]
    if e == "retouche":
        r = c["retouche"]
        return [blender(dernier_blend_avant("retouche"), s["retouche"], f["retouche_blend"], "--desaturer",
                        r["desaturer"], "--poussiere", r["poussiere"], "--taille", c["texture"]["px"],
                        "--controle", os.path.join(f["rendus"], "retouche"))]
    if e == "anim":
        return [blender(dernier_blend_avant("anim"), s["anim"], f["anim_glb"], f["anim_blend"])]
    if e == "bibliotheque":
        # Une source par passage ; les passages s'enchaînent, le dernier écrit final_blend et final_glb.
        cmds, entree = [], f["anim_blend"]
        for k, b in enumerate(BIB):
            dernier = k == len(BIB) - 1
            sortie = FINAL_BLEND if dernier else FINAL_BLEND.replace(".blend", "_etape%d.blend" % k)
            a = [chemin(b["source"]), sortie, "--prefixe", c["prefixe_actions"],
                 "--actions", "%s=%s" % (b.get("action", "*"), b["nom"]), "--remplacer"]
            if b.get("arme"):
                a += ["--arme-deux-mains", b["arme"]]
            if dernier:
                a += ["--glb", FINAL_GLB]
            cmds.append(blender(entree, os.path.join(KIT, "recibler_bibliotheque.py"), *a))
            entree = sortie
        return cmds
    if e == "controle_anim":
        d = os.path.join(f["rendus"], "controle_anim")
        actions = []
        for nom in c["animation"]["actions"]:
            actions += ["--action", nom]
        return [blender(FINAL_BLEND, os.path.join(KIT, "rendu_verification.py"), "--sortie", d,
                        "--vues", "face,trois_quarts", "--rts", *actions),
                ["python3", os.path.join(KIT, "audit_glb.py"), FINAL_GLB,
                 "--max-triangles", str(c["budget"]["triangles"]), "--max-texture", str(c["budget"]["texture"])]]
    if e == "video":
        a = c["animation"]
        return [blender(FINAL_BLEND, s["video"], f["video_mp4"], chemin(c["video"]["reference"]),
                        "--marche", a["vitesse_marche"], "--course", a["vitesse_course"])]
    raise ValueError(e)


def dernier_blend_avant(e):
    """Fichier produit par la dernière étape active qui précède e (les étapes optionnelles se sautent)."""
    for prec, cle in (("retouche", "retouche_blend"), ("accessoire", "accessoire_blend"),
                      ("corpulence", "corpulence_blend"), ("rig", "rig_blend")):
        if ETAPES.index(prec) < ETAPES.index(e) and actives.get(prec):
            return f[cle]
    return f["rig_blend"]


def promouvoir():
    source, cible = FINAL_GLB, chemin(c["jeu"]["glb"])
    if os.path.exists(cible):
        sauvegarde = os.path.join("sauvegardes", "%s_%s.glb" % (os.path.basename(cible)[:-4], time.strftime("%Y%m%d-%H%M%S")))
        os.makedirs("sauvegardes", exist_ok=True)
        shutil.copy2(cible, sauvegarde)
        print("Ancien GLB du jeu sauvegardé : " + sauvegarde)
    shutil.copy2(source, cible)
    if empreinte(source) != empreinte(cible):
        sys.exit("ÉCHEC : la copie dans le jeu diffère de la source")
    print("Promu : %s → %s (md5 %s). Relancer l'import Godot (--headless --import)." % (source, cible, empreinte(cible)))


depuis, jusqu_a, seule = option("--depuis"), option("--jusqu-a"), option("--etape")
for e in ETAPES:
    if seule:
        if e != seule:
            continue
    else:
        if e == "promouvoir":
            continue                                   # touche au jeu : seulement sur demande explicite
        if (e in actives and not actives[e]) or (e == "bibliotheque" and not BIB):
            continue
        if depuis and ETAPES.index(e) < ETAPES.index(depuis):
            continue
        if not depuis and e in etat:
            print("(déjà fait : %s)" % e)
            continue
    print("\n=== %s ===" % e)
    if e == "promouvoir":
        if "--seche" not in sys.argv:
            promouvoir()
    else:
        for commande in commandes(e):
            print(" ".join(commande))
            if "--seche" in sys.argv:
                continue
            os.makedirs(f["rendus"], exist_ok=True)
            journal = os.path.join(f["rendus"], "journal_%s.txt" % e)
            with open(journal, "a") as j:
                code = subprocess.call(commande, stdout=j, stderr=subprocess.STDOUT)
            if code != 0:
                sys.exit("ÉCHEC de l'étape %s (code %d) : voir %s, corriger, puis --depuis %s" % (e, code, journal, e))
    if "--seche" not in sys.argv:
        etat[e] = time.strftime("%Y-%m-%d %H:%M:%S")
        json.dump(etat, open(FICHIER_ETAT, "w"), indent=1)
    if e.startswith("controle"):
        print(">>> À REGARDER avant de continuer : %s/%s/" % (f["rendus"], e))
    if e == jusqu_a:
        print("Arrêt demandé après %s." % e)
        break
