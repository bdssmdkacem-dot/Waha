extends Node2D
## Waha - isometric oasis puzzle. All visuals and sounds are generated in code.

const Levels = preload("res://levels.gd")
const TILE := Vector2(120.0, 60.0)
const THICK := 26.0
const ZSTEP := 40.0
const UNLOCK_ALL := false
const SAVE_PATH := "user://waha.cfg"
const SKY_TOP := Color("#14213d")
const SKY_MID := Color("#6d2e63")
const SKY_BOT := Color("#f4a259")
const SAND := Color("#f1dba8")
const SAND_L := Color("#cfa860")
const SAND_R := Color("#a97f3d")
const AMBER := Color("#f4c27a")
const TEAL := Color("#1fb5ad")
const CREAM := Color("#fff4dc")
const INK := Color("#14213d")
const WOOD := Color("#7a4e2d")

enum State { MENU, PLAY }
var state: State = State.MENU
var time := 0.0
var unlocked := 1
var level_index := 0
var level: Dictionary = {}
var cells: Array = []
var mechs: Array = []
var level_names: Array = []
var pid := 0
var ppos := Vector2.ZERO
var pkey := 0.0
var walking := false
var busy := false
var won := false
var transitioning := false
var fade := 0.0
var zoom := 1.0
var origin := Vector2.ZERO
var particles: Array = []
var stars: Array = []

func _ready() -> void:
	randomize()
	_load_save()
	for i in 90:
		stars.append(Vector3(randf(), randf() * 0.6, randf() * TAU))
	for i in Levels.count():
		level_names.append(Levels.get_level(i)["name"])
	var sounds := {
		"step": _tone([520.0], 0.07, 0.35),
		"click": _tone([440.0], 0.05, 0.3),
		"crank": _tone([220.0, 330.0, 260.0], 0.18, 0.4),
		"win": _tone([523.0, 659.0, 784.0, 1046.0], 0.6, 0.4),
	}
	for k in sounds:
		var pl := AudioStreamPlayer.new()
		pl.name = k
		pl.stream = sounds[k]
		add_child(pl)
	get_viewport().size_changed.connect(_fit_view)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.PLAY:
			_go_menu()
		else:
			get_tree().quit()

func _tone(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var f: float = freqs[int(float(i) / n * freqs.size())]
		var env := 1.0 - float(i) / n
		var v := int(sin(TAU * f * float(i) / rate) * 32000.0 * vol * env)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s

func play(k: String) -> void:
	var pl := get_node_or_null(k) as AudioStreamPlayer
	if pl:
		pl.play()

func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		unlocked = int(cf.get_value("progress", "unlocked", 1))

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked", unlocked)
	cf.save(SAVE_PATH)

func iso(p: Vector3) -> Vector2:
	return Vector2((p.x - p.y) * TILE.x / 2.0, (p.x + p.y) * TILE.y / 2.0 - p.z * ZSTEP)

func _key(p: Vector3) -> float:
	return p.x + p.y + p.z * 0.6

func _rot_pos(bp: Vector3, pivot: Vector2, ang: float) -> Vector3:
	var off := (Vector2(bp.x, bp.y) - pivot).rotated(ang)
	return Vector3(pivot.x + off.x, pivot.y + off.y, bp.z)

func load_level(i: int) -> void:
	level_index = i
	level = Levels.get_level(i)
	cells = []
	for c in level["cells"]:
		cells.append({"base": c["p"], "pos": c["p"], "lift": 0.0, "goal": c["goal"], "mech": false})
	mechs = []
	for m in level["mechs"]:
		mechs.append({"def": m, "t": 0.0, "state": 0})
		cells[m["cell"]]["mech"] = true
	pid = 0
	busy = false
	won = false
	walking = false
	particles.clear()
	_apply_mechs()
	ppos = iso(cells[0]["pos"])
	pkey = _key(cells[0]["pos"]) + 0.5
	_fit_view()

func _fit_view() -> void:
	if cells.is_empty():
		return
	var pts: Array[Vector2] = []
	for c in cells:
		pts.append(iso(c["base"]))
	for m in mechs:
		var d: Dictionary = m["def"]
		var bp: Vector3 = cells[d["cell"]]["base"]
		if d["kind"] == "slide":
			pts.append(iso(d["to"]))
		elif d["kind"] == "rotate":
			pts.append(iso(_rot_pos(bp, d["pivot"], d["angle"])))
		pts.append(iso(d["crank"]))
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	mn -= Vector2(90.0, 140.0)
	mx += Vector2(90.0, 150.0)
	var view := get_viewport_rect().size
	zoom = minf(minf(view.x * 0.94 / (mx.x - mn.x), view.y * 0.58 / (mx.y - mn.y)), 2.4)
	origin = Vector2(view.x / 2.0, view.y * 0.52) - (mn + mx) / 2.0 * zoom

func _apply_mechs() -> void:
	for c in cells:
		c["pos"] = c["base"]
		c["lift"] = 0.0
	for m in mechs:
		var d: Dictionary = m["def"]
		var t: float = m["t"]
		var c: Dictionary = cells[d["cell"]]
		var bp: Vector3 = c["base"]
		match d["kind"]:
			"fold":
				c["lift"] = (1.0 - t) * 75.0
			"slide":
				c["pos"] = bp.lerp(d["to"], t)
			"rotate":
				c["pos"] = _rot_pos(bp, d["pivot"], d["angle"] * t)

func edge_ok(e: Array) -> bool:
	if e.size() < 4:
		return true
	for m in mechs:
		if m["def"]["id"] == e[2]:
			return m["state"] == e[3]
	return false

func _path(from: int, to: int) -> Array[int]:
	var prev := {from: -1}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to:
			break
		for e in level["edges"]:
			var other := -1
			if e[0] == cur:
				other = e[1]
			elif e[1] == cur:
				other = e[0]
			if other >= 0 and not prev.has(other) and edge_ok(e):
				prev[other] = cur
				queue.append(other)
	var out: Array[int] = []
	if not prev.has(to):
		return out
	var n := to
	while n != from:
		out.push_front(n)
		n = prev[n]
	return out

func walk_to(target: int) -> void:
	if busy or won or target == pid:
		return
	var seq := _path(pid, target)
	if seq.is_empty():
		play("click")
		return
	busy = true
	walking = true
	var tw := create_tween()
	for n in seq:
		var np: Vector3 = cells[n]["pos"]
		tw.tween_callback(play.bind("step"))
		tw.tween_property(self, "ppos", iso(np), 0.3)
		tw.parallel().tween_property(self, "pkey", _key(np) + 0.5, 0.3)
		tw.tween_callback(_arrive.bind(n))
	tw.tween_callback(_walk_done)

func _arrive(n: int) -> void:
	pid = n
	for k in 4:
		particles.append({"pos": ppos + Vector2(randf_range(-12.0, 12.0), 0.0), "vel": Vector2(randf_range(-40.0, 40.0), randf_range(-60.0, -20.0)), "life": 0.5, "max": 0.5, "col": SAND, "size": 4.0})

func _walk_done() -> void:
	walking = false
	busy = false
	if cells[pid]["goal"]:
		_win()

func toggle(mi: int) -> void:
	if busy or won:
		return
	var m: Dictionary = mechs[mi]
	if pid == m["def"]["cell"]:
		return
	busy = true
	m["state"] = 1 - int(m["state"])
	play("crank")
	var tw := create_tween()
	tw.tween_method(_set_mech_t.bind(m), float(m["t"]), float(m["state"]), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_unbusy)

func _set_mech_t(v: float, m: Dictionary) -> void:
	m["t"] = v

func _unbusy() -> void:
	busy = false

func _win() -> void:
	won = true
	play("win")
	unlocked = maxi(unlocked, mini(level_index + 2, Levels.count()))
	_save()
	var cols := [AMBER, TEAL, CREAM, Color("#e76f51")]
	for k in 70:
		var v := Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(120.0, 380.0)
		particles.append({"pos": ppos + Vector2(0.0, -40.0), "vel": v, "life": 1.6, "max": 1.6, "col": cols[randi() % cols.size()], "size": randf_range(3.0, 6.0)})

func _go_level(i: int) -> void:
	if transitioning: return
	transitioning = true
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.25)
	tw.tween_callback(_enter_level.bind(i))
	tw.tween_property(self, "fade", 0.0, 0.3)
	tw.tween_callback(_end_transition)

func _go_menu() -> void:
	if transitioning: return
	transitioning = true
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.25)
	tw.tween_callback(_enter_menu)
	tw.tween_property(self, "fade", 0.0, 0.3)
	tw.tween_callback(_end_transition)

func _enter_level(i: int) -> void:
	load_level(i)
	state = State.PLAY

func _enter_menu() -> void:
	state = State.MENU
	particles.clear()

func _end_transition() -> void:
	transitioning = false

func _menu_rects(view: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var w := minf(view.x * 0.78, 760.0)
	for i in Levels.count():
		out.append(Rect2((view.x - w) / 2.0, view.y * 0.60 + i * 190.0, w, 150.0))
	return out

func _back_rect(_view: Vector2) -> Rect2:
	return Rect2(40.0, 90.0, 110.0, 110.0)

func _restart_rect(view: Vector2) -> Rect2:
	return Rect2(view.x - 150.0, 90.0, 110.0, 110.0)

func _win_rects(view: Vector2) -> Array[Rect2]:
	var w := minf(view.x * 0.84, 820.0)
	var panel := Rect2((view.x - w) / 2.0, view.y * 0.5 - 260.0, w, 520.0)
	var bw := (w - 100.0) / 2.0
	var by := panel.position.y + panel.size.y - 170.0
	return [panel, Rect2(panel.position.x + 40.0, by, bw, 130.0), Rect2(panel.position.x + 60.0 + bw, by, bw, 130.0)]

func _unhandled_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or transitioning:
		return
	var p := get_local_mouse_position()
	var view := get_viewport_rect().size
	if state == State.MENU:
		for i in _menu_rects(view).size():
			var rs := _menu_rects(view)
			if rs[i].has_point(p) and (UNLOCK_ALL or i < unlocked):
				play("click"); _go_level(i); return
		return
	if won:
		var w := _win_rects(view)
		if w[1].has_point(p):
			play("click"); _go_menu()
		elif w[2].has_point(p):
			play("click")
			if level_index + 1 < Levels.count(): _go_level(level_index + 1)
			else: _go_menu()
		return
	if _back_rect(view).has_point(p):
		play("click"); _go_menu(); return
	if _restart_rect(view).has_point(p):
		play("click"); _go_level(level_index); return
	var wp := (p - origin) / zoom
	for i in mechs.size():
		var cp: Vector3 = mechs[i]["def"]["crank"]
		if wp.distance_to(iso(cp) + Vector2(0.0, -20.0)) < 70.0:
			toggle(i); return
	var best := -1
	var bd := 75.0
	for i in cells.size():
		var d := wp.distance_to(iso(cells[i]["pos"]))
		if d < bd:
			bd = d; best = i
	if best >= 0: walk_to(best)

func _process(delta: float) -> void:
	time += delta
	for p in particles:
		p["life"] -= delta
		var v: Vector2 = p["vel"]
		v.y += 220.0 * delta
		p["vel"] = v
		p["pos"] += v * delta
	particles = particles.filter(func(q): return q["life"] > 0.0)
	_apply_mechs()
	queue_redraw()

func _draw() -> void:
	var view := get_viewport_rect().size
	_draw_background(view)
	if state == State.MENU:
		_draw_menu(view)
	else:
		_draw_world()
		_draw_hud(view)
		if won: _draw_win(view)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.05, 0.08, 0.15, fade))

func _draw_background(view: Vector2) -> void:
	var m := view.y * 0.55
	draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(view.x,0),Vector2(view.x,m),Vector2(0,m)]),PackedColorArray([SKY_TOP,SKY_TOP,SKY_MID,SKY_MID]))
	draw_polygon(PackedVector2Array([Vector2(0,m),Vector2(view.x,m),view,Vector2(0,view.y)]),PackedColorArray([SKY_MID,SKY_MID,SKY_BOT,SKY_BOT]))
	for s in stars:
		var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 2.0 + s.z))
		draw_circle(Vector2(s.x * view.x, s.y * view.y), 1.8, Color(1,1,1,a))
	var moon := Vector2(view.x * 0.8, view.y * 0.14)
	for r in [130.0,95.0,72.0]: draw_circle(moon,r,Color(1.0,0.95,0.8,0.06))
	draw_circle(moon,52.0,Color("#fff3d6"))
	for layer in 3:
		var base := view.y * (0.80 + layer * 0.07)
		var pts := PackedVector2Array([Vector2(0,view.y)])
		var x := 0.0
		while x <= view.x + 40.0:
			pts.append(Vector2(x,base + sin(x*0.006+layer*1.7)*38.0 + sin(x*0.015+layer)*12.0)); x += 40.0
		pts.append(Vector2(view.x+40.0,view.y))
		draw_colored_polygon(pts,Color("#3b2a4a").lerp(Color("#c97b4a"),layer*0.35))

func _draw_menu(view: Vector2) -> void:
	draw_set_transform(Vector2(view.x/2.0,view.y*0.36),0.0,Vector2(1.7,1.7))
	_draw_tile({"pos":Vector3.ZERO,"lift":0.0,"goal":true,"mech":false})
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(0,view.y*0.17),"Waha",HORIZONTAL_ALIGNMENT_CENTER,view.x,170,CREAM)
	draw_string(font,Vector2(0,view.y*0.17+70.0),"an oasis puzzle",HORIZONTAL_ALIGNMENT_CENTER,view.x,44,AMBER)
	var rs := _menu_rects(view)
	for i in rs.size():
		var ok := UNLOCK_ALL or i < unlocked
		_button(rs[i],"%d   %s" % [i+1,level_names[i]] if ok else "%d   Locked" % (i+1),AMBER,46,ok)

func _draw_world() -> void:
	draw_set_transform(origin,0.0,Vector2(zoom,zoom))
	var items:Array=[]
	for i in cells.size():
		items.append([_key(cells[i]["pos"]),0,i])
	for i in mechs.size():
		items.append([_key(mechs[i]["def"]["crank"])+0.4,1,i])
	items.append([pkey,2,0])
	items.sort_custom(func(a,b): return a[0] < b[0])
	for it in items:
		match it[1]:
			0: _draw_tile(cells[it[2]])
			1: _draw_crank(mechs[it[2]])
			2: _draw_player()
	for p in particles:
		draw_circle(p["pos"],p["size"],Color(p["col"],float(p["life"])/float(p["max"])))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _ellipse(c:Vector2,rx:float,ry:float)->PackedVector2Array:
	var pts:=PackedVector2Array()
	for i in 28:
		var a:=TAU*i/28.0
		pts.append(c+Vector2(cos(a)*rx,sin(a)*ry))
	return pts

func _draw_tile(c:Dictionary)->void:
	var p:Vector3=c["pos"]
	var ctr:=iso(p)
	var lift:float=c["lift"]
	var hw:=TILE.x/2.0
	var hh:=TILE.y/2.0
	var t0:=ctr+Vector2(0,-hh-lift)
	var t1:=ctr+Vector2(hw,-lift)
	var t2:=ctr+Vector2(0,hh)
	var t3:=ctr+Vector2(-hw,0)
	var is_mech:bool=c["mech"]
	var is_goal:bool=c["goal"]
	var pillar:=0.0 if is_mech else maxf(p.z,0.0)*ZSTEP
	var down:=Vector2(0,THICK+pillar)
	var top_col:=SAND.lerp(CREAM,clampf(p.z*0.18,0,0.5))
	if is_mech: top_col=AMBER
	if is_goal: top_col=TEAL
	draw_colored_polygon(PackedVector2Array([t3,t2,t2+down,t3+down]),SAND_L)
	draw_colored_polygon(PackedVector2Array([t2,t1,t1+down,t2+down]),SAND_R)
	draw_colored_polygon(PackedVector2Array([t0,t1,t2,t3]),top_col)
	var ce:Vector2=(t0+t1+t2+t3)/4.0
	draw_polyline(PackedVector2Array([t0,t1,t2,t3,t0]),Color(1,1,1,0.3),2.0)
	draw_circle(ce,4.0,Color(0,0,0,0.14))
	if is_goal:
		for r in 2:
			var e:=_ellipse(ce,30.0+r*12.0+sin(time*2.0+r)*3.0,15.0+r*6.0); e.append(e[0])
			draw_polyline(e,Color(1,1,1,0.5-r*0.2),2.0)
		_draw_palm(ce+Vector2(-14,-4))
		for k in 3:
			var sp:=ce+Vector2(cos(time+k*2.1)*40.0,sin(time+k*2.1)*18.0-50.0-12.0*absf(sin(time*2.0+k)))
			var sa:=0.4+0.6*absf(sin(time*3.0+k))
			draw_line(sp-Vector2(7,0),sp+Vector2(7,0),Color(1,1,1,sa),2)
			draw_line(sp-Vector2(0,7),sp+Vector2(0,7),Color(1,1,1,sa),2)

func _draw_palm(base:Vector2)->void:
	var sway:=sin(time*1.6)*5.0
	var knee:=base+Vector2(-4,-46)
	var tip:=base+Vector2(-8+sway,-92)
	draw_line(base,knee,WOOD,9); draw_line(knee,tip,WOOD,7)
	for k in 6:
		var a:=-PI/2.0+(k-2.5)*0.55
		var dir:=Vector2.from_angle(a)
		var perp:=dir.orthogonal()
		var mid:=tip+dir*28+Vector2(0,8)
		var end:=tip+dir*56+Vector2(0,26)
		var leaf:=Color("#2e9e6b") if k%2==0 else Color("#3fbf82")
		draw_colored_polygon(PackedVector2Array([tip,mid+perp*9,end,mid-perp*9]),leaf)

func _draw_crank(m:Dictionary)->void:
	var d:Dictionary=m["def"]
	var ctr:=iso(d["crank"])
	var t:float=m["t"]
	draw_colored_polygon(_ellipse(ctr+Vector2(0,14),40,20),WOOD)
	draw_rect(Rect2(ctr.x-40,ctr.y,80,14),WOOD)
	draw_colored_polygon(_ellipse(ctr,40,20),Color("#b9855a"))
	var a:=t*PI+0.6
	var shaft:=ctr+Vector2(0,-22)
	var arm:=shaft+Vector2(cos(a)*46,sin(a)*23)
	draw_line(ctr+Vector2(0,-4),shaft,CREAM,8); draw_line(shaft,arm,CREAM,9)
	draw_circle(arm,12,AMBER); draw_circle(arm,5,Color("#c47a1e"))
	if not busy and not won: draw_arc(ctr+Vector2(0,-10),58+sin(time*3)*3,0,TAU,40,Color(1,1,1,0.22),2)

func _draw_player()->void:
	var bob:=absf(sin(time*15))*6 if walking else 0.0
	var pp:=ppos+Vector2(0,-bob)
	draw_colored_polygon(_ellipse(ppos,16,8),Color(0,0,0,0.25))
	draw_colored_polygon(PackedVector2Array([pp+Vector2(-15,0),pp+Vector2(15,0),pp+Vector2(5,-48),pp+Vector2(-5,-48)]),Color("#e76f51"))
	draw_circle(pp+Vector2(0,-56),10,CREAM)
	draw_colored_polygon(PackedVector2Array([pp+Vector2(-13,-60),pp+Vector2(13,-60),pp+Vector2(4+sin(time*2)*2,-92)]),Color("#2a9d8f"))

func _button(r:Rect2,label:String,col:Color,fs:int=44,enabled:bool=true)->void:
	var sb:=StyleBoxFlat.new()
	sb.bg_color=col if enabled else Color(0.3,0.3,0.35,0.8)
	sb.set_corner_radius_all(int(minf(r.size.x,r.size.y)*0.28))
	sb.shadow_color=Color(0,0,0,0.3); sb.shadow_size=8
	draw_style_box(sb,r)
	if label!="":
		draw_string(ThemeDB.fallback_font,Vector2(r.position.x,r.position.y+r.size.y/2+fs*0.35),label,HORIZONTAL_ALIGNMENT_CENTER,r.size.x,fs,INK if enabled else CREAM)

func _draw_hud(view:Vector2)->void:
	var br:=_back_rect(view); _button(br,"",CREAM)
	draw_polyline(PackedVector2Array([br.position+Vector2(66,32),br.position+Vector2(40,55),br.position+Vector2(66,78)]),INK,8)
	var rr:=_restart_rect(view); _button(rr,"",CREAM)
	var rc:=rr.get_center(); var ea:=TAU-0.5
	draw_arc(rc,28,0.7,ea,24,INK,8)
	draw_string(ThemeDB.fallback_font,Vector2(0,160),"%d   %s" % [level_index+1,level["name"]],HORIZONTAL_ALIGNMENT_CENTER,view.x,46,CREAM)
	var used:=false
	for m in mechs:
		if m["state"]==1: used=true
	if not used and not won:
		draw_multiline_string(ThemeDB.fallback_font,Vector2(60,view.y-230),level["hint"],HORIZONTAL_ALIGNMENT_CENTER,view.x-120,38,-1,Color(CREAM,0.9))

func _draw_win(view:Vector2)->void:
	draw_rect(Rect2(Vector2.ZERO,view),Color(0.05,0.08,0.15,0.55))
	var w:=_win_rects(view)
	var panel:=StyleBoxFlat.new(); panel.bg_color=CREAM; panel.set_corner_radius_all(48); panel.shadow_color=Color(0,0,0,0.35); panel.shadow_size=24
	draw_style_box(panel,w[0])
	var r:Rect2=w[0]
	draw_string(ThemeDB.fallback_font,Vector2(r.position.x,r.position.y+130),"Oasis reached",HORIZONTAL_ALIGNMENT_CENTER,r.size.x,78,INK)
	var sub:="You finished stage %d" % (level_index+1)
	if level_index+1>=Levels.count(): sub="More oases are coming soon"
	draw_string(ThemeDB.fallback_font,Vector2(r.position.x,r.position.y+210),sub,HORIZONTAL_ALIGNMENT_CENTER,r.size.x,40,SAND_R)
	_button(w[1],"Menu",AMBER,46); _button(w[2],"Next" if level_index+1<Levels.count() else "Done",TEAL,46)
