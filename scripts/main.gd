## Interfaccia di La Furia di Dracula: menu, partita contro l'IA, online con Firebase, salvataggi.
extends Node

const F_TITOLO := preload("res://assets/font/Cinzel-Bold.ttf")
const F_TITOLO_R := preload("res://assets/font/Cinzel-Regular.ttf")
const F_TESTO := preload("res://assets/font/EBGaramond-Regular.ttf")
const F_GRASSETTO := preload("res://assets/font/EBGaramond-SemiBold.ttf")
const F_CORSIVO := preload("res://assets/font/EBGaramond-Italic.ttf")
const F_FELL := preload("res://assets/font/IMFellEnglishSC.ttf")
const F_GOTICO := preload("res://assets/font/PirataOne.ttf")

const C_FONDO := Color(0.07, 0.03, 0.03, 0.94)
const C_PERG := Color(0.93, 0.86, 0.7)
const C_ORO := Color(0.86, 0.7, 0.38)
const C_SANGUE := Color(0.62, 0.05, 0.05)
const C_SANGUE_V := Color(0.85, 0.12, 0.1)
const C_TESTO := Color(0.95, 0.9, 0.8)
const C_SPENTO := Color(0.66, 0.58, 0.5)
const C_LEGNO := Color(0.22, 0.12, 0.07)
const SALVA_LOCALE := "user://partita_furiadracula.json"
const SEGRETO := "user://impostazioni_furiadracula.cfg"

var ui: CanvasLayer
var schermo: Control
var net: Rete
var m: Motore
var ia: IA
var mappa: Mappa

var in_partita := false
var online := false
var codice := ""
var mio_posto := 0
var nomi_posti := {}
var attesa := 0.0
var velocita := 1.0
var richiesta_mostrata := -1
var aspetto_rete := false
var ultimo_log := 0
var salvataggio_in_corso := false
var ultimo_salvataggio := 0.0
var ultimo_evento_visto := -1
var ultimo_round_visto := ""
var mostra_segreti := false

# widget della partita
var top_tempo: Label
var top_influenza: Label
var top_barra_inf: HBoxContainer
var top_dracula: Label
var top_extra: Label
var col_cacciatori: VBoxContainer
var box_percorso: HBoxContainer
var box_tane: HBoxContainer
var lbl_percorso: Label
var pannello_rich: VBoxContainer
var titolo_rich: Label
var opz_box: VBoxContainer
var mano_box: HBoxContainer
var mano_titolo: Label
var diario: RichTextLabel
var comb_panel: PanelContainer
var comb_box: VBoxContainer
var popup: Control
var notifica: PanelContainer
var mano_di := -1

func _ready() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	schermo = Control.new()
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(schermo)
	net = Rete.new()
	add_child(net)
	var tema := Theme.new()
	tema.default_font = F_TESTO
	tema.default_font_size = 18
	schermo.theme = tema
	mostra_menu()

# ============================================================ elementi grafici

func stile(bg: Color, bordo := Color(0, 0, 0, 0), spessore := 0, raggio := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func etichetta(testo: String, font: Font = F_TESTO, size := 18, col := C_TESTO) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func bottone(testo: String, cb: Callable, col := Color(0.32, 0.08, 0.06), size := 18) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_override("font", F_GRASSETTO)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", C_TESTO)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))
	b.add_theme_stylebox_override("normal", stile(col, C_ORO.darkened(0.3), 1, 5))
	b.add_theme_stylebox_override("hover", stile(col.lightened(0.15), C_ORO, 2, 5))
	b.add_theme_stylebox_override("pressed", stile(col.darkened(0.2), C_ORO, 2, 5))
	b.add_theme_stylebox_override("disabled", stile(Color(0.2, 0.17, 0.15), Color(0.3, 0.25, 0.2), 1, 5))
	b.pressed.connect(cb)
	return b

func pannello(bg := C_FONDO, bordo := Color(0.55, 0.38, 0.18, 0.8)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(bg, bordo, 2, 8))
	return p

func immagine(path: String, w: float, h: float) -> TextureRect:
	var t := TextureRect.new()
	if path != "" and ResourceLoader.exists(path):
		t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(w, h)
	return t

## Una carta cliccabile (si ingrandisce).
func carta(path: String, w := 70.0, didascalia := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var im := immagine(path, w, w * 1.56)
	im.mouse_filter = Control.MOUSE_FILTER_STOP
	im.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_ingrandisci(path, didascalia))
	im.tooltip_text = didascalia
	v.add_child(im)
	if didascalia != "":
		var l := etichetta(didascalia, F_TESTO, 12, C_SPENTO)
		l.custom_minimum_size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return v

func _ingrandisci(path: String, testo: String) -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = ColorRect.new()
	(popup as ColorRect).color = Color(0, 0, 0, 0.7)
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	schermo.add_child(popup)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(cc)
	var v := VBoxContainer.new()
	cc.add_child(v)
	var h: float = min(schermo.size.y * 0.75, 640.0)
	v.add_child(immagine(path, h / 1.56, h))
	if testo != "":
		var l := etichetta(testo, F_GRASSETTO, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var chiudi := etichetta("(tocca per chiudere)", F_CORSIVO, 15, C_SPENTO)
	chiudi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(chiudi)
	popup.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			popup.queue_free())

func _ingrandisci_scheda(path: String) -> void:
	_ingrandisci(path, "")
	var im := popup.find_children("*", "TextureRect", true, false)
	if not im.is_empty():
		var h: float = min(schermo.size.y * 0.7, 560.0)
		(im[0] as TextureRect).custom_minimum_size = Vector2(h * 1.25, h)

func pulisci() -> void:
	for c in schermo.get_children():
		c.queue_free()
	in_partita = false

func _sfondo() -> void:
	var t := TextureRect.new()
	t.texture = load("res://assets/tabellone.webp")
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.modulate = Color(0.35, 0.22, 0.2)
	schermo.add_child(t)
	var vel := ColorRect.new()
	vel.color = Color(0.08, 0.0, 0.0, 0.35)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(vel)

func _riquadro(w: float, h: float) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(cc)
	var p := pannello(Color(0.08, 0.03, 0.03, 0.93))
	p.custom_minimum_size = Vector2(min(w, schermo.size.x - 20), min(h, schermo.size.y - 20))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v

# ============================================================ menu

func mostra_menu() -> void:
	pulisci()
	online = false
	_sfondo()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(cc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	cc.add_child(h)
	var ritratto := immagine("res://assets/ui/copertina.webp", 420, 420)
	h.add_child(ritratto)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var t := etichetta("La Furia", F_GOTICO, 76, C_SANGUE_V)
	v.add_child(t)
	var t2 := etichetta("di Dracula", F_GOTICO, 64, C_PERG)
	v.add_child(t2)
	v.add_child(etichetta("Caccia al Conte attraverso l'Europa del 1898", F_CORSIVO, 22, C_ORO))
	var esiste := FileAccess.file_exists(SALVA_LOCALE)
	v.add_child(bottone("NUOVA PARTITA", _menu_nuova, Color(0.4, 0.06, 0.05), 24))
	var bc := bottone("CONTINUA LA PARTITA", _menu_continua, Color(0.28, 0.14, 0.06), 20)
	bc.disabled = not esiste
	v.add_child(bc)
	v.add_child(bottone("GIOCA ONLINE CON GLI AMICI", _menu_online, Color(0.14, 0.12, 0.22), 20))
	v.add_child(bottone("COME SI GIOCA", _menu_regole, Color(0.2, 0.16, 0.1), 18))
	v.add_child(etichetta("Versione digitale non ufficiale, per uso personale.\nGrafica: La Furia di Dracula, terza edizione (Fantasy Flight Games / Asmodee Italia).", F_TESTO, 14, C_SPENTO))

var scelta_ruolo := "cacciatori"

func _menu_nuova() -> void:
	pulisci()
	_sfondo()
	var v := _riquadro(760, 560)
	v.add_child(etichetta("Nuova partita", F_TITOLO, 34, C_ORO))
	v.add_child(etichetta("Scegli da che parte stai. Gli altri ruoli li guida l'intelligenza artificiale.", F_CORSIVO, 19, C_SPENTO))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for ruolo in ["cacciatori", "dracula"]:
		var b := VBoxContainer.new()
		var img := "res://assets/carte/personaggi/vanhelsing.webp" if ruolo == "cacciatori" else "res://assets/carte/personaggi/dracula.webp"
		var pic := immagine(img, 300, 240)
		b.add_child(pic)
		var testo := "I CACCIATORI\nGuidi Lord Godalming, il Dr. Seward, Van Helsing e Mina Harker: dovete scovare e distruggere il Conte." if ruolo == "cacciatori" else "DRACULA\nTi muovi in segreto per l'Europa, semini vampiri e trappole e fai crescere la tua Influenza fino a 13."
		var l := etichetta(testo, F_TESTO, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		b.add_child(l)
		var r: String = ruolo
		var bt := bottone("GIOCA COME " + ("CACCIATORI" if ruolo == "cacciatori" else "DRACULA"), func(): _avvia_locale(r), Color(0.4, 0.06, 0.05) if ruolo == "dracula" else Color(0.18, 0.2, 0.12), 18)
		b.add_child(bt)
		h.add_child(b)
	v.add_child(bottone("INDIETRO", mostra_menu, Color(0.15, 0.12, 0.1)))

func _avvia_locale(ruolo: String) -> void:
	scelta_ruolo = ruolo
	online = false
	mio_posto = 0
	var seed := int(Time.get_unix_time_from_system()) % 1000000
	var seat := [0, 0, 0, 0, -1] if ruolo == "cacciatori" else [-1, -1, -1, -1, 0]
	m = Motore.new()
	m.nuova({"seat": seat, "seed": seed})
	ia = IA.new(m)
	_apri_partita()
	_salva(true)

func _menu_continua() -> void:
	var f := FileAccess.open(SALVA_LOCALE, FileAccess.READ)
	if f == null:
		return
	var st = JSON.parse_string(f.get_as_text())
	f.close()
	if not (st is Dictionary) or not st.has("cacc"):
		_avviso("Il salvataggio non è leggibile.")
		return
	_riprendi(st)

func _riprendi(st: Dictionary) -> void:
	online = false
	mio_posto = 0
	m = Motore.new()
	m.carica(st)
	ia = IA.new(m)
	_apri_partita()

func _avviso(t: String) -> void:
	var p := pannello(Color(0.25, 0.04, 0.03, 0.95), C_ORO)
	p.position = Vector2(schermo.size.x / 2 - 300, 70)
	p.custom_minimum_size = Vector2(600, 0)
	var l := etichetta(t, F_GRASSETTO, 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	schermo.add_child(p)
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())

func _menu_regole() -> void:
	pulisci()
	_sfondo()
	var v := _riquadro(900, 760)
	v.add_child(etichetta("Come si gioca", F_TITOLO, 32, C_ORO))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 560)
	v.add_child(sc)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("normal_font", F_TESTO)
	r.add_theme_font_override("bold_font", F_GRASSETTO)
	r.add_theme_font_override("italics_font", F_CORSIVO)
	r.add_theme_font_size_override("normal_font_size", 18)
	r.add_theme_font_size_override("bold_font_size", 18)
	r.add_theme_color_override("default_color", C_TESTO)
	r.text = REGOLE
	sc.add_child(r)
	v.add_child(bottone("INDIETRO", mostra_menu, Color(0.15, 0.12, 0.1)))

const REGOLE := """[b]Lo scopo.[/b] Dracula si muove in segreto per l'Europa lasciando dietro di sé un [b]Percorso[/b] di sei carte Luogo coperte. I cacciatori vincono se riducono a zero la sua vita (15). Dracula vince se la sua [b]Influenza[/b] arriva a 13: la fa salire quando un vampiro nascosto nel Percorso [i]matura[/i] (3 o 4 punti, +3 con una Diceria), quando morde di notte e quando sconfigge un cacciatore (2 più la Disperazione).

[b]Il turno.[/b] Ogni turno ha un'[b]alba[/b], un [b]giorno[/b] (un'azione per cacciatore), un [b]tramonto[/b], una [b]notte[/b] (un'altra azione, ma senza muoversi) e poi il [b]turno di Dracula[/b]. All'alba e al tramonto, se un cacciatore è nella città di Dracula, si combatte. Ogni lunedì arriva un segnalino Disperazione (al massimo 3): Dracula diventa più pericoloso.

[b]Le azioni dei cacciatori.[/b] Muoversi (solo di giorno) su strada, in treno con un biglietto (numero bianco sulle ferrovie bianche, giallo se si usano quelle gialle) o per mare; prenotare un biglietto; riposare (1 danno, 2 con il Dr. Seward); cercare (si rivelano e si risolvono gli incontri del nascondiglio dove ti trovi); rifornirsi (Oggetto nelle grandi città, più una carta Evento: di giorno dalla cima del mazzo, di notte dal fondo, e se è di Dracula la prende lui); scambiare; giocare eventi e abilità.

[b]Il Percorso.[/b] Quando un cacciatore entra in una città del Percorso la carta si rivela e Dracula può tendere un'imboscata con gli incontri piazzati lì. Le carte di mare e il Castello hanno un dorso diverso, quindi si capisce quando Dracula va per mare. Quando una carta esce dal sesto spazio, i suoi incontri maturano (o Dracula ne fa una tana).

[b]Il combattimento.[/b] Ogni round Dracula sceglie una carta e ogni cacciatore una carta con lo stendardo (Pugno, Schivare, Fuggire o un Oggetto). Se l'icona della carta di Dracula compare sullo stendardo della carta del cacciatore che affronta, la carta di Dracula è annullata. Non si può rigiocare la stessa carta nel round successivo. Dopo 6 carte di Dracula il combattimento finisce. Le fughe (Pipistrello, Nebbia) funzionano solo se Dracula ha già giocato più carte dei segnalini Disperazione.

[b]Poteri di Dracula.[/b] Nascondersi, Forma del Lupo, Richiamo Oscuro, Nutrirsi e Depistaggio si giocano al posto di una carta Luogo. Dracula non può entrare dove c'è il Terreno Consacrato. Il Castello Dracula gli fa recuperare 5 danni.

[b]Sullo schermo.[/b] La mappa si ingrandisce con la rotella o con i pulsanti + e -, e si trascina. Le città dove puoi andare lampeggiano: toccale per sceglierle. Tocca una carta per ingrandirla. Il diario racconta tutto quello che succede.

[b]Online.[/b] Chi crea la stanza sceglie se fare Dracula o i cacciatori; gli amici entrano con il codice di 4 lettere. I ruoli senza giocatore li guida l'IA."""

# ============================================================ online

var on_nome: LineEdit
var on_codice: LineEdit
var on_stato: Label
var lobby_box: VBoxContainer
var on_ruolo := "dracula"
var on_dracula_amico := false

func _menu_online() -> void:
	pulisci()
	_sfondo()
	var v := _riquadro(680, 600)
	v.add_child(etichetta("Online", F_TITOLO, 34, C_ORO))
	v.add_child(etichetta("Chi crea la stanza sceglie il proprio ruolo; gli amici entrano con il codice. I ruoli liberi li guida l'IA.", F_CORSIVO, 17, C_SPENTO))
	var r1 := HBoxContainer.new()
	v.add_child(r1)
	r1.add_child(etichetta("Il tuo nome:", F_GRASSETTO, 18))
	on_nome = LineEdit.new()
	on_nome.custom_minimum_size = Vector2(260, 0)
	on_nome.text = str(net.load_session().get("name", "Cacciatore"))
	on_nome.max_length = 20
	r1.add_child(on_nome)
	var r3 := HBoxContainer.new()
	v.add_child(r3)
	r3.add_child(etichetta("Nella stanza che crei sarai:", F_TESTO, 17))
	var ob := OptionButton.new()
	ob.add_item("Dracula")
	ob.add_item("i cacciatori")
	ob.selected = 0 if on_ruolo == "dracula" else 1
	ob.item_selected.connect(func(k): on_ruolo = "dracula" if k == 0 else "cacciatori")
	r3.add_child(ob)
	var cb := CheckBox.new()
	cb.text = "Se faccio i cacciatori, Dracula lo fa il primo amico che entra"
	cb.button_pressed = on_dracula_amico
	cb.toggled.connect(func(x): on_dracula_amico = x)
	v.add_child(cb)
	v.add_child(bottone("CREA UNA STANZA", _online_crea, Color(0.4, 0.06, 0.05), 20))
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	on_codice = LineEdit.new()
	on_codice.placeholder_text = "CODICE"
	on_codice.max_length = 4
	on_codice.custom_minimum_size = Vector2(120, 0)
	r2.add_child(on_codice)
	r2.add_child(bottone("ENTRA", _online_entra, Color(0.14, 0.12, 0.22), 20))
	var sess := net.load_session()
	if str(sess.get("room", "")) != "":
		r2.add_child(bottone("RIENTRA IN %s" % sess["room"], func():
			on_codice.text = str(sess["room"])
			_online_entra(), Color(0.2, 0.16, 0.1), 16))
	on_stato = etichetta("", F_TESTO, 17, C_ORO)
	on_stato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(on_stato)
	lobby_box = VBoxContainer.new()
	v.add_child(lobby_box)
	v.add_child(bottone("INDIETRO", mostra_menu, Color(0.15, 0.12, 0.1)))

func _online_crea() -> void:
	on_stato.text = "Creo la stanza..."
	net._save({"name": on_nome.text})
	var c := await net.create_room(on_nome.text, {"ruolo": on_ruolo, "amico": on_dracula_amico})
	if c == "":
		on_stato.text = "Non riesco a creare la stanza: " + net.last_error
		return
	codice = c
	mio_posto = 0
	net.remember_room(c, 0)
	on_stato.text = "Stanza %s creata. Dai il codice agli amici, poi premi INIZIA." % c
	_lobby(true)

func _online_entra() -> void:
	var c := on_codice.text.strip_edges().to_upper()
	if c.length() != 4:
		on_stato.text = "Il codice ha 4 lettere."
		return
	on_stato.text = "Entro nella stanza %s..." % c
	net._save({"name": on_nome.text})
	var p := await net.join_room(c, on_nome.text, 5)
	if p < 0:
		on_stato.text = "Non riesco a entrare (stanza piena, inesistente o già iniziata). " + net.last_error
		return
	codice = c
	mio_posto = p
	net.remember_room(c, p)
	var room := await net.room(c)
	if room.get("status", "") == "playing":
		_avvia_da_stanza(room)
		return
	on_stato.text = "Sei nella stanza %s, posto %d. Aspetta che l'host inizi." % [c, p + 1]
	_lobby(false)

func _lobby(host: bool) -> void:
	for ch in lobby_box.get_children():
		ch.queue_free()
	var lista := etichetta("", F_TESTO, 17)
	lobby_box.add_child(lista)
	if host:
		lobby_box.add_child(bottone("INIZIA LA PARTITA", _online_inizia, Color(0.4, 0.06, 0.05), 20))
	while is_instance_valid(lista) and not in_partita:
		var room := await net.room(codice)
		if not is_instance_valid(lista):
			return
		var seats := Rete._as_dict(room.get("seats", {}))
		var t := "Giocatori nella stanza:\n"
		for k in seats:
			t += "  %d. %s\n" % [int(k) + 1, seats[k].get("name", "?")]
		lista.text = t
		if not host and room.get("status", "") == "playing":
			_avvia_da_stanza(room)
			return
		await get_tree().create_timer(1.5).timeout

func _online_inizia() -> void:
	var room := await net.room(codice)
	var seats := Rete._as_dict(room.get("seats", {}))
	var cfg = JSON.parse_string(str(room.get("cfg", "{}")))
	if not (cfg is Dictionary):
		cfg = {}
	var posti := seats.keys().map(func(x): return int(x))
	posti.sort()
	var seat := [-1, -1, -1, -1, -1]
	var cacciatori_umani := []
	if str(cfg.get("ruolo", "dracula")) == "dracula":
		seat[4] = 0
		cacciatori_umani = posti.filter(func(x): return x != 0)
	else:
		cacciatori_umani = [0]
		var altri := posti.filter(func(x): return x != 0)
		if bool(cfg.get("amico", false)) and not altri.is_empty():
			seat[4] = altri.pop_front()
		cacciatori_umani.append_array(altri)
	if not cacciatori_umani.is_empty():
		for i in 4:
			seat[i] = cacciatori_umani[i % cacciatori_umani.size()]
	var nomi := {}
	for k in seats:
		nomi[str(k)] = seats[k].get("name", "?")
	var seed := int(Time.get_unix_time_from_system()) % 1000000
	var game := {"seat": seat, "seed": seed, "nomi": nomi}
	if not await net.start_room(codice, game):
		on_stato.text = "Non riesco a iniziare: " + net.last_error
		return
	room["game"] = JSON.stringify(game)
	_avvia_da_stanza(room)

func _avvia_da_stanza(room: Dictionary) -> void:
	var game = JSON.parse_string(str(room.get("game", "{}")))
	if not (game is Dictionary):
		on_stato.text = "Dati della partita illeggibili."
		return
	online = true
	nomi_posti = game.get("nomi", {})
	m = Motore.new()
	m.nuova(game)
	ia = IA.new(m)
	var log := await net.get_decisions(codice, 0)
	var guard := 0
	while not m.finita() and guard < 30000:
		guard += 1
		var r := m.richiesta()
		if r.is_empty():
			break
		var seat: int = m.s["seat"][r["g"]]
		var id := ""
		if seat < 0:
			id = ia.decidi(r)
		elif log.has(int(m.s["passo"])):
			id = str(log[int(m.s["passo"])].get("id", ""))
		else:
			break
		m.applica({"id": id})
	_apri_partita()

# ============================================================ la partita

func io(g: int) -> bool:
	return int(m.s["seat"][g]) == mio_posto

## Il giocatore vede i segreti di Dracula?
func vedo_dracula() -> bool:
	if io(Motore.DRACULA):
		return true
	return mostra_segreti and not online

func miei_cacciatori() -> Array:
	var out := []
	for i in 4:
		if io(i):
			out.append(i)
	return out

func _apri_partita() -> void:
	pulisci()
	in_partita = true
	richiesta_mostrata = -1
	ultimo_log = 0
	ultimo_evento_visto = int(m.s.get("ultimo_evento", {}).get("passo", -1))
	var sfondo := ColorRect.new()
	sfondo.color = Color(0.05, 0.02, 0.02)
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(sfondo)
	mappa = Mappa.new()
	mappa.set_anchors_preset(Control.PRESET_FULL_RECT)
	mappa.offset_left = 250
	mappa.offset_right = -370
	mappa.offset_top = 50
	mappa.offset_bottom = -200
	schermo.add_child(mappa)
	mappa.luogo_cliccato.connect(_luogo_cliccato)
	_costruisci_hud()
	_aggiorna_tutto()
	var mio := miei_cacciatori()
	if not mio.is_empty() and m.c(mio[0])["pos"] != "":
		mappa.call_deferred("centra", m.c(mio[0])["pos"])

func _costruisci_hud() -> void:
	# barra in alto
	var top := pannello(Color(0.1, 0.03, 0.03, 0.95))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 48
	schermo.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 18)
	top.add_child(th)
	th.add_child(etichetta("La Furia di Dracula", F_GOTICO, 28, C_SANGUE_V))
	top_tempo = etichetta("", F_FELL, 20, C_ORO)
	th.add_child(top_tempo)
	th.add_child(etichetta("Influenza", F_FELL, 18, C_PERG))
	top_barra_inf = HBoxContainer.new()
	top_barra_inf.add_theme_constant_override("separation", 2)
	th.add_child(top_barra_inf)
	top_influenza = etichetta("", F_GRASSETTO, 20, C_SANGUE_V)
	th.add_child(top_influenza)
	top_dracula = etichetta("", F_GRASSETTO, 18, C_PERG)
	th.add_child(top_dracula)
	top_extra = etichetta("", F_TESTO, 16, C_SPENTO)
	top_extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_extra.clip_text = true
	th.add_child(top_extra)
	th.add_child(bottone("+", func(): mappa.zooma(1.25, mappa.size / 2), Color(0.2, 0.12, 0.08), 18))
	th.add_child(bottone("-", func(): mappa.zooma(0.8, mappa.size / 2), Color(0.2, 0.12, 0.08), 18))
	var vel := bottone("Velocità x1", func(): pass, Color(0.2, 0.12, 0.08), 15)
	vel.pressed.connect(func():
		if velocita == 1.0:
			velocita = 3.0
		elif velocita == 3.0:
			velocita = 0.5
		else:
			velocita = 1.0
		vel.text = "Velocità x%s" % ("1" if velocita == 1.0 else ("3" if velocita == 3.0 else "1/2")))
	th.add_child(vel)
	th.add_child(bottone("Menu", _menu_partita, Color(0.3, 0.06, 0.05), 16))
	# colonna dei cacciatori
	var sx := pannello(Color(0.08, 0.03, 0.03, 0.93))
	sx.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sx.offset_top = 50
	sx.offset_right = 248
	sx.offset_bottom = -200
	schermo.add_child(sx)
	var sxs := ScrollContainer.new()
	sxs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sx.add_child(sxs)
	col_cacciatori = VBoxContainer.new()
	col_cacciatori.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_cacciatori.add_theme_constant_override("separation", 6)
	sxs.add_child(col_cacciatori)
	# colonna destra: percorso e richiesta
	var dx := pannello(Color(0.08, 0.03, 0.03, 0.95))
	dx.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	dx.offset_top = 50
	dx.offset_left = -368
	dx.offset_bottom = -200
	schermo.add_child(dx)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	dx.add_child(dv)
	lbl_percorso = etichetta("Il Percorso di Dracula", F_FELL, 19, C_ORO)
	dv.add_child(lbl_percorso)
	box_percorso = HBoxContainer.new()
	box_percorso.add_theme_constant_override("separation", 3)
	dv.add_child(box_percorso)
	dv.add_child(etichetta("Le tane di Dracula", F_FELL, 16, C_ORO))
	box_tane = HBoxContainer.new()
	box_tane.add_theme_constant_override("separation", 8)
	dv.add_child(box_tane)
	dv.add_child(HSeparator.new())
	pannello_rich = VBoxContainer.new()
	pannello_rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(pannello_rich)
	titolo_rich = etichetta("", F_GRASSETTO, 18, C_PERG)
	titolo_rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titolo_rich.custom_minimum_size = Vector2(320, 0)
	pannello_rich.add_child(titolo_rich)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pannello_rich.add_child(sc)
	opz_box = VBoxContainer.new()
	opz_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opz_box.add_theme_constant_override("separation", 4)
	sc.add_child(opz_box)
	# striscia in basso: mano e diario
	var bas := pannello(Color(0.07, 0.03, 0.02, 0.96))
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_top = -198
	schermo.add_child(bas)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	bas.add_child(bh)
	var mv := VBoxContainer.new()
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.size_flags_stretch_ratio = 1.4
	bh.add_child(mv)
	mano_titolo = etichetta("", F_FELL, 17, C_ORO)
	mv.add_child(mano_titolo)
	var msc := ScrollContainer.new()
	msc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mv.add_child(msc)
	mano_box = HBoxContainer.new()
	mano_box.add_theme_constant_override("separation", 5)
	msc.add_child(mano_box)
	diario = RichTextLabel.new()
	diario.bbcode_enabled = true
	diario.scroll_following = true
	diario.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diario.add_theme_font_override("normal_font", F_TESTO)
	diario.add_theme_font_override("bold_font", F_GRASSETTO)
	diario.add_theme_font_size_override("normal_font_size", 16)
	diario.add_theme_font_size_override("bold_font_size", 16)
	diario.add_theme_color_override("default_color", C_TESTO)
	diario.add_theme_stylebox_override("normal", stile(Color(0.12, 0.08, 0.05, 0.9), Color(0.4, 0.28, 0.14), 1, 4))
	bh.add_child(diario)
	# riquadro del combattimento (sopra la mappa)
	comb_panel = pannello(Color(0.12, 0.02, 0.02, 0.93), C_SANGUE_V)
	comb_panel.position = Vector2(262, 58)
	comb_panel.visible = false
	schermo.add_child(comb_panel)
	comb_box = VBoxContainer.new()
	comb_panel.add_child(comb_box)

func _menu_partita() -> void:
	var v := _riquadro(460, 380)
	v.get_parent().get_parent().name = "menu_partita"
	v.add_child(etichetta("Menu", F_TITOLO, 28, C_ORO))
	var chiudi := func(): v.get_parent().get_parent().queue_free()
	v.add_child(bottone("Torna alla partita", chiudi, Color(0.2, 0.16, 0.1)))
	if not online and not io(Motore.DRACULA):
		var t := "Nascondi i segreti di Dracula" if mostra_segreti else "Mostra i segreti di Dracula (spoiler)"
		v.add_child(bottone(t, func():
			mostra_segreti = not mostra_segreti
			chiudi.call()
			_aggiorna_tutto(), Color(0.3, 0.1, 0.08)))
	v.add_child(bottone("Come si gioca", func():
		chiudi.call()
		_ingrandisci_regole(), Color(0.2, 0.16, 0.1)))
	v.add_child(bottone("Salva ed esci al menu", func():
		_salva(true)
		mostra_menu(), Color(0.3, 0.06, 0.05)))

func _ingrandisci_regole() -> void:
	var v := _riquadro(860, 700)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 560)
	v.add_child(sc)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("normal_font", F_TESTO)
	r.add_theme_font_override("bold_font", F_GRASSETTO)
	r.add_theme_font_override("italics_font", F_CORSIVO)
	r.add_theme_color_override("default_color", C_TESTO)
	r.text = REGOLE
	sc.add_child(r)
	v.add_child(bottone("Chiudi", func(): v.get_parent().get_parent().queue_free(), Color(0.2, 0.16, 0.1)))

# ---------- ciclo

func _process(delta: float) -> void:
	if not in_partita or m == null:
		return
	if m.finita():
		if richiesta_mostrata != -2:
			richiesta_mostrata = -2
			_aggiorna_tutto()
			_mostra_fine()
		return
	var r := m.richiesta()
	if r.is_empty():
		return
	var seat: int = m.s["seat"][r["g"]]
	if seat < 0:
		attesa += delta * velocita
		var pausa := _pausa_ia(r)
		if attesa >= pausa:
			attesa = 0.0
			var id := ia.decidi(r)
			m.applica({"id": id})
			_aggiorna_tutto()
			if not online:
				_salva(false)
	elif seat == mio_posto:
		if richiesta_mostrata != int(m.s["passo"]):
			richiesta_mostrata = int(m.s["passo"])
			_mostra_richiesta(r)
	elif online and not aspetto_rete:
		_aspetta_remoto()

func _pausa_ia(r: Dictionary) -> float:
	var k: String = r["k"]
	if r["g"] == Motore.DRACULA and not vedo_dracula() and not (k in ["comb_d", "imboscata", "ingaggio"]):
		return 0.25
	if k.begins_with("comb") or k == "ingaggio":
		return 0.9
	if k == "azione":
		return 0.55
	return 0.35

func _aspetta_remoto() -> void:
	aspetto_rete = true
	var n: int = m.s["passo"]
	var d = await net.get_decision(codice, n)
	if d is Dictionary and d.has("id") and int(m.s["passo"]) == n:
		m.applica({"id": str(d["id"])})
		_aggiorna_tutto()
	else:
		await get_tree().create_timer(1.0).timeout
	aspetto_rete = false

func _decidi(id: String) -> void:
	if online:
		var n: int = m.s["passo"]
		var ok := await net.post_decision(codice, n, {"id": id})
		if not ok:
			_avviso("Rete: non riesco a inviare la mossa (" + net.last_error + "). Riprova.")
			richiesta_mostrata = -1
			return
	if not m.applica({"id": id}):
		richiesta_mostrata = -1
		return
	mappa.evidenziati = {}
	_aggiorna_tutto()
	if not online:
		_salva(m.finita())

var ultimo_locale := 0.0

func _salva(subito: bool) -> void:
	if online or m == null:
		return
	var adesso := Time.get_unix_time_from_system()
	if not subito and adesso - ultimo_locale < 3.0:
		return
	ultimo_locale = adesso
	var testo := JSON.stringify(m.s)
	var f := FileAccess.open(SALVA_LOCALE, FileAccess.WRITE)
	if f:
		f.store_string(testo)
		f.close()
	var ora := Time.get_unix_time_from_system()
	if (subito or ora - ultimo_salvataggio > 30.0) and not salvataggio_in_corso:
		ultimo_salvataggio = ora
		salvataggio_in_corso = true
		await net.salva_partita(m.s)
		salvataggio_in_corso = false

func _luogo_cliccato(l: String) -> void:
	var r := m.richiesta()
	if r.is_empty() or not io(r["g"]):
		return
	for o in r["opz"]:
		if str(o.get("luogo", "")) == l:
			_decidi(str(o["id"]))
			return

# ---------- la richiesta corrente

const GRUPPI := {"muovi": "Spostarti", "azioni": "Azioni", "scambi": "Scambi", "speciale": "Speciale ed Eventi"}

func _mostra_richiesta(r: Dictionary) -> void:
	for ch in opz_box.get_children():
		ch.queue_free()
	titolo_rich.text = r["testo"]
	titolo_rich.add_theme_color_override("font_color", C_SANGUE_V if r["g"] == Motore.DRACULA else C_PERG)
	# evidenzia sulla mappa le città selezionabili
	var ev := {}
	for o in r["opz"]:
		if o.has("luogo") and Dati.luoghi().has(str(o["luogo"])):
			ev[str(o["luogo"])] = Color(1.0, 0.85, 0.3) if r["g"] != Motore.DRACULA else Color(1.0, 0.2, 0.15)
	mappa.evidenziati = ev
	if r["k"] == "azione" and r["g"] < 4:
		mano_di = r["g"]
		_aggiorna_mano()
	var gruppi := {}
	var ordine := []
	for o in r["opz"]:
		var g: String = o.get("gruppo", "")
		if not gruppi.has(g):
			gruppi[g] = []
			ordine.append(g)
		gruppi[g].append(o)
	for g in ordine:
		if g != "" and ordine.size() > 1:
			opz_box.add_child(etichetta(GRUPPI.get(g, g), F_FELL, 16, C_ORO))
		for o in gruppi[g]:
			opz_box.add_child(_bottone_opzione(r, o))
	if r["k"].begins_with("comb_c") or r["k"] == "comb_d":
		_aggiorna_combattimento()

func _bottone_opzione(r: Dictionary, o: Dictionary) -> Control:
	var h := HBoxContainer.new()
	var col := Color(0.32, 0.08, 0.06)
	var id: String = str(o["id"])
	if id == "passa" or id == "no" or id == "fine":
		col = Color(0.18, 0.15, 0.12)
	elif r["g"] == Motore.DRACULA:
		col = Color(0.42, 0.04, 0.04)
	elif id.begins_with("strada:") or id.begins_with("mare:") or id.begins_with("treno"):
		col = Color(0.18, 0.2, 0.1)
	var b := bottone(str(o["testo"]), func(): _decidi(id), col, 16)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(270, 0)
	if o.has("luogo"):
		b.mouse_entered.connect(func():
			if Dati.luoghi().has(str(o["luogo"])):
				mappa.evidenziati = {str(o["luogo"]): Color(0.4, 1.0, 0.5)}
				mappa.queue_redraw())
		b.mouse_exited.connect(func():
			_mostra_evidenziati(r))
	var path := _img_opzione(r, o)
	if path != "":
		var im := immagine(path, 34, 52)
		h.add_child(im)
	h.add_child(b)
	return h

func _mostra_evidenziati(r: Dictionary) -> void:
	var ev := {}
	for o in r["opz"]:
		if o.has("luogo") and Dati.luoghi().has(str(o["luogo"])):
			ev[str(o["luogo"])] = Color(1.0, 0.85, 0.3) if r["g"] != Motore.DRACULA else Color(1.0, 0.2, 0.15)
	mappa.evidenziati = ev

func _img_opzione(r: Dictionary, o: Dictionary) -> String:
	var c: String = str(o.get("carta", ""))
	if c == "":
		return ""
	var k: String = r["k"]
	if Dati.EVENTI.has(c) and not (k in ["imboscata", "piazza_inc", "piazza_inc_tana", "velo", "sconsacrato", "spose"]):
		return Dati.img("evento", c)
	if k in ["comb_c"]:
		return Dati.img("comb", c) if Dati.COMB_CACCIATORE.has(c) else Dati.img("oggetto", c)
	if k in ["comb_d", "macchinazione"]:
		return Dati.img("comb", c)
	if Dati.INCONTRI.has(c):
		return Dati.img("incontro", c)
	if Dati.OGGETTI.has(c):
		return Dati.img("oggetto", c)
	return ""

# ---------- aggiornamento

func _aggiorna_tutto() -> void:
	if m == null or not in_partita:
		return
	var s := m.s
	top_tempo.text = m.descr_tempo() + ("" if s["fase"] != "dracula" else " (turno di Dracula)")
	for ch in top_barra_inf.get_children():
		ch.queue_free()
	for k in 13:
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(9, 18)
		cr.color = C_SANGUE_V if k < int(s["influenza"]) else Color(0.25, 0.18, 0.14)
		top_barra_inf.add_child(cr)
	top_influenza.text = "%d/13" % int(s["influenza"])
	top_dracula.text = "Dracula: %d/15 vita" % (Dati.VITA_DRACULA - int(s["dr"]["danni"]))
	var ex := "Disperazione %d/3" % int(s["disperazione"])
	if s["alleato_c"] != "":
		ex += "  |  Alleato dei cacciatori: " + Dati.EVENTI[s["alleato_c"]]["nome"]
	if s["dr"]["alleato"] != "":
		ex += "  |  Alleato di Dracula: " + Dati.EVENTI[s["dr"]["alleato"]]["nome"]
	if vedo_dracula():
		ex += "  |  Dicerie in mano: %d" % int(s["dicerie"])
	top_extra.text = ex
	_aggiorna_cacciatori()
	_aggiorna_percorso()
	_aggiorna_mappa()
	_aggiorna_mano()
	_aggiorna_diario()
	_aggiorna_combattimento()
	_mostra_evento_giocato()
	var r := m.richiesta()
	if r.is_empty() or not io(r["g"]):
		for ch in opz_box.get_children():
			ch.queue_free()
		if not r.is_empty():
			var chi: String = m.nome(r["g"])
			var seat: int = s["seat"][r["g"]]
			if online and seat >= 0:
				chi += " (" + str(nomi_posti.get(str(seat), "?")) + ")"
			titolo_rich.text = "In attesa: %s sta decidendo..." % chi
			titolo_rich.add_theme_color_override("font_color", C_SPENTO)
			if r["g"] != Motore.DRACULA or vedo_dracula():
				var l := etichetta(r["testo"], F_CORSIVO, 15, C_SPENTO)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(330, 0)
				opz_box.add_child(l)
		mappa.evidenziati = {}

func _aggiorna_mappa() -> void:
	var s := m.s
	var st := {"blocchi": s["blocchi"], "nebbia": s["nebbia"], "tempeste": s["tempeste"], "consacrato": s["consacrato"], "schiera": s["schiera"], "cacciatori": [], "tracce": []}
	var r := m.richiesta()
	for i in 4:
		var h := m.c(i)
		if h["sconfitto"] or h["pos"] == "":
			continue
		st["cacciatori"].append({"id": h["id"], "pos": h["pos"], "osp": h["osp"] != "", "trattenuto": h["trattenuto"], "pipistrelli": h["pipistrelli"],
			"attivo": not r.is_empty() and r["g"] == i})
	if vedo_dracula():
		st["dracula"] = m.pos_dracula()
		st["dracula_segreto"] = not m.dracula_rivelato()
	elif m.dracula_rivelato():
		st["dracula"] = m.pos_dracula()
	for h in s["percorso"]:
		if h["luogo"] != "" and (h["riv"] or vedo_dracula()) and h["luogo"] != st.get("dracula", ""):
			st["tracce"].append({"luogo": h["luogo"], "tana": false, "n": h["inc"].size()})
	for h in s["tane"]:
		if h["riv"] or vedo_dracula():
			st["tracce"].append({"luogo": h["luogo"], "tana": true, "n": h["inc"].size()})
	mappa.stato = st
	mappa.queue_redraw()

func _aggiorna_cacciatori() -> void:
	for ch in col_cacciatori.get_children():
		ch.queue_free()
	var r := m.richiesta()
	for i in 4:
		var h := m.c(i)
		var p := pannello(Color(0.16, 0.08, 0.05, 0.9) if not (not r.is_empty() and r["g"] == i) else Color(0.32, 0.18, 0.06, 0.95), C_ORO if io(i) else Color(0.4, 0.28, 0.14))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var ii := i
		p.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				mano_di = ii
				_aggiorna_mano()
				if m.c(ii)["pos"] != "":
					mappa.centra(m.c(ii)["pos"]))
		col_cacciatori.add_child(p)
		var hb := HBoxContainer.new()
		p.add_child(hb)
		hb.add_child(immagine("res://assets/ui/pg_%s.png" % h["id"], 54, 54))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		hb.add_child(v)
		var nm := m.nome(i)
		if online and int(m.s["seat"][i]) >= 0:
			nm += " (" + str(nomi_posti.get(str(m.s["seat"][i]), "?")) + ")"
		elif int(m.s["seat"][i]) < 0:
			nm += " (IA)"
		v.add_child(etichetta(nm, F_GRASSETTO, 15, C_PERG))
		var dove := "sconfitto" if h["sconfitto"] else ("ospedale di " + Dati.nome(h["osp"]) if h["osp"] != "" else Dati.nome(h["pos"]))
		v.add_child(etichetta(dove + (" (trattenuto)" if h["trattenuto"] else ""), F_TESTO, 14, C_ORO))
		var vita: int = m.vita(i) - int(h["danni"])
		var barra := HBoxContainer.new()
		barra.add_theme_constant_override("separation", 1)
		for k in m.vita(i):
			var cr := ColorRect.new()
			cr.custom_minimum_size = Vector2(9, 8)
			cr.color = Color(0.8, 0.65, 0.3) if k < vita else Color(0.3, 0.1, 0.08)
			barra.add_child(cr)
		v.add_child(barra)
		var info := "Vita %d/%d  Morsi %d/%d" % [vita, m.vita(i), int(h["morsi"]), int(Dati.CACCIATORI[i]["morsi"])]
		v.add_child(etichetta(info, F_TESTO, 13, C_TESTO))
		v.add_child(etichetta("Oggetti %d  Eventi %d  Biglietti %d" % [h["ogg"].size(), h["ev"].size(), h["big"].size()], F_TESTO, 13, C_SPENTO))
		var scop := _scoperte(i)
		if not scop.is_empty():
			var ls := etichetta("Scoperte: " + ", ".join(scop), F_CORSIVO, 13, C_ORO)
			ls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ls.custom_minimum_size = Vector2(170, 0)
			v.add_child(ls)
	# riquadro di Dracula
	var pd := pannello(Color(0.25, 0.03, 0.03, 0.9), C_SANGUE_V)
	pd.mouse_filter = Control.MOUSE_FILTER_STOP
	pd.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			mano_di = Motore.DRACULA
			_aggiorna_mano())
	col_cacciatori.add_child(pd)
	var hd := HBoxContainer.new()
	pd.add_child(hd)
	hd.add_child(immagine("res://assets/ui/pg_dracula.png", 54, 54))
	var vd := VBoxContainer.new()
	vd.add_theme_constant_override("separation", 0)
	hd.add_child(vd)
	var nd := "Dracula"
	if int(m.s["seat"][4]) < 0:
		nd += " (IA)"
	elif online:
		nd += " (" + str(nomi_posti.get(str(m.s["seat"][4]), "?")) + ")"
	vd.add_child(etichetta(nd, F_GRASSETTO, 15, C_PERG))
	var dove := "posizione segreta"
	if m.dracula_rivelato() or vedo_dracula():
		dove = Dati.nome(m.pos_dracula()) + ("" if m.dracula_rivelato() else " (segreto)")
	vd.add_child(etichetta(dove, F_TESTO, 14, C_ORO))
	vd.add_child(etichetta("Vita %d/15  Incontri %d  Eventi %d" % [Dati.VITA_DRACULA - int(m.s["dr"]["danni"]), m.s["dr"]["inc"].size(), m.s["dr"]["ev"].size()], F_TESTO, 13))
	if int(m.s["dr"]["guardie"]) > 0:
		vd.add_child(etichetta("Guardie Szgany pronte: %d" % m.s["dr"]["guardie"], F_TESTO, 13, C_SANGUE_V))

## Le carte che un cacciatore indebolito tiene scoperte (le vede anche Dracula).
func _scoperte(i: int) -> Array:
	var h := m.c(i)
	var out := []
	if not m.indebolito(i):
		return out
	if str(h.get("sc_ogg", "")) in h["ogg"]:
		out.append(Dati.OGGETTI[h["sc_ogg"]]["nome"])
	if str(h.get("sc_ev", "")) in h["ev"]:
		out.append(Dati.EVENTI[h["sc_ev"]]["nome"])
	return out

func _img_nascondiglio(h: Dictionary) -> Array:
	# [immagine principale, didascalia]
	var p := m.pubblico(h)
	if vedo_dracula():
		if h["luogo"] != "":
			var t := Dati.nome(h["luogo"])
			if h["potere"] != "":
				t += " + " + ("Fuga" if h["potere"] == "pipistrello" else Dati.POTERI[h["potere"]]["nome"])
			if not h["riv"]:
				t += " (segreto)"
			return [Dati.img("luogo", h["luogo"]), t]
		if h["potere"] != "":
			return [Dati.img("potere", h["potere"]), Dati.POTERI[h["potere"]]["nome"] + ("" if potere_pubblico(h) else " (segreto)")]
	if p["luogo"] != "":
		var t2 := Dati.nome(p["luogo"])
		if p["potere"] != "":
			t2 += " + " + ("Fuga" if p["potere"] == "pipistrello" else Dati.POTERI[p["potere"]]["nome"])
		return [Dati.img("luogo", p["luogo"]), t2]
	if p["potere"] != "" and p["potere"] != "pipistrello" and p["potere"] != "lupo":
		return [Dati.img("potere", p["potere"]), Dati.POTERI[p["potere"]]["nome"]]
	match p["tipo"]:
		"mare": return ["res://assets/carte/luoghi/dorso_mare.webp", "Mare"]
		"castello": return [Dati.img("luogo", "castello"), "Castello"]
	if p["potere"] == "lupo":
		return ["res://assets/carte/potere/lupo.webp", "Lupo + città"]
	return ["res://assets/carte/luoghi/dorso.webp", "?"]

func potere_pubblico(h: Dictionary) -> bool:
	return m.potere_visibile(h)

func _aggiorna_percorso() -> void:
	for ch in box_percorso.get_children():
		ch.queue_free()
	for ch in box_tane.get_children():
		ch.queue_free()
	var perc: Array = m.s["percorso"]
	for k in 6:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		box_percorso.add_child(v)
		if k < perc.size():
			var h: Dictionary = perc[k]
			var info := _img_nascondiglio(h)
			v.add_child(carta(info[0], 49, ""))
			var t: String = info[1]
			var l := etichetta(t, F_TESTO, 11, C_PERG if h["riv"] else C_SPENTO)
			l.custom_minimum_size = Vector2(49, 0)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
			v.add_child(_riga_incontri(h))
		else:
			var vuoto := ColorRect.new()
			vuoto.color = Color(0.18, 0.1, 0.06, 0.6)
			vuoto.custom_minimum_size = Vector2(49, 76)
			v.add_child(vuoto)
			v.add_child(etichetta("%d" % (k + 1), F_FELL, 12, C_SPENTO))
	for h in m.s["tane"]:
		var hv := HBoxContainer.new()
		box_tane.add_child(hv)
		var v := VBoxContainer.new()
		hv.add_child(v)
		var info := ["res://assets/carte/luoghi/dorso.webp", "Tana"]
		if h["riv"] or vedo_dracula():
			info = [Dati.img("luogo", h["luogo"]), Dati.nome(h["luogo"])]
		v.add_child(carta(info[0], 40, ""))
		var l := etichetta(info[1], F_TESTO, 11, C_PERG)
		l.custom_minimum_size = Vector2(46, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		var ri := _riga_incontri(h)
		ri.custom_minimum_size = Vector2(28, 0)
		hv.add_child(ri)
	if m.s["tane"].is_empty():
		box_tane.add_child(etichetta("nessuna", F_CORSIVO, 14, C_SPENTO))

func _riga_incontri(h: Dictionary) -> Control:
	var hb := HFlowContainer.new()
	hb.custom_minimum_size = Vector2(49, 0)
	for e in h["inc"]:
		var path := "res://assets/carte/incontri/dorso.webp"
		var t := "Incontro coperto"
		if e["riv"] or vedo_dracula():
			path = Dati.img("incontro", e["id"])
			t = Dati.INCONTRI[e["id"]]["nome"] + ("" if e["riv"] else " (segreto)")
			if int(e.get("danni", 0)) > 0:
				t += " - %d danni" % int(e["danni"])
		var im := immagine(path, 24, 37)
		im.tooltip_text = t
		im.mouse_filter = Control.MOUSE_FILTER_STOP
		im.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				_ingrandisci(path, t))
		hb.add_child(im)
	if h["diceria"]:
		var d := immagine("res://assets/segnalini/diceria.webp", 22, 22)
		d.tooltip_text = "Diceria: se il vampiro matura, +3 Influenza"
		hb.add_child(d)
	return hb

func _aggiorna_mano() -> void:
	if mano_box == null:
		return
	for ch in mano_box.get_children():
		ch.queue_free()
	if mano_di < 0:
		var mio := miei_cacciatori()
		mano_di = mio[0] if not mio.is_empty() else Motore.DRACULA
	if mano_di == Motore.DRACULA:
		if not vedo_dracula():
			mano_titolo.text = "Dracula: %d Incontri e %d Eventi in mano (segreti)" % [m.s["dr"]["inc"].size(), m.s["dr"]["ev"].size()]
			for k in m.s["dr"]["inc"].size():
				mano_box.add_child(carta("res://assets/carte/incontri/dorso.webp", 64))
			for k in m.s["dr"]["ev"].size():
				mano_box.add_child(carta("res://assets/carte/eventi/dorso_d.webp", 64))
			return
		mano_titolo.text = "La mano di Dracula: Incontri ed Eventi"
		for e in m.s["dr"]["inc"]:
			mano_box.add_child(carta(Dati.img("incontro", e), 70, Dati.INCONTRI[e]["nome"]))
		for e in m.s["dr"]["ev"]:
			mano_box.add_child(carta(Dati.img("evento", e), 70, Dati.EVENTI[e]["nome"]))
		if int(m.s["dr"]["guardie"]) > 0:
			mano_box.add_child(carta(Dati.img("incontro", "guardie"), 70, "Guardie pronte x%d" % m.s["dr"]["guardie"]))
		return
	var i := mano_di
	var h := m.c(i)
	var segreto := not (io(i) or (not online and not io(Motore.DRACULA)) or (online and not miei_cacciatori().is_empty()))
	mano_titolo.text = "Le carte di %s%s" % [m.nome(i), " (le vede solo la squadra dei cacciatori)" if not segreto else " (segrete)"]
	var scheda := immagine("res://assets/carte/personaggi/%s.webp" % h["id"], 190, 152)
	scheda.tooltip_text = Dati.CACCIATORI[i]["abilita"]
	scheda.mouse_filter = Control.MOUSE_FILTER_STOP
	var pth := "res://assets/carte/personaggi/%s.webp" % h["id"]
	scheda.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_ingrandisci_scheda(pth))
	mano_box.add_child(scheda)
	var sc_o := str(h.get("sc_ogg", "")) if m.indebolito(i) else ""
	var sc_e := str(h.get("sc_ev", "")) if m.indebolito(i) else ""
	for o in h["ogg"]:
		var vis: bool = not segreto or o == sc_o
		if o == sc_o:
			sc_o = "#"
		mano_box.add_child(carta(Dati.img("oggetto", o) if vis else "res://assets/carte/oggetti/dorso.webp", 70, (Dati.OGGETTI[o]["nome"] + (" (scoperta)" if segreto else "")) if vis else ""))
	for e in h["ev"]:
		var vis: bool = not segreto or e == sc_e
		if e == sc_e:
			sc_e = "#"
		mano_box.add_child(carta(Dati.img("evento", e) if vis else "res://assets/carte/eventi/dorso.webp", 70, (Dati.EVENTI[e]["nome"] + (" (scoperta)" if segreto else "")) if vis else ""))
	for b in h["big"]:
		var path := Dati.img_biglietto(b) if not segreto else "res://assets/segnalini/biglietto_dorso.webp"
		var im := immagine(path, 60, 100)
		im.tooltip_text = "Biglietto"
		mano_box.add_child(im)

func _aggiorna_diario() -> void:
	var log: Array = m.s["log"]
	if ultimo_log > log.size():
		ultimo_log = 0
		diario.clear()
	if ultimo_log == 0:
		diario.clear()
		ultimo_log = max(0, log.size() - 150)
	for k in range(ultimo_log, log.size()):
		var t: String = log[k]
		if t.begins_with("—"):
			diario.append_text("[color=#d9b26a][b]%s[/b][/color]\n" % t)
		elif "COMBATTIMENTO" in t or "VINC" in t or "SCONFITTO" in t or "MORSO" in t or "IMBOSCATA" in t:
			diario.append_text("[color=#ff6a50][b]%s[/b][/color]\n" % t)
		elif t.begins_with("Rivelat") or "Rivelato" in t or "scoperto" in t:
			diario.append_text("[color=#f0d070]%s[/color]\n" % t)
		else:
			diario.append_text(t + "\n")
	ultimo_log = log.size()

func _aggiorna_combattimento() -> void:
	var cb: Dictionary = m.s["comb"]
	if cb.is_empty():
		comb_panel.visible = false
		return
	comb_panel.visible = true
	for ch in comb_box.get_children():
		ch.queue_free()
	var avv: String = "DRACULA" if cb["tipo"] == "dracula" else Dati.INCONTRI[cb["inc"]]["nome"].to_upper()
	var vita: int = (Dati.VITA_DRACULA - int(m.s["dr"]["danni"])) if cb["tipo"] == "dracula" else (int(cb["vamp_vita"]) - int(cb["vamp_danni"]))
	comb_box.add_child(etichetta("Combattimento contro %s — round %d — %s" % [avv, int(cb["round"]), "notte" if cb["notte"] else "giorno"], F_TITOLO, 18, C_SANGUE_V))
	comb_box.add_child(etichetta("Vita dell'avversario: %d    Carte giocate da Dracula: %d/6    Mesmerizzati: %s" % [vita, int(cb["giocate"]), ", ".join(cb["mesm"].map(func(x): return m.nome(x))) if not cb["mesm"].is_empty() else "nessuno"], F_TESTO, 15))
	var riv: Dictionary = cb.get("rivelate", {})
	if not riv.is_empty():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		comb_box.add_child(h)
		h.add_child(carta(Dati.img("comb", riv["d"]), 74, Dati.COMB_DRACULA[riv["d"]]["nome"]))
		h.add_child(etichetta("contro", F_CORSIVO, 16, C_SPENTO))
		for j in riv["c"]:
			var sc: String = riv["c"][j]
			var path := Dati.img("comb", sc.get_slice(":", 1)) if sc.begins_with("c:") else Dati.img("oggetto", sc.get_slice(":", 1))
			var t := m.nome(int(j)) + (" (affrontato)" if int(j) == int(riv["ing"]) else "")
			h.add_child(carta(path, 64, t))
	if vedo_dracula() and not cb["mano"].is_empty():
		comb_box.add_child(etichetta("Mano di combattimento: " + ", ".join(cb["mano"].map(func(x): return Dati.COMB_DRACULA[x]["nome"])), F_TESTO, 14, C_ORO))
	if "macchinazione" in cb["scoperte"]:
		comb_box.add_child(etichetta("Macchinazione scoperta: può annullare Pugno, Schivare o Fuggire.", F_CORSIVO, 14, C_SPENTO))

func _mostra_evento_giocato() -> void:
	var ue: Dictionary = m.s.get("ultimo_evento", {})
	if ue.is_empty() or int(ue.get("passo", -1)) == ultimo_evento_visto:
		return
	ultimo_evento_visto = int(ue["passo"])
	if is_instance_valid(notifica):
		notifica.queue_free()
	notifica = pannello(Color(0.1, 0.03, 0.03, 0.95), C_ORO)
	notifica.position = Vector2(schermo.size.x / 2 - 110, 70)
	var v := VBoxContainer.new()
	notifica.add_child(v)
	v.add_child(etichetta("%s gioca" % m.nome(int(ue["g"])), F_FELL, 16, C_ORO))
	v.add_child(immagine(Dati.img("evento", ue["e"]), 200, 312))
	schermo.add_child(notifica)
	var n := notifica
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free())

func _mostra_fine() -> void:
	var es: Dictionary = m.s["esito"]
	var v := _riquadro(640, 420)
	var vince_dr: bool = es.get("vince", "") == "dracula"
	v.add_child(etichetta("Vince Dracula" if vince_dr else "Vincono i cacciatori", F_GOTICO, 54, C_SANGUE_V if vince_dr else C_ORO))
	var l := etichetta(es.get("testo", ""), F_TESTO, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	v.add_child(etichetta("Giorni di caccia: %d   Influenza finale: %d   Vita di Dracula: %d/15" % [int(m.s["giorno"]) + 1, int(m.s["influenza"]), Dati.VITA_DRACULA - int(m.s["dr"]["danni"])], F_TESTO, 17, C_SPENTO))
	var bh := HBoxContainer.new()
	v.add_child(bh)
	bh.add_child(bottone("Guarda il tabellone", func(): v.get_parent().get_parent().queue_free(), Color(0.2, 0.16, 0.1)))
	bh.add_child(bottone("Menu principale", func():
		if not online:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SALVA_LOCALE))
		mostra_menu(), Color(0.4, 0.06, 0.05)))
