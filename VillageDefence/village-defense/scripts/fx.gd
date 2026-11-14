extends Node2D
## Shot tracers, floating "+coins" text, placement previews and the selection box.

var main
var tracers: Array = []   # [from, to, color, life]
var texts: Array = []     # [pos, text, color, life]
var markers: Array = []   # [pos, life]


func add_tracer(a: Vector2, b: Vector2, c: Color) -> void:
	tracers.append([a, b, c, 0.1])


func add_text(p: Vector2, s: String, c: Color) -> void:
	if texts.size() < 60:
		texts.append([p, s, c, 1.0])


func add_marker(p: Vector2) -> void:
	markers.append([p, 0.6])


func _process(delta: float) -> void:
	var real := minf(get_process_delta_time() / maxf(Engine.time_scale, 0.001), 0.1)
	for t in tracers:
		t[3] -= delta
	tracers = tracers.filter(func(t): return t[3] > 0.0)
	for t in texts:
		t[3] -= delta
		t[0] = t[0] + Vector2(0, -24.0 * delta)
	texts = texts.filter(func(t): return t[3] > 0.0)
	for m in markers:
		m[1] -= real
	markers = markers.filter(func(m): return m[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for t in tracers:
		draw_line(t[0], t[1], t[2], 2.0)
	for t in texts:
		var c: Color = t[2]
		c.a = clampf(t[3], 0.0, 1.0)
		var w := font.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, t[0] - Vector2(w * 0.5, 0), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
	for m in markers:
		draw_arc(m[0], 6.0 + (0.6 - m[1]) * 20.0, 0, TAU, 20, Color(0.4, 1, 0.4, m[1] / 0.6), 2.0)

	if main.game_over:
		return
	var wp: Vector2 = get_global_mouse_position()
	var mode: String = main.mode
	if mode in main.BUILD_MODES:
		var t: Vector2i = main.tile_of(wp)
		var ok: bool = main.can_place(t) and main.coins >= main.cost_of(mode)
		var r := Rect2(Vector2(t) * Cfg.TILE, Vector2.ONE * Cfg.TILE)
		draw_rect(r, Color(0.3, 1, 0.3, 0.35) if ok else Color(1, 0.2, 0.2, 0.35))
		if mode == "turret":
			draw_arc(r.get_center(), Cfg.TURRET_RANGE, 0, TAU, 64, Color(1, 1, 1, 0.35), 1.5)
	elif mode == "buy":
		var p: Vector2i = main.plot_of(wp)
		if p.x >= 0 and p.y >= 0 and p.x < Cfg.GRID and p.y < Cfg.GRID and not main.owned.has(p):
			var ok: bool = main.can_buy(p) and main.coins >= main.plot_cost()
			var r: Rect2 = main.plot_rect(p)
			draw_rect(r, Color(1, 0.9, 0.3, 0.25) if ok else Color(1, 0.2, 0.2, 0.2))
			var label := "Buy: %d" % main.plot_cost() if main.can_buy(p) else "Not adjacent"
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, r.get_center() - Vector2(w * 0.5, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	elif mode == "demolish":
		var b = main.occupied.get(main.tile_of(wp))
		if b != null and b.kind != "hall":
			var h: float = Cfg.TILE * b.size * 0.5
			draw_rect(Rect2(b.position - Vector2(h, h), Vector2(h, h) * 2), Color(1, 0.2, 0.2, 0.45))
			var label := "Refund %d" % int(b.paid * Cfg.REFUND)
			draw_string(font, b.position + Vector2(-30, -h - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	elif mode == "clear":
		var t: Vector2i = main.tile_of(wp)
		var k: int = main.terrain.get_at(t)
		if k != Terrain.GRASS:
			var cost: int = main.terrain.clear_cost(k)
			var ok: bool = main.owned.has(main.tile_plot(t)) and main.coins >= cost
			var r := Rect2(Vector2(t) * Cfg.TILE, Vector2.ONE * Cfg.TILE)
			draw_rect(r, Color(1, 0.9, 0.3, 0.4) if ok else Color(1, 0.2, 0.2, 0.4))
			var label := "Clear %s: %d" % [Terrain.NAMES[k], cost]
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, r.get_center() + Vector2(-w * 0.5, -22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	if main.dragging:
		var r := Rect2(main.drag_start, Vector2.ZERO).expand(wp)
		draw_rect(r, Color(0.4, 1, 0.4, 0.12))
		draw_rect(r, Color(0.4, 1, 0.4, 0.8), false, 1.5)
