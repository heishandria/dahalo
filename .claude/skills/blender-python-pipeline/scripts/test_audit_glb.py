#!/usr/bin/env python3
"""Tests hors ligne : vrais octets JSON/GLB, fichiers simulés en mémoire, aucune dépendance externe.

Usage : python3 -B .claude/skills/blender-python-pipeline/scripts/test_audit_glb.py
"""
import contextlib
import io
import json
import os
import struct
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_glb  # noqa: E402


def document(mode=4, compte=6, indexe=True):
    attributs = {"POSITION": 0}
    accessors = [{"count": 3 if indexe else compte, "type": "VEC3", "componentType": 5126}]
    primitive = {"attributes": attributs}
    if mode is not None:
        primitive["mode"] = mode
    if indexe:
        primitive["indices"] = 1
        accessors.append({"count": compte, "type": "SCALAR", "componentType": 5123})
    return {
        "asset": {"version": "2.0"},
        "accessors": accessors,
        "nodes": [{"mesh": 0, "name": "essai"}],
        "meshes": [{"primitives": [primitive]}],
    }


def chunk(type_chunk, contenu):
    remplissage = b" " if type_chunk == b"JSON" else b"\x00"
    contenu += remplissage * (-len(contenu) % 4)
    return struct.pack("<I4s", len(contenu), type_chunk) + contenu


def glb(*chunks):
    contenu = b"".join(chunks)
    return struct.pack("<4sII", b"glTF", 2, 12 + len(contenu)) + contenu


def encoder(gltf, binaire=False):
    contenu = json.dumps(gltf).encode("utf-8")
    return glb(chunk(b"JSON", contenu)) if binaire else contenu


@contextlib.contextmanager
def fichiers_memoire(fichiers):
    def ouvrir(chemin, mode):
        if chemin not in fichiers:
            raise FileNotFoundError("Fichier introuvable : " + chemin)
        return io.BytesIO(fichiers[chemin])

    with patch("builtins.open", side_effect=ouvrir), \
            patch.object(audit_glb.os.path, "getsize", side_effect=lambda p: len(fichiers[p])):
        yield


class TestAudit(unittest.TestCase):
    def auditer(self, gltf, binaire=False, **options):
        chemin = "essai.glb" if binaire else "essai.gltf"
        with fichiers_memoire({chemin: encoder(gltf, binaire)}):
            return audit_glb.auditer(chemin, **options)

    def commande(self, fichiers, *arguments):
        sortie, erreurs = io.StringIO(), io.StringIO()
        with fichiers_memoire(fichiers), patch.object(sys, "argv", ["audit_glb.py", *arguments]), \
                contextlib.redirect_stdout(sortie), contextlib.redirect_stderr(erreurs):
            with self.assertRaises(SystemExit) as fin:
                audit_glb.main()
        return fin.exception.code, sortie.getvalue(), erreurs.getvalue()

    def test_triangles_strips_fans_indexes_et_sans_indices(self):
        for binaire in (False, True):
            for indexe in (False, True):
                for mode, attendu in ((None, 2), (4, 2), (5, 4), (6, 4)):
                    with self.subTest(glb=binaire, indexe=indexe, mode=mode):
                        resultat = self.auditer(document(mode, indexe=indexe), binaire)
                        self.assertEqual(resultat["triangles"], attendu)
                        self.assertEqual(resultat["maillages"][0]["triangles"], attendu)
                        self.assertTrue(resultat["comptage_complet"])
                        self.assertEqual(resultat["alertes"], [])
                        self.assertEqual(resultat["infos"], [])

    def test_un_triangle_minimal(self):
        for mode in (4, 5, 6):
            self.assertEqual(self.auditer(document(mode, 3))["triangles"], 1)

    def test_plusieurs_primitives_et_instances(self):
        gltf = document(4)
        gltf["meshes"][0]["primitives"] += [
            {"mode": 5, "indices": 1, "attributes": {"POSITION": 0}},
            {"mode": 6, "attributes": {"POSITION": 0}},
        ]
        gltf["nodes"].append({"mesh": 0, "name": "instance"})
        resultat = self.auditer(gltf)
        self.assertEqual([m["triangles"] for m in resultat["maillages"]], [7, 7])
        self.assertEqual(resultat["triangles"], 14)

    def test_modes_non_supportes_et_invalides_bloquent_strict(self):
        for mode in (0, 1, 2, 3, -1, 7, "4", 4.0, True, [], {}, None):
            with self.subTest(mode=mode):
                gltf = document(mode)
                gltf["meshes"][0]["primitives"][0]["mode"] = mode
                resultat = self.auditer(gltf)
                self.assertEqual(resultat["triangles"], 0)
                self.assertFalse(resultat["comptage_complet"])
                self.assertIn("Mode de primitive", resultat["alertes"][0])
                self.assertIn("essai, primitive 0", resultat["alertes"][0])
                code, sortie, _ = self.commande(
                    {"essai.glb": encoder(gltf, True)}, "--strict", "essai.glb")
                self.assertEqual(code, 1)
                self.assertIn("total partiel", sortie)
                self.assertNotIn("OK aucune alerte", sortie)

    def test_comptes_invalides_et_incomplets(self):
        for mode in (4, 5, 6):
            for compte in (0, 1, 2, -3, 6.0, True, "6", None):
                for indexe in (False, True):
                    with self.subTest(mode=mode, compte=compte, indexe=indexe):
                        resultat = self.auditer(document(mode, compte, indexe))
                        self.assertFalse(resultat["comptage_complet"])
                        self.assertTrue(resultat["alertes"])
                        self.assertEqual(resultat["triangles"], 0)
        resultat = self.auditer(document(4, 5))
        self.assertIn("incompatible", resultat["alertes"][0])
        code, _, _ = self.commande(
            {"essai.gltf": encoder(document(4, 5))}, "--strict", "essai.gltf")
        self.assertEqual(code, 1)

    def test_accessors_invalides(self):
        for role in ("indices", "POSITION"):
            for reference in (-1, 2, True, "0", None):
                with self.subTest(role=role, reference=reference):
                    gltf = document()
                    primitive = gltf["meshes"][0]["primitives"][0]
                    cible = primitive if role == "indices" else primitive["attributes"]
                    cible[role] = reference
                    resultat = self.auditer(gltf)
                    self.assertFalse(resultat["comptage_complet"])
                    self.assertIn("Référence accessor", resultat["alertes"][0])
        gltf = document()
        gltf["meshes"][0]["primitives"][0]["attributes"] = {}
        self.assertIn("POSITION", self.auditer(gltf)["alertes"][0])

    def test_total_partiel_garde_les_primitives_connues(self):
        gltf = document(5)
        gltf["meshes"][0]["primitives"].append({"mode": 1})
        resultat = self.auditer(gltf)
        self.assertEqual(resultat["triangles"], 4)
        self.assertFalse(resultat["comptage_complet"])

    def test_budget_strict_et_sortie_json(self):
        for mode in (4, 5, 6):
            for binaire in (False, True):
                with self.subTest(mode=mode, glb=binaire):
                    fichiers = {"essai": encoder(document(mode), binaire)}
                    budget = 1 if mode == 4 else 3
                    code, sortie, _ = self.commande(
                        fichiers, "--json", "--strict", "--max-triangles", str(budget), "essai")
                    self.assertEqual(code, 1)
                    self.assertIn("budget", json.loads(sortie)["alertes"][0])
                    self.assertEqual(self.commande(fichiers, "--strict", "essai")[0], 0)
                    self.assertEqual(self.commande(fichiers, "essai", "--strict", "essai")[0], 0)
                    self.assertEqual(self.commande(
                        fichiers, "--strict", "--max-triangles", "0", "essai")[0], 1)

    def test_avertissement_sans_strict(self):
        code, sortie, _ = self.commande({"essai": encoder(document(1))}, "essai")
        self.assertEqual(code, 0)
        self.assertIn("ALERTE", sortie)
        self.assertNotIn("OK aucune alerte", sortie)

    def test_glb_bin_et_chunk_inconnu(self):
        contenu = json.dumps(document()).encode("utf-8")
        donnees = glb(chunk(b"JSON", contenu), chunk(b"TEST", b"ignorer"),
                      chunk(b"BIN\x00", b"\x01\x02\x03\x04"))
        with fichiers_memoire({"essai": donnees}):
            gltf, binaire = audit_glb.lire("essai")
        self.assertEqual(gltf, document())
        self.assertEqual(binaire, b"\x01\x02\x03\x04")

    def test_texture_embarquee_apres_lecture_glb(self):
        gltf = document()
        entete_png = b"\x89PNG\r\n\x1a\n" + struct.pack(">I4sII", 13, b"IHDR", 4096, 2048)
        gltf["buffers"] = [{"byteLength": len(entete_png)}]
        gltf["bufferViews"] = [{"buffer": 0, "byteLength": len(entete_png)}]
        gltf["images"] = [{"name": "texture", "mimeType": "image/png", "bufferView": 0}]
        donnees = glb(chunk(b"JSON", json.dumps(gltf).encode("utf-8")), chunk(b"BIN\x00", entete_png))
        with fichiers_memoire({"essai.glb": donnees}):
            resultat = audit_glb.auditer("essai.glb", max_tex=2048)
        self.assertEqual(resultat["textures"][0]["dimensions"], [4096, 2048])
        self.assertIn("Texture texture", resultat["alertes"][0])

    def test_fichiers_invalides_code_2_sans_traceback(self):
        valide = encoder(document(), True)
        json_chunk = chunk(b"JSON", json.dumps(document()).encode("utf-8"))
        cas = [
            b"glTF", valide[:-1], b"{", b"[]", b"\xff",
            b'{"asset":{"version":"1.0"}}',
            valide[:4] + struct.pack("<I", 1) + valide[8:],
            glb(chunk(b"BIN\x00", b"abcd")),
            glb(json_chunk, json_chunk),
            glb(chunk(b"JSON", b"null"), json_chunk),
            glb(json_chunk, chunk(b"BIN\x00", b""), chunk(b"BIN\x00", b"")),
            glb(json_chunk, b"abcd"),
            glb(struct.pack("<I4s", 999, b"JSON") + b"{}"),
        ]
        for numero, donnees in enumerate(cas):
            with self.subTest(cas=numero):
                code, sortie, erreurs = self.commande({"essai": donnees}, "--json", "essai")
                self.assertEqual(code, 2)
                self.assertIn("erreur", json.loads(sortie))
                self.assertNotIn("Traceback", erreurs)

    def test_erreur_fichier_prioritaire_sur_alerte(self):
        fichiers = {"alerte": encoder(document(1))}
        for chemins in (("absent", "alerte"), ("alerte", "absent")):
            code, _, erreurs = self.commande(fichiers, "--strict", *chemins)
            self.assertEqual(code, 2)
            self.assertIn("ERREUR absent", erreurs)

    def test_arguments_invalides(self):
        for arguments in ((), ("--strict",), ("--inconnu", "essai"), ("--max-triangles", "abc", "essai")):
            self.assertEqual(self.commande({}, *arguments)[0], 2)


if __name__ == "__main__":
    unittest.main()
