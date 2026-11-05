extends SceneTree
## Screenshot dell'interfaccia: xvfb-run godot --path . -s res://tests/foto.gd -- <modo> [passi] [ruolo]
## modo: menu | nuova | partita | fine | regole | online
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func shot(nome: String):
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % nome)
	print("shot ", nome)
func _run():
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0] if a.size() > 0 else "menu"
	await shot("menu")
	if modo == "menu":
		quit(); return
	if modo == "regole":
		main._menu_regole(); await shot("regole"); quit(); return
	if modo == "online":
		main._menu_online(); await shot("online"); quit(); return
	main._menu_nuova()
	await shot("nuova")
	if modo == "nuova":
		quit(); return
	var ruolo: String = a[2] if a.size() > 2 else "cacciatori"
	main._avvia_locale(ruolo)
	main.velocita = 100.0
	var target := int(a[1]) if a.size() > 1 else 40
	var passi := 0
	var comb := modo == "comb"
	while (passi < target or (comb and (main.m.s["comb"].is_empty() or main.m.s["comb"].get("rivelate", {}).is_empty()))) and not main.m.finita() and passi < 20000:
		var r: Dictionary = main.m.richiesta()
		var id: String = main.ia.decidi(r)
		if main.io(r["g"]):
			main._decidi(id)
		else:
			main.m.applica({"id": id})
		passi += 1
	main._aggiorna_tutto()
	for i in 20: await process_frame
	main.richiesta_mostrata = -1
	await shot("partita")
	if modo == "fine":
		while not main.m.finita() and passi < 20000:
			var r2: Dictionary = main.m.richiesta()
			main.m.applica({"id": main.ia.decidi(r2)})
			passi += 1
		main._aggiorna_tutto()
		for i in 30: await process_frame
		await shot("fine")
	quit()
