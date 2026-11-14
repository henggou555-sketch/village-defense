class_name Zombie
extends Node2D
## Walks toward the village core. Attacks any building or soldier that gets close.
## Fungus-infested zombies leave a fungus patch when they die.

var main
var fungal := false
var hp := 60.0
var max_hp := 60.0
var speed := 42.0
var dps := 10.0
var radius := 10.0
var target = null
var retarget := 0.0
var lane := Vector2.ZERO
var facing := Vector2.RIGHT


func setup(m, is_fungal: bool, night: int) -> void:
	main = m
	fungal = is_fungal
	var scale_f := 1.0 + night * Cfg.ZOMBIE_HP_PER_NIGHT
	if fungal:
		max_hp = 90.0 * scale_f
		speed = 34.0
		dps = 12.0
		radius = 11.0
	else:
		max_hp = 60.0 * scale_f
		speed = 42.0
		dps = 10.0
	hp = max_hp
	speed *= randf_range(0.9, 1.1)
	lane = Vector2(randf_range(-60, 60), randf_range(-60, 60))
	retarget = randf() * 0.5


func is_alive() -> bool:
	return hp > 0.0 and not is_queued_for_deletion()


func _process(delta: float) -> void:
	if main.game_over:
		return
	retarget -= delta
	if retarget <= 0.0 or not main.valid(target):
		retarget = 0.5
		target = main.zombie_target(position)
	var goal: Vector2 = main.core_center + lane
	var reach := 0.0
	var has_target: bool = main.valid(target)
	if has_target:
		goal = target.position
		reach = target.radius + radius + 2.0
	var to := goal - position
	if to.length() > 0.01:
		facing = to.normalized()
	if has_target and to.length() <= reach:
		target.take_damage(dps * delta)
	else:
		var spd: float = speed * main.terrain.speed_factor(position)
		position += facing * minf(spd * delta, to.length())
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		main.on_zombie_killed(self)


func _draw() -> void:
	var body := Color(0.45, 0.6, 0.38) if not fungal else Color(0.5, 0.38, 0.55)
	draw_circle(Vector2.ZERO, radius + 1.5, Color(0.08, 0.1, 0.06))
	draw_circle(Vector2.ZERO, radius, body)
	if fungal:
		draw_circle(Vector2(-4, -3), 3.0, Color(0.95, 0.55, 0.2))
		draw_circle(Vector2(4, 4), 2.5, Color(0.95, 0.55, 0.2))
		draw_circle(Vector2(3, -5), 1.8, Color(0.95, 0.55, 0.2))
	var side := facing.orthogonal() * 3.5
	var fwd := facing * (radius * 0.55)
	draw_circle(fwd + side, 2.0, Color(0.95, 0.15, 0.1))
	draw_circle(fwd - side, 2.0, Color(0.95, 0.15, 0.1))
	if hp < max_hp:
		draw_rect(Rect2(-radius, -radius - 6, radius * 2, 3), Color(0.2, 0, 0))
		draw_rect(Rect2(-radius, -radius - 6, radius * 2 * hp / max_hp, 3), Color(0.9, 0.2, 0.2))
