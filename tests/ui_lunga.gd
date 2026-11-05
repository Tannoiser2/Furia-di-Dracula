extends SceneTree
## Partita intera passando dall'interfaccia (aggiornamento a ogni decisione) per scovare errori di visualizzazione.
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func _run():
	var a := OS.get_cmdline_user_args()
	var ruolo: String = a[0] if a.size() > 0 else "cacciatori"
	for partita in 2:
		main._avvia_locale(ruolo)
		var n := 0
		while not main.m.finita() and n < 3000:
			var r: Dictionary = main.m.richiesta()
			var id: String = main.ia.decidi(r)
			if main.io(r["g"]):
				main._mostra_richiesta(r)
				await main._decidi(id)
			else:
				main.m.applica({"id": id})
				main._aggiorna_tutto()
			n += 1
			if n % 25 == 0:
				await process_frame
		print("partita ", partita, " passi ", n, " esito ", main.m.s["esito"].get("vince", "?"))
	quit()
