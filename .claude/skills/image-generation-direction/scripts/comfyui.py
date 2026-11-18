#!/usr/bin/env python3
"""Piloter un serveur ComfyUI local par son API HTTP (sans MCP, sans interface, bibliothèque standard seulement).

Commandes :
  python3 comfyui.py etat
      Le serveur répond-il ? Matériel, version, modèles installés par dossier.
  python3 comfyui.py modeles-workflow [--filtre 3d]
      Liste les modèles de workflow fournis avec ComfyUI (dossier du paquet comfyui_workflow_templates_json).
  python3 comfyui.py convertir WORKFLOW.json SORTIE_API.json
      Convertit un workflow au format de l'interface en format API (à partir de /object_info du serveur).
  python3 comfyui.py executer WORKFLOW.json --sortie DOSSIER [--image FICHIER] [--noeud-image ID]
          [--param ID.entree=valeur]… [--delai 7200] [--interrompre]
      Au-delà du délai, le script cesse d'attendre mais LAISSE le calcul tourner (sauf --interrompre) ;
      l'identifiant est noté dans DOSSIER/journal.json pour « recuperer ».
  python3 comfyui.py recuperer PROMPT_ID --sortie DOSSIER
      Télécharge les sorties d'un calcul terminé (lancé plus tôt, ou dont on a cessé d'attendre).
      Convertit si besoin, envoie l'image d'entrée, applique les réglages, lance, suit l'avancement, télécharge
      les sorties (images, modèles 3D) dans DOSSIER et écrit DOSSIER/journal.json.

Serveur : variable COMFYUI_URL (défaut http://127.0.0.1:8188).
Exemple (image → modèle 3D texturé) :
  python3 comfyui.py executer 3d_pixal3d_trellis2_image_to_model.json --image seau.png --sortie essais/seau \\
      --param 186.target_faces=20000 --param 288.value=2048
"""
import glob
import json
import mimetypes
import os
import sys
import time
import urllib.parse
import urllib.request
import uuid

URL = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188").rstrip("/")
TYPES_REGLAGES = {"INT", "FLOAT", "STRING", "BOOLEAN", "COMBO", "COLOR", "LOAD_3D", "COMFY_DYNAMICCOMBO_V3"}
CONTROLES_GRAINE = {"fixed", "randomize", "increment", "decrement"}
NOEUDS_INTERFACE = {"Note", "MarkdownNote", "Reroute", "PrimitiveNode"}


# --- HTTP -----------------------------------------------------------------------------------------------

def requete(chemin, donnees=None, entetes=None, delai=60):
    corps = None
    if donnees is not None and not isinstance(donnees, bytes):
        corps = json.dumps(donnees).encode()
        entetes = {"Content-Type": "application/json", **(entetes or {})}
    elif isinstance(donnees, bytes):
        corps = donnees
    req = urllib.request.Request(URL + chemin, data=corps, headers=entetes or {})
    with urllib.request.urlopen(req, timeout=delai) as r:
        contenu = r.read()
        if "json" in (r.headers.get("Content-Type") or ""):
            return json.loads(contenu)
        return contenu


def envoyer_image(chemin):
    """Envoie une image dans le dossier d'entrée de ComfyUI ; renvoie le nom à mettre dans LoadImage."""
    limite = "----dahalo" + uuid.uuid4().hex
    nom = os.path.basename(chemin)
    type_mime = mimetypes.guess_type(nom)[0] or "application/octet-stream"
    with open(chemin, "rb") as f:
        octets = f.read()
    corps = (("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n"
              % (limite, nom, type_mime)).encode() + octets +
             ("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--%s--\r\n"
              % (limite, limite)).encode())
    r = requete("/upload/image", corps, {"Content-Type": "multipart/form-data; boundary=" + limite})
    return (r.get("subfolder") + "/" if r.get("subfolder") else "") + r["name"]


# --- Conversion interface → API -------------------------------------------------------------------------

def est_reglage(definition):
    type_entree = definition[0]
    options = definition[1] if len(definition) > 1 and isinstance(definition[1], dict) else {}
    if options.get("forceInput"):
        return False
    return isinstance(type_entree, list) or type_entree in TYPES_REGLAGES


def entrees_api(definition_noeud):
    """Entrées dans l'ordre de l'interface (obligatoires puis facultatives) : [(nom, définition)]."""
    entrees = []
    for groupe in ("required", "optional"):
        for nom, d in definition_noeud.get("input", {}).get(groupe, {}).items():
            entrees.append((nom, d))
    return entrees


def convertir(workflow, info):
    """Workflow de l'interface (nodes/links) → prompt API {id: {class_type, inputs}}."""
    if "nodes" not in workflow:
        return workflow                                   # déjà au format API
    liens = {l[0]: l for l in workflow.get("links", [])}
    prompt = {}
    for n in workflow["nodes"]:
        type_noeud = n["type"]
        if type_noeud in NOEUDS_INTERFACE or n.get("mode", 0) in (2, 4):   # notes, muets, contournés
            continue
        if type_noeud not in info:
            raise SystemExit("ERREUR nœud inconnu du serveur : %s (id %s) — nœud personnalisé manquant ?"
                             % (type_noeud, n["id"]))
        entrees = {}
        relies = {}
        for e in n.get("inputs", []):
            if e.get("link") is not None and e["link"] in liens:
                l = liens[e["link"]]
                relies[e["name"]] = [str(l[1]), l[2]]
        valeurs = list(n.get("widgets_values") or [])
        if isinstance(n.get("widgets_values"), dict):       # certains nœuds stockent un dictionnaire
            valeurs = []
            entrees.update(n["widgets_values"])
        file_entrees = entrees_api(info[type_noeud])
        i = 0
        while file_entrees:
            nom, d = file_entrees.pop(0)
            if not est_reglage(d):
                continue
            if i >= len(valeurs):
                break
            v = valeurs[i]
            i += 1
            entrees[nom] = v
            # Contrôle « après génération » (graine) : valeur d'interface à sauter.
            if d[0] == "INT" and i < len(valeurs) and valeurs[i] in CONTROLES_GRAINE:
                i += 1
            # Menu dynamique : ses sous-réglages (de l'option choisie) suivent immédiatement.
            if d[0] == "COMFY_DYNAMICCOMBO_V3":
                for option in d[1].get("options", []):
                    if option["key"] == v:
                        sous = []
                        for groupe in ("required", "optional"):
                            for sn, sd in option.get("inputs", {}).get(groupe, {}).items():
                                sous.append((nom + "." + sn, sd))
                        file_entrees = sous + file_entrees
        entrees.update(relies)
        prompt[str(n["id"])] = {"class_type": type_noeud, "inputs": entrees,
                                "_meta": {"title": n.get("title") or type_noeud}}
    return prompt


def appliquer_param(prompt, param):
    cle, valeur = param.split("=", 1)
    noeud, entree = cle.split(".", 1)
    if noeud not in prompt:
        raise SystemExit("ERREUR --param : nœud %s absent" % noeud)
    try:
        valeur = json.loads(valeur)
    except ValueError:
        pass
    prompt[noeud]["inputs"][entree] = valeur


# --- Exécution ------------------------------------------------------------------------------------------

def telecharger_sorties(historique, sortie, journal):
    """Statut, erreurs et fichiers de sortie (images, modèles 3D) d'un calcul terminé."""
    st = historique.get("status", {})
    journal["statut"] = st.get("status_str")
    for m in st.get("messages", []):
        if m[0] in ("execution_error", "execution_interrupted"):
            journal["messages"].append(m)
    for noeud, sorties in historique.get("outputs", {}).items():
        for genre, fichiers in sorties.items():
            for fi in fichiers if isinstance(fichiers, list) else []:
                if not isinstance(fi, dict) or "filename" not in fi:
                    continue
                if fi.get("type") == "temp" and genre == "images":
                    continue                    # aperçus temporaires : ignorés
                q = urllib.parse.urlencode({"filename": fi["filename"], "subfolder": fi.get("subfolder", ""),
                                            "type": fi.get("type", "output")})
                contenu = requete("/view?" + q, delai=300)
                dest = os.path.join(sortie, "%s_%s" % (noeud, os.path.basename(fi["filename"])))
                with open(dest, "wb") as f:
                    f.write(contenu if isinstance(contenu, bytes) else json.dumps(contenu).encode())
                journal["sorties"].append(dest)


def ecrire_journal(sortie, journal, duree):
    with open(os.path.join(sortie, "journal.json"), "w", encoding="utf-8") as f:
        json.dump(journal, f, ensure_ascii=False, indent=1)
    print("Statut : %s en %.0f s ; %d fichier(s)" % (journal["statut"], duree, len(journal["sorties"])))
    for s in journal["sorties"]:
        print("  " + s)
    for m in journal["messages"]:
        print("ERREUR %s" % json.dumps(m[1], ensure_ascii=False)[:1500])


def recuperer(pid, sortie):
    os.makedirs(sortie, exist_ok=True)
    journal = {"prompt_id": pid, "statut": None, "sorties": [], "messages": []}
    h = requete("/history/" + pid)
    if pid not in h:
        q = requete("/queue")
        en_file = any(x[1] == pid for x in q.get("queue_running", []) + q.get("queue_pending", []))
        journal["statut"] = "toujours en cours" if en_file else "inconnu (serveur redémarré ?)"
    else:
        telecharger_sorties(h[pid], sortie, journal)
    ecrire_journal(sortie, journal, 0)
    return journal


def executer(workflow_chemin, sortie, image=None, noeud_image=None, params=(), delai=7200, interrompre=False):
    os.makedirs(sortie, exist_ok=True)
    info = requete("/object_info", delai=120)
    with open(workflow_chemin, encoding="utf-8") as f:
        prompt = convertir(json.load(f), info)
    if image:
        nom = envoyer_image(image)
        cibles = [k for k, v in prompt.items() if v["class_type"] == "LoadImage"]
        if noeud_image:
            cibles = [noeud_image]
        if not cibles:
            raise SystemExit("ERREUR aucun nœud LoadImage pour l'image d'entrée")
        for k in cibles:
            prompt[k]["inputs"]["image"] = nom
        print("Image envoyée : %s → nœud(s) %s" % (nom, ", ".join(cibles)))
    for p in params:
        appliquer_param(prompt, p)
    with open(os.path.join(sortie, "prompt_api.json"), "w", encoding="utf-8") as f:
        json.dump(prompt, f, ensure_ascii=False, indent=1)
    client = uuid.uuid4().hex
    debut = time.time()
    try:
        r = requete("/prompt", {"prompt": prompt, "client_id": client})
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        with open(os.path.join(sortie, "erreur.json"), "w", encoding="utf-8") as f:
            f.write(detail)
        raise SystemExit("ERREUR refus du serveur (%d) : %s" % (e.code, detail[:1500]))
    pid = r["prompt_id"]
    print("Lancé : %s" % pid)
    historique = None
    dernier = ""
    while time.time() - debut < delai:
        time.sleep(3)
        h = requete("/history/" + pid)
        if pid in h:
            historique = h[pid]
            if historique.get("status", {}).get("completed") or historique.get("status", {}).get("status_str") == "error":
                break
        q = requete("/queue")
        etat = "en cours" if any(x[1] == pid for x in q.get("queue_running", [])) else "en attente"
        if etat != dernier:
            print("  %s (%.0f s)" % (etat, time.time() - debut))
            dernier = etat
    duree = time.time() - debut
    journal = {"prompt_id": pid, "workflow": workflow_chemin, "image": image, "params": list(params),
               "duree_s": round(duree, 1), "statut": None, "sorties": [], "messages": []}
    if historique is None:
        if interrompre:
            journal["statut"] = "délai dépassé (calcul interrompu)"
            requete("/interrupt", {})
        else:
            journal["statut"] = "délai dépassé (calcul laissé en cours : « recuperer %s »)" % pid
    else:
        telecharger_sorties(historique, sortie, journal)
    ecrire_journal(sortie, journal, duree)
    return journal


# --- Divers ---------------------------------------------------------------------------------------------

def etat():
    s = requete("/system_stats")
    print("ComfyUI %s — %s" % (s["system"].get("comfyui_version"), URL))
    for d in s.get("devices", []):
        print("  Matériel : %s, mémoire %.1f Go" % (d.get("name"), d.get("vram_total", 0) / 1e9))
    for dossier in requete("/models"):
        fichiers = requete("/models/" + dossier)
        if fichiers:
            print("  %-22s %s" % (dossier, ", ".join(fichiers)))


def modeles_workflow(filtre=""):
    import site
    chemins = []
    fin = os.path.join("comfyui_workflow_templates_json", "templates", "*.json")
    # Environnement du serveur : COMFYUI_DIR/.venv, ou installations de ComfyUI Desktop (dossiers cachés que
    # glob(**) ne parcourt pas sous Python < 3.11).
    racines = [os.environ.get("COMFYUI_DIR", "")] + glob.glob(os.path.expanduser("~/ComfyUI-Installs/*/ComfyUI"))
    for r in racines:
        if r:
            chemins += glob.glob(os.path.join(r, ".venv", "lib", "python*", "site-packages", fin))
    for base in site.getsitepackages() + [os.path.expanduser("~/ComfyUI-Installs")]:
        chemins += glob.glob(os.path.join(base, "**", fin), recursive=True)
    # L'environnement du serveur (ComfyUI/.venv) d'abord : d'autres environnements peuvent avoir des versions
    # plus anciennes des modèles de workflow, incompatibles avec les nœuds du serveur.
    vus = set()
    for c in sorted(chemins, key=lambda c: (".venv" not in c, c)):
        nom = os.path.basename(c)
        if nom in vus or (filtre and filtre not in nom) or nom.startswith("index"):
            continue
        vus.add(nom)
        print(c)


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        sys.exit(2)

    def opt(nom, defaut=None, multiple=False):
        v = [a[i + 1] for i, x in enumerate(a) if x == nom and i + 1 < len(a)]
        return v if multiple else (v[-1] if v else defaut)

    try:
        if a[0] == "etat":
            etat()
        elif a[0] == "modeles-workflow":
            modeles_workflow(opt("--filtre", ""))
        elif a[0] == "convertir":
            info = requete("/object_info", delai=120)
            with open(a[1], encoding="utf-8") as f:
                p = convertir(json.load(f), info)
            with open(a[2], "w", encoding="utf-8") as f:
                json.dump(p, f, ensure_ascii=False, indent=1)
            print("OK %d nœuds → %s" % (len(p), a[2]))
        elif a[0] == "recuperer":
            j = recuperer(a[1], opt("--sortie", "sorties_comfyui"))
            sys.exit(0 if j["statut"] == "success" else 1)
        elif a[0] == "executer":
            j = executer(a[1], opt("--sortie", "sorties_comfyui"), opt("--image"), opt("--noeud-image"),
                         opt("--param", multiple=True), int(opt("--delai", "7200")), "--interrompre" in a)
            sys.exit(0 if j["statut"] == "success" else 1)
        else:
            print(__doc__)
            sys.exit(2)
    except urllib.error.URLError as e:
        raise SystemExit("ERREUR serveur ComfyUI injoignable (%s) : lancer ComfyUI ou régler COMFYUI_URL" % e)


if __name__ == "__main__":
    main()
