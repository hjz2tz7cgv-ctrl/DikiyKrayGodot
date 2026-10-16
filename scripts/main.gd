extends Node2D
# Dikiy Kray: self-contained Godot 4 top-down mobile survival vertical slice.
const SAVE_PATH := "user://dikiy_krai.save"
const WORLD := Vector2(2800, 2000)
const SPEED := 185.0
var player := Vector2(1400, 1000)
var facing := Vector2.RIGHT
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var elapsed := 0.0
var message := "Исследуйте мир, собирайте ресурсы"
var message_time := 5.0
var inventory := {"wood": 0, "stone": 0, "berry": 3, "fish": 0, "meat": 0, "hide": 0, "herb": 0, "spear": 0, "axe": 0, "campfire": 0, "shelter": 0}
var names := {"wood":"Дерево", "stone":"Камень", "berry":"Ягоды", "fish":"Рыба", "meat":"Мясо", "hide":"Шкура", "herb":"Травы", "spear":"Копьё", "axe":"Топор", "campfire":"Костёр", "shelter":"Укрытие"}
var weapon := "fists"
var resources: Array = []
var animals: Array = []
var drops: Array = []
var effects: Array = []
var structures: Array = []
var ui: CanvasLayer
var hud: Label
var status: Label
var menu: PanelContainer
var menu_text: RichTextLabel
var bag_button: Button
var joystick_origin := Vector2.ZERO
var joystick_pointer := -1
var joystick_direction := Vector2.ZERO
var move_key := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var action_cooldown := 0.0

func _ready() -> void:
	rng.seed = 34918
	generate_world()
	load_game()
	make_ui()
	get_viewport().size_changed.connect(queue_redraw)

func generate_world() -> void:
	for i in range(165):
		var kind := "tree" if i < 78 else ("rock" if i < 111 else ("berry" if i < 145 else "herb"))
		var p := Vector2(rng.randf_range(80, WORLD.x-80), rng.randf_range(80, WORLD.y-80))
		if p.distance_to(Vector2(1850, 700)) < 310 or p.distance_to(player) < 100: continue
		resources.append({"pos":p, "kind":kind, "hp": 3 if kind == "tree" else 2 if kind == "rock" else 1})
	for i in range(24):
		var kind := "deer" if i < 9 else ("rabbit" if i < 18 else "boar")
		animals.append({"pos":Vector2(rng.randf_range(140, 2600),rng.randf_range(140, 1850)), "kind":kind, "hp": 2 if kind == "rabbit" else 4 if kind == "deer" else 6, "angle":rng.randf_range(-PI,PI), "timer":rng.randf_range(0.5,3.0), "step":0.0, "alert":0.0})

func _process(delta: float) -> void:
	elapsed += delta
	message_time -= delta
	action_cooldown = maxf(0, action_cooldown-delta)
	hunger = maxf(0, hunger - delta * 0.017)
	thirst = maxf(0, thirst - delta * 0.029)
	if hunger <= 0 or thirst <= 0: health = maxf(0, health-delta*0.9)
	var dir := (joystick_direction + move_key).limit_length(1)
	if menu.visible: dir = Vector2.ZERO
	if dir.length() > 0.1:
		facing = dir.normalized()
		var next := (player + dir*SPEED*delta).clamp(Vector2(35,35), WORLD-Vector2(35,35))
		if next.distance_to(Vector2(1850,700)) > 285: player = next
	for a in animals:
		a["timer"] -= delta
		var away: Vector2 = a["pos"] - player
		var dist := away.length()
		var kind: String = a["kind"]
		var fleeing := (kind != "boar" and dist < (280 if kind == "deer" else 200))
		var charging := kind == "boar" and dist < 135
		if a["timer"] <= 0:
			a["angle"] = rng.randf_range(-PI, PI)
			a["timer"] = rng.randf_range(1.0, 3.2)
		var target := Vector2.from_angle(a["angle"])
		if fleeing: target = away.normalized()
		if charging: target = -away.normalized()
		var speed := 26.0 if kind == "deer" else 42.0 if kind == "rabbit" else 22.0
		if fleeing: speed *= 4.0
		if charging: speed = 112.0
		var new_pos: Vector2 = (a["pos"] + target*speed*delta).clamp(Vector2(25,25), WORLD-Vector2(25,25))
		if new_pos.distance_to(Vector2(1850,700)) > 292: a["pos"] = new_pos
		a["angle"] = lerp_angle(float(a["angle"]), target.angle(), minf(1, delta*5))
		a["step"] += delta*speed*0.12
		if charging and dist < 29: health = maxf(0,health-delta*7)
	for e in effects:
		e["life"] -= delta
	effects = effects.filter(func(e): return e["life"] > 0)
	for d in drops:
		if d["pos"].distance_to(player) < 53 and not d["rare"]:
			pickup_drop(d)
	drops = drops.filter(func(d): return not d.get("taken",false))
	if health <= 0:
		health = 65; hunger = 65; thirst = 65; player = Vector2(1400,1000); say("Вы потеряли сознание и очнулись у лагеря")
	if is_instance_valid(hud):
		hud.text = "❤ %d    🍖 %d    💧 %d    ⚔ %s" % [int(health),int(hunger),int(thirst),{"fists":"Кулаки","spear":"Копьё","axe":"Топор"}[weapon]]
		status.text = message if message_time > 0 else ""
	queue_redraw()

func _draw() -> void:
	var view := get_viewport_rect().size
	var camera := player - view*0.5
	draw_rect(Rect2(Vector2.ZERO,view), Color("6f9860"))
	for x in range(int(camera.x/90)-1,int((camera.x+view.x)/90)+2):
		for y in range(int(camera.y/90)-1,int((camera.y+view.y)/90)+2):
			var pos := Vector2(x*90+28,y*90+30)-camera
			var seed_val := abs((x*193+y*379)%7)
			draw_circle(pos,2.5,Color("7eaa69") if seed_val<4 else Color("547b49"))
	draw_circle(Vector2(1850,700)-camera,300,Color("c0ae79"))
	draw_circle(Vector2(1850,700)-camera,286,Color("478da4"))
	draw_circle(Vector2(1850,700)-camera,269,Color("509cb0"))
	for r in resources:
		var p: Vector2 = r["pos"]-camera
		if not Rect2(Vector2(-60,-60),view+Vector2(120,120)).has_point(p): continue
		match r["kind"]:
			"tree":
				draw_circle(p+Vector2(5,7),26,Color("4c6c3d"));draw_circle(p,25,Color("285c36"));draw_circle(p+Vector2(-7,-8),18,Color("387a45"));draw_circle(p+Vector2(6,-9),13,Color("4a8c51"))
			"rock":
				draw_colored_polygon(PackedVector2Array([p+Vector2(-19,12),p+Vector2(-14,-10),p+Vector2(7,-17),p+Vector2(22,1),p+Vector2(12,15)]),Color("838b87"));draw_line(p+Vector2(-14,-10),p+Vector2(7,-17),Color("b3b9ac"),3)
			"berry":
				draw_circle(p,16,Color("347844"));draw_circle(p+Vector2(-7,0),4,Color("b74751"));draw_circle(p+Vector2(5,-7),4,Color("b74751"));draw_circle(p+Vector2(7,6),4,Color("b74751"))
			"herb":
				for j in range(5): draw_line(p,p+Vector2.from_angle(j*TAU/5)*15,Color("276b3b"),4)
	for s in structures:
		var p: Vector2 = s["pos"]-camera
		if s["kind"]=="campfire":
			draw_circle(p,24,Color("51473b"));draw_circle(p,13,Color("e87531"));draw_circle(p+Vector2(2,-5),7,Color("f9c65a"))
		else:
			draw_rect(Rect2(p-Vector2(38,30),Vector2(76,60)),Color("79583d"));draw_colored_polygon(PackedVector2Array([p+Vector2(-43,-24),p+Vector2(0,-50),p+Vector2(43,-24)]),Color("aa8b5e"))
	for a in animals:
		var p: Vector2 = a["pos"]-camera
		var ang: float = a["angle"]
		var front := Vector2.from_angle(ang)
		var side := front.orthogonal()
		var k: String = a["kind"]
		var size := 13.0 if k=="rabbit" else 21.0 if k=="deer" else 24.0
		var col := Color("b59a74") if k=="deer" else Color("c6b7a0") if k=="rabbit" else Color("4d443d")
		var gait := sin(float(a["step"]))*5
		draw_line(p-side*9-front*9,p-side*(11+gait)-front*17,col.darkened(0.25),5)
		draw_line(p+side*9-front*9,p+side*(11-gait)-front*17,col.darkened(0.25),5)
		draw_circle(p,size,col)
		draw_circle(p+front*(size*0.82),size*0.52,col.lightened(0.12))
		if k=="rabbit":
			draw_line(p+front*size+side*5,p+front*(size+17)+side*8,col,5);draw_line(p+front*size-side*5,p+front*(size+17)-side*8,col,5)
		if k=="deer":
			draw_line(p+front*(size+5)+side*8,p+front*(size+16)+side*16,Color("59492f"),2)
			draw_line(p+front*(size+5)-side*8,p+front*(size+16)-side*16,Color("59492f"),2)
	for d in drops:
		var p: Vector2 = d["pos"]-camera
		draw_circle(p+Vector2(0,3),11,Color(0,0,0,0.16));draw_circle(p,8,drop_color(d["kind"]))
	for e in effects:
		var p: Vector2 = e["pos"]-camera
		draw_circle(p,5+10*(1-float(e["life"])),e["color"])
	var center := player-camera
	draw_circle(center+Vector2(2,6),17,Color(0,0,0,0.2))
	draw_circle(center,14,Color("d7b38a"))
	draw_circle(center-facing*5,11,Color("526e48"))
	draw_line(center,center+facing*21,Color("e1c49e"),5)
	if weapon != "fists": draw_line(center+facing*10,center+facing*(40 if weapon=="spear" else 29),Color("d0d1c5"),4)
	if joystick_pointer != -1:
		draw_arc(joystick_origin,55,0,TAU,40,Color(1,1,1,0.25),3)
		draw_circle(joystick_origin+joystick_direction*40,19,Color(1,1,1,0.25))

func drop_color(kind: String) -> Color:
	match kind:
		"wood": return Color("9b633e")
		"stone": return Color("c4c8c4")
		"berry": return Color("be4a5c")
		"fish": return Color("91c3c9")
		"meat": return Color("b65a55")
		"hide": return Color("9d8264")
		_: return Color("71d78b")

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_E: gather()
				KEY_SPACE: attack()
				KEY_F: fish()
				KEY_I: toggle_bag()
				KEY_Q: cycle_weapon()
				KEY_P: pickup_nearby()
				KEY_ESCAPE: menu.hide()
		move_key = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport_rect().size.x*0.43 and joystick_pointer == -1 and not menu.visible:
			joystick_pointer = event.index;joystick_origin = event.position;joystick_direction = Vector2.ZERO
		elif not event.pressed and event.index == joystick_pointer:
			joystick_pointer = -1;joystick_direction = Vector2.ZERO
	if event is InputEventScreenDrag and event.index == joystick_pointer:
		joystick_direction = ((event.position-joystick_origin)/65).limit_length(1)

func say(t: String) -> void:
	message = t;message_time = 2.8

func add_drop(kind: String, pos: Vector2, rare := false) -> void:
	drops.append({"kind":kind,"pos":pos+Vector2(rng.randf_range(-18,18),rng.randf_range(-18,18)),"rare":rare})
	effects.append({"pos":pos,"life":0.35,"color":drop_color(kind)})

func pickup_drop(d: Dictionary) -> void:
	if d.get("taken",false): return
	d["taken"] = true
	inventory[d["kind"]] += 1
	say("+1 " + names[d["kind"]] + " → 🎒")
	effects.append({"pos":d["pos"],"life":0.45,"color":Color("f5e39a")})

func pickup_nearby() -> void:
	var count := 0
	for d in drops:
		if d["pos"].distance_to(player)<115:
			pickup_drop(d);count+=1
	if count==0: say("Нет предметов рядом")

func gather() -> void:
	if action_cooldown>0: return
	var nearest := -1
	var best := 100.0
	for i in range(resources.size()):
		var dist: float = resources[i]["pos"].distance_to(player)
		if dist < best: best=dist;nearest=i
	if nearest<0: say("Подойдите к ресурсу");return
	var r: Dictionary = resources[nearest]
	action_cooldown=0.32
	r["hp"] -= 2 if (r["kind"]=="tree" and weapon=="axe") else 1
	effects.append({"pos":r["pos"],"life":0.35,"color":Color("f2e3a2")})
	if r["hp"]<=0:
		var kind: String = {"tree":"wood","rock":"stone","berry":"berry","herb":"herb"}[r["kind"]]
		for j in range(3 if kind=="wood" else 2 if kind=="stone" else 2): add_drop(kind,r["pos"])
		resources.remove_at(nearest)
		say("Добыто: "+names[kind])
	else: say("Добыча… ещё удар")

func attack() -> void:
	if action_cooldown>0: return
	action_cooldown=0.45
	var nearest := -1
	var best := 82.0 if weapon=="spear" else 55.0
	for i in range(animals.size()):
		var dist: float = animals[i]["pos"].distance_to(player)
		if dist < best: best=dist;nearest=i
	if nearest<0: say("Животное слишком далеко");return
	var a: Dictionary = animals[nearest]
	a["hp"] -= 3 if weapon=="spear" else 2 if weapon=="axe" else 1
	effects.append({"pos":a["pos"],"life":0.4,"color":Color("f4d58c")})
	if a["hp"]<=0:
		add_drop("meat",a["pos"],true)
		add_drop("hide",a["pos"],true)
		if a["kind"]!="rabbit": add_drop("meat",a["pos"],true)
		animals.remove_at(nearest)
		say("Добыча на земле. Нажмите «Подобрать»")
	else: say("Попадание!")

func fish() -> void:
	if player.distance_to(Vector2(1850,700))>380: say("Подойдите к берегу озера");return
	if action_cooldown>0:return
	action_cooldown=1.1
	var p := Vector2(1850,700).lerp(player,0.82)
	effects.append({"pos":p,"life":0.8,"color":Color("d7eff5")})
	add_drop("fish",player+facing*33,true)
	say("Рыба выловлена! Подберите её")

func eat() -> void:
	if inventory["berry"]>0: inventory["berry"]-=1;hunger=minf(100,hunger+16);say("Вы съели ягоды")
	elif inventory["fish"]>0: inventory["fish"]-=1;hunger=minf(100,hunger+24);say("Вы съели рыбу")
	elif inventory["meat"]>0: inventory["meat"]-=1;hunger=minf(100,hunger+22);say("Вы съели мясо")
	else: say("Нет еды")

func drink() -> void:
	if player.distance_to(Vector2(1850,700))<380: thirst=minf(100,thirst+45);say("Вы попили воды")
	else: say("Нужно подойти к озеру")

func cycle_weapon() -> void:
	var available := ["fists"]
	if inventory["spear"]>0: available.append("spear")
	if inventory["axe"]>0: available.append("axe")
	weapon=available[(available.find(weapon)+1)%available.size()]
	say("Оружие: "+{"fists":"кулаки","spear":"копьё","axe":"топор"}[weapon])

func craft(kind: String) -> void:
	var recipes := {"spear":{"wood":3,"stone":2},"axe":{"wood":2,"stone":3},"campfire":{"wood":5,"stone":4},"shelter":{"wood":9,"hide":2}}
	for item in recipes[kind]:
		if inventory[item]<recipes[kind][item]: say("Недостаточно: "+names[item]);return
	for item in recipes[kind]: inventory[item]-=recipes[kind][item]
	if kind=="campfire" or kind=="shelter": structures.append({"kind":kind,"pos":player+facing*75})
	else: inventory[kind]+=1
	say("Создано: "+names[kind]);update_menu()

func make_ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	var top := HBoxContainer.new();top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);top.offset_bottom=65;top.add_theme_constant_override("separation",14);ui.add_child(top)
	hud=Label.new();hud.add_theme_font_size_override("font_size",23);hud.add_theme_color_override("font_color",Color.WHITE);top.add_child(hud)
	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(spacer)
	bag_button=Button.new();bag_button.text="🎒 Рюкзак";bag_button.custom_minimum_size=Vector2(125,52);bag_button.pressed.connect(toggle_bag);top.add_child(bag_button)
	var save_btn:=Button.new();save_btn.text="💾";save_btn.custom_minimum_size=Vector2(60,52);save_btn.pressed.connect(save_game);top.add_child(save_btn)
	status=Label.new();status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);status.position=Vector2(0,70);status.add_theme_font_size_override("font_size",22);ui.add_child(status)
	var right:=VBoxContainer.new();right.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT);right.offset_left=-150;right.offset_right=-12;right.offset_top=-235;right.offset_bottom=240;right.add_theme_constant_override("separation",6);ui.add_child(right)
	for spec in [["🖐 Собрать","gather"],["⚔ Атака","attack"],["📦 Подобрать","pickup"],["🎣 Рыба","fish"],["🍓 Есть","eat"],["💧 Пить","drink"],["🔄 Оружие","weapon"]]:
		var b:=Button.new();b.text=spec[0];b.custom_minimum_size=Vector2(138,52);right.add_child(b)
		match spec[1]:
			"gather": b.pressed.connect(gather)
			"attack": b.pressed.connect(attack)
			"pickup": b.pressed.connect(pickup_nearby)
			"fish": b.pressed.connect(fish)
			"eat": b.pressed.connect(eat)
			"drink": b.pressed.connect(drink)
			"weapon": b.pressed.connect(cycle_weapon)
	menu=PanelContainer.new();menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER);menu.custom_minimum_size=Vector2(470,520);menu.position=Vector2(-235,-260);ui.add_child(menu)
	var col:=VBoxContainer.new();menu.add_child(col)
	var title:=Label.new();title.text="🎒 РЮКЗАК И КРАФТ";title.add_theme_font_size_override("font_size",26);col.add_child(title)
	menu_text=RichTextLabel.new();menu_text.bbcode_enabled=true;menu_text.custom_minimum_size=Vector2(450,290);col.add_child(menu_text)
	var craft_row:=GridContainer.new();craft_row.columns=2;col.add_child(craft_row)
	for kind in ["spear","axe","campfire","shelter"]:
		var b:=Button.new();b.text="Создать: "+names[kind];b.custom_minimum_size=Vector2(210,44);craft_row.add_child(b);b.pressed.connect(craft.bind(kind))
	var close:=Button.new();close.text="Закрыть";col.add_child(close);close.pressed.connect(toggle_bag)
	menu.hide()

func toggle_bag() -> void:
	menu.visible = not menu.visible
	if menu.visible: update_menu()

func update_menu() -> void:
	if not is_instance_valid(menu_text):return
	var t:="[b]ПРЕДМЕТЫ[/b]\n"
	for k in inventory:
		if inventory[k]>0: t += names[k]+": "+str(inventory[k])+"     "
	t+="\n\n[b]РЕЦЕПТЫ[/b]\nКопьё: 3 дерева + 2 камня\nТопор: 2 дерева + 3 камня\nКостёр: 5 дерева + 4 камня\nУкрытие: 9 дерева + 2 шкуры\n\nРедкую добычу подбирайте кнопкой «Подобрать»."
	menu_text.text=t

func save_game() -> void:
	var data := {"player":[player.x,player.y],"health":health,"hunger":hunger,"thirst":thirst,"inventory":inventory,"resources":serialize_positions(resources),"animals":serialize_positions(animals),"drops":serialize_positions(drops),"structures":serialize_positions(structures),"weapon":weapon}
	var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(data));say("Игра сохранена")

func serialize_positions(items: Array) -> Array:
	var result:=[]
	for item in items:
		var copy: Dictionary=item.duplicate()
		copy["pos"]=[item["pos"].x,item["pos"].y]
		result.append(copy)
	return result

func restore_positions(items: Array) -> Array:
	for item in items: item["pos"]=Vector2(item["pos"][0],item["pos"][1])
	return items

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):return
	var file:=FileAccess.open(SAVE_PATH,FileAccess.READ)
	if not file:return
	var data=JSON.parse_string(file.get_as_text())
	if not data is Dictionary:return
	player=Vector2(data["player"][0],data["player"][1]);health=data.get("health",100);hunger=data.get("hunger",100);thirst=data.get("thirst",100)
	for k in data.get("inventory",{}): inventory[k]=data["inventory"][k]
	resources=restore_positions(data.get("resources",resources));animals=restore_positions(data.get("animals",animals));drops=restore_positions(data.get("drops",[]));structures=restore_positions(data.get("structures",[]));weapon=data.get("weapon","fists")
