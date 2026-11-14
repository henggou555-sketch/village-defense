class_name Soldier
extends Node2D
## Holds a guard post. Shoots enemies in range and chases those near the post.

var main
var hp := Cfg.SOLDIER_HP
var max_hp := Cfg.SOLDIER_HP
var radius := 9.0
var guard := Vector2.ZERO
var cooldown := 0.0
var selected := false
var aim := Vector2.UP


func is_alive() -> bool:
	return hp > 0.0 and not is_queued_for_deletion()


func _process(delta: float) -> void:
	if main.game_over:
		return
	cooldown -= delta
	var enemy = main.nearest_enemy(position, Cfg.SOLDIER_RANGE)
	if enemy != null:
		aim = (enemy.position - position).normalized()
		if cooldown <= 0.0:
			main.shoot(position + aim * 10.0, enemy, Cfg.SOLDIER_DMG, Color(0.6, 0.9, 1.0))
			cooldown = Cfg.SOLDIER_RATE
		queue_redraw()
		return
	var dest := guard
	var chase = main.nearest_enemy(guard, Cfg.SOLDIER_LEASH)
	if chase != null:
		dest = chase.position
	var to := dest - position
	if to.length() > 3.0:
		aim = to.normalized()
		var spd: float = Cfg.SOLDIER_SPEED * main.terrain.speed_factor(position)
		position += aim * minf(spd * delta, to.length())
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		main.on_soldier_killed(self)


func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, radius + 5, 0, TAU, 24, Color(0.4, 1.0, 0.4), 2.0)
	draw_circle(Vector2.ZERO, radius + 1.5, Color(0.05, 0.08, 0.15))
	draw_circle(Vector2.ZERO, radius, Color(0.25, 0.45, 0.85))
	draw_line(Vector2.ZERO, aim * (radius + 7), Color(0.15, 0.15, 0.15), 3.0)
	draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.7, 0.55))
	if hp < max_hp:
		draw_rect(Rect2(-radius, -radius - 6, radius * 2, 3), Color(0.2, 0, 0))
		draw_rect(Rect2(-radius, -radius - 6, radius * 2 * hp / max_hp, 3), Color(0.3, 0.9, 0.3))
