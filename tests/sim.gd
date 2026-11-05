extends SceneTree
## Partite automatiche tutte IA: controlla che finiscano e conta chi vince.
## godot --headless --path . -s res://tests/sim.gd -- [partite] [dettagli]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 20
	var dettagli := args.size() > 1
	var esiti := {}
	var tot_passi := 0
	var tot_giorni := 0
	var inf := 0
	var dan := 0
	var ki := {}
	for p in n:
		var mo := Motore.new()
		mo.nuova({"seat": [-1, -1, -1, -1, -1], "seed": p * 101 + 7})
		var ia := IA.new(mo)
		var passi := 0
		while not mo.finita() and passi < 30000:
			var rq := mo.richiesta()
			if rq.is_empty():
				push_error("nessuna richiesta ma partita non finita")
				break
			var id := ia.decidi(rq)
			ki[rq["k"]] = int(ki.get(rq["k"], 0)) + 1
			if not mo.applica({"id": id}):
				push_error("decisione rifiutata %s %s" % [rq["k"], id])
				break
			passi += 1
			if OS.get_environment("DBG") != "" and passi % 300 == 0:
				print(passi, " ", rq["k"], " ", id, " giorno ", mo.s["giorno"], " inf ", mo.s["influenza"], " dr ", mo.s["dr"]["danni"])
		tot_passi += passi
		tot_giorni += int(mo.s["giorno"])
		inf += int(mo.s["influenza"])
		dan += int(mo.s["dr"]["danni"])
		var v: String = mo.s["esito"].get("vince", "NON FINITA")
		esiti[v] = esiti.get(v, 0) + 1
		if p < 3 or v == "NON FINITA" or dettagli:
			print("partita %d: %s, passi %d, giorni %d, influenza %d, danni Dracula %d | %s" % [p, v, passi, mo.s["giorno"], mo.s["influenza"], mo.s["dr"]["danni"], mo.s["esito"].get("testo", "")])
			if v == "NON FINITA" or dettagli:
				print(mo.richiesta())
				for l in mo.s["log"].slice(-40):
					print("   ", l)
	print("ESITI ", esiti, " passi medi ", tot_passi / n, " giorni medi ", float(tot_giorni) / n, " influenza media ", float(inf) / n, " danni Dracula medi ", float(dan) / n)
	print("decisioni: ", ki)
	quit()
