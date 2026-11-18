#!/usr/bin/env python3
"""Audit d'un fichier glTF 2.0 (.glb ou .gltf) sans dépendance : triangles, matériaux, textures, squelettes,
animations, et alertes de budget.

Usage :
    python3 audit_glb.py modele.glb [--max-triangles 10000] [--max-texture 2048] [--max-materiaux 4] [--strict]
    python3 audit_glb.py --json modele.glb

--strict : code de sortie 1 si une alerte est levée (pour un contrôle automatique).
Code 2 : fichier illisible ou structure invalide. Les modes 4/5/6 sont comptés d'après les accessors,
indices s'ils existent, sinon POSITION ; les triangles dégénérés restent inclus (budget conservateur).
Les autres modes et les comptes invalides rendent le total partiel et lèvent une alerte.
"""
import argparse
import json
import os
import struct
import sys


def lire(chemin):
    with open(chemin, "rb") as f:
        donnees = f.read()
    if donnees[:4] == b"glTF":
        if len(donnees) < 20:
            raise ValueError("En-tête GLB tronqué")
        _, version, longueur = struct.unpack_from("<4sII", donnees)
        if version != 2 or longueur != len(donnees):
            raise ValueError("Version ou longueur GLB invalide (GLB 2.0 attendu)")
        gltf = None
        binaire = b""
        binaire_lu = False
        decalage = 12
        while decalage < longueur:
            if decalage + 8 > longueur:
                raise ValueError("En-tête de chunk GLB tronqué")
            taille, type_chunk = struct.unpack_from("<I4s", donnees, decalage)
            fin = decalage + 8 + taille
            if taille % 4 or fin > longueur:
                raise ValueError("Longueur de chunk GLB invalide")
            contenu = donnees[decalage + 8:fin]
            if decalage == 12 and type_chunk != b"JSON":
                raise ValueError("Le premier chunk GLB doit être JSON")
            if type_chunk == b"JSON":
                if decalage != 12:
                    raise ValueError("Chunk JSON GLB dupliqué")
                gltf = json.loads(contenu.decode("utf-8"))
            elif type_chunk == b"BIN\x00":
                if binaire_lu:
                    raise ValueError("Chunk BIN GLB dupliqué")
                binaire, binaire_lu = contenu, True
            decalage = fin
    else:
        gltf, binaire = json.loads(donnees.decode("utf-8")), b""
    if not isinstance(gltf, dict) or not isinstance(gltf.get("asset"), dict) or \
            gltf["asset"].get("version") != "2.0":
        raise ValueError("Document glTF 2.0 attendu (asset.version)")
    return gltf, binaire


def compter_triangles(primitive, acc):
    """Compte les triangles assemblés, sans décoder les buffers ni retirer les dégénérescences."""
    if not isinstance(primitive, dict):
        raise ValueError("Primitive invalide (objet attendu)")
    mode = primitive.get("mode", 4)
    if type(mode) is not int or mode not in range(7):
        raise ValueError("Mode de primitive invalide : %r" % mode)
    if mode not in (4, 5, 6):
        raise ValueError("Mode de primitive non pris en charge : %d (seuls 4/5/6 sont comptés)" % mode)
    attributs = primitive.get("attributes", {})
    if not isinstance(attributs, dict) or "POSITION" not in attributs:
        raise ValueError("Attribut POSITION manquant ou invalide")
    comptes = {}
    for role, reference in [("POSITION", attributs["POSITION"])] + (
            [("indices", primitive["indices"])] if "indices" in primitive else []):
        if type(reference) is not int or not 0 <= reference < len(acc):
            raise ValueError("Référence accessor %s invalide : %r" % (role, reference))
        accessor = acc[reference]
        compte = accessor.get("count") if isinstance(accessor, dict) else None
        if type(compte) is not int or compte < 1:
            raise ValueError("Compte accessor %s invalide : %r" % (role, compte))
        comptes[role] = compte
    compte = comptes.get("indices", comptes["POSITION"])
    if compte < 3 or (mode == 4 and compte % 3):
        raise ValueError("Compte %d incompatible avec le mode %d" % (compte, mode))
    return compte // 3 if mode == 4 else compte - 2


def taille_image(octets):
    """Largeur, hauteur d'un PNG ou d'un JPEG (en-tête seulement)."""
    if octets[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", octets[16:24])
    if octets[:2] == b"\xff\xd8":
        i = 2
        while i < len(octets) - 9:
            if octets[i] != 0xFF:
                i += 1
                continue
            marqueur = octets[i + 1]
            longueur = struct.unpack(">H", octets[i + 2:i + 4])[0]
            if marqueur in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", octets[i + 5:i + 9])
                return w, h
            i += 2 + longueur
    return None


def auditer(chemin, max_tri=None, max_tex=None, max_mat=None):
    gltf, binaire = lire(chemin)
    acc = gltf.get("accessors", [])
    vues = gltf.get("bufferViews", [])
    r = {"fichier": chemin, "taille_octets": os.path.getsize(chemin),
         "generateur": gltf.get("asset", {}).get("generator"), "maillages": [], "triangles": 0,
         "materiaux": [m.get("name") for m in gltf.get("materials", [])], "textures": [],
         "squelettes": [], "animations": [], "alertes": [], "infos": [], "comptage_complet": True}
    noms_noeuds = {}
    for i, n in enumerate(gltf.get("nodes", [])):
        noms_noeuds[i] = n.get("name", "noeud_%d" % i)
    for i, n in enumerate(gltf.get("nodes", [])):
        if "mesh" not in n:
            continue
        m = gltf["meshes"][n["mesh"]]
        tri = 0
        for numero, p in enumerate(m.get("primitives", [])):
            try:
                tri += compter_triangles(p, acc)
            except ValueError as erreur:
                r["comptage_complet"] = False
                r["alertes"].append("%s, primitive %d : %s ; total de triangles partiel"
                                    % (noms_noeuds[i], numero, erreur))
        sommets = 0
        for p in m.get("primitives", []):
            ref = (p.get("attributes") or {}).get("POSITION") if isinstance(p, dict) else None
            if type(ref) is int and 0 <= ref < len(acc) and isinstance(acc[ref], dict) \
                    and type(acc[ref].get("count")) is int and acc[ref]["count"] > 0:
                sommets += acc[ref]["count"]
        r["maillages"].append({"noeud": n.get("name"), "triangles": tri, "sommets": sommets, "skin": "skin" in n})
        r["triangles"] += tri
        # Un maillage ordinaire a ~0,5 à 3 sommets par triangle ; bien plus = faces manquantes (fichier abîmé,
        # ex. sortie image→3D tronquée) ou sommets inutilisés.
        if tri and sommets > tri * 6:
            r["alertes"].append("%s : %d sommets pour %d triangles — faces manquantes ou sommets inutilisés"
                                % (noms_noeuds[i], sommets, tri))
    for i, img in enumerate(gltf.get("images", [])):
        e = {"nom": img.get("name") or img.get("uri") or "image_%d" % i, "type": img.get("mimeType")}
        if "bufferView" in img and binaire:
            v = vues[img["bufferView"]]
            octets = binaire[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
            e["octets"] = len(octets)
            t = taille_image(octets)
            if t:
                e["dimensions"] = list(t)
        elif img.get("uri") and not img["uri"].startswith("data:"):
            e["externe"] = img["uri"]
        r["textures"].append(e)
    for s in gltf.get("skins", []):
        r["squelettes"].append({"os": len(s["joints"]), "noms": [noms_noeuds[j] for j in s["joints"]]})
    for a in gltf.get("animations", []):
        duree = 0.0
        for s in a.get("samplers", []):
            mx = acc[s["input"]].get("max")
            if mx:
                duree = max(duree, mx[0])
        r["animations"].append({"nom": a.get("name"), "duree_s": round(duree, 3), "canaux": len(a.get("channels", [])),
                                "boucle_godot": (a.get("name") or "").endswith("_loop")})
    # Alertes
    if max_tri is not None and r["triangles"] > max_tri:
        r["alertes"].append("Triangles : %d > budget %d" % (r["triangles"], max_tri))
    if max_mat and len(r["materiaux"]) > max_mat:
        r["alertes"].append("Matériaux : %d > budget %d" % (len(r["materiaux"]), max_mat))
    for t in r["textures"]:
        d = t.get("dimensions")
        if d and max_tex and max(d) > max_tex:
            r["alertes"].append("Texture %s : %dx%d > %d px" % (t["nom"], d[0], d[1], max_tex))
        if d and any(x & (x - 1) for x in d):
            r["infos"].append("Texture %s : dimensions non puissances de 2 (%dx%d)" % (t["nom"], d[0], d[1]))
    for s in r["squelettes"]:
        if s["os"] > 64:
            r["alertes"].append("Squelette de %d os (beaucoup pour une unité de jeu)" % s["os"])
    return r


def main():
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument("fichiers", nargs="+")
    analyseur.add_argument("--max-triangles", type=int)
    analyseur.add_argument("--max-texture", type=int)
    analyseur.add_argument("--max-materiaux", type=int)
    analyseur.add_argument("--json", action="store_true")
    analyseur.add_argument("--strict", action="store_true")
    args = analyseur.parse_intermixed_args()
    code = 0
    for f in args.fichiers:
        try:
            r = auditer(f, args.max_triangles, args.max_texture, args.max_materiaux)
        except (OSError, ValueError, KeyError, IndexError, TypeError, AttributeError, struct.error) as erreur:
            if args.json:
                print(json.dumps({"fichier": f, "erreur": str(erreur)}, ensure_ascii=False))
            else:
                print("ERREUR %s : %s" % (f, erreur), file=sys.stderr)
            code = 2
            continue
        if args.json:
            print(json.dumps(r, ensure_ascii=False, indent=2))
        else:
            print("== %s (%.1f Mo, %s)" % (f, r["taille_octets"] / 1e6, r["generateur"]))
            print("  Triangles : %d dans %d maillage(s)%s" % (
                r["triangles"], len(r["maillages"]), "" if r["comptage_complet"] else " (total partiel)"))
            for m in r["maillages"]:
                print("    - %-28s %6d%s" % (m["noeud"], m["triangles"], "  (skinné)" if m["skin"] else ""))
            print("  Matériaux : %s" % r["materiaux"])
            for t in r["textures"]:
                print("  Texture : %s %s %s" % (t["nom"], t.get("dimensions", ""), t.get("type") or t.get("externe", "")))
            for s in r["squelettes"]:
                print("  Squelette : %d os" % s["os"])
            for a in r["animations"]:
                print("  Animation : %-36s %.2f s  %d canaux%s" % (a["nom"], a["duree_s"], a["canaux"],
                      "  (boucle)" if a["boucle_godot"] else ""))
            for i in r["infos"]:
                print("  INFO " + i)
            for al in r["alertes"]:
                print("  ALERTE " + al)
            if not r["alertes"]:
                print("  OK aucune alerte")
        if r["alertes"] and args.strict:
            code = max(code, 1)
    sys.exit(code)


if __name__ == "__main__":
    main()
