class_name Fungus
extends Node2D
## Left behind by fungus-infested zombies. Every 30s of night it spawns 4 more.
## It stays through the day, so destroy it with turrets or soldiers.

const TEX := preload("res://GrassTexture/Fungus.png")

var main
var hp := Cfg.FUNGUS_HP
var max_hp := Cfg.FUNGUS_HP
var radius := 16.0
var timer := Cfg.FUNGUS_INTERVAL
var seed_offset := 0.0


func _ready() -> void:
	seed_offset = randf() * TAU
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art crisp


func is_alive() -> bool:
	return hp > 0.0 and not is_queued_for_deletion()


func _process(delta: float) -> void:
	if main.game_over:
		return
	if main.is_night:
		timer -= delta
		if timer <= 0.0:
			timer = Cfg.FUNGUS_INTERVAL
			for i in Cfg.FUNGUS_SPAWN:
				var off := Vector2.from_angle(TAU * i / Cfg.FUNGUS_SPAWN + seed_offset) * 22.0
				main.spawn_zombie(position + off, true)
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		main.on_fungus_killed(self)


func _draw() -> void:
	# The fungus image fills its whole tile.
	var h := Cfg.TILE * 0.5
	draw_texture_rect(TEX, Rect2(-h, -h, Cfg.TILE, Cfg.TILE), false)
	if main.is_night:
		var frac := 1.0 - timer / Cfg.FUNGUS_INTERVAL
		draw_arc(Vector2.ZERO, radius + 6, -PI / 2, -PI / 2 + TAU * frac, 24, Color(1, 0.4, 0.2, 0.8), 2.0)
	if hp < max_hp:
		draw_rect(Rect2(-radius, -radius - 12, radius * 2, 3), Color(0.2, 0, 0))
		draw_rect(Rect2(-radius, -radius - 12, radius * 2 * hp / max_hp, 3), Color(0.9, 0.5, 0.2))
