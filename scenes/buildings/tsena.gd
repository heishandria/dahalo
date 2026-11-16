extends Batiment
## Tsena : le marché du clan. Vente de zébus et de surplus contre des Ariary, achat de bois et de nourriture.
## Spec : docs/specs/economie.md (§ Tsena)


func commercer(action: String) -> void:
	match action:
		"vendre_zebu":
			_vendre_zebu()
		"vendre_bois":
			_vendre_surplus("bois")
		"vendre_nourriture":
			_vendre_surplus("nourriture")
		"acheter_bois":
			_acheter("bois")
		"acheter_nourriture":
			_acheter("nourriture")
		"acheter_zebu":
			_acheter_zebu()


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
	var prix := GameRules.prix_zebu_actuel(candidat.est_vole_recemment(), faction)
	var decote: bool = candidat.est_vole_recemment()
	ResourceManager.zebu_perdu(faction)
	candidat.queue_free()
	ResourceManager.ajouter(faction, "ariary", prix)
	if decote:
		_message("Zébu volé vendu au rabais : %d Ar. Les marchands se méfient." % int(prix))
	else:
		_message("Zébu vendu au Tsena : %d Ar." % int(prix))


func _vendre_surplus(ressource: String) -> void:
	var offre: Dictionary = GameRules.VENTES[ressource]
	if not ResourceManager.payer(faction, {ressource: offre["quantite"]}):
		_message("Pas assez de %s à vendre (%d)." % [ressource, int(offre["quantite"])])
		return
	var prix := GameRules.prix_vente_surplus(faction, float(offre["prix"]))
	ResourceManager.ajouter(faction, "ariary", prix)
	_message("Vendu : %d %s pour %d Ar." % [int(offre["quantite"]), ressource, int(prix)])


func _acheter(ressource: String) -> void:
	var offre: Dictionary = GameRules.ACHATS[ressource]
	var prix := GameRules.prix_achat(faction, float(offre["prix"]))
	if not ResourceManager.payer(faction, {"ariary": prix}):
		_message("Pas assez d'Ariary (%d Ar)." % int(prix))
		return
	ResourceManager.ajouter(faction, ressource, offre["quantite"])
	_message("Acheté : %d %s." % [int(offre["quantite"]), ressource])


## Maîtres du Tsena (Âge 3) : achat d'un zébu reproducteur, livré dans un enclos.
func _acheter_zebu() -> void:
	if not ResourceManager.a_technologie(faction, "maitres_tsena"):
		_message("Il faut la technologie « Maîtres du Tsena » (Âge 3).")
		return
	if not ResourceManager.a_place(faction):
		_message("Enclos pleins : construisez un enclos d'abord.")
		return
	var enclos = null
	for e in get_tree().get_nodes_in_group("enclos"):
		if e.faction == faction:
			enclos = e
			break
	if enclos == null or CommandBus.monde == null:
		return
	if not ResourceManager.payer(faction, {"ariary": GameRules.PRIX_ZEBU_REPRODUCTEUR}):
		_message("Pas assez d'Ariary (%d Ar)." % int(GameRules.PRIX_ZEBU_REPRODUCTEUR))
		return
	var zebu = CommandBus.monde.creer_zebu(enclos.global_position, enclos.global_position)
	zebu.securiser(enclos)
	_message("Zébu reproducteur acheté et livré à l'enclos.")

