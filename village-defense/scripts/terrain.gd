class_name Terrain
extends Node2D
## Randomly generated terrain: winding rivers, rock fields and forests.
## Terrain tiles block building until they are cleared for coins.
## Water also slows zombies and soldiers that wade through it.

enum { GRASS, ROCK, TREE, WATER }

const WATER_TEX := preload("res://GrassTexture/WaterTexture.jpg")
const ROCK_TEX := preload("res://GrassTexture/RockTexture.jpg")
const N := Cfg.MAP / Cfg.TILE      # tiles per side
const ROCK_SCALE := 3.0            # each rock tile shows a 96px slice of the rock image
const NAMES := {ROCK: "Rock", TREE: "Tree", WATER: "Water"}

var grid := PackedByteArray()


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < N and t.y < N


func get_at(t: Vector2i) -> int:
	if not in_bounds(t):
		return GRASS
	return grid[t.y * N + t.x]


func set_at(t: Vector2i, v: int) -> void:
	if in_bounds(t):
		grid[t.y * N + t.x] = v
		queue_redraw()


func clear_cost(kind: int) -> int:
	match kind:
		TREE:
			return Cfg.CLEAR_TREE
		ROCK:
			return Cfg.CLEAR_ROCK
		WATER:
			return Cfg.CLEAR_WATER
	return 0


## Movement speed multiplier at a world position (water slows you down).
func speed_factor(pos: Vector2) -> float:
	var t := Vector2i(floori(pos.x / Cfg.TILE), floori(pos.y / Cfg.TILE))
	return Cfg.WATER_SLOW if get_at(t) == WATER else 1.0


# ---------------------------------------------------------------- generation
func generate() -> void:
	grid.resize(N * N)
	grid.fill(GRASS)
	_scatter(ROCK, 0.05, 0.38)
	_scatter(TREE, 0.06, 0.25)
	var horizontal := randf() < 0.5
	_river(horizontal)
	if randf() < 0.5:
		_river(not horizontal)
	_clear_core()
	queue_redraw()


func _scatter(kind: int, freq: float, threshold: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = freq
	for y in N:
		for x in N:
			if noise.get_noise_2d(x, y) > threshold and randf() < 0.85:
				grid[y * N + x] = kind


## One continuous river from one map edge to the opposite edge. It meanders on
## one side of the village and never enters the core or the ring around it.
func _river(horizontal: bool) -> void:
	var core_lo := Cfg.CORE.x * Cfg.PLOT_TILES - Cfg.PLOT_TILES   # first tile of the ring around the core
	var core_hi := (Cfg.CORE.x + 2) * Cfg.PLOT_TILES - 1            # last tile of that ring
	var before := randf() < 0.5
	var lo := 2.0 if before else float(core_hi + 3)
	var hi := float(core_lo - 3) if before else float(N - 3)
	var path := FastNoiseLite.new()
	path.seed = randi()
	path.frequency = 0.03
	var width := FastNoiseLite.new()
	width.seed = randi()
	width.frequency = 0.08
	var mid := (lo + hi) * 0.5
	var amp := (hi - lo) * 0.5
	for a in N:
		var c := clampf(mid + path.get_noise_1d(a) * amp * 1.8, lo, hi)
		var half := 1.1 + (width.get_noise_1d(a) + 1.0) * 0.7   # 1.1 .. 2.5 tiles
		for b in range(floori(c - half), ceili(c + half)):
			var t := Vector2i(a, b) if horizontal else Vector2i(b, a)
			set_at(t, WATER)


func _clear_core() -> void:
	var start := Vector2i(Cfg.CORE) * Cfg.PLOT_TILES
	for x in Cfg.PLOT_TILES:
		for y in Cfg.PLOT_TILES:
			set_at(start + Vector2i(x, y), GRASS)


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var s := float(Cfg.TILE)
	for y in N:
		for x in N:
			var k := grid[y * N + x]
			if k == GRASS:
				continue
			var r := Rect2(x * s, y * s, s, s)
			match k:
				WATER:
					# sample in world space so the river is one seamless surface
					draw_texture_rect_region(WATER_TEX, r, r)
					_edges(x, y, k, Color(0.85, 0.8, 0.55), 3.0)
				ROCK:
					draw_texture_rect_region(ROCK_TEX, r, Rect2(r.position * ROCK_SCALE, r.size * ROCK_SCALE))
					_edges(x, y, k, Color(0.2, 0.2, 0.2, 0.8), 2.0)
				TREE:
					_tree(r.get_center(), x, y)


## Outline the sides of a tile that border a different terrain type.
func _edges(x: int, y: int, k: int, c: Color, w: float) -> void:
	var s := float(Cfg.TILE)
	var p := Vector2(x, y) * s
	var hw := w * 0.5
	if get_at(Vector2i(x, y - 1)) != k:
		draw_line(p + Vector2(0, hw), p + Vector2(s, hw), c, w)
	if get_at(Vector2i(x, y + 1)) != k:
		draw_line(p + Vector2(0, s - hw), p + Vector2(s, s - hw), c, w)
	if get_at(Vector2i(x - 1, y)) != k:
		draw_line(p + Vector2(hw, 0), p + Vector2(hw, s), c, w)
	if get_at(Vector2i(x + 1, y)) != k:
		draw_line(p + Vector2(s - hw, 0), p + Vector2(s - hw, s), c, w)


func _tree(c: Vector2, x: int, y: int) -> void:
	var h := absi((x * 73856093) ^ (y * 19349663))
	var jitter := Vector2((h % 7) - 3, ((h / 7) % 7) - 3)
	var size := 11.0 + (h % 4)
	c += jitter
	draw_circle(c + Vector2(4, 5), size, Color(0, 0, 0, 0.3))
	draw_circle(c, size, Color(0.1, 0.32, 0.12))
	draw_circle(c + Vector2(-3, -3), size * 0.65, Color(0.16, 0.45, 0.17))
	draw_circle(c + Vector2(-5, -5), size * 0.3, Color(0.3, 0.6, 0.25))
