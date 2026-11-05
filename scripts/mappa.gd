## Il tabellone: mappa dell'Europa con zoom (rotella, pulsanti, pizzico) e trascinamento.
## Disegna le pedine dei cacciatori, Dracula (se visibile), i segnalini e evidenzia le città selezionabili.
class_name Mappa
extends Control

signal luogo_cliccato(id: String)

const TEX := preload("res://assets/tabellone.webp")
var tex_pg := {}
var tex_seg := {}
var zoom := 0.3
var offset := Vector2.ZERO
var evidenziati: Dictionary = {}   # luogo -> colore
var stato: Dictionary = {}         # cosa disegnare (preparato da main.gd)
var _trascina := false
var _mosso := 0.0
var _ultimo := Vector2.ZERO
var _sopra := ""
var _tocchi := {}
var _dist_pizzico := 0.0
var font: Font
var t := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for k in ["godalming", "seward", "vanhelsing", "mina", "dracula"]:
		tex_pg[k] = load("res://assets/ui/pg_%s.png" % k)
	for k in ["nebbia", "tempesta", "blocco_strada", "blocco_ferrovia", "consacrato", "schiera", "pipistrelli", "diceria"]:
		tex_seg[k] = load("res://assets/segnalini/%s.webp" % k)
	font = load("res://assets/font/IMFellEnglishSC.ttf")
	resized.connect(_adatta)
	call_deferred("_adatta")

func _adatta() -> void:
	if size.x <= 0:
		return
	var z: float = min(size.x / TEX.get_width(), size.y / TEX.get_height())
	zoom = clamp(z, 0.12, 2.0)
	offset = (size - Vector2(TEX.get_size()) * zoom) / 2.0
	queue_redraw()

func _limita() -> void:
	var dim := Vector2(TEX.get_size()) * zoom
	var marg := size * 0.5
	offset.x = clamp(offset.x, size.x - dim.x - marg.x, marg.x)
	offset.y = clamp(offset.y, size.y - dim.y - marg.y, marg.y)

func a_schermo(p: Vector2) -> Vector2:
	return offset + p * zoom

func zooma(f: float, centro: Vector2) -> void:
	var vecchio := zoom
	zoom = clamp(zoom * f, 0.1, 1.6)
	offset = centro - (centro - offset) * (zoom / vecchio)
	_limita()
	queue_redraw()

func centra(luogo: String) -> void:
	if not Dati.luoghi().has(luogo):
		return
	var L := Dati.L(luogo)
	offset = size / 2.0 - Vector2(L["x"], L["y"]) * zoom
	_limita()
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	if not evidenziati.is_empty() or stato.get("lampeggia", "") != "":
		queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_tocchi[ev.index] = ev.position
		else:
			_tocchi.erase(ev.index)
		_dist_pizzico = 0.0
	elif ev is InputEventScreenDrag:
		_tocchi[ev.index] = ev.position
		if _tocchi.size() >= 2:
			var k: Array = _tocchi.keys()
			var d: float = (_tocchi[k[0]] as Vector2).distance_to(_tocchi[k[1]])
			if _dist_pizzico > 0:
				zooma(d / _dist_pizzico, ((_tocchi[k[0]] as Vector2) + (_tocchi[k[1]] as Vector2)) / 2.0)
			_dist_pizzico = d
			_mosso = 99
			return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			zooma(1.15, ev.position)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			zooma(1.0 / 1.15, ev.position)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_trascina = true
				_mosso = 0.0
				_ultimo = ev.position
			else:
				_trascina = false
				if _mosso < 8 and _tocchi.size() < 2:
					var l := luogo_in(ev.position)
					if l != "":
						luogo_cliccato.emit(l)
	elif ev is InputEventMouseMotion:
		if _trascina and _tocchi.size() < 2:
			var d: Vector2 = ev.position - _ultimo
			_mosso += d.length()
			_ultimo = ev.position
			offset += d
			_limita()
			queue_redraw()
		var l := luogo_in(ev.position)
		if l != _sopra:
			_sopra = l
			tooltip_text = Dati.nome(l) if l != "" else ""
			queue_redraw()

func luogo_in(p: Vector2) -> String:
	var best := ""
	var bd := 9999.0
	for k in Dati.luoghi():
		var L := Dati.L(k)
		var d := a_schermo(Vector2(L["x"], L["y"])).distance_to(p)
		var r: float = max(24.0, (110.0 if L["mare"] else 60.0) * zoom)
		if d < r and d < bd:
			bd = d
			best = k
	return best

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.02))
	draw_texture_rect(TEX, Rect2(offset, Vector2(TEX.get_size()) * zoom), false)
	var z := zoom
	# blocchi su strade e ferrovie
	for b in stato.get("blocchi", []):
		var a: Dictionary = Dati.L(b[0])
		var c: Dictionary = Dati.L(b[1])
		var mid := a_schermo((Vector2(a["x"], a["y"]) + Vector2(c["x"], c["y"])) / 2.0)
		var tx: Texture2D = tex_seg["blocco_ferrovia" if b[2] else "blocco_strada"]
		var r: float = max(12.0, 46.0 * z)
		draw_line(a_schermo(Vector2(a["x"], a["y"])), a_schermo(Vector2(c["x"], c["y"])), Color(0.9, 0.1, 0.05, 0.75), max(2.0, 8.0 * z))
		draw_texture_rect(tx, Rect2(mid - Vector2(r, r), Vector2(r, r) * 2), false)
	# città selezionabili
	for k in evidenziati:
		var L := Dati.L(k)
		var p := a_schermo(Vector2(L["x"], L["y"]))
		var r: float = max(14.0, (95.0 if L["mare"] else 62.0) * z)
		var col: Color = evidenziati[k]
		var a2 := 0.55 + 0.35 * sin(t * 4.0)
		draw_arc(p, r, 0, TAU, 40, Color(col.r, col.g, col.b, a2), max(2.5, 10.0 * z))
		draw_circle(p, r * 0.92, Color(col.r, col.g, col.b, 0.12))
	# segnalini sulle città
	for k in stato.get("nebbia", {}):
		_segnalino(k, "nebbia", Vector2(-50, -60), int(stato["nebbia"][k]))
	for k in stato.get("tempeste", []):
		_segnalino(k, "tempesta", Vector2(60, -40), 1)
	for k in stato.get("consacrato", []):
		_segnalino(k, "consacrato", Vector2(60, -60), 1)
	for k in stato.get("schiera", []):
		_segnalino(k, "schiera", Vector2(60, 50), 1)
	# luoghi rivelati del Percorso e delle tane
	for x in stato.get("tracce", []):
		var L := Dati.L(x["luogo"])
		var p := a_schermo(Vector2(L["x"], L["y"]))
		var r: float = max(10.0, 40.0 * z)
		var col := Color(0.75, 0.05, 0.05, 0.85) if x["tana"] else Color(0.95, 0.75, 0.2, 0.9)
		draw_arc(p, r * 1.5, 0, TAU, 32, col, max(2.0, 7.0 * z))
		if x.get("n", 0) > 0:
			_testo(p + Vector2(-r * 1.6, -r * 1.2), str(x["n"]), col, max(13, int(48 * z)))
	# Dracula
	var dr: String = stato.get("dracula", "")
	if dr != "":
		var L := Dati.L(dr)
		_pedina(a_schermo(Vector2(L["x"], L["y"]) + Vector2(0, -85)), "dracula", 1.15, stato.get("dracula_segreto", false))
	# cacciatori (raggruppati per città)
	var gruppi := {}
	for c in stato.get("cacciatori", []):
		var k: String = c["pos"]
		if not gruppi.has(k):
			gruppi[k] = []
		gruppi[k].append(c)
	for k in gruppi:
		var L := Dati.L(k)
		var base := Vector2(L["x"], L["y"])
		var n: int = gruppi[k].size()
		for idx in n:
			var c: Dictionary = gruppi[k][idx]
			var dx := (idx - (n - 1) / 2.0) * 120.0
			var p := a_schermo(base + Vector2(dx, 70))
			if c.get("osp", false):
				var o: Dictionary = Dati.mappa()["ospedali"][k]
				p = a_schermo(Vector2(o["x"], o["y"]) + Vector2(dx, -40))
			_pedina(p, c["id"], 1.0, false, c.get("trattenuto", false), c.get("attivo", false), c.get("pipistrelli", false))
	# nome della città sotto il mouse
	if _sopra != "":
		var L := Dati.L(_sopra)
		var p := a_schermo(Vector2(L["x"], L["y"]))
		_testo(p + Vector2(18, -18), Dati.nome(_sopra), Color(1, 0.93, 0.8), 18, true)

func _pedina(p: Vector2, id: String, scala: float, segreto: bool, trattenuto := false, attivo := false, pipistrelli := false) -> void:
	var r: float = clamp(62.0 * zoom, 15.0, 48.0) * scala
	if attivo:
		draw_circle(p, r * 1.28, Color(1.0, 0.85, 0.3, 0.45 + 0.3 * sin(t * 5.0)))
	draw_circle(p + Vector2(3, 4), r, Color(0, 0, 0, 0.5))
	var tx: Texture2D = tex_pg[id]
	draw_texture_rect(tx, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, Color(1, 1, 1, 0.55) if segreto else Color.WHITE)
	if segreto:
		draw_arc(p, r * 1.08, 0, TAU, 32, Color(0.8, 0.1, 0.1, 0.9), 3.0)
	if trattenuto:
		draw_line(p + Vector2(-r, r * 0.9), p + Vector2(r, r * 0.9), Color(0.1, 0.1, 0.1, 0.9), 6)
		_testo(p + Vector2(-r, r * 1.5), "trattenuto", Color(1, 0.8, 0.6), 13, true)
	if pipistrelli:
		var tb: Texture2D = tex_seg["pipistrelli"]
		draw_texture_rect(tb, Rect2(p + Vector2(r * 0.4, -r * 1.2), Vector2(r, r)), false)

func _segnalino(k: String, tipo: String, d: Vector2, n: int) -> void:
	var L := Dati.L(k)
	var r: float = max(12.0, 40.0 * zoom)
	var p := a_schermo(Vector2(L["x"], L["y"]) + d)
	draw_texture_rect(tex_seg[tipo], Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false)
	if n > 1:
		_testo(p + Vector2(r, 0), "x%d" % n, Color.WHITE, 14, true)

func _testo(p: Vector2, s: String, col: Color, size_px: int, ombra := false) -> void:
	if ombra:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(0, 0, 0, 0.85))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
