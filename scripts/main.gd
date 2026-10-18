extends Node3D

# Дикий край — самодостаточный Godot 4 3D прототип для Web/iPhone.
const WALK_SPEED := 5.0
const PLAYER_RADIUS := 0.48
const LAKE_CENTER := Vector2(18.0, -14.0)
const LAKE_RADIUS := 9.0
const WORLD_LIMIT := 240.0

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
const CABIN_POS := Vector2(-9.0, 31.0)
var cabin_searched := false
var cabin_note_found := false
var campfire_node: Node3D
var campfire_light: OmniLight3D
var fire_flames: Array[MeshInstance3D] = []
var sitting := false
var camp_time := 0.0
const COOK_SECONDS := 11.0
var cooking_active := false
var cooking_elapsed := 0.0
var leg_left: Node3D
var leg_right: Node3D
var obstacles: Array[Dictionary] = []
var resources: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var scenery: Array[Node3D] = []
var inventory := {"wood": 0, "stone": 0, "berry": 0, "meat": 0, "hide": 0, "mushroom": 0, "cooked_meat": 0, "iron": 0, "silver": 0, "gold": 0}
var hunger := 100.0
var thirst := 100.0
var survival_label: Label
var survival_buttons: Array[Button] = []
var has_spear := false
var has_pickaxe := false
var has_iron_tool := false
var iron_recipe_button: Button
var minimap: Control
var minimap_dots: Array[Control] = []
var stream_points: Array[Vector2] = []
var crossing_z_positions: Array[float] = [-37.0, -7.0, 5.0, 23.0, 43.0]
# Панель быстрого доступа: инструменты остаются собственностью игрока,
# но выбираются здесь, без открытия рюкзака.
var equipped_tool := "hand"
var quickbar: HBoxContainer
var quickbar_buttons: Dictionary = {}
var pickaxe_recipe_button: Button
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
var camera_smooth_yaw := 0.0
var camera_yaw_initialized := false
var camera_display_distance := 0.0
var camera_touch_last := Vector2.ZERO
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
var hint_panel: PanelContainer
var hint_label: Label
var hint_tween: Tween
var last_hint_message := ""
var progress_bar: ProgressBar
var bag_panel: PanelContainer
var bag_label: Label
var action_button: Button
var nearby_button: Button
var nearby_touch_ids: Dictionary = {}
var water_portions := 0
var action_menu: PanelContainer
var action_list: VBoxContainer
var action_options: Array[String] = []
var nearby_action_kind := ""
var nearby_action_index := -1
var nearby_action_position := Vector3.ZERO
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
    _create_stream_and_hills()
    _create_stream_crossings()
    _create_tent()
    _create_camp()
    _create_player()
    _create_camera()
    _create_resources()
    _create_ore()
    _create_scenery()
    _create_forest_paths()
    _create_abandoned_cabin()
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
    _mesh_box(self, Vector3(484, 0.3, 484), Vector3(0, -0.2, 0), Color("628a51"))
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

func _stream_center_x(z: float) -> float:
    return -25.0 + sin(z * 0.105) * 5.0 + sin(z * 0.24) * 1.8

func _is_stream(pos: Vector2, margin: float = 0.0) -> bool:
    return absf(pos.x - _stream_center_x(pos.y)) < 1.65 + margin and absf(pos.y) < 56.0

func _create_stream_and_hills() -> void:
    # Извилистый ручей из коротких плоских сегментов. Вода не требует шейдеров.
    for i in range(56):
        var z := -55.0 + float(i) * 2.0
        var x := _stream_center_x(z)
        var next_x := _stream_center_x(z + 2.0)
        var direction := Vector2(next_x - x, 2.0)
        var section := Node3D.new()
        section.position = Vector3(x, -0.035, z + 1.0)
        section.rotation.y = atan2(direction.x, direction.y)
        add_child(section)
        _mesh_box(section, Vector3(3.25, 0.045, 2.25), Vector3.ZERO, Color("48a8c4"))
        if i % 3 == 0:
            _mesh_sphere(section, 0.42, Vector3(-2.05, 0.18, 0), Color("939b92"), Vector3(1.5, 0.42, 0.8))
            _mesh_sphere(section, 0.35, Vector3(2.05, 0.15, 0), Color("a2a69b"), Vector3(1.4, 0.45, 0.9))
        stream_points.append(Vector2(x, z))
    # Невысокие холмы и скальные выступы по краям карты.
    for i in range(65):
        var pos := _random_land_pos(228.0)
        if pos.length() < 16.0 or pos.distance_to(CABIN_POS) < 9.0 or _is_lake(pos, 5.0) or _is_stream(pos, 5.0):
            continue
        var hill := Node3D.new()
        hill.position = Vector3(pos.x, -0.1, pos.y)
        add_child(hill)
        var radius := rng.randf_range(2.2, 4.5)
        _mesh_sphere(hill, radius, Vector3(0, 0.05, 0), Color("668956"), Vector3(1.45, 0.34, 1.1))
        if i % 2 == 0:
            _mesh_sphere(hill, radius * 0.57, Vector3(radius * 0.28, radius * 0.25, 0), Color("7d8580"), Vector3(1.1, 0.65, 0.9))
        obstacles.append({"pos": pos, "radius": radius * 0.72, "node": hill})

func _on_stream_crossing(pos: Vector2, radius: float = 0.0) -> bool:
    # Проход разрешён только по настилу или поваленному дереву.
    for z in crossing_z_positions:
        if absf(pos.y - z) <= 0.95 - radius * 0.15 and absf(pos.x - _stream_center_x(z)) <= 4.25:
            return true
    return false

func _create_stream_crossings() -> void:
    # Два деревянных мостика и два поваленных ствола над ручьём.
    for i in range(crossing_z_positions.size()):
        var z: float = crossing_z_positions[i]
        var x := _stream_center_x(z)
        var crossing := Node3D.new()
        crossing.name = "Bridge_%d" % i if i % 2 == 0 else "Fallen_Log_%d" % i
        crossing.position = Vector3(x, 0.0, z)
        add_child(crossing)
        if i % 2 == 0:
            # Дощатый мост: поперечные доски и две продольные балки.
            for plank in range(9):
                _mesh_box(crossing, Vector3(0.76, 0.18, 1.8), Vector3(-3.2 + float(plank) * 0.8, 0.18, 0), Color("9b7148"))
            for side in [-0.72, 0.72]:
                _mesh_box(crossing, Vector3(7.4, 0.25, 0.19), Vector3(0, 0.03, side), Color("65462f"))
        else:
            # Толстый ствол и небольшие ветви; широкая невидимая зона прохода.
            var trunk := _mesh_box(crossing, Vector3(8.1, 0.65, 1.25), Vector3(0, 0.23, 0), Color("76513a"))
            trunk.rotation.x = 0.06
            for branch_x in [-2.4, 2.1]:
                _mesh_box(crossing, Vector3(0.32, 0.28, 1.85), Vector3(branch_x, 0.47, 0.45), Color("64422d"))

func _create_ore() -> void:
    var types := ["iron", "silver", "gold"]
    var colors := [Color("9c6b51"), Color("c1c8d0"), Color("d5ad3b")]
    for i in range(75):
        var kind: String = types[0] if i < 45 else types[1] if i < 65 else types[2]
        var pos := Vector2.ZERO
        var found := false
        for attempt in range(100):
            pos = _random_land_pos(230.0)
            if _can_place(pos, 1.1) and (kind != "gold" or _is_stream(pos, 8.0)):
                found = true
                break
        if not found:
            continue
        var ore := Node3D.new()
        ore.position = Vector3(pos.x, 0, pos.y)
        add_child(ore)
        _mesh_sphere(ore, 1.1, Vector3(0, 0.62, 0), Color("626d70"), Vector3(1.2, 0.72, 1.0))
        var color: Color = colors[types.find(kind)]
        for j in range(5):
            _mesh_sphere(ore, 0.23, Vector3(rng.randf_range(-0.65, 0.65), rng.randf_range(0.6, 1.05), rng.randf_range(-0.6, 0.6)), color)
        obstacles.append({"pos": pos, "radius": 0.95, "node": ore})
        resources.append({"kind": kind, "pos": pos, "node": ore, "duration": 6.0, "large": true, "alive": true})

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
    # Separate legs swing gently while sitting on the bench.
    leg_left = Node3D.new()
    leg_right = Node3D.new()
    player_visual.add_child(leg_left)
    player_visual.add_child(leg_right)
    leg_left.position = Vector3(-0.22, -0.34, -0.08)
    leg_right.position = Vector3(0.22, -0.34, -0.08)
    _mesh_box(leg_left, Vector3(0.22, 0.63, 0.23), Vector3(0, -0.31, 0), Color("4c7050"))
    _mesh_box(leg_right, Vector3(0.22, 0.63, 0.23), Vector3(0, -0.31, 0), Color("4c7050"))

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
        camera_focus = camera_focus.lerp(target_focus, 1.0 - exp(-5.0 * delta))
    # Поворот камеры плавный даже при резком свайпе правым пальцем.
    if not camera_yaw_initialized:
        camera_smooth_yaw = camera_input_yaw
        camera_yaw_initialized = true
    elif delta > 0.0:
        camera_smooth_yaw = lerp_angle(camera_smooth_yaw, camera_input_yaw, 1.0 - exp(-2.0 * delta))
    if camera_display_distance <= 0.0:
        camera_display_distance = camera_distance
    elif delta > 0.0:
        camera_display_distance = lerpf(camera_display_distance, camera_distance, 1.0 - exp(-5.0 * delta))
    var backward := Vector3(sin(camera_smooth_yaw), 0.0, cos(camera_smooth_yaw))
    camera.global_position = camera_focus + backward * camera_display_distance * camera_tilt + Vector3.UP * camera_display_distance
    camera.look_at(camera_focus, Vector3.UP)

func _is_lake(pos: Vector2, margin := 0.0) -> bool:
    return pos.distance_to(LAKE_CENTER) < LAKE_RADIUS + margin

func _can_place(pos: Vector2, radius: float) -> bool:
    if _is_lake(pos, radius + 0.3) or _is_stream(pos, radius + 0.3) or pos.distance_to(CABIN_POS) < radius + 7.0:
        return false
    if pos.length() < 3.3 or pos.distance_to(TENT_POS) < radius + 3.5 or pos.distance_to(FIRE_POS) < radius + 3.2 or pos.distance_to(BENCH_POS) < radius + 2.4:
        return false
    for obstacle in obstacles:
        if pos.distance_to(obstacle["pos"]) < radius + obstacle["radius"] + 1.0:
            return false
    return true

func _random_land_pos(edge: float = 231.0) -> Vector2:
    return Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))

func _create_resources() -> void:
    # Больше ресурсов, но без тяжёлых импортированных моделей.
    for i in range(380):
        var kind := "tree" if i < 240 else "rock"
        var radius := 0.85 if kind == "tree" else (0.48 if i % 3 == 0 else 0.9)
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
            var small_rock := i % 3 == 0
            var rock_color := Color("929c9a") if not small_rock else Color("777f86")
            var rock_size := rng.randf_range(0.32, 0.48) if small_rock else rng.randf_range(0.95, 1.4)
            _mesh_sphere(node, rock_size, Vector3(0, rock_size * 0.55, 0), rock_color, Vector3(1.1, 0.65, 0.9))
        obstacles.append({"pos": pos, "radius": radius, "node": node})
        resources.append({"kind": kind, "pos": pos, "node": node, "duration": 2.4 if kind == "tree" else (1.3 if i % 3 == 0 else 5.0), "large": kind == "rock" and i % 3 != 0, "alive": true})
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
        if _is_lake(pos, 0.5) or _is_stream(pos, 0.5) or pos.length() < 3.0:
            continue
        var tuft := Node3D.new()
        tuft.position = Vector3(pos.x, 0, pos.y)
        add_child(tuft)
        var color := Color("8baf58") if i % 4 else Color("e2cf83")
        _mesh_sphere(tuft, 0.23, Vector3(0, 0.12, 0), color, Vector3(1.0, 0.4, 0.8))
        scenery.append(tuft)

func _create_forest_paths() -> void:
    # Светлая извилистая тропа от лагеря к заброшенной хижине.
    # Плоские пятна не блокируют движение и не требуют текстур.
    # Хижина стоит на восточном берегу; тропа не пересекает воду.
    var waypoints: Array[Vector2] = [
        Vector2(-7.0, 8.0),
        Vector2(-10.0, 16.0),
        Vector2(-8.0, 23.0),
        CABIN_POS + Vector2(0.0, -3.5)
    ]
    for segment in range(waypoints.size() - 1):
        var a := waypoints[segment]
        var b := waypoints[segment + 1]
        var steps := maxi(3, int(a.distance_to(b) * 1.8))
        for i in range(steps):
            var t := float(i) / float(steps)
            var point := a.lerp(b, t)
            # На мосту тропинка не рисуется поверх воды.
            if _is_stream(point, 0.8) or _is_lake(point, 0.8):
                continue
            var patch := Node3D.new()
            patch.position = Vector3(point.x, 0.013, point.y)
            add_child(patch)
            _mesh_sphere(patch, 0.7, Vector3.ZERO, Color("a28e63"), Vector3(1.2, 0.018, 0.8))
    # Заросли папоротника у тропы и в лесу.
    for i in range(190):
        var pos := _random_land_pos(230.0)
        if pos.distance_to(TENT_POS) < 6.0 or pos.distance_to(BENCH_POS) < 5.0 or pos.distance_to(CABIN_POS) < 4.0:
            continue
        if _is_lake(pos, 0.5) or _is_stream(pos, 0.5):
            continue
        var fern := Node3D.new()
        fern.position = Vector3(pos.x, 0.0, pos.y)
        add_child(fern)
        for j in range(4):
            var angle := float(j) * PI * 0.5
            var leaf := _mesh_sphere(fern, 0.44, Vector3(cos(angle) * 0.27, 0.28, sin(angle) * 0.27), Color("397447"), Vector3(0.38, 0.36, 1.4))
            leaf.rotation.y = angle

func _create_abandoned_cabin() -> void:
    # Исследуемая хижина. Вход со стороны юга, поэтому нет сплошной передней стены.
    var cabin := Node3D.new()
    cabin.name = "AbandonedCabin"
    # Защита от случайного переноса постройки в воду при следующих обновлениях.
    if _is_lake(CABIN_POS, 5.0) or _is_stream(CABIN_POS, 5.0):
        push_error("Хижина попала в воду: измените CABIN_POS")
        return
    cabin.position = Vector3(CABIN_POS.x, 0.0, CABIN_POS.y)
    add_child(cabin)
    _mesh_box(cabin, Vector3(5.8, 0.22, 4.7), Vector3(0, 0.12, 0), Color("5e4934"))
    _mesh_box(cabin, Vector3(5.8, 2.7, 0.35), Vector3(0, 1.5, 2.25), Color("695039"))
    for side in [-2.75, 2.75]:
        _mesh_box(cabin, Vector3(0.32, 2.7, 4.6), Vector3(side, 1.5, 0), Color("75583b"))
    for x in [-1.9, 1.9]:
        _mesh_box(cabin, Vector3(1.9, 2.7, 0.34), Vector3(x, 1.5, -2.25), Color("70513a"))
    for side in [-1.0, 1.0]:
        var roof := _mesh_box(cabin, Vector3(3.75, 0.25, 5.25), Vector3(side * 1.43, 3.27, 0), Color("463a32"))
        roof.rotation.z = side * 0.33
    _mesh_box(cabin, Vector3(1.2, 0.7, 0.7), Vector3(0.4, 0.49, 0.6), Color("836044"))
    _mesh_box(cabin, Vector3(0.85, 0.14, 0.8), Vector3(0.4, 0.91, 0.6), Color("b19b6c"))
    # Старый рюкзак, ящик с припасами и записка на столе.
    _mesh_box(cabin, Vector3(0.65, 0.72, 0.42), Vector3(-1.2, 0.47, 0.55), Color("645b3d"))
    _mesh_box(cabin, Vector3(0.85, 0.55, 0.8), Vector3(1.45, 0.38, 1.1), Color("765637"))
    _mesh_box(cabin, Vector3(0.43, 0.035, 0.32), Vector3(0.4, 1.01, 0.6), Color("e1d2a3"))
    # Стены учитываются как препятствия, но вход открыт.
    for wall_data in [[Vector2(-2.75, 0), 0.7], [Vector2(2.75, 0), 0.7], [Vector2(0, 2.25), 0.7], [Vector2(-1.9, -2.25), 0.5], [Vector2(1.9, -2.25), 0.5]]:
        var offset: Vector2 = wall_data[0]
        var radius: float = wall_data[1]
        obstacles.append({"pos": CABIN_POS + offset, "radius": radius, "node": cabin})

func _create_animals() -> void:
    # Зайцы, олени и кабаны мирно бродят по миру.
    for i in range(32):
        var pos := _random_land_pos(226.0)
        for attempt in range(40):
            if not _is_lake(pos, 1.5) and not _blocked(pos, 0.8):
                break
            pos = _random_land_pos(226.0)
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
    # Прозрачная подсказка над нижней кнопкой взаимодействия.
    var hint_layer := CanvasLayer.new()
    hint_layer.layer = 25
    add_child(hint_layer)
    var hint_root := Control.new()
    hint_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_layer.add_child(hint_root)
    hint_panel = PanelContainer.new()
    hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    hint_panel.offset_left = -220.0
    hint_panel.offset_right = 220.0
    hint_panel.offset_top = -222.0
    hint_panel.offset_bottom = -162.0
    hint_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_panel.modulate.a = 0.0
    hint_panel.visible = false
    hint_root.add_child(hint_panel)
    hint_label = Label.new()
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint_label.add_theme_font_size_override("font_size", 22)
    hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    hint_label.add_theme_constant_override("outline_size", 4)
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_panel.add_child(hint_label)
    bag_button = Button.new()
    bag_button.text = "Рюкзак"
    bag_button.custom_minimum_size = Vector2(145, 56)
    bag_button.pressed.connect(_toggle_bag)
    top.add_child(bag_button)
    craft_button = Button.new()
    craft_button.text = "Крафт"
    craft_button.custom_minimum_size = Vector2(110, 56)
    craft_button.pressed.connect(_toggle_craft)
    craft_button.visible = true
    top.add_child(craft_button)
    time_label = Label.new()
    time_label.add_theme_font_size_override("font_size", 20)
    top.add_child(time_label)
    # Отдельный верхний слой: кнопки всегда поверх игрового HUD.
    var zoom_layer := CanvasLayer.new()
    zoom_layer.layer = 20
    add_child(zoom_layer)
    var zoom_root := Control.new()
    zoom_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    zoom_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    zoom_layer.add_child(zoom_root)
    var zoom_controls := HBoxContainer.new()
    zoom_controls.anchor_left = 0.5
    zoom_controls.anchor_right = 0.5
    zoom_controls.anchor_top = 0.0
    zoom_controls.anchor_bottom = 0.0
    zoom_controls.offset_left = -66.0
    zoom_controls.offset_right = 66.0
    zoom_controls.offset_top = 12.0
    zoom_controls.offset_bottom = 60.0
    zoom_controls.add_theme_constant_override("separation", 8)
    zoom_controls.mouse_filter = Control.MOUSE_FILTER_STOP
    zoom_root.add_child(zoom_controls)
    var zoom_out_button := Button.new()
    zoom_out_button.text = "−"
    zoom_out_button.custom_minimum_size = Vector2(62, 48)
    zoom_out_button.add_theme_font_size_override("font_size", 30)
    zoom_out_button.focus_mode = Control.FOCUS_NONE
    zoom_out_button.pressed.connect(_zoom.bind(1.5))
    zoom_controls.add_child(zoom_out_button)
    var zoom_in_button := Button.new()
    zoom_in_button.text = "+"
    zoom_in_button.custom_minimum_size = Vector2(62, 48)
    zoom_in_button.add_theme_font_size_override("font_size", 30)
    zoom_in_button.focus_mode = Control.FOCUS_NONE
    zoom_in_button.pressed.connect(_zoom.bind(-1.5))
    zoom_controls.add_child(zoom_in_button)
    var bottom := VBoxContainer.new()
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 8
    bottom.offset_right = -8
    bottom.offset_top = -27
    bottom.offset_bottom = -2
    root.add_child(bottom)
    bag_fly = Label.new()
    bag_fly.visible = false
    bag_fly.add_theme_font_size_override("font_size", 27)
    bag_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(bag_fly)
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress_bar = ProgressBar.new()
    progress_bar.max_value = 100
    progress_bar.custom_minimum_size.y = 22
    progress_bar.visible = false
    bottom.add_child(progress_bar)
    bag_panel = PanelContainer.new()
    root.add_child(bag_panel)
    bag_panel.set_anchors_preset(Control.PRESET_CENTER)
    bag_panel.offset_left = -155
    bag_panel.offset_right = 155
    bag_panel.offset_top = -130
    bag_panel.offset_bottom = 130
    bag_panel.visible = false
    var bag_col := VBoxContainer.new()
    bag_col.add_theme_constant_override("separation", 8)
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
    bag_label.add_theme_font_size_override("font_size", 18)
    bag_col.add_child(bag_label)
    # Рюкзак показывает только предметы; все действия вынесены в кнопку «Действие».
    # Действия у костра и воды теперь находятся рядом с объектами, не в рюкзаке.
    action_button = Button.new()
    action_button.text = "Действие"
    action_button.custom_minimum_size = Vector2(112, 52)
    action_button.focus_mode = Control.FOCUS_NONE
    action_button.pressed.connect(_open_action_menu)
    top.add_child(action_button)
    nearby_button = Button.new()
    nearby_button.text = "Действие рядом"
    nearby_button.custom_minimum_size = Vector2(0, 0)
    nearby_button.focus_mode = Control.FOCUS_NONE
    nearby_button.visible = false
    # Контекстная кнопка обрабатывается напрямую в _input: мобильный Web не всегда
    # посылает Button.pressed при одновременной работе виртуального джойстика.
    # Используем тот же HUD, что и работающие кнопки «Рюкзак» и «Действие».
    # Якоря задаются относительно реального размера экрана.
    root.add_child(nearby_button)
    nearby_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    nearby_button.offset_left = -112.0
    nearby_button.offset_right = 112.0
    nearby_button.offset_top = -150.0
    nearby_button.offset_bottom = -110.0
    nearby_button.mouse_filter = Control.MOUSE_FILTER_STOP
    nearby_button.pressed.connect(_perform_nearby_action)
    # Нижняя панель снаряжения под кнопкой взаимодействия.
    quickbar = HBoxContainer.new()
    quickbar.alignment = BoxContainer.ALIGNMENT_CENTER
    quickbar.add_theme_constant_override("separation", 5)
    root.add_child(quickbar)
    quickbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    quickbar.offset_left = -158.0
    quickbar.offset_right = 158.0
    quickbar.offset_top = -99.0
    quickbar.offset_bottom = -48.0
    for tool_id in ["hand", "spear", "pickaxe", "sword", "bow"]:
        var tool_button := Button.new()
        tool_button.custom_minimum_size = Vector2(58, 48)
        tool_button.focus_mode = Control.FOCUS_NONE
        tool_button.mouse_filter = Control.MOUSE_FILTER_STOP
        tool_button.text = ""
        tool_button.disabled = true
        quickbar.add_child(tool_button)
        quickbar_buttons[tool_id] = tool_button
    _refresh_quickbar()
    _create_minimap(root)
    action_menu = PanelContainer.new()
    root.add_child(action_menu)
    action_menu.set_anchors_preset(Control.PRESET_CENTER)
    action_menu.offset_left = -160
    action_menu.offset_right = 160
    action_menu.offset_top = -175
    action_menu.offset_bottom = 175
    action_menu.visible = false
    action_list = VBoxContainer.new()
    action_list.add_theme_constant_override("separation", 5)
    action_menu.add_child(action_list)
    var close := Button.new()
    close.text = "Закрыть"
    close.pressed.connect(_toggle_bag)
    bag_col.add_child(close)
    # Отдельное окно крафта: ресурсы расходуются только по кнопке «Создать».
    craft_panel = PanelContainer.new()
    root.add_child(craft_panel)
    craft_panel.set_anchors_preset(Control.PRESET_CENTER)
    craft_panel.offset_left = -160
    craft_panel.offset_right = 160
    craft_panel.offset_top = -190
    craft_panel.offset_bottom = 190
    craft_panel.visible = false
    var craft_col := VBoxContainer.new()
    craft_panel.add_child(craft_col)
    var craft_title := Label.new()
    craft_title.text = "МАСТЕРСКАЯ\nИнструменты"
    craft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    craft_title.add_theme_font_size_override("font_size", 25)
    craft_col.add_child(craft_title)
    var craft_description := Label.new()
    craft_description.text = "Копьё, кирка и железный инструмент"
    craft_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    craft_col.add_child(craft_description)
    craft_recipe_button = Button.new()
    craft_recipe_button.custom_minimum_size.y = 55
    craft_recipe_button.pressed.connect(_craft_spear)
    craft_col.add_child(craft_recipe_button)
    pickaxe_recipe_button = Button.new()
    pickaxe_recipe_button.custom_minimum_size.y = 55
    pickaxe_recipe_button.pressed.connect(_craft_pickaxe)
    craft_col.add_child(pickaxe_recipe_button)
    iron_recipe_button = Button.new()
    iron_recipe_button.custom_minimum_size.y = 55
    iron_recipe_button.pressed.connect(_craft_iron_tool)
    craft_col.add_child(iron_recipe_button)
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

func _create_minimap(root: Control) -> void:
    # Круглая карта справа сверху. Точки не перехватывают касания.
    minimap = Control.new()
    minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    minimap.offset_left = -150.0
    minimap.offset_right = -12.0
    minimap.offset_top = 82.0
    minimap.offset_bottom = 220.0
    minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(minimap)
    var disc := Panel.new()
    disc.position = Vector2.ZERO
    disc.size = Vector2(138, 138)
    disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.10, 0.20, 0.16, 0.82)
    style.corner_radius_top_left = 69
    style.corner_radius_top_right = 69
    style.corner_radius_bottom_left = 69
    style.corner_radius_bottom_right = 69
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color("a6bd9c")
    disc.add_theme_stylebox_override("panel", style)
    minimap.add_child(disc)
    # Маркеры создаются один раз и перемещаются при обновлении.
    for i in range(4):
        var dot := ColorRect.new()
        dot.size = Vector2(8, 8) if i == 0 else Vector2(6, 6)
        dot.color = Color("fff1a4") if i == 0 else Color("c8b180") if i == 1 else Color("4cb7d7") if i == 2 else Color("d9ad62")
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        minimap.add_child(dot)
        minimap_dots.append(dot)
    _update_minimap()

func _update_minimap() -> void:
    if minimap == null or player == null or minimap_dots.size() < 4:
        return
    var positions := [Vector2(player.position.x, player.position.z), TENT_POS, LAKE_CENTER, Vector2(_stream_center_x(0.0), 0.0)]
    for i in range(4):
        var point: Vector2 = positions[i]
        minimap_dots[i].position = Vector2(69, 69) + point * 0.91 - minimap_dots[i].size * 0.5

func _craft_iron_tool() -> void:
    if has_iron_tool:
        status_message = "Железный инструмент уже изготовлен"
    elif inventory["iron"] >= 2 and inventory["wood"] >= 2:
        inventory["iron"] -= 2
        inventory["wood"] -= 2
        has_iron_tool = true
        status_message = "Железная кирка готова: руда добывается быстрее"
    else:
        status_message = "Нужно 2 железа и 2 дерева"
    _update_ui()

func _toggle_craft() -> void:
    craft_panel.visible = not craft_panel.visible
    if craft_panel.visible:
        action_menu.visible = false
        bag_panel.visible = false
        sleep_panel.visible = false
    _update_ui()

func _tool_owned(tool_id: String) -> bool:
    if tool_id == "hand":
        return true
    if tool_id == "spear":
        return has_spear
    if tool_id == "pickaxe":
        return has_pickaxe
    return false # Меч и лук добавим вместе с их крафтом и механиками.

func _select_quick_tool(tool_id: String) -> void:
    if not _tool_owned(tool_id):
        status_message = "Сначала изготовь инструмент" if tool_id == "spear" or tool_id == "pickaxe" else "Этот инструмент появится позже"
        _update_ui()
        return
    equipped_tool = tool_id
    status_message = "Выбрано: " + {"hand":"Рука", "spear":"Копьё", "pickaxe":"Кирка"}.get(tool_id, tool_id)
    _update_ui()

func _refresh_quickbar() -> void:
    # Только рука видна при старте. Прочие слоты полностью пустые до крафта.
    # После крафта инструменты занимают свободные ячейки по порядку.
    var owned_tools: Array[String] = ["hand"]
    if has_spear:
        owned_tools.append("spear")
    if has_pickaxe:
        owned_tools.append("pickaxe")
    var labels := {"hand": "Рука", "spear": "Копьё", "pickaxe": "Кирка"}
    var slot_ids := ["hand", "spear", "pickaxe", "sword", "bow"]
    for slot_index in range(slot_ids.size()):
        var button: Button = quickbar_buttons[slot_ids[slot_index]]
        if slot_index < owned_tools.size():
            var tool_id: String = owned_tools[slot_index]
            button.text = ("● " if equipped_tool == tool_id else "") + ("Жел. кирка" if tool_id == "pickaxe" and has_iron_tool else str(labels[tool_id]))
            button.disabled = false
            button.modulate = Color(1.0, 0.94, 0.67) if equipped_tool == tool_id else Color(1, 1, 1)
            # При заполнении слотов переназначаем действие на нужный инструмент.
            for connection in button.pressed.get_connections():
                button.pressed.disconnect(connection["callable"])
            button.pressed.connect(_select_quick_tool.bind(tool_id))
        else:
            button.text = ""
            button.tooltip_text = ""
            for connection in button.pressed.get_connections():
                button.pressed.disconnect(connection["callable"])
            button.disabled = true
            button.modulate = Color(1, 1, 1)

func _craft_spear() -> void:
    if has_spear:
        status_message = "Копьё уже изготовлено"
    elif inventory["wood"] >= 3 and inventory["stone"] >= 1:
        inventory["wood"] -= 3
        inventory["stone"] -= 1
        has_spear = true
        equipped_tool = "spear"
        status_message = "Деревянное копьё готово! Нажми на животное"
    else:
        status_message = "Для копья нужны 3 дерева и 1 камень"
    _update_ui()

func _craft_pickaxe() -> void:
    if has_pickaxe:
        status_message = "Кирка уже изготовлена"
    elif inventory["wood"] >= 3 and inventory["stone"] >= 2:
        inventory["wood"] -= 3
        inventory["stone"] -= 2
        has_pickaxe = true
        equipped_tool = "pickaxe"
        status_message = "Кирка готова! Теперь можно добывать крупные камни"
    else:
        status_message = "Для кирки нужны 3 дерева и 2 камня"
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
    if bag_panel.visible:
        action_menu.visible = false
        craft_panel.visible = false
    _update_nearby_action()
    _update_ui()

func _zoom(amount: float) -> void:
    camera_distance = clampf(camera_distance + amount, 5.5, 32.0)
    # Обновление камеры только в физическом кадре: без скачка при нажатии кнопки.
    _update_ui()

func _show_center_hint(message: String) -> void:
    if hint_panel == null or hint_label == null or message.is_empty():
        return
    if hint_tween != null and hint_tween.is_running():
        hint_tween.kill()
    hint_label.text = message
    hint_panel.visible = true
    hint_panel.modulate.a = 0.0
    hint_tween = create_tween()
    hint_tween.tween_property(hint_panel, "modulate:a", 1.0, 0.35)
    hint_tween.tween_interval(2.0)
    hint_tween.tween_property(hint_panel, "modulate:a", 0.0, 0.65)
    hint_tween.tween_callback(func() -> void: hint_panel.visible = false)

func _update_ui() -> void:
    info_label.text = "ДИКИЙ КРАЙ 3D"
    if status_message != last_hint_message:
        last_hint_message = status_message
        _show_center_hint(status_message)
    if survival_label != null:
        survival_label.text = "🍖 Голод: %d%%    💧 Жажда: %d%%" % [int(hunger), int(thirst)]
    if time_label != null:
        var hour := int(day_clock) % 24
        var minute := int((day_clock - floor(day_clock)) * 60.0)
        time_label.text = "День %d  %02d:%02d" % [day_count, hour, minute]
    bag_label.text = "РЮКЗАК\nДерево: %d    Камень: %d\nЯгоды: %d    Грибы: %d\nМясо: %d    Жареное: %d\nШкуры: %d    Копьё: %s\nКирка: %s" % [inventory["wood"], inventory["stone"], inventory["berry"], inventory["mushroom"], inventory["meat"], inventory["cooked_meat"], inventory["hide"], "есть" if has_spear else "нет", "есть" if has_pickaxe else "нет"]
    bag_label.text += "\nЖелезо: %d  Серебро: %d  Золото: %d\nЖелезный инструмент: %s" % [inventory["iron"], inventory["silver"], inventory["gold"], "есть" if has_iron_tool else "нет"]
    if cabin_note_found:
        bag_label.text += "\nЗаписка из хижины: «03:17. Кто-то стоял у палатки...»"
    if quickbar != null:
        _refresh_quickbar()
    _update_minimap()
    if craft_recipe_button != null:
        craft_recipe_button.text = "Копьё уже создано" if has_spear else "Создать копьё (3 дерева + 1 камень)"
        craft_recipe_button.disabled = has_spear or inventory["wood"] < 3 or inventory["stone"] < 1
    if iron_recipe_button != null:
        iron_recipe_button.text = "Железный инструмент готов" if has_iron_tool else "Железный инструмент (2 железа + 2 дерева)"
        iron_recipe_button.disabled = has_iron_tool or inventory["iron"] < 2 or inventory["wood"] < 2
    if pickaxe_recipe_button != null:
        pickaxe_recipe_button.text = "Кирка уже создана" if has_pickaxe else "Создать кирку (3 дерева + 2 камня)"
        pickaxe_recipe_button.disabled = has_pickaxe or inventory["wood"] < 3 or inventory["stone"] < 2

func _sit_on_bench() -> void:
    sitting = true
    pending_index = -1
    pending_kind = ""
    hunt_target = -1
    player.position.x = BENCH_POS.x
    player.position.z = BENCH_POS.y - 0.15
    player_visual.position.y = -0.35
    # В Godot модель смотрит вдоль -Z при rotation.y == 0.
    # Поворачиваем её точно к костру, а не спиной к нему.
    var to_fire := FIRE_POS - Vector2(player.position.x, player.position.z)
    player_facing = atan2(-to_fire.x, -to_fire.y)
    player_visual.rotation.y = player_facing

func _finish_cooking() -> void:
    cooking_active = false
    cooking_elapsed = 0.0
    inventory["cooked_meat"] += 1
    status_message = "Мясо готово! +1 жареное мясо в рюкзаке"
    progress_bar.visible = false

func _survival_action(kind: String) -> void:
    var here := Vector2(player.position.x, player.position.z)
    if kind == "drink":
        if water_portions > 0:
            water_portions -= 1
            thirst = minf(100.0, thirst + 65.0)
            status_message = "Ты попил воды из фляги"
        else:
            status_message = "Во фляге нет воды"
    elif kind == "water":
        if here.distance_to(LAKE_CENTER) <= LAKE_RADIUS + 1.3:
            water_portions = mini(5, water_portions + 1)
            status_message = "Набрана вода во флягу (%d/5)" % water_portions
        else:
            status_message = "Подойди к берегу озера"
    elif kind == "cabin":
        if here.distance_to(CABIN_POS) > 4.1:
            status_message = "Подойди к заброшенной хижине"
        elif cabin_searched:
            status_message = "Хижина уже осмотрена. Внутри тихо и пусто"
        else:
            cabin_searched = true
            cabin_note_found = true
            inventory["wood"] += 3
            inventory["stone"] += 2
            status_message = "Тайник: +3 дерева, +2 камня. Записка: «03:17. Кто-то стоял у палатки...»"
    elif kind == "rest":
        if here.distance_to(BENCH_POS) <= 3.0 and not cooking_active:
            _sit_on_bench()
            status_message = "Сидим на скамейке и смотрим на костёр. Двигайся, чтобы встать"
        else:
            status_message = "Подойди к скамейке у костра"
    elif kind == "cook":
        if here.distance_to(FIRE_POS) > 3.2:
            status_message = "Готовить мясо можно только у костра"
        elif inventory["meat"] < 1 or inventory["wood"] < 1:
            status_message = "Для жарки нужны 1 мясо и 1 дерево"
        else:
            if cooking_active:
                status_message = "Мясо уже жарится у костра"
            else:
                inventory["meat"] -= 1
                inventory["wood"] -= 1
                cooking_active = true
                cooking_elapsed = 0.0
                _sit_on_bench()
                status_message = "Жарим мясо 11 секунд — отдыхаем на лавочке"
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

func _open_action_menu() -> void:
    if action_menu == null:
        return
    if action_menu.visible:
        action_menu.visible = false
        return
    bag_panel.visible = false
    craft_panel.visible = false
    for child in action_list.get_children():
        child.queue_free()
    action_options.clear()
    if int(inventory.get("berry", 0)) > 0:
        _add_action_option("Съесть ягоды", "berry")
    if int(inventory.get("mushroom", 0)) > 0:
        _add_action_option("Съесть гриб", "mushroom")
    if int(inventory.get("cooked_meat", 0)) > 0:
        _add_action_option("Съесть жареное мясо", "cooked_meat")
    if water_portions > 0:
        _add_action_option("Попить воды (%d)" % water_portions, "drink")
    if Vector2(player.position.x, player.position.z).distance_to(CABIN_POS) <= 4.1:
        _add_action_option("Осмотреть заброшенную хижину", "cabin")
    if Vector2(player.position.x, player.position.z).distance_to(FIRE_POS) <= 3.5:
        _add_action_option("Пожарить мясо и сесть", "cook")
    if Vector2(player.position.x, player.position.z).distance_to(BENCH_POS) <= 3.0:
        if sitting:
            _add_action_option("Встать со скамейки", "stand")
        else:
            _add_action_option("Сесть и отдохнуть у костра", "rest")
    _add_action_option("Крафт", "craft")
    var close := Button.new()
    close.text = "Закрыть"
    close.custom_minimum_size.y = 42
    close.pressed.connect(func(): action_menu.visible = false)
    action_list.add_child(close)
    action_menu.visible = true

func _add_action_option(title: String, kind: String) -> void:
    var id := action_options.size()
    action_options.append(kind)
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 42
    button.pressed.connect(_select_action.bind(id))
    action_list.add_child(button)

func _select_action(id: int) -> void:
    if id < 0 or id >= action_options.size():
        return
    var kind := action_options[id]
    action_menu.visible = false
    if kind == "craft":
        _toggle_craft()
    elif kind == "resource":
        var index := _nearest_resource()
        if index >= 0:
            _begin_mining(index)
    elif kind != "none":
        _survival_action(kind)
    _update_nearby_action()

func _update_nearby_action() -> void:
    if nearby_button == null or player == null:
        return
    nearby_action_kind = ""
    nearby_action_index = -1
    nearby_button.hide()
    if bag_panel.visible or action_menu.visible or craft_panel.visible or sleep_panel.visible or sleep_in_progress:
        return
    var here := Vector2(player.global_position.x, player.global_position.z)
    # Палатка — отдельное действие при приближении, как костёр и озеро.
    # Проверяем её первой, чтобы другие ресурсы не скрывали кнопку отдыха.
    if here.distance_to(TENT_POS) <= 2.8:
        nearby_action_kind = "tent"
        nearby_button.text = "Отдохнуть в палатке"
    elif here.distance_to(CABIN_POS) <= 4.1:
        nearby_action_kind = "cabin"
        nearby_button.text = "Осмотреть заброшенную хижину"
    elif here.distance_to(BENCH_POS) <= 2.8 and not cooking_active:
        nearby_action_kind = "stand" if sitting else "rest"
        nearby_button.text = "Встать со скамейки" if sitting else "Сесть на скамейку и отдохнуть"
    elif here.distance_to(FIRE_POS) <= 3.2:
        nearby_action_kind = "cook"
        nearby_button.text = "Мясо жарится…" if cooking_active else "Пожарить мясо и сесть"
    elif here.distance_to(LAKE_CENTER) <= LAKE_RADIUS + 1.3:
        nearby_action_kind = "water"
        nearby_button.text = "Набрать воды"
    else:
        var closest_drop := -1
        var drop_distance := 2.0
        for i in range(drops.size()):
            var d: float = here.distance_to(drops[i]["pos"])
            if d < drop_distance:
                drop_distance = d
                closest_drop = i
        if closest_drop >= 0:
            nearby_action_kind = "drop"
            nearby_action_index = closest_drop
            nearby_button.text = "Собрать предмет"
        else:
            var index := _nearest_resource()
            if index >= 0:
                nearby_action_kind = "resource"
                nearby_action_index = index
                var kind: String = resources[index]["kind"]
                if kind == "tree":
                    nearby_button.text = "Срубить дерево"
                elif kind == "rock":
                    nearby_button.text = "Добыть крупный камень (кирка)" if resources[index].get("large", false) else "Подобрать маленький камень"
                elif kind == "iron" or kind == "silver" or kind == "gold":
                    nearby_button.text = "Добыть руду (кирка)"
                elif kind == "berry":
                    nearby_button.text = "Собрать ягоды"
                elif kind == "mushroom":
                    nearby_button.text = "Собрать грибы"
    if nearby_action_kind != "":
        nearby_button.show()

func _perform_nearby_action() -> void:
    # Обрабатываем именно то действие, которое написано на кнопке.
    # Не прячем и не пересчитываем кнопку перед нажатием.
    var chosen: String = nearby_action_kind
    var selected: int = nearby_action_index
    if chosen == "tent":
        var here := Vector2(player.global_position.x, player.global_position.z)
        if here.distance_to(TENT_POS) <= 2.8:
            _show_sleep_panel()
        else:
            status_message = "Подойди ближе к палатке"
    elif chosen == "cabin":
        _survival_action("cabin")
    elif chosen == "rest":
        _survival_action("rest")
    elif chosen == "stand":
        sitting = false
        player_visual.position.y = 0.0
        status_message = "Ты встал со скамейки"
    elif chosen == "cook":
        _survival_action("cook")
    elif chosen == "water":
        _survival_action("water")
    elif chosen == "drop":
        if selected >= 0 and selected < drops.size():
            var pos: Vector2 = drops[selected]["pos"]
            var here := Vector2(player.position.x, player.position.z)
            if here.distance_to(pos) <= 2.1:
                var selected_kind: String = str(drops[selected]["kind"])
                if selected_kind == "meat" or selected_kind == "hide":
                    var corpse_pos: Vector2 = drops[selected]["pos"]
                    for j in range(drops.size() - 1, -1, -1):
                        var other_kind: String = str(drops[j]["kind"])
                        if (other_kind == "meat" or other_kind == "hide") and corpse_pos.distance_to(drops[j]["pos"]) <= 1.3:
                            _pickup_index(j)
                else:
                    _pickup_index(selected)
            else:
                status_message = "Подойди ближе к предмету"
    elif chosen == "resource":
        if selected >= 0 and selected < resources.size() and bool(resources[selected]["alive"]):
            var pos: Vector2 = resources[selected]["pos"]
            var here := Vector2(player.position.x, player.position.z)
            if here.distance_to(pos) <= 2.9:
                pending_index = -1
                pending_kind = ""
                _begin_mining(selected)
            else:
                status_message = "Подойди ближе к ресурсу"
    _update_nearby_action()
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
        if not has_spear or equipped_tool != "spear":
            status_message = "Выбери копьё в нижней панели для охоты"
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
    if index < 0 or index >= resources.size() or not bool(resources[index]["alive"]):
        return
    if (resources[index]["kind"] == "rock" and bool(resources[index].get("large", false)) or resources[index]["kind"] == "iron" or resources[index]["kind"] == "silver" or resources[index]["kind"] == "gold") and (not has_pickaxe or equipped_tool != "pickaxe"):
        status_message = "Для большого камня выбери кирку в нижней панели (крафт: 3 дерева + 2 камня)"
        _update_ui()
        return
    target_resource = index
    mining_active = true
    mining_progress = 0.0
    status_message = "Добыча началась — подожди заполнения шкалы"
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
    var kind: String = "wood" if r["kind"] == "tree" else "stone" if r["kind"] == "rock" else "mushroom" if r["kind"] == "mushroom" else str(r["kind"]) if r["kind"] == "iron" or r["kind"] == "silver" or r["kind"] == "gold" else "berry"
    var drop := Node3D.new()
    drop.position = Vector3(r["pos"].x, 0.35, r["pos"].y)
    add_child(drop)
    _mesh_sphere(drop, 0.28, Vector3.ZERO, Color("bd8b52") if kind == "wood" else Color("c0c5c8") if kind == "stone" else Color("a57859") if kind == "iron" else Color("d0d6dd") if kind == "silver" else Color("e2bc48") if kind == "gold" else Color("bd394e"))
    drops.append({"kind": kind, "pos": r["pos"], "node": drop})
    status_message = "Ресурс выпал — нажми на него"
    _stop_mining()
    _update_ui()

func _pickup_index(index: int) -> void:
    if index < 0 or index >= drops.size():
        return
    var item: Dictionary = drops[index]
    var kind: String = str(item["kind"])
    var world_pos: Vector3 = item["node"].global_position
    var start: Vector2 = camera.unproject_position(world_pos)
    # Сразу зачисляем добычу: повторное касание не может потерять предмет,
    # даже если анимация предыдущего предмета ещё не закончилась.
    inventory[kind] = int(inventory.get(kind, 0)) + 1
    pickup_flight = {"kind": kind, "start": start}
    pickup_time = 0.0
    bag_fly.text = "● +1"
    bag_fly.position = start
    bag_fly.visible = true
    item["node"].queue_free()
    drops.remove_at(index)
    status_message = "В рюкзаке: +1 " + kind
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
        pickup_flight.clear()
        bag_fly.visible = false
        bag_fly.scale = Vector2.ONE
        # Предмет уже зачислен и сообщение показано в _pickup_index().
        # Здесь только завершаем анимацию, не обращаясь к локальной переменной kind.

func _blocked(pos: Vector2, radius: float) -> bool:
    if absf(pos.x) > WORLD_LIMIT or absf(pos.y) > WORLD_LIMIT:
        return true
    # На берег можно зайти немного, но глубже 0.45 м — нельзя.
    if _is_lake(pos, radius - 0.45):
        return true
    if _is_stream(pos, radius - 0.45) and not _on_stream_crossing(pos, radius):
        return true
    for obstacle in obstacles:
        if pos.distance_to(obstacle["pos"]) < radius + obstacle["radius"]:
            return true
    return false

func _physics_process(delta: float) -> void:
    if sleep_in_progress:
        _advance_sleep(delta)
        return
    if cooking_active:
        cooking_elapsed += delta
        progress_bar.visible = true
        progress_bar.value = 100.0 * minf(1.0, cooking_elapsed / COOK_SECONDS)
        if cooking_elapsed >= COOK_SECONDS:
            _finish_cooking()
    if sitting and leg_left != null and leg_right != null:
        camp_time += delta
        leg_left.rotation.x = sin(camp_time * 4.0) * 0.32
        leg_right.rotation.x = sin(camp_time * 4.0 + PI) * 0.32
    elif leg_left != null and leg_right != null:
        leg_left.rotation.x = 0.0
        leg_right.rotation.x = 0.0
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
                _sit_on_bench()
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
    if cooking_active:
        direction = Vector2.ZERO
    if sitting and not cooking_active and (direction.length() > 0.1 or steering_active):
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
    if gather_touch != -1 and gather_direction.length() > 0.2 and not mining_active and not cooking_active:
        var nearest := _nearest_resource()
        if nearest >= 0:
            _begin_mining(nearest)
    if mining_active:
        if target_resource < 0 or not resources[target_resource]["alive"] or Vector2(player.position.x, player.position.z).distance_to(resources[target_resource]["pos"]) > 3.0:
            _stop_mining()
            status_message = "Слишком далеко — добыча прервана"
            _update_ui()
        else:
            var ore_kind: String = str(resources[target_resource]["kind"])
            var ore_bonus := 1.7 if has_iron_tool and (ore_kind == "iron" or ore_kind == "silver" or ore_kind == "gold") else 1.0
            mining_progress += delta * ore_bonus
            if not cooking_active:
                progress_bar.visible = true
                progress_bar.value = 100.0 * mining_progress / resources[target_resource]["duration"]
            if mining_progress >= resources[target_resource]["duration"]:
                _finish_mining()
    _move_animals(delta)
    _update_nearby_action()
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
            # Сначала перехватываем нажатие на кнопку, ДО джойстика и камеры.
            # Запоминаем палец и выполняем действие при отпускании.
            if nearby_button != null and nearby_button.visible and nearby_button.get_global_rect().has_point(event.position):
                nearby_touch_ids[event.index] = true
                get_viewport().set_input_as_handled()
                return
            if quickbar != null and quickbar.get_global_rect().has_point(event.position):
                return
            active_touches[event.index] = event.position
            var viewport_width := get_viewport().get_visible_rect().size.x
            var viewport_height := get_viewport().get_visible_rect().size.y
            # Не захватываем касания по контекстной кнопке действий.
            if action_button != null and action_button.visible and Rect2(action_button.global_position, action_button.size).has_point(event.position):
                return
            # Верхняя центральная область отдана кнопкам + и −.
            if event.position.y < 70.0 and absf(event.position.x - viewport_width * 0.5) < 80.0:
                return
            if event.position.y > viewport_height * 0.32 and event.position.x < viewport_width * 0.5 and joystick_touch == -1:
                joystick_touch = event.index
                joystick_origin = event.position
                joystick_basis_yaw = camera_input_yaw
                touch_move = Vector2.ZERO
            elif event.position.y > viewport_height * 0.25 and event.position.x >= viewport_width * 0.5 and gather_touch == -1:
                gather_touch = event.index
                gather_origin = event.position
                camera_touch_last = event.position
                gather_direction = Vector2.ZERO
        else:
            if quickbar != null and quickbar.get_global_rect().has_point(event.position):
                active_touches.erase(event.index)
                return
            active_touches.erase(event.index)
            if nearby_touch_ids.has(event.index):
                nearby_touch_ids.erase(event.index)
                if nearby_button != null and nearby_button.visible and nearby_button.get_global_rect().has_point(event.position):
                    _perform_nearby_action()
                get_viewport().set_input_as_handled()
                return
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
            elif nearby_button != null and Rect2(nearby_button.global_position, nearby_button.size).has_point(event.position):
                return
            elif active_touches.is_empty() and not (event.position.y < 70.0 and absf(event.position.x - get_viewport().get_visible_rect().size.x * 0.5) < 80.0):
                _tap_world(event.position)
    elif event is InputEventScreenDrag:
        if nearby_touch_ids.has(event.index):
            get_viewport().set_input_as_handled()
            return
        # Пальцы независимы: левый всегда двигает героя, правый — камеру.
        # Используем координаты КОНКРЕТНОГО пальца, не event.relative,
        # который в мобильном браузере может прыгать при двух касаниях.
        if event.index == joystick_touch:
            touch_move = ((event.position - joystick_origin) / 65.0).limit_length(1.0)
        elif event.index == gather_touch:
            var swipe_x: float = clampf(event.position.x - camera_touch_last.x, -22.0, 22.0)
            camera_input_yaw -= swipe_x * 0.0022
            camera_touch_last = event.position
        active_touches[event.index] = event.position

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(-1.0)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(1.0)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if quickbar != null and quickbar.get_global_rect().has_point(event.position):
                return
            if nearby_button != null and nearby_button.visible and nearby_button.get_global_rect().has_point(event.position):
                return
            _tap_world(event.position)
