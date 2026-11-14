extends CanvasLayer
## Top info bar, bottom build bar, messages and the win/lose screen.

var main
var info: Label
var msg: Label
var msg_until := 0
var help: Label
var buttons := {}
var speed_btn: Button
var pause_btn: Button
var night_btn: Button
var end_panel: PanelContainer
var end_label: Label


func _ready() -> void:
	# --- top bar
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_bottom = 36
	add_child(top)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 18)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(info)

	# --- message
	msg = Label.new()
	msg.anchor_right = 1.0
	msg.offset_top = 46
	msg.offset_bottom = 80
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_outline_color", Color.BLACK)
	msg.add_theme_constant_override("outline_size", 6)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg)

	# --- bottom bar
	var bottom := PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -52
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	bottom.add_child(row)
	for k in ["mine", "turret", "wall", "soldier", "buy", "clear", "demolish"]:
		var b := _button(row)
		b.toggle_mode = k != "soldier"
		if k == "soldier":
			b.pressed.connect(func(): main.spawn_soldier())
		else:
			b.pressed.connect(func(): main.set_mode(k))
		buttons[k] = b
	row.add_child(VSeparator.new())
	night_btn = _button(row)
	night_btn.text = "Start night [N]"
	night_btn.pressed.connect(func(): main.start_night_now())
	speed_btn = _button(row)
	speed_btn.pressed.connect(func(): main.cycle_speed())
	pause_btn = _button(row)
	pause_btn.pressed.connect(func(): main.toggle_pause())

	# --- help
	help = Label.new()
	help.text = "LMB: build / select soldiers (drag)   RMB: cancel / move selected soldiers   Q: select all soldiers   WASD: pan   Wheel: zoom"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.anchor_right = 1.0
	help.offset_top = -76
	help.offset_bottom = -56
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 4)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help)

	# --- end screen
	end_panel = PanelContainer.new()
	end_panel.anchor_left = 0.5
	end_panel.anchor_right = 0.5
	end_panel.anchor_top = 0.5
	end_panel.anchor_bottom = 0.5
	end_panel.offset_left = -240
	end_panel.offset_right = 240
	end_panel.offset_top = -110
	end_panel.offset_bottom = 110
	end_panel.visible = false
	add_child(end_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	end_panel.add_child(box)
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.add_theme_font_size_override("font_size", 22)
	box.add_child(end_label)
	var again := Button.new()
	again.text = "Play again"
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func(): main.restart())
	box.add_child(again)


func _button(parent: Node) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	parent.add_child(b)
	return b


func show_message(text: String) -> void:
	msg.text = text
	msg_until = Time.get_ticks_msec() + 4000


func show_end(won: bool, reason: String) -> void:
	end_label.text = ("VICTORY!\n" if won else "THE VILLAGE HAS FALLEN\n") + reason + "\nZombies killed: %d" % main.kills
	end_panel.visible = true


func _process(_delta: float) -> void:
	var phase := "NIGHT" if main.is_night else "DAY"
	var secs := maxi(0, ceili(main.phase_time))
	var night_label := "Night %d / %d" % [main.night, Cfg.MAX_NIGHTS] if main.is_night \
		else "Before night %d / %d" % [main.night + 1, Cfg.MAX_NIGHTS]
	info.text = "Coins: %d     |     %s     |     %s  %d:%02d     |     Zombies: %d   Fungus: %d     |     Territory: %d     |     Mines: %d" % [
		main.coins, night_label, phase, secs / 60, secs % 60,
		main.zombies_cache.size(), main.fungus_cache.size(), main.owned.size(), main.mine_count]

	var labels := {"mine": "[1] Mine", "turret": "[2] Turret", "wall": "[3] Wall",
		"soldier": "[4] Soldier", "buy": "[5] Buy land", "clear": "[C] Clear land", "demolish": "[X] Demolish"}
	for k in buttons:
		var b: Button = buttons[k]
		var cost: int = main.cost_of(k)
		b.text = labels[k] + ("  %d" % cost if cost > 0 else "")
		b.disabled = main.game_over or (cost > main.coins and k == "soldier")
		if b.toggle_mode:
			b.set_pressed_no_signal(main.mode == k)
	night_btn.disabled = main.is_night or main.game_over
	speed_btn.text = "Speed %dx [F]" % int(main.SPEEDS[main.speed_index])
	pause_btn.text = "Resume [P]" if main.paused else "Pause [P]"

	var left := msg_until - Time.get_ticks_msec()
	msg.modulate.a = clampf(left / 600.0, 0.0, 1.0)
