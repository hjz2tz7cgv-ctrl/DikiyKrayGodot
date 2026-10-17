extends Node3D

# Дикий край — самодостаточный Godot 4 3D прототип для Web/iPhone.
const WALK_SPEED := 5.0
const PLAYER_RADIUS := 0.48
const LAKE_CENTER := Vector2(10.0, -7.0)
const LAKE_RADIUS := 7.0
const WORLD_LIMIT := 27.0

var player: CharacterBody3D
var camera: Camera3D
var camera_distance := 17.0
var camera_tilt := 0.68
var obstacles: Array[Dictionary] = []
var resources: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var inventory := {"wood": 0, "stone": 0, "berry": 0}
var target_resource := -1
var mining_progress := 0.0
var mining_active := false
var touch_move := Vector2.ZERO
var joystick_touch := -1
var joystick_origin := Vector2.ZERO
var active_touches := {}
var pinch_previous := 0.0
var pending_kind := ""
var pending_index := -1
var pending_pos := Vector2.ZERO
var pickup_flight := {}
var pickup_time := 0.0
var bag_button: Button
var bag_fly: Label
var hud: CanvasLayer
var info_label: Label
var progress_bar: ProgressBar
var bag_panel: PanelContainer
var bag_label: Label
var zoom_label: Label
var action_button: Button
var status_message := "Подойдите к дереву или камню"
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 20261017
    _create_world()
    _create_player()
    _create_camera()
    _create_resources()
    _create_animals()
    _create_ui()
    _update_ui()

func _material(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.94
    return m

func _mesh_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.position = pos
    mi.material_override = _material(color)
    parent.add_child(mi)
    return mi

func _mesh_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, scale_value := Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mi.mesh = mesh
    mi.position = pos
    mi.scale = scale_value
    mi.material_override = _material(color)
    parent.add_child(mi)
    return mi

func _create_world() -> void:
    _mesh_box(self, Vector3(60, 0.3, 60), Vector3(0, -0.2, 0), Color("628a51"))
    var water := _mesh_sphere(self, LAKE_RADIUS, Vector3(LAKE_CENTER.x, -0.15, LAKE_CENTER.y), Color("3d9dc0"), Vector3(1.0, 0.018, 1.0))
    water.name = "Lake"
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-58, -35, 0)
    sun.light_energy = 1.1
    add_child(sun)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("8cb9d2")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("d9e6de")
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 0.9, 0)
    add_child(player)
    var capsule := CapsuleShape3D.new()
    capsule.radius = PLAYER_RADIUS
    capsule.height = 1.8
    var collision := CollisionShape3D.new()
    collision.shape = capsule
    player.add_child(collision)
    _mesh_sphere(player, 0.55, Vector3(0, 0.0, 0), Color("d7a579"), Vector3(0.8, 1.25, 0.7))
    _mesh_sphere(player, 0.34, Vector3(0, 0.9, 0), Color("edc59b"))
    _mesh_box(player, Vector3(0.7, 0.15, 0.18), Vector3(0, 0.5, -0.3), Color("4c7050"))

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 54.0
    add_child(camera)
    _position_camera()

func _position_camera() -> void:
    if camera == null or player == null:
        return
    var focus := player.global_position + Vector3(0, 0.35, 0)
    camera.global_position = focus + Vector3(0, camera_distance, camera_distance * camera_tilt)
    camera.look_at(focus, Vector3.UP)

func _is_lake(pos: Vector2, margin := 0.0) -> bool:
    return pos.distance_to(LAKE_CENTER) < LAKE_RADIUS + margin

func _can_place(pos: Vector2, radius: float) -> bool:
    if _is_lake(pos, radius + 0.3):
        return false
    if pos.length() < 3.3:
        return false
    for obstacle in obstacles:
        if pos.distance_to(obstacle["pos"]) < radius + obstacle["radius"] + 1.0:
            return false
    return true

func _create_resources() -> void:
    for i in range(30):
        var kind := "tree" if i < 19 else "rock"
        var radius := 0.85 if kind == "tree" else 0.7
        var pos := Vector2.ZERO
        var found := false
        for attempt in range(80):
            pos = Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24))
            if _can_place(pos, radius):
                found = true
                break
        if not found:
            continue
        var node := Node3D.new()
        node.position = Vector3(pos.x, 0, pos.y)
        add_child(node)
        if kind == "tree":
            _mesh_box(node, Vector3(0.55, 2.2, 0.55), Vector3(0, 1.1, 0), Color("765238"))
            _mesh_sphere(node, 1.25, Vector3(0, 2.55, 0), Color("286e3f"), Vector3(1, 0.85, 1))
            _mesh_sphere(node, 0.75, Vector3(0.5, 3.05, 0.1), Color("3a8850"))
        else:
            _mesh_sphere(node, 0.88, Vector3(0, 0.55, 0), Color("929c9a"), Vector3(1.1, 0.65, 0.9))
        obstacles.append({"pos": pos, "radius": radius, "node": node})
        resources.append({"kind": kind, "pos": pos, "node": node, "duration": 2.4 if kind == "tree" else 3.4, "alive": true})
    for i in range(13):
        var pos := Vector2(rng.randf_range(-23, 23), rng.randf_range(-23, 23))
        if not _can_place(pos, 0.4):
            continue
        var bush := Node3D.new()
        bush.position = Vector3(pos.x, 0, pos.y)
        add_child(bush)
        _mesh_sphere(bush, 0.55, Vector3(0, 0.4, 0), Color("317d45"))
        for j in range(4):
            _mesh_sphere(bush, 0.1, Vector3(rng.randf_range(-0.35, 0.35), 0.65, rng.randf_range(-0.35, 0.35)), Color("c64248"))
        resources.append({"kind": "berry", "pos": pos, "node": bush, "duration": 1.3, "alive": true})

func _create_animals() -> void:
    for i in range(5):
        var pos := Vector2(rng.randf_range(-19, 19), rng.randf_range(-19, 19))
        if _is_lake(pos, 1.2):
            pos = Vector2(-10 + i * 2, 10)
        var animal := Node3D.new()
        animal.position = Vector3(pos.x, 0, pos.y)
        add_child(animal)
        _mesh_sphere(animal, 0.58, Vector3(0, 0.65, 0), Color("a88465"), Vector3(1.3, 0.75, 0.7))
        _mesh_sphere(animal, 0.34, Vector3(0.7, 0.85, 0), Color("c29a77"))
        animals.append({"node": animal, "pos": pos, "dir": Vector2.RIGHT.rotated(rng.randf_range(0, TAU)), "timer": rng.randf_range(1, 3)})

func _create_ui() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    hud.add_child(root)
    var top := HBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 20
    top.offset_top = 12
    top.offset_right = -20
    top.offset_bottom = 65
    root.add_child(top)
    info_label = Label.new()
    info_label.add_theme_font_size_override("font_size", 24)
    info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(info_label)
    bag_button = Button.new()
    bag_button.text = "🎒 Рюкзак"
    bag_button.custom_minimum_size = Vector2(145, 56)
    bag_button.pressed.connect(_toggle_bag)
    top.add_child(bag_button)
    var bottom := VBoxContainer.new()
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 210
    bottom.offset_right = -210
    bottom.offset_top = -92
    bottom.offset_bottom = -15
    root.add_child(bottom)
    bag_fly = Label.new()
    bag_fly.visible = false
    bag_fly.add_theme_font_size_override("font_size", 27)
    bag_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(bag_fly)
    zoom_label = Label.new()
    zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    zoom_label.add_theme_font_size_override("font_size", 19)
    bottom.add_child(zoom_label)
    progress_bar = ProgressBar.new()
    progress_bar.max_value = 100
    progress_bar.custom_minimum_size.y = 22
    progress_bar.visible = false
    bottom.add_child(progress_bar)
    bag_panel = PanelContainer.new()
    bag_panel.set_anchors_preset(Control.PRESET_CENTER)
    bag_panel.offset_left = -170
    bag_panel.offset_right = 170
    bag_panel.offset_top = -125
    bag_panel.offset_bottom = 125
    bag_panel.visible = false
    root.add_child(bag_panel)
    var bag_col := VBoxContainer.new()
    bag_panel.add_child(bag_col)
    bag_label = Label.new()
    bag_label.add_theme_font_size_override("font_size", 25)
    bag_col.add_child(bag_label)
    var close := Button.new()
    close.text = "Закрыть"
    close.pressed.connect(_toggle_bag)
    bag_col.add_child(close)

func _toggle_bag() -> void:
    bag_panel.visible = not bag_panel.visible
    _update_ui()

func _zoom(amount: float) -> void:
    camera_distance = clampf(camera_distance + amount, 7.0, 29.0)
    _position_camera()
    _update_ui()

func _update_ui() -> void:
    info_label.text = "ДИКИЙ КРАЙ 3D   |   " + status_message
    zoom_label.text = "Слева — движение  •  Нажми на предмет  •  Два пальца — масштаб"
    bag_label.text = "🎒 РЮКЗАК\n\n🪵 Дерево: %d\n🪨 Камень: %d\n🫐 Ягоды: %d" % [inventory["wood"], inventory["stone"], inventory["berry"]]

func _nearest_resource() -> int:
    var closest := -1
    var best := 2.8
    var p := Vector2(player.position.x, player.position.z)
    for i in range(resources.size()):
        if not resources[i]["alive"]:
            continue
        var d := p.distance_to(resources[i]["pos"])
        if d < best:
            best = d
            closest = i
    return closest

func _tap_world(screen: Vector2) -> void:
    if camera == null or bag_panel.visible:
        return
    var origin := camera.project_ray_origin(screen)
    var ray_dir := camera.project_ray_normal(screen)
    if absf(ray_dir.y) < 0.001:
        return
    var ground := origin + ray_dir * (-origin.y / ray_dir.y)
    var pos := Vector2(ground.x, ground.z)
    var best := 1.65
    pending_kind = ""
    pending_index = -1
    for i in range(drops.size()):
        var dist: float = pos.distance_to(drops[i]["pos"])
        if dist < best:
            best = dist
            pending_kind = "drop"
            pending_index = i
    if pending_kind == "":
        best = 2.0
        for i in range(resources.size()):
            if not resources[i]["alive"]:
                continue
            var dist: float = pos.distance_to(resources[i]["pos"])
            if dist < best:
                best = dist
                pending_kind = "resource"
                pending_index = i
    if pending_index < 0:
        return
    pending_pos = drops[pending_index]["pos"] if pending_kind == "drop" else resources[pending_index]["pos"]
    status_message = "Подходим к предмету…"
    _update_ui()

func _begin_mining(index: int) -> void:
    target_resource = index
    mining_active = true
    mining_progress = 0.0
    status_message = "Добываем ресурс…"
    _update_ui()

func _stop_mining() -> void:
    mining_active = false
    mining_progress = 0.0
    progress_bar.visible = false

func _finish_mining() -> void:
    var r: Dictionary = resources[target_resource]
    r["alive"] = false
    r["node"].queue_free()
    resources[target_resource] = r
    for i in range(obstacles.size() - 1, -1, -1):
        if obstacles[i]["node"] == r["node"]:
            obstacles.remove_at(i)
    var kind: String = "wood" if r["kind"] == "tree" else "stone" if r["kind"] == "rock" else "berry"
    var drop := Node3D.new()
    drop.position = Vector3(r["pos"].x, 0.35, r["pos"].y)
    add_child(drop)
    _mesh_sphere(drop, 0.28, Vector3.ZERO, Color("bd8b52") if kind == "wood" else Color("c0c5c8") if kind == "stone" else Color("bd394e"))
    drops.append({"kind": kind, "pos": r["pos"], "node": drop})
    status_message = "Ресурс выпал — нажми на него"
    _stop_mining()
    _update_ui()

func _pickup_index(index: int) -> void:
    if index < 0 or index >= drops.size():
        return
    var item: Dictionary = drops[index]
    var world_pos: Vector3 = item["node"].global_position
    var start: Vector2 = camera.unproject_position(world_pos)
    pickup_flight = {"kind": item["kind"], "start": start}
    pickup_time = 0.0
    bag_fly.text = "● +1"
    bag_fly.position = start
    bag_fly.visible = true
    item["node"].queue_free()
    drops.remove_at(index)
    status_message = "Предмет летит в рюкзак…"
    _update_ui()

func _animate_pickup(delta: float) -> void:
    if pickup_flight.is_empty():
        return
    pickup_time += delta
    var t := clampf(pickup_time / 0.65, 0.0, 1.0)
    var end := bag_button.get_global_rect().get_center()
    var start: Vector2 = pickup_flight["start"]
    bag_fly.position = start.lerp(end, t) + Vector2(0, -75.0 * sin(t * PI))
    bag_fly.scale = Vector2.ONE * (1.0 - 0.35 * t)
    if t >= 1.0:
        var kind: String = pickup_flight["kind"]
        inventory[kind] += 1
        pickup_flight.clear()
        bag_fly.visible = false
        bag_fly.scale = Vector2.ONE
        status_message = "В рюкзаке: +1 " + kind
        _update_ui()

func _blocked(pos: Vector2, radius: float) -> bool:
    if absf(pos.x) > WORLD_LIMIT or absf(pos.y) > WORLD_LIMIT:
        return true
    # На берег можно зайти немного, но глубже 0.45 м — нельзя.
    if _is_lake(pos, radius - 0.45):
        return true
    for obstacle in obstacles:
        if pos.distance_to(obstacle["pos"]) < radius + obstacle["radius"]:
            return true
    return false

func _physics_process(delta: float) -> void:
    _animate_pickup(delta)
    if pending_index >= 0:
        var here := Vector2(player.position.x, player.position.z)
        if here.distance_to(pending_pos) <= 2.25:
            if pending_kind == "resource" and pending_index < resources.size() and resources[pending_index]["alive"]:
                _begin_mining(pending_index)
            elif pending_kind == "drop" and pending_index < drops.size():
                _pickup_index(pending_index)
            pending_index = -1
            pending_kind = ""
    var direction := touch_move
    if pending_index >= 0 and joystick_touch == -1:
        var towards := pending_pos - Vector2(player.position.x, player.position.z)
        if towards.length() > 1.95:
            direction = towards.normalized()
    direction += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    direction = direction.limit_length(1.0)
    var current := Vector2(player.position.x, player.position.z)
    var motion := direction * WALK_SPEED * delta
    var next_x := current + Vector2(motion.x, 0)
    if not _blocked(next_x, PLAYER_RADIUS):
        current.x = next_x.x
    var next_y := current + Vector2(0, motion.y)
    if not _blocked(next_y, PLAYER_RADIUS):
        current.y = next_y.y
    player.position.x = current.x
    player.position.z = current.y
    _position_camera()
    if mining_active:
        if target_resource < 0 or not resources[target_resource]["alive"] or Vector2(player.position.x, player.position.z).distance_to(resources[target_resource]["pos"]) > 2.85:
            _stop_mining()
            status_message = "Слишком далеко — добыча прервана"
            _update_ui()
        else:
            mining_progress += delta
            progress_bar.visible = true
            progress_bar.value = 100.0 * mining_progress / resources[target_resource]["duration"]
            if mining_progress >= resources[target_resource]["duration"]:
                _finish_mining()
    _move_animals(delta)

func _move_animals(delta: float) -> void:
    for animal in animals:
        animal["timer"] -= delta
        if animal["timer"] <= 0:
            animal["timer"] = rng.randf_range(1.0, 3.0)
            animal["dir"] = Vector2.RIGHT.rotated(rng.randf_range(0, TAU))
        var new_pos: Vector2 = animal["pos"] + animal["dir"] * delta * 1.2
        if _blocked(new_pos, 0.5):
            animal["dir"] = -animal["dir"].rotated(rng.randf_range(-0.8, 0.8))
        else:
            animal["pos"] = new_pos
            animal["node"].position.x = new_pos.x
            animal["node"].position.z = new_pos.y

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            active_touches[event.index] = event.position
            if active_touches.size() == 1 and event.position.x < get_viewport().get_visible_rect().size.x * 0.46:
                joystick_touch = event.index
                joystick_origin = event.position
            if active_touches.size() == 2:
                touch_move = Vector2.ZERO
                joystick_touch = -1
                var pts := active_touches.values()
                pinch_previous = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
        else:
            active_touches.erase(event.index)
            if event.index == joystick_touch:
                joystick_touch = -1
                touch_move = Vector2.ZERO
                if event.position.distance_to(joystick_origin) < 18.0:
                    _tap_world(event.position)
            elif active_touches.is_empty() and pinch_previous <= 0.0:
                _tap_world(event.position)
            if active_touches.size() < 2:
                pinch_previous = 0.0
    elif event is InputEventScreenDrag:
        active_touches[event.index] = event.position
        if active_touches.size() == 2:
            var pts := active_touches.values()
            var new_distance: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
            if pinch_previous > 0.0:
                _zoom((pinch_previous - new_distance) * 0.035)
            pinch_previous = new_distance
        elif event.index == joystick_touch:
            touch_move = ((event.position - joystick_origin) / 65.0).limit_length(1.0)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(-1.0)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(1.0)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            _tap_world(event.position)
