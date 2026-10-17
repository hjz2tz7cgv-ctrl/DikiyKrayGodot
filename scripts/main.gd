extends Node3D

# Дикий край — самодостаточный Godot 4 3D прототип для Web/iPhone.
const WALK_SPEED := 5.0
const PLAYER_RADIUS := 0.48
const LAKE_CENTER := Vector2(18.0, -14.0)
const LAKE_RADIUS := 9.0
const WORLD_LIMIT := 64.0

var player: CharacterBody3D
var camera: Camera3D
var camera_distance := 17.0
var camera_tilt := 0.68
var camera_yaw := 0.0
var desired_camera_yaw := 0.0
var camera_focus := Vector3.ZERO
var camera_initialized := false
var camera_follow_yaw := 0.0
var player_visual: Node3D
var player_facing := 0.0
const FIRE_POS := Vector2(-3.0, 4.0)
const BENCH_POS := Vector2(-3.0, 7.1)
var campfire_node: Node3D
var campfire_light: OmniLight3D
var fire_flames: Array[MeshInstance3D] = []
var sitting := false
var camp_time := 0.0
var obstacles: Array[Dictionary] = []
var resources: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var scenery: Array[Node3D] = []
var inventory := {"wood": 0, "stone": 0, "berry": 0, "meat": 0, "hide": 0, "mushroom": 0, "cooked_meat": 0}
var hunger := 100.0
var thirst := 100.0
var survival_label: Label
var survival_buttons: Array[Button] = []
var has_spear := false
var hunt_target := -1
var attack_cooldown := 0.0
var craft_button: Button
var craft_panel: PanelContainer
var craft_recipe_button: Button
var target_resource := -1
var mining_progress := 0.0
var mining_active := false
var touch_move := Vector2.ZERO
var joystick_touch := -1
var joystick_origin := Vector2.ZERO
var gather_touch := -1
var gather_origin := Vector2.ZERO
var gather_direction := Vector2.ZERO
var camera_input_yaw := 0.0
var joystick_basis_yaw := 0.0
var active_touches := {}
var pinch_previous := 0.0
var pinch_in_progress := false
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

# 24 минуты реального времени = одни игровые сутки.
const DAY_SECONDS := 1440.0
const TENT_POS := Vector2(4.8, 3.5)
var day_clock := 9.0
var day_count := 1
var sun_light: DirectionalLight3D
var sky_environment: Environment
var tent_node: Node3D
var sleep_panel: PanelContainer
var time_label: Label
var sleep_fade: ColorRect
var sleep_in_progress := false
var sleep_elapsed := 0.0

func _ready() -> void:
    rng.seed = 20261017
    _create_world()
    _create_tent()
    _create_camp()
    _create_player()
    _create_camera()
    _create_resources()
    _create_scenery()
    _create_animals()
    _create_ui()
    _update_lighting()
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
    _mesh_box(self, Vector3(132, 0.3, 132), Vector3(0, -0.2, 0), Color("628a51"))
    var water := _mesh_sphere(self, LAKE_RADIUS, Vector3(LAKE_CENTER.x, -0.15, LAKE_CENTER.y), Color("3d9dc0"), Vector3(1.0, 0.018, 1.0))
    water.name = "Lake"
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-58, -35, 0)
    sun.light_energy = 1.1
    add_child(sun)
    sun_light = sun
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("8cb9d2")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("d9e6de")
    e.ambient_light_energy = 0.8
    env.environment = e
    sky_environment = e
    add_child(env)

func _create_tent() -> void:
    # Палатка на стартовой поляне. Простая геометрия для WebGL/iPhone.
    tent_node = Node3D.new()
    tent_node.name = "StartTent"
    tent_node.position = Vector3(TENT_POS.x, 0.0, TENT_POS.y)
    add_child(tent_node)
    _mesh_box(tent_node, Vector3(3.7, 0.14, 3.2), Vector3(0, 0.03, 0), Color("554637"))
    var cloth := Color("b9a16d")
    var roof_left := _mesh_box(tent_node, Vector3(2.45, 0.12, 3.35), Vector3(-0.88, 1.05, 0), cloth)
    roof_left.rotation.z = -0.85
    var roof_right := _mesh_box(tent_node, Vector3(2.45, 0.12, 3.35), Vector3(0.88, 1.05, 0), cloth)
    roof_right.rotation.z = 0.85
    _mesh_box(tent_node, Vector3(1.35, 1.45, 0.12), Vector3(0, 0.77, -1.67), Color("806a48"))
    _mesh_box(tent_node, Vector3(1.1, 1.15, 0.13), Vector3(0, 0.61, 1.68), Color("473d35"))
    _mesh_box(tent_node, Vector3(0.18, 2.2, 0.18), Vector3(0, 1.13, -1.75), Color("6d4d2d"))

func _create_camp() -> void:
    # Camp placed close to spawn, deliberately away from the tent and lake.
    campfire_node = Node3D.new()
    campfire_node.name = "Campfire_Cauldron"
    campfire_node.position = Vector3(FIRE_POS.x, 0, FIRE_POS.y)
    add_child(campfire_node)
    _mesh_sphere(campfire_node, 1.25, Vector3(0, 0.055, 0), Color("514d40"), Vector3(1.0, 0.12, 1.0))
    for i in range(9):
        var a := TAU * float(i) / 9.0
        _mesh_sphere(campfire_node, 0.23, Vector3(cos(a) * 0.9, 0.16, sin(a) * 0.9), Color("8b8d87"), Vector3(1.2, 0.7, 0.8))
    for i in range(4):
        var log := _mesh_box(campfire_node, Vector3(1.4, 0.22, 0.24), Vector3(0, 0.24, 0), Color("67412b"))
        log.rotation.y = float(i) * PI / 4.0
    for i in range(3):
        var flame := _mesh_sphere(campfire_node, 0.28, Vector3((i - 1) * 0.23, 0.72, 0), Color("ff9b29") if i != 1 else Color("ffe069"), Vector3(0.62, 1.75, 0.62))
        var fm := flame.material_override as StandardMaterial3D
        fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        fire_flames.append(flame)
    campfire_light = OmniLight3D.new()
    campfire_light.position = Vector3(0, 1.6, 0)
    campfire_light.light_color = Color("ffb36a")
    campfire_light.light_energy = 1.7
    campfire_light.omni_range = 9.0
    campfire_light.shadow_enabled = false
    campfire_node.add_child(campfire_light)
    # Iron cooking pot, supported by two wooden posts.
    for x in [-1.15, 1.15]:
        _mesh_box(campfire_node, Vector3(0.13, 2.0, 0.13), Vector3(x, 1.02, 0), Color("6b4c35"))
    _mesh_box(campfire_node, Vector3(2.55, 0.13, 0.13), Vector3(0, 2.02, 0), Color("6b4c35"))
    _mesh_box(campfire_node, Vector3(0.06, 0.56, 0.06), Vector3(0, 1.69, 0), Color("454545"))
    _mesh_sphere(campfire_node, 0.46, Vector3(0, 1.22, 0), Color("34393b"), Vector3(1.0, 0.68, 1.0))
    _mesh_box(campfire_node, Vector3(0.9, 0.07, 0.9), Vector3(0, 1.49, 0), Color("303436"))
    var bench := Node3D.new()
    bench.name = "Sit_Bench"
    bench.position = Vector3(BENCH_POS.x, 0, BENCH_POS.y)
    add_child(bench)
    _mesh_box(bench, Vector3(2.7, 0.23, 0.75), Vector3(0, 0.8, 0), Color("926b46"))
    _mesh_box(bench, Vector3(2.7, 0.8, 0.19), Vector3(0, 1.3, 0.32), Color("815b39"))
    for x in [-1.05, 1.05]:
        _mesh_box(bench, Vector3(0.2, 0.77, 0.2), Vector3(x, 0.37, 0), Color("65432d"))
    # A few stepping stones lead from the tent to the fire.
    for i in range(7):
        var t := float(i) / 6.0
        var pp := TENT_POS.lerp(FIRE_POS, t)
        _mesh_sphere(self, 0.42, Vector3(pp.x, 0.035, pp.y), Color("a49576"), Vector3(1.1, 0.12, 0.75))

func _animate_camp(delta: float) -> void:
    camp_time += delta
    for i in range(fire_flames.size()):
        var flame := fire_flames[i]
        flame.scale.y = 1.5 + 0.26 * sin(camp_time * 6.0 + float(i) * 2.2)
        flame.position.y = 0.72 + 0.07 * sin(camp_time * 7.0 + float(i))
    if campfire_light != null:
        campfire_light.light_energy = 1.5 + 0.23 * sin(camp_time * 8.0)

func _update_lighting() -> void:
    # Плавное освещение без тяжёлых эффектов постобработки.
    var phase := (day_clock - 6.0) / 24.0 * TAU
    var daylight := clampf(sin(phase), 0.0, 1.0)
    var twilight := clampf(sin(phase) * 2.0 + 0.20, 0.0, 1.0)
    if sun_light != null:
        sun_light.rotation_degrees = Vector3(-12.0 - 68.0 * daylight, -35.0 + day_clock * 8.0, 0)
        sun_light.light_energy = lerpf(0.07, 1.15, daylight)
    if sky_environment != null:
        sky_environment.background_color = Color("101c38").lerp(Color("91bfd7"), twilight)
        sky_environment.ambient_light_color = Color("66738e").lerp(Color("e1e9dd"), twilight)
        sky_environment.ambient_light_energy = lerpf(0.27, 0.83, twilight)

func _start_sleep() -> void:
    if sleep_in_progress:
        return
    sleep_panel.visible = false
    sleep_in_progress = true
    sleep_elapsed = 0.0
    pending_kind = ""
    pending_index = -1
    touch_move = Vector2.ZERO
    mining_active = false
    progress_bar.visible = false
    status_message = "Отдыхаем в палатке…"
    _update_ui()

func _advance_sleep(delta: float) -> void:
    if not sleep_in_progress:
        return
    sleep_elapsed += delta
    var alpha := sin(clampf(sleep_elapsed / 2.0, 0.0, 1.0) * PI)
    sleep_fade.color = Color(0.015, 0.025, 0.06, alpha)
    if sleep_elapsed >= 1.0 and day_clock != 7.0:
        if day_clock >= 7.0:
            day_count += 1
        day_clock = 7.0
        _update_lighting()
    if sleep_elapsed >= 2.0:
        sleep_in_progress = false
        sleep_fade.color = Color(0, 0, 0, 0)
        status_message = "Доброе утро! День %d" % day_count
        _update_ui()

func _show_sleep_panel() -> void:
    pending_kind = ""
    pending_index = -1
    sleep_panel.visible = true
    status_message = "Палатка: можно поспать до утра"
    _update_ui()

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
    player_visual = Node3D.new()
    player.add_child(player_visual)
    _mesh_sphere(player_visual, 0.55, Vector3(0, 0.0, 0), Color("d7a579"), Vector3(0.8, 1.25, 0.7))
    _mesh_sphere(player_visual, 0.34, Vector3(0, 0.9, 0), Color("edc59b"))
    _mesh_box(player_visual, Vector3(0.7, 0.15, 0.18), Vector3(0, 0.5, -0.3), Color("4c7050"))

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 54.0
    add_child(camera)
    _position_camera(0.016)

func _position_camera(delta: float = 0.0) -> void:
    if camera == null or player == null:
        return
    # Фиксированный угол: персонаж НЕ поворачивает камеру.
    # Камера следует за положением героя, угол меняется только свайпом справа.
    var target_focus := player.global_position + Vector3(0.0, 0.35, 0.0)
    if not camera_initialized:
        camera_focus = target_focus
        camera_initialized = true
    elif delta > 0.0:
        camera_focus = camera_focus.lerp(target_focus, 1.0 - exp(-7.0 * delta))
    else:
        camera_focus = target_focus
    var backward := Vector3(sin(camera_input_yaw), 0.0, cos(camera_input_yaw))
    camera.global_position = camera_focus + backward * camera_distance * camera_tilt + Vector3.UP * camera_distance
    camera.look_at(camera_focus, Vector3.UP)

func _is_lake(pos: Vector2, margin := 0.0) -> bool:
    return pos.distance_to(LAKE_CENTER) < LAKE_RADIUS + margin

func _can_place(pos: Vector2, radius: float) -> bool:
    if _is_lake(pos, radius + 0.3):
        return false
    if pos.length() < 3.3 or pos.distance_to(TENT_POS) < radius + 3.5 or pos.distance_to(FIRE_POS) < radius + 3.2 or pos.distance_to(BENCH_POS) < radius + 2.4:
        return false
    for obstacle in obstacles:
        if pos.distance_to(obstacle["pos"]) < radius + obstacle["radius"] + 1.0:
            return false
    return true

func _random_land_pos(edge: float = 59.0) -> Vector2:
    return Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))

func _create_resources() -> void:
    # Больше ресурсов, но без тяжёлых импортированных моделей.
    for i in range(112):
        var kind := "tree" if i < 72 else "rock"
        var radius := 0.85 if kind == "tree" else 0.7
        var pos := Vector2.ZERO
        var found := false
        for attempt in range(90):
            pos = _random_land_pos()
            if _can_place(pos, radius):
                found = true
                break
        if not found:
            continue
        var node := Node3D.new()
        node.position = Vector3(pos.x, 0, pos.y)
        add_child(node)
        if kind == "tree":
            var tall := rng.randf_range(0.85, 1.4)
            var species := i % 4
            var bark := Color("d8d2c3") if species == 1 else Color("765238")
            _mesh_box(node, Vector3(0.48 if species == 1 else 0.65, 2.5 * tall, 0.48 if species == 1 else 0.65), Vector3(0, 1.25 * tall, 0), bark)
            if species == 0: # Spruce
                for layer in range(3):
                    _mesh_sphere(node, 1.1 - layer * 0.22, Vector3(0, (2.25 + layer * 0.72) * tall, 0), Color("245b3d"), Vector3(0.9, 0.85, 0.9))
            elif species == 1: # Birch
                for stripe in range(3):
                    _mesh_box(node, Vector3(0.5, 0.08, 0.5), Vector3(0, (0.8 + stripe * 0.55) * tall, 0), Color("4e504b"))
                _mesh_sphere(node, 1.2, Vector3(0, 2.65 * tall, 0), Color("75a65a"), Vector3(0.85, 1.05, 0.85))
            elif species == 2: # Oak
                _mesh_sphere(node, 1.55, Vector3(0, 2.55 * tall, 0), Color("387b3c"), Vector3(1.25, 0.78, 1.1))
                _mesh_sphere(node, 0.85, Vector3(0.9, 2.75 * tall, 0), Color("438a45"))
            else: # Pine
                _mesh_sphere(node, 1.05, Vector3(0, 2.9 * tall, 0), Color("317049"), Vector3(0.9, 1.45, 0.9))
                _mesh_sphere(node, 0.7, Vector3(0, 3.7 * tall, 0), Color("28643e"))
        else:
            var rock_color := Color("929c9a") if i % 3 else Color("777f86")
            _mesh_sphere(node, rng.randf_range(0.65, 1.05), Vector3(0, 0.55, 0), rock_color, Vector3(1.1, 0.65, 0.9))
        obstacles.append({"pos": pos, "radius": radius, "node": node})
        resources.append({"kind": kind, "pos": pos, "node": node, "duration": 2.4 if kind == "tree" else 3.4, "alive": true})
    for i in range(48):
        var pos := _random_land_pos()
        if not _can_place(pos, 0.4):
            continue
        var bush := Node3D.new()
        bush.position = Vector3(pos.x, 0, pos.y)
        add_child(bush)
        _mesh_sphere(bush, 0.55, Vector3(0, 0.4, 0), Color("317d45"))
        for j in range(4):
            _mesh_sphere(bush, 0.1, Vector3(rng.randf_range(-0.35, 0.35), 0.65, rng.randf_range(-0.35, 0.35)), Color("c64248"))
        resources.append({"kind": "berry", "pos": pos, "node": bush, "duration": 1.3, "alive": true})

    # Съедобные грибы: отдельные лесные ресурсы.
    for i in range(32):
        var pos := _random_land_pos()
        if not _can_place(pos, 0.35):
            continue
        var mushroom := Node3D.new()
        mushroom.position = Vector3(pos.x, 0, pos.y)
        add_child(mushroom)
        _mesh_box(mushroom, Vector3(0.13, 0.32, 0.13), Vector3(0, 0.16, 0), Color("e8d9b4"))
        _mesh_sphere(mushroom, 0.27, Vector3(0, 0.37, 0), Color("b76b3e"), Vector3(1.0, 0.48, 1.0))
        resources.append({"kind": "mushroom", "pos": pos, "node": mushroom, "duration": 1.2, "alive": true})

func _create_scenery() -> void:
    # Небольшие декоративные поляны и цветы, не блокирующие движение.
    for i in range(95):
        var pos := _random_land_pos()
        if _is_lake(pos, 0.5) or pos.length() < 3.0:
            continue
        var tuft := Node3D.new()
        tuft.position = Vector3(pos.x, 0, pos.y)
        add_child(tuft)
        var color := Color("8baf58") if i % 4 else Color("e2cf83")
        _mesh_sphere(tuft, 0.23, Vector3(0, 0.12, 0), color, Vector3(1.0, 0.4, 0.8))
        scenery.append(tuft)

func _create_animals() -> void:
    # Зайцы, олени и кабаны мирно бродят по миру.
    for i in range(19):
        var pos := _random_land_pos(53.0)
        for attempt in range(40):
            if not _is_lake(pos, 1.5) and not _blocked(pos, 0.8):
                break
            pos = _random_land_pos(53.0)
        if _blocked(pos, 0.8):
            continue
        var animal := Node3D.new()
        animal.position = Vector3(pos.x, 0, pos.y)
        add_child(animal)
        var species := "rabbit" if i % 3 == 0 else "deer" if i % 3 == 1 else "boar"
        var speed := 1.7 if species == "rabbit" else 1.25 if species == "deer" else 0.9
        if species == "rabbit":
            _mesh_sphere(animal, 0.35, Vector3(0, 0.34, 0), Color("c7bba4"), Vector3(1.15, 0.8, 0.8))
            _mesh_sphere(animal, 0.22, Vector3(0.36, 0.46, 0), Color("d5c9b5"))
            _mesh_sphere(animal, 0.12, Vector3(0.38, 0.79, -0.13), Color("d5c9b5"), Vector3(0.55, 2.0, 0.5))
            _mesh_sphere(animal, 0.12, Vector3(0.38, 0.79, 0.13), Color("d5c9b5"), Vector3(0.55, 2.0, 0.5))
        elif species == "deer":
            _mesh_sphere(animal, 0.58, Vector3(0, 0.85, 0), Color("ae835f"), Vector3(1.3, 0.75, 0.65))
            _mesh_sphere(animal, 0.28, Vector3(0.75, 1.05, 0), Color("c49a75"))
            for z in [-0.34, 0.34]:
                _mesh_box(animal, Vector3(0.12, 0.75, 0.12), Vector3(-0.35, 0.38, z), Color("76523d"))
                _mesh_box(animal, Vector3(0.12, 0.75, 0.12), Vector3(0.35, 0.38, z), Color("76523d"))
        else:
            _mesh_sphere(animal, 0.62, Vector3(0, 0.6, 0), Color("665044"), Vector3(1.35, 0.8, 0.8))
            _mesh_sphere(animal, 0.29, Vector3(0.75, 0.64, 0), Color("856859"))
            _mesh_sphere(animal, 0.16, Vector3(0.98, 0.58, 0), Color("a48477"), Vector3(0.45, 0.8, 1.0))
        animals.append({"node": animal, "pos": pos, "dir": Vector2.RIGHT.rotated(rng.randf_range(0, TAU)), "timer": rng.randf_range(1.0, 3.0), "speed": speed, "species": species, "health": 2 if species == "rabbit" else 4 if species == "deer" else 5, "alive": true})

func _create_ui() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    bag_button.text = "Рюкзак"
    bag_button.custom_minimum_size = Vector2(145, 56)
    bag_button.pressed.connect(_toggle_bag)
    top.add_child(bag_button)
    craft_button = Button.new()
    craft_button.text = "Крафт"
    craft_button.custom_minimum_size = Vector2(110, 56)
    craft_button.pressed.connect(_toggle_craft)
    top.add_child(craft_button)
    time_label = Label.new()
    time_label.add_theme_font_size_override("font_size", 20)
    top.add_child(time_label)
    # Две компактные кнопки масштаба по центру сверху.
    var zoom_controls := HBoxContainer.new()
    zoom_controls.set_anchors_preset(Control.PRESET_CENTER_TOP)
    zoom_controls.offset_left = -57
    zoom_controls.offset_right = 57
    zoom_controls.offset_top = 76
    zoom_controls.offset_bottom = 116
    zoom_controls.add_theme_constant_override("separation", 8)
    root.add_child(zoom_controls)
    var zoom_out_button := Button.new()
    zoom_out_button.text = "−"
    zoom_out_button.custom_minimum_size = Vector2(52, 40)
    zoom_out_button.pressed.connect(_zoom.bind(1.5))
    zoom_controls.add_child(zoom_out_button)
    var zoom_in_button := Button.new()
    zoom_in_button.text = "+"
    zoom_in_button.custom_minimum_size = Vector2(52, 40)
    zoom_in_button.pressed.connect(_zoom.bind(-1.5))
    zoom_controls.add_child(zoom_in_button)
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
    bag_panel.offset_top = -235
    bag_panel.offset_bottom = 235
    bag_panel.visible = false
    root.add_child(bag_panel)
    var bag_col := VBoxContainer.new()
    bag_panel.add_child(bag_col)
    survival_label = Label.new()
    survival_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    survival_label.offset_left = 20
    survival_label.offset_top = 74
    survival_label.offset_right = -20
    survival_label.offset_bottom = 112
    survival_label.add_theme_font_size_override("font_size", 20)
    survival_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(survival_label)
    bag_label = Label.new()
    bag_label.add_theme_font_size_override("font_size", 25)
    bag_col.add_child(bag_label)
    for entry in [["Съесть ягоды", "berry"], ["Съесть гриб", "mushroom"], ["Съесть жареное мясо", "cooked_meat"], ["Пожарить мясо у костра", "cook"], ["Набрать воды у озера", "water"]]:
        var use_button := Button.new()
        use_button.text = entry[0]
        use_button.custom_minimum_size.y = 43
        use_button.pressed.connect(_survival_action.bind(entry[1]))
        bag_col.add_child(use_button)
        survival_buttons.append(use_button)
    var close := Button.new()
    close.text = "Закрыть"
    close.pressed.connect(_toggle_bag)
    bag_col.add_child(close)
    # Отдельное окно крафта: ресурсы расходуются только по кнопке «Создать».
    craft_panel = PanelContainer.new()
    craft_panel.set_anchors_preset(Control.PRESET_CENTER)
    craft_panel.offset_left = -190
    craft_panel.offset_right = 190
    craft_panel.offset_top = -125
    craft_panel.offset_bottom = 125
    craft_panel.visible = false
    root.add_child(craft_panel)
    var craft_col := VBoxContainer.new()
    craft_panel.add_child(craft_col)
    var craft_title := Label.new()
    craft_title.text = "МАСТЕРСКАЯ\nДеревянное копьё"
    craft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    craft_title.add_theme_font_size_override("font_size", 25)
    craft_col.add_child(craft_title)
    var craft_description := Label.new()
    craft_description.text = "Для охоты\nНужно: 3 дерева и 1 камень"
    craft_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    craft_col.add_child(craft_description)
    craft_recipe_button = Button.new()
    craft_recipe_button.custom_minimum_size.y = 55
    craft_recipe_button.pressed.connect(_craft_spear)
    craft_col.add_child(craft_recipe_button)
    var craft_close := Button.new()
    craft_close.text = "Закрыть"
    craft_close.custom_minimum_size.y = 48
    craft_close.pressed.connect(_toggle_craft)
    craft_col.add_child(craft_close)
    sleep_panel = PanelContainer.new()
    sleep_panel.set_anchors_preset(Control.PRESET_CENTER)
    sleep_panel.offset_left = -190
    sleep_panel.offset_right = 190
    sleep_panel.offset_top = -110
    sleep_panel.offset_bottom = 110
    sleep_panel.visible = false
    root.add_child(sleep_panel)
    var sleep_col := VBoxContainer.new()
    sleep_panel.add_child(sleep_col)
    var sleep_title := Label.new()
    sleep_title.text = "ПАЛАТКА\nОтдохнуть до утра?"
    sleep_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sleep_title.add_theme_font_size_override("font_size", 25)
    sleep_col.add_child(sleep_title)
    var sleep_yes := Button.new()
    sleep_yes.text = "Спать до утра"
    sleep_yes.pressed.connect(_start_sleep)
    sleep_col.add_child(sleep_yes)
    var sleep_no := Button.new()
    sleep_no.text = "Отмена"
    sleep_no.pressed.connect(func(): sleep_panel.visible = false)
    sleep_col.add_child(sleep_no)
    sleep_fade = ColorRect.new()
    sleep_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sleep_fade.color = Color(0, 0, 0, 0)
    sleep_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(sleep_fade)

func _toggle_craft() -> void:
    craft_panel.visible = not craft_panel.visible
    if craft_panel.visible:
        bag_panel.visible = false
        sleep_panel.visible = false
    _update_ui()

func _craft_spear() -> void:
    if has_spear:
        status_message = "Копьё уже изготовлено"
    elif inventory["wood"] >= 3 and inventory["stone"] >= 1:
        inventory["wood"] -= 3
        inventory["stone"] -= 1
        has_spear = true
        status_message = "Деревянное копьё готово! Нажми на животное"
    else:
        status_message = "Для копья нужны 3 дерева и 1 камень"
    _update_ui()

func _finish_hunt(index: int) -> void:
    var animal: Dictionary = animals[index]
    animal["alive"] = false
    animal["node"].queue_free()
    animals[index] = animal
    var pos: Vector2 = animal["pos"]
    for kind in ["meat", "hide"]:
        var drop := Node3D.new()
        drop.position = Vector3(pos.x + rng.randf_range(-0.45, 0.45), 0.35, pos.y + rng.randf_range(-0.45, 0.45))
        add_child(drop)
        _mesh_sphere(drop, 0.27, Vector3.ZERO, Color("bd625a") if kind == "meat" else Color("b9956a"))
        drops.append({"kind": kind, "pos": Vector2(drop.position.x, drop.position.z), "node": drop})
    hunt_target = -1
    status_message = "Охота завершена! Нажми на мясо и шкуру"
    _update_ui()

func _toggle_bag() -> void:
    bag_panel.visible = not bag_panel.visible
    _update_ui()

func _zoom(amount: float) -> void:
    camera_distance = clampf(camera_distance + amount, 5.5, 32.0)
    _position_camera()
    _update_ui()

func _update_ui() -> void:
    info_label.text = "ДИКИЙ КРАЙ 3D   |   " + status_message
    if survival_label != null:
        survival_label.text = "🍖 Голод: %d%%    💧 Жажда: %d%%" % [int(hunger), int(thirst)]
    if time_label != null:
        var hour := int(day_clock) % 24
        var minute := int((day_clock - floor(day_clock)) * 60.0)
        time_label.text = "День %d  %02d:%02d" % [day_count, hour, minute]
    zoom_label.text = "Слева — ходьба  •  Справа — добыча  •  Нажми на предмет"
    bag_label.text = "РЮКЗАК\\nДерево: %d  Камень: %d\\nЯгоды: %d  Грибы: %d\\nМясо: %d  Жареное: %d  Шкуры: %d\\nКопьё: %s" % [inventory["wood"], inventory["stone"], inventory["berry"], inventory["mushroom"], inventory["meat"], inventory["cooked_meat"], inventory["hide"], "есть" if has_spear else "нет"]
    if craft_recipe_button != null:
        craft_recipe_button.text = "Копьё уже создано" if has_spear else "Создать копьё (3 дерева + 1 камень)"
        craft_recipe_button.disabled = has_spear or inventory["wood"] < 3 or inventory["stone"] < 1

func _survival_action(kind: String) -> void:
    var here := Vector2(player.position.x, player.position.z)
    if kind == "water":
        if here.distance_to(LAKE_CENTER) <= LAKE_RADIUS + 2.5:
            thirst = minf(100.0, thirst + 65.0)
            status_message = "Фляга наполнена — ты попил воды"
        else:
            status_message = "Подойди к берегу озера"
    elif kind == "cook":
        if here.distance_to(FIRE_POS) > 4.0:
            status_message = "Готовить мясо можно только у костра"
        elif inventory["meat"] < 1 or inventory["wood"] < 1:
            status_message = "Для жарки нужны 1 мясо и 1 дерево"
        else:
            inventory["meat"] -= 1
            inventory["wood"] -= 1
            inventory["cooked_meat"] += 1
            status_message = "Мясо приготовлено!"
    elif inventory.get(kind, 0) <= 0:
        status_message = "Такой еды пока нет в рюкзаке"
    else:
        inventory[kind] -= 1
        if kind == "berry":
            hunger = minf(100.0, hunger + 12.0)
            thirst = minf(100.0, thirst + 4.0)
        elif kind == "mushroom":
            hunger = minf(100.0, hunger + 18.0)
        elif kind == "cooked_meat":
            hunger = minf(100.0, hunger + 42.0)
        status_message = "Ты поел"
    _update_ui()

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
    if camera == null or bag_panel.visible or sleep_panel.visible or sleep_in_progress:
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
    if pos.distance_to(BENCH_POS) < 2.0:
        pending_kind = "bench"
        pending_index = 0
    if pos.distance_to(TENT_POS) < 2.7:
        pending_kind = "tent"
        pending_index = 0
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
    # Выбор животного отдельным нажатием, без автоматической охоты поблизости.
    if pending_kind == "":
        var animal_best := 1.9
        for i in range(animals.size()):
            if not animals[i]["alive"]:
                continue
            var animal_dist: float = pos.distance_to(animals[i]["pos"])
            if animal_dist < animal_best:
                animal_best = animal_dist
                pending_kind = "animal"
                pending_index = i
    if pending_kind == "animal":
        if not has_spear:
            status_message = "Для охоты сначала изготовь копьё"
        else:
            hunt_target = pending_index
            status_message = "Охота! Персонаж преследует животное"
        pending_index = -1
        pending_kind = ""
        _update_ui()
        return
    if pending_index < 0:
        return
    if pending_kind == "tent":
        pending_pos = TENT_POS
    elif pending_kind == "bench":
        pending_pos = BENCH_POS
    else:
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
    var kind: String = "wood" if r["kind"] == "tree" else "stone" if r["kind"] == "rock" else "mushroom" if r["kind"] == "mushroom" else "berry"
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
    if sleep_in_progress:
        _advance_sleep(delta)
        return
    _animate_camp(delta)
    hunger = maxf(0.0, hunger - delta * 0.035)
    thirst = maxf(0.0, thirst - delta * 0.055)
    day_clock += delta * 24.0 / DAY_SECONDS
    if day_clock >= 24.0:
        day_clock -= 24.0
        day_count += 1
    _update_lighting()
    _animate_pickup(delta)
    if pending_index >= 0:
        var here := Vector2(player.position.x, player.position.z)
        if here.distance_to(pending_pos) <= 2.25:
            if pending_kind == "resource" and pending_index < resources.size() and resources[pending_index]["alive"]:
                _begin_mining(pending_index)
            elif pending_kind == "drop" and pending_index < drops.size():
                _pickup_index(pending_index)
            elif pending_kind == "tent":
                _show_sleep_panel()
            elif pending_kind == "bench":
                sitting = true
                player.position.x = BENCH_POS.x
                player.position.z = BENCH_POS.y - 0.15
                player_visual.position.y = -0.35
                status_message = "Отдыхаем у костра — двигайся, чтобы встать"
            pending_index = -1
            pending_kind = ""
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    # Джойстик задаёт направление относительно взгляда персонажа в момент касания.
    # Направление фиксируется до отпускания пальца, чтобы движение не закручивалось.
    var direction := Vector2.ZERO
    var steering_active := joystick_touch != -1 and touch_move.length() > 0.12
    if steering_active:
        direction = Vector2(
            cos(joystick_basis_yaw) * touch_move.x + sin(joystick_basis_yaw) * touch_move.y,
            -sin(joystick_basis_yaw) * touch_move.x + cos(joystick_basis_yaw) * touch_move.y
        )
        # Вперёд на джойстике означает туда, куда смотрел персонаж при касании.
        # Пока палец удерживается, базовый угол не пересчитывается от поворота персонажа.
        var desired_facing := atan2(-direction.x, -direction.y)
        player_facing = lerp_angle(player_facing, desired_facing, 1.0 - exp(-14.0 * delta))
        # Ручное управление отменяет автоподход к выбранному объекту.
        pending_index = -1
        pending_kind = ""
        hunt_target = -1
    elif pending_index >= 0 and joystick_touch == -1:
        var towards := pending_pos - Vector2(player.position.x, player.position.z)
        if towards.length() > 1.95:
            direction = towards.normalized()
            var desired_facing := atan2(-direction.x, -direction.y)
            player_facing = lerp_angle(player_facing, desired_facing, 1.0 - exp(-10.0 * delta))
    elif hunt_target >= 0 and hunt_target < animals.size() and animals[hunt_target]["alive"]:
        var prey: Dictionary = animals[hunt_target]
        var prey_offset: Vector2 = prey["pos"] - Vector2(player.position.x, player.position.z)
        if prey_offset.length() > 1.55:
            direction = prey_offset.normalized()
        elif attack_cooldown <= 0.0:
            attack_cooldown = 0.65
            prey["health"] = int(prey["health"]) - 1
            animals[hunt_target] = prey
            status_message = "Удар копьём!"
            if prey["health"] <= 0:
                _finish_hunt(hunt_target)
        if direction.length() > 0.1:
            var hunt_facing := atan2(-direction.x, -direction.y)
            player_facing = lerp_angle(player_facing, hunt_facing, 1.0 - exp(-10.0 * delta))
    var keyboard_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if keyboard_direction.length() > 0.12:
        hunt_target = -1
        direction = keyboard_direction
        var keyboard_facing := atan2(-direction.x, -direction.y)
        player_facing = lerp_angle(player_facing, keyboard_facing, 1.0 - exp(-10.0 * delta))
    direction = direction.limit_length(1.0)
    if sitting and (direction.length() > 0.1 or steering_active):
        sitting = false
        player_visual.position.y = 0.0
    if sitting:
        direction = Vector2.ZERO
    player_visual.rotation.y = player_facing
    # Камера ориентируется на реальный поворот модели, а не на касание.

    var current := Vector2(player.position.x, player.position.z)
    var survival_speed := 0.65 if hunger <= 0.0 or thirst <= 0.0 else 1.0
    var motion := direction * WALK_SPEED * survival_speed * delta
    var next_x := current + Vector2(motion.x, 0)
    if not _blocked(next_x, PLAYER_RADIUS):
        current.x = next_x.x
    var next_y := current + Vector2(0, motion.y)
    if not _blocked(next_y, PLAYER_RADIUS):
        current.y = next_y.y
    player.position.x = current.x
    player.position.z = current.y
    _position_camera(delta)
    if gather_touch != -1 and gather_direction.length() > 0.2 and not mining_active:
        var nearest := _nearest_resource()
        if nearest >= 0:
            _begin_mining(nearest)
    if gather_touch != -1 and gather_direction.length() <= 0.2 and mining_active:
        _stop_mining()
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
    _update_ui()

func _move_animals(delta: float) -> void:
    for i in range(animals.size()):
        var animal: Dictionary = animals[i]
        if not animal["alive"]:
            continue
        var hunted := hunt_target == i
        if hunted:
            var escape: Vector2 = animal["pos"] - Vector2(player.position.x, player.position.z)
            if escape.length() < 12.0 and escape.length() > 0.01:
                animal["dir"] = escape.normalized()
                animal["timer"] = 0.6
        animal["timer"] -= delta
        if animal["timer"] <= 0:
            animal["timer"] = rng.randf_range(1.0, 3.0)
            animal["dir"] = Vector2.RIGHT.rotated(rng.randf_range(0, TAU))
        var flee_speed: float = 3.2 if animal["species"] == "rabbit" else 3.6 if animal["species"] == "deer" else 2.4
        var actual_speed: float = flee_speed if hunted else animal["speed"]
        var new_pos: Vector2 = animal["pos"] + animal["dir"] * delta * actual_speed
        if _blocked(new_pos, 0.5):
            animal["dir"] = -animal["dir"].rotated(rng.randf_range(-0.8, 0.8))
        else:
            animal["pos"] = new_pos
            animal["node"].position.x = new_pos.x
            animal["node"].position.z = new_pos.y
        animals[i] = animal

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            active_touches[event.index] = event.position
            var viewport_width := get_viewport().get_visible_rect().size.x
            var viewport_height := get_viewport().get_visible_rect().size.y
            # Верхняя центральная область отдана кнопкам + и −.
            if event.position.y < 130.0 and absf(event.position.x - viewport_width * 0.5) < 85.0:
                return
            if event.position.y > viewport_height * 0.32 and event.position.x < viewport_width * 0.5 and joystick_touch == -1:
                joystick_touch = event.index
                joystick_origin = event.position
                joystick_basis_yaw = camera_input_yaw
                touch_move = Vector2.ZERO
            elif event.position.y > viewport_height * 0.25 and event.position.x >= viewport_width * 0.5 and gather_touch == -1:
                gather_touch = event.index
                gather_origin = event.position
                gather_direction = Vector2.ZERO
        else:
            active_touches.erase(event.index)
            if event.index == joystick_touch:
                joystick_touch = -1
                touch_move = Vector2.ZERO
                if event.position.distance_to(joystick_origin) < 18.0:
                    _tap_world(event.position)
            elif event.index == gather_touch:
                gather_touch = -1
                gather_direction = Vector2.ZERO
                if event.position.distance_to(gather_origin) < 18.0:
                    _tap_world(event.position)
            elif active_touches.is_empty() and not (event.position.y < 130.0 and absf(event.position.x - get_viewport().get_visible_rect().size.x * 0.5) < 85.0):
                _tap_world(event.position)
    elif event is InputEventScreenDrag:
        active_touches[event.index] = event.position
        if event.index == joystick_touch:
            touch_move = ((event.position - joystick_origin) / 65.0).limit_length(1.0)
        elif event.index == gather_touch:
            camera_input_yaw -= event.relative.x * 0.005
            _position_camera()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(-1.0)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(1.0)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            _tap_world(event.position)
