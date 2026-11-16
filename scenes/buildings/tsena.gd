extends Batiment
## Tsena : le marché du clan. Vente de zébus contre des Ariary, achat de bois et de nourriture.
## Spec : docs/specs/economie.md (§ Tsena)


func commercer(action: String) -> void:
	match action:
		"vendre_zebu":
			_vendre_zebu()
		"acheter_bois":
			_acheter("bois")
		"acheter_nourriture":
			_acheter("nourriture")


func _vendre_zebu() -> void:
	# On vend en priorité un zébu « en règle » : un zébu volé récemment rapporte beaucoup moins.
	var candidat = null
	for z in get_tree().get_nodes_in_group("zebus"):
		if z.etat != Zebu.Etat.ENCLOS or z.proprietaire != faction:
			continue
		if candidat == null or (candidat.est_vole_recemment() and not z.est_vole_recemment()):
			candidat = z
	if candidat == null:
		_message("Aucun zébu dans vos enclos à vendre.")
		return
	var prix := GameRules.prix_zebu_actuel(candidat.est_vole_recemment())
	var decote: bool = candidat.est_vole_recemment()
	ResourceManager.zebu_perdu(faction)
	candidat.queue_free()
	ResourceManager.ajouter(faction, "ariary", prix)
	if decote:
		_message("Zébu volé vendu au rabais : %d Ar. Les marchands se méfient." % int(prix))
	else:
		_message("Zébu vendu au Tsena : %d Ar." % int(prix))


func _acheter(ressource: String) -> void:
	var offre: Dictionary = GameRules.ACHATS[ressource]
	if not ResourceManager.payer(faction, {"ariary": offre["prix"]}):
		_message("Pas assez d'Ariary (%d Ar)." % int(offre["prix"]))
		return
	ResourceManager.ajouter(faction, ressource, offre["quantite"])
	_message("Acheté : %d %s." % [int(offre["quantite"]), ressource])

