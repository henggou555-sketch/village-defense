extends Node
## Only active when launched with `-- --autotest`. Builds a simple base, runs the
## game fast and prints a line at every day/night change.

var main
var last_night := -1
var last_is_night := false


func _ready() -> void:
	Engine.time_scale = 8.0
	main.coins = 2000
	var base := Vector2i(Cfg.CORE) * Cfg.PLOT_TILES
	for t in [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 5), Vector2i(5, 5)]:
		main.try_place("turret", base + t)
	main.try_place("mine", base + Vector2i(1, 0))
	main.try_place("mine", base + Vector2i(2, 0))
	main.try_buy(Cfg.CORE + Vector2i(1, 0))
	main.try_place("turret", (Cfg.CORE + Vector2i(1, 0)) * Cfg.PLOT_TILES + Vector2i(3, 3))
	for i in 4:
		main.spawn_soldier()
	print("AUTOTEST start coins=%d owned=%d buildings=%d" % [main.coins, main.owned.size(),
		get_tree().get_nodes_in_group("buildings").size()])


var shot_frames := 0


func _process(_d: float) -> void:
	# `-- --autotest --shot`: place fungus, save a screenshot to user://shot.png, quit.
	if OS.get_cmdline_user_args().has("--shot"):
		shot_frames += 1
		if shot_frames == 5:
			Engine.time_scale = 1.0
			var c: Vector2 = main.core_center
			for off in [Vector2(-140, -40), Vector2(-110, 20), Vector2(150, 60), Vector2(130, -90)]:
				main._spawn_fungus(c + off)
		elif shot_frames == 40:
			get_viewport().get_texture().get_image().save_png("user://shot.png")
			main.camera.zoom = Vector2.ONE * 0.4
		elif shot_frames == 50:
			get_viewport().get_texture().get_image().save_png("user://shot_map.png")
			get_tree().quit()
		return
	if main.night != last_night or main.is_night != last_is_night:
		last_night = main.night
		last_is_night = main.is_night
		print("AUTOTEST %s night=%d coins=%d owned=%d zombies=%d fungus=%d soldiers=%d buildings=%d kills=%d" % [
			"NIGHT" if main.is_night else "DAY", main.night, main.coins, main.owned.size(),
			get_tree().get_nodes_in_group("zombies").size(), get_tree().get_nodes_in_group("fungus").size(),
			get_tree().get_nodes_in_group("soldiers").size(), get_tree().get_nodes_in_group("buildings").size(),
			main.kills])
	if main.game_over:
		print("AUTOTEST GAME OVER at night %d: %s" % [main.night, main.hud.end_label.text.replace("\n", " | ")])
		get_tree().quit()
