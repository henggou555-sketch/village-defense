class_name Building
extends Node2D
## Mine, turret, wall or the town hall. Occupies size x size tiles.

const TURRET_TEX := preload("res://GrassTexture/Turret.png")
const TURRET_FACES := 16
const TURRET_STEP := TAU / TURRET_FACES

var main
var face := 12          # turret facing index 0..15 (0 = right, 12 = up)
var kind := ""
var tile := Vector2i.ZERO
var plot := Vector2i.ZERO
var size := 1
var hp := 100.0
var max_hp := 100.0
var radius := 14.0
var timer := 0.0
var paid := 0


func setup(m, k: String, t: Vector2i, cost: int) -> void:
	main = m
	kind = k
	tile = t
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel art
	paid = cost
	var d: Dictionary = Cfg.BUILDINGS[k]
	size = d["size"]
	max_hp = d["hp"]
	hp = max_hp
	position = Vector2(t) * Cfg.TILE + Vector2.ONE * (Cfg.TILE * size * 0.5)
	radius = Cfg.TILE * size * 0.45
	plot = main.plot_of(position)


func tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in size:
		for y in size:
			out.append(tile + Vector2i(x, y))
	return out


func is_alive() -> bool:
	return hp > 0.0 and not is_queued_for_deletion()


func _process(delta: float) -> void:
	if main.game_over:
		return
	match kind:
		"mine":
			timer += delta
			if timer >= Cfg.MINE_INTERVAL:
				timer -= Cfg.MINE_INTERVAL
				main.add_coins(Cfg.MINE_INCOME, position + Vector2(0, -16))
		"turret":
			timer -= delta
			if timer <= 0.0:
				var target = main.nearest_enemy(position, Cfg.TURRET_RANGE)
				if target != null:
					_aim_at(target.position)
					var muzzle := position + Vector2.from_angle(face * TURRET_STEP) * Cfg.TILE * 0.5
					main.shoot(muzzle, target, Cfg.TURRET_DMG, Color(1.0, 0.85, 0.4))
					timer = Cfg.TURRET_RATE
				else:
					timer = 0.15


## Snap the turret to the nearest of its 16 facings.
func _aim_at(p: Vector2) -> void:
	var idx := posmod(roundi((p - position).angle() / TURRET_STEP), TURRET_FACES)
	if idx != face:
		face = idx
		queue_redraw()


func take_damage(amount: float) -> void:
	if kind == "hall" or hp <= 0.0:
		return
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		main.remove_building(self, false)


func _draw() -> void:
	var h := Cfg.TILE * size * 0.5 - 2.0
	var r := Rect2(-h, -h, h * 2.0, h * 2.0)
	match kind:
		"hall":
			draw_rect(r, Color(0.45, 0.28, 0.16))
			draw_rect(r.grow(-5), Color(0.72, 0.5, 0.3))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-h + 3, -2), Vector2(0, -h + 3), Vector2(h - 3, -2)]), Color(0.65, 0.18, 0.15))
			draw_rect(Rect2(-6, 6, 12, h - 8), Color(0.3, 0.18, 0.1))
		"mine":
			draw_rect(r, Color(0.32, 0.25, 0.18))
			draw_circle(Vector2(0, 2), h * 0.6, Color(0.12, 0.1, 0.08))
			draw_circle(Vector2(-5, -6), 3.0, Color(1.0, 0.82, 0.2))
			draw_circle(Vector2(6, -4), 2.5, Color(1.0, 0.82, 0.2))
			draw_circle(Vector2(1, 8), 2.0, Color(1.0, 0.82, 0.2))
		"turret":
			# Sprite fills the tile; its barrel points left (angle PI) in the image.
			var full := Cfg.TILE * 0.5
			draw_set_transform(Vector2.ZERO, face * TURRET_STEP - PI)
			draw_texture_rect(TURRET_TEX, Rect2(-full, -full, Cfg.TILE, Cfg.TILE), false)
			draw_set_transform(Vector2.ZERO)
		"wall":
			draw_rect(r, Color(0.5, 0.48, 0.44))
			draw_line(Vector2(-h, 0), Vector2(h, 0), Color(0.35, 0.33, 0.3), 2.0)
			draw_line(Vector2(0, -h), Vector2(0, 0), Color(0.35, 0.33, 0.3), 2.0)
			draw_line(Vector2(-h * 0.5, 0), Vector2(-h * 0.5, h), Color(0.35, 0.33, 0.3), 2.0)
			draw_line(Vector2(h * 0.5, 0), Vector2(h * 0.5, h), Color(0.35, 0.33, 0.3), 2.0)
	if hp < max_hp:
		var w := h * 2.0
		draw_rect(Rect2(-h, -h - 7, w, 4), Color(0.2, 0, 0))
		draw_rect(Rect2(-h, -h - 7, w * hp / max_hp, 4), Color(0.3, 0.9, 0.3))
