extends Node2D
## Game state: day/night cycle, waves, territory, building placement, win/lose.

const GRASS := preload("res://GrassTexture/GrassText.jpg")
const FxScript := preload("res://scripts/fx.gd")
const HudScript := preload("res://scripts/hud.gd")
const SPEEDS := [1.0, 2.0, 3.0]
const BUILD_MODES := ["mine", "turret", "wall"]

var coins: int = Cfg.START_COINS
var night := 0
var is_night := false
var phase_time: float = Cfg.DAY_LEN
var game_over := false

var owned := {}        # Vector2i plot -> true
var contested := {}    # plots invaded at some point this night (for messages)
var presence := {}     # plots with zombies inside right now
var occupied := {}     # Vector2i tile -> Building
var mine_count := 0
var kills := 0

var spawn_left := 0
var spawn_timer := 0.0
var spawn_interval := 1.0

var mode := ""         # "", "mine", "turret", "wall", "buy", "demolish", "clear"
var selected: Array = []
var drag_start := Vector2.ZERO
var dragging := false
var middle_drag := false
var speed_index := 0
var paused := false

# per-frame caches of live entities
var zombies_cache: Array = []
var fungus_cache: Array = []
var targets_cache: Array = []

var core_center := Vector2.ZERO
var camera: Camera2D
var tint: CanvasModulate
var fx
var hud
var entities: Node2D
var terrain: Terrain
var last_ticks := 0
var night_tint := Color(0.36, 0.4, 0.66)


func _ready() -> void:
	randomize()
	Engine.time_scale = 1.0
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # needed to tile the grass
	core_center = Vector2(Cfg.CORE) * Cfg.PLOT + Vector2.ONE * (Cfg.PLOT * 0.5)

	terrain = Terrain.new()
	add_child(terrain)
	terrain.generate()
	entities = Node2D.new()
	add_child(entities)
	fx = FxScript.new()
	fx.main = self
	fx.z_index = 10
	add_child(fx)
	tint = CanvasModulate.new()
	add_child(tint)
	camera = Camera2D.new()
	camera.position = core_center
	add_child(camera)
	camera.make_current()
	hud = HudScript.new()
	hud.main = self
	add_child(hud)

	owned[Cfg.CORE] = true
	_place_building("hall", Vector2i(Cfg.CORE) * Cfg.PLOT_TILES + Vector2i(2, 2), 0)
	last_ticks = Time.get_ticks_usec()
	hud.show_message("Day 1: build mines and turrets. Night falls in 60 seconds.")
	if OS.get_cmdline_user_args().has("--autotest"):
		var at = preload("res://scripts/autotest.gd").new()
		at.main = self
		add_child(at)


# ---------------------------------------------------------------- helpers
func plot_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / Cfg.PLOT), floori(pos.y / Cfg.PLOT))


func tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / Cfg.TILE), floori(pos.y / Cfg.TILE))


func tile_plot(t: Vector2i) -> Vector2i:
	return Vector2i(floori(float(t.x) / Cfg.PLOT_TILES), floori(float(t.y) / Cfg.PLOT_TILES))


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t) * Cfg.TILE + Vector2.ONE * (Cfg.TILE * 0.5)


func plot_rect(p: Vector2i) -> Rect2:
	return Rect2(Vector2(p) * Cfg.PLOT, Vector2.ONE * Cfg.PLOT)


func valid(n) -> bool:
	return n != null and is_instance_valid(n) and n.is_alive()


func plot_cost() -> int:
	return Cfg.PLOT_BASE_COST + Cfg.PLOT_COST_STEP * (owned.size() - 1)


func cost_of(kind: String) -> int:
	match kind:
		"mine":
			return int(Cfg.BUILDINGS["mine"]["cost"]) + Cfg.MINE_COST_STEP * mine_count
		"soldier":
			return Cfg.SOLDIER_COST
		"buy":
			return plot_cost()
		"demolish", "clear", "":
			return 0
	return int(Cfg.BUILDINGS[kind]["cost"])


func add_coins(n: int, at: Vector2) -> void:
	coins += n
	fx.add_text(at, "+%d" % n, Color(1.0, 0.85, 0.25))


# ---------------------------------------------------------------- main loop
func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := minf((now - last_ticks) / 1000000.0, 0.1)
	last_ticks = now
	_update_camera(real_dt)
	queue_redraw()
	if game_over:
		return
	_refresh_caches()
	phase_time -= delta
	if is_night:
		_process_spawning(delta)
		_check_zombie_positions()
		if game_over:
			return
	if phase_time <= 0.0:
		if is_night:
			_end_night()
		else:
			_start_night()
	_update_tint()


func _refresh_caches() -> void:
	zombies_cache = get_tree().get_nodes_in_group("zombies")
	fungus_cache = get_tree().get_nodes_in_group("fungus")
	targets_cache = get_tree().get_nodes_in_group("soldiers")
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.kind != "hall":
			targets_cache.append(b)


func _update_tint() -> void:
	var c := Color.WHITE
	if is_night:
		c = night_tint
		if phase_time < 8.0:
			c = night_tint.lerp(Color.WHITE, 1.0 - phase_time / 8.0)
	elif phase_time < 8.0:
		c = Color.WHITE.lerp(night_tint, 1.0 - phase_time / 8.0)
	tint.color = c


func _update_camera(dt: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	camera.position += dir.normalized() * 700.0 * dt / camera.zoom.x
	camera.position = camera.position.clamp(Vector2(-200, -200), Vector2(Cfg.MAP + 200, Cfg.MAP + 200))


# ---------------------------------------------------------------- day / night
func _start_night() -> void:
	night += 1
	is_night = true
	phase_time = Cfg.NIGHT_LEN
	contested.clear()
	spawn_left = Cfg.wave_size(night)
	spawn_interval = Cfg.SPAWN_WINDOW / spawn_left
	spawn_timer = 0.0
	for f in get_tree().get_nodes_in_group("fungus"):
		f.timer = Cfg.FUNGUS_INTERVAL
	hud.show_message("Night %d / %d: the dead are coming!" % [night, Cfg.MAX_NIGHTS])


func start_night_now() -> void:
	if not is_night and not game_over:
		phase_time = 0.0


func _end_night() -> void:
	# Any owned plot (except the core) that still has a zombie inside at dawn is lost.
	var lost := {}
	for z in get_tree().get_nodes_in_group("zombies"):
		var p := plot_of(z.position)
		if owned.has(p) and p != Cfg.CORE:
			lost[p] = true
	for p in lost:
		_lose_plot(p)
	# Daylight: no zombies. Fungus patches survive.
	for z in get_tree().get_nodes_in_group("zombies"):
		z.remove_from_group("zombies")
		z.queue_free()
	contested.clear()
	presence.clear()
	spawn_left = 0
	if night >= Cfg.MAX_NIGHTS:
		_finish(true, "You survived all %d nights!" % Cfg.MAX_NIGHTS)
		return
	is_night = false
	phase_time = Cfg.DAY_LEN
	if lost.size() > 0:
		hud.show_message("Dawn. You lost %d territor%s to the horde." % [lost.size(), "y" if lost.size() == 1 else "ies"])
	else:
		hud.show_message("Dawn. You survived night %d!" % night)


func _process_spawning(delta: float) -> void:
	if spawn_left <= 0:
		return
	spawn_timer -= delta
	while spawn_timer <= 0.0 and spawn_left > 0:
		spawn_timer += spawn_interval
		spawn_left -= 1
		spawn_zombie(_edge_point(), randf() < Cfg.fungal_ratio(night))


func _edge_point() -> Vector2:
	var m := float(Cfg.MAP)
	var t := randf() * m
	match randi() % 4:
		0:
			return Vector2(t, -24)
		1:
			return Vector2(t, m + 24)
		2:
			return Vector2(-24, t)
	return Vector2(m + 24, t)


func spawn_zombie(pos: Vector2, fungal: bool) -> void:
	if get_tree().get_nodes_in_group("zombies").size() >= Cfg.MAX_ZOMBIES:
		return
	var z := Zombie.new()
	z.setup(self, fungal, night)
	z.position = pos
	z.add_to_group("zombies")
	entities.add_child(z)


func _check_zombie_positions() -> void:
	presence.clear()
	for z in zombies_cache:
		if not valid(z):
			continue
		var p := plot_of(z.position)
		if p == Cfg.CORE:
			_finish(false, "A zombie broke into the village core on night %d." % night)
			return
		if owned.has(p):
			presence[p] = true
			if not contested.has(p):
				contested[p] = true
				hud.show_message("Zombies in your territory! Kill them before dawn or lose it.")


func _lose_plot(p: Vector2i) -> void:
	owned.erase(p)
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.plot == p:
			remove_building(b, false)


func _finish(won: bool, reason: String) -> void:
	game_over = true
	Engine.time_scale = 1.0
	tint.color = Color.WHITE
	hud.show_end(won, reason)


# ---------------------------------------------------------------- combat
func nearest_enemy(pos: Vector2, rng: float):
	var best = null
	var bd := rng * rng
	for z in zombies_cache:
		if not valid(z):
			continue
		var d := pos.distance_squared_to(z.position)
		if d < bd:
			bd = d
			best = z
	if best != null:
		return best
	bd = rng * rng
	for f in fungus_cache:
		if not valid(f):
			continue
		var d := pos.distance_squared_to(f.position)
		if d < bd:
			bd = d
			best = f
	return best


func zombie_target(pos: Vector2):
	var best = null
	var bd := Cfg.ZOMBIE_AGGRO * Cfg.ZOMBIE_AGGRO
	for t in targets_cache:
		if not valid(t):
			continue
		var d := pos.distance_squared_to(t.position)
		if d < bd:
			bd = d
			best = t
	return best


func shoot(from: Vector2, target, dmg: float, color: Color) -> void:
	fx.add_tracer(from, target.position, color)
	target.take_damage(dmg)


func on_zombie_killed(z) -> void:
	kills += 1
	coins += Cfg.FUNGAL_KILL_REWARD if z.fungal else Cfg.KILL_REWARD
	z.remove_from_group("zombies")
	z.queue_free()
	if z.fungal:
		_spawn_fungus(z.position)


func _spawn_fungus(pos: Vector2) -> void:
	var patches := get_tree().get_nodes_in_group("fungus")
	if patches.size() >= Cfg.MAX_FUNGUS:
		return
	# Fungus snaps to the tile grid and fills one tile. If a building is on that
	# tile, it grows on the nearest free neighbouring tile instead.
	var taken := {}
	for p in patches:
		taken[tile_of(p.position)] = true
	var home := tile_of(pos)
	var spot = null
	for off in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var t: Vector2i = home + off
		if taken.has(t):
			return  # merges into the patch already there
		if not occupied.has(t) and terrain.get_at(t) == Terrain.GRASS:
			spot = t
			break
	if spot == null:
		return
	var f := Fungus.new()
	f.main = self
	f.position = tile_center(spot)
	f.add_to_group("fungus")
	entities.add_child(f)


func on_fungus_killed(f) -> void:
	add_coins(Cfg.FUNGUS_KILL_REWARD, f.position)
	f.remove_from_group("fungus")
	f.queue_free()


func on_soldier_killed(s) -> void:
	selected.erase(s)
	s.remove_from_group("soldiers")
	s.queue_free()


# ---------------------------------------------------------------- building
func set_mode(m: String) -> void:
	if game_over:
		return
	mode = "" if mode == m else m


func can_place(t: Vector2i) -> bool:
	if not owned.has(tile_plot(t)) or occupied.has(t):
		return false
	if terrain.get_at(t) != Terrain.GRASS:
		return false
	var c := tile_center(t)
	for f in get_tree().get_nodes_in_group("fungus"):
		if f.position.distance_to(c) < 26.0:
			return false
	return true


func try_place(kind: String, t: Vector2i, quiet := false) -> void:
	if not can_place(t):
		if not quiet:
			hud.show_message("You can only build on empty tiles inside your territory.")
		return
	var cost := cost_of(kind)
	if coins < cost:
		if not quiet:
			hud.show_message("Not enough coins (%d needed)." % cost)
		return
	coins -= cost
	_place_building(kind, t, cost)


func _place_building(kind: String, t: Vector2i, cost: int) -> void:
	var b := Building.new()
	b.setup(self, kind, t, cost)
	b.add_to_group("buildings")
	for bt in b.tiles():
		occupied[bt] = b
	if kind == "mine":
		mine_count += 1
	entities.add_child(b)


func remove_building(b, refund: bool) -> void:
	if b.is_queued_for_deletion():
		return
	for bt in b.tiles():
		occupied.erase(bt)
	if b.kind == "mine":
		mine_count -= 1
	if refund:
		add_coins(int(b.paid * Cfg.REFUND), b.position)
	b.remove_from_group("buildings")
	b.queue_free()


func try_demolish(t: Vector2i) -> void:
	var b = occupied.get(t)
	if b == null or b.kind == "hall":
		return
	remove_building(b, true)


## Pay to remove a tree or rock, or fill in a water tile, on land you own.
func try_clear(t: Vector2i) -> void:
	var k := terrain.get_at(t)
	if k == Terrain.GRASS:
		return
	if not owned.has(tile_plot(t)):
		hud.show_message("You can only clear land inside your territory.")
		return
	var cost := terrain.clear_cost(k)
	if coins < cost:
		hud.show_message("Not enough coins (%d needed)." % cost)
		return
	coins -= cost
	terrain.set_at(t, Terrain.GRASS)
	fx.add_text(tile_center(t), "-%d" % cost, Color(1.0, 0.5, 0.4))


func can_buy(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= Cfg.GRID or p.y >= Cfg.GRID or owned.has(p):
		return false
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if owned.has(p + d):
			return true
	return false


func try_buy(p: Vector2i) -> void:
	if not can_buy(p):
		hud.show_message("Territory must border land you already own.")
		return
	var cost := plot_cost()
	if coins < cost:
		hud.show_message("Not enough coins (%d needed)." % cost)
		return
	coins -= cost
	owned[p] = true
	hud.show_message("Territory bought. Defend it at night!")


func spawn_soldier() -> void:
	if game_over:
		return
	if coins < Cfg.SOLDIER_COST:
		hud.show_message("Not enough coins (%d needed)." % Cfg.SOLDIER_COST)
		return
	coins -= Cfg.SOLDIER_COST
	var s := Soldier.new()
	s.main = self
	s.position = core_center + Vector2(randf_range(-20, 20), 44)
	s.guard = core_center + Vector2(randf_range(-70, 70), randf_range(50, 85))
	s.add_to_group("soldiers")
	entities.add_child(s)


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var wp := get_global_mouse_position()
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 1.1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			middle_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and not game_over:
			if mb.pressed:
				match mode:
					"":
						dragging = true
						drag_start = wp
					"buy":
						try_buy(plot_of(wp))
					"demolish":
						try_demolish(tile_of(wp))
					"clear":
						try_clear(tile_of(wp))
					_:
						try_place(mode, tile_of(wp))
			elif dragging:
				dragging = false
				_finish_selection(drag_start, wp)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not game_over:
			if mode != "":
				mode = ""
			elif selected.size() > 0:
				_order_move(wp)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if middle_drag:
			camera.position -= mm.relative / camera.zoom
		elif mode == "wall" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			try_place("wall", tile_of(get_global_mouse_position()), true)
		elif mode == "clear" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			try_clear(tile_of(get_global_mouse_position()))
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				set_mode("mine")
			KEY_2:
				set_mode("turret")
			KEY_3:
				set_mode("wall")
			KEY_4:
				spawn_soldier()
			KEY_5:
				set_mode("buy")
			KEY_X:
				set_mode("demolish")
			KEY_C:
				set_mode("clear")
			KEY_Q:
				_select_all()
			KEY_N:
				start_night_now()
			KEY_P, KEY_SPACE:
				toggle_pause()
			KEY_F:
				cycle_speed()
			KEY_ESCAPE:
				mode = ""
				_clear_selection()


func _zoom(f: float) -> void:
	camera.zoom = (camera.zoom * f).clamp(Vector2.ONE * 0.35, Vector2.ONE * 2.5)


func _clear_selection() -> void:
	for s in selected:
		if is_instance_valid(s):
			s.selected = false
			s.queue_redraw()
	selected.clear()


func _select_all() -> void:
	_clear_selection()
	for s in get_tree().get_nodes_in_group("soldiers"):
		s.selected = true
		selected.append(s)


func _finish_selection(a: Vector2, b: Vector2) -> void:
	_clear_selection()
	var r := Rect2(a, Vector2.ZERO).expand(b)
	var tiny := r.size.length() < 6.0
	for s in get_tree().get_nodes_in_group("soldiers"):
		var hit: bool = s.position.distance_to(b) < 16.0 if tiny else r.has_point(s.position)
		if hit:
			s.selected = true
			selected.append(s)
			if tiny:
				break


func _order_move(target: Vector2) -> void:
	var i := 0
	for s in selected:
		if not is_instance_valid(s):
			continue
		var off := Vector2.ZERO
		if i > 0:
			off = Vector2.from_angle(i * 2.4) * 16.0 * sqrt(float(i))
		s.guard = target + off
		i += 1
	fx.add_marker(target)


func toggle_pause() -> void:
	if game_over:
		return
	paused = not paused
	Engine.time_scale = 0.0 if paused else SPEEDS[speed_index]


func cycle_speed() -> void:
	if game_over:
		return
	speed_index = (speed_index + 1) % SPEEDS.size()
	if not paused:
		Engine.time_scale = SPEEDS[speed_index]


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var m := float(Cfg.MAP)
	draw_rect(Rect2(-600, -600, m + 1200, m + 1200), Color(0.13, 0.16, 0.1))
	draw_texture_rect(GRASS, Rect2(0, 0, m, m), true)  # repeats the grass across the map
	var t := Time.get_ticks_msec() / 1000.0
	var show_tiles := mode in BUILD_MODES or mode == "demolish" or mode == "clear"
	for x in Cfg.GRID:
		for y in Cfg.GRID:
			var p := Vector2i(x, y)
			var r := plot_rect(p)
			if owned.has(p):
				# translucent warm tint so the grass still shows through owned land
				draw_rect(r, Color(1.0, 0.85, 0.4, 0.22) if p == Cfg.CORE else Color(1.0, 0.9, 0.5, 0.14))
				if show_tiles:
					for i in range(1, Cfg.PLOT_TILES):
						var o := i * Cfg.TILE
						draw_line(r.position + Vector2(o, 0), r.position + Vector2(o, Cfg.PLOT), Color(0, 0, 0, 0.12))
						draw_line(r.position + Vector2(0, o), r.position + Vector2(Cfg.PLOT, o), Color(0, 0, 0, 0.12))
				if presence.has(p):
					draw_rect(r, Color(1, 0, 0, 0.18 + 0.12 * sin(t * 8.0)))
				draw_rect(r.grow(-1), Color(0.95, 0.85, 0.4, 0.55), false, 2.0)
			else:
				draw_rect(r, Color(0, 0, 0, 0.15), false, 1.0)
	draw_rect(plot_rect(Cfg.CORE).grow(-3), Color(1, 0.35, 0.25, 0.9), false, 3.0)
