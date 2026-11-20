extends "res://tests/test_base.gd"

func test_palette_placement_commits_on_release() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	runner.root.add_child(game)
	game.set_process(false)
	var view: BattlefieldView = game.field
	view.zoom = 40.0
	view.origin = Vector2.ZERO
	var arrow: Button = game.site_actions.get_node("BuildArrow")
	check(not arrow.disabled, "An affordable tower can be chosen before choosing a tile")
	arrow.pressed.emit()
	equal(view.placement_preview.kind, "arrow")
	var gold: int = game.sim.state.gold
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	pointer.position = game.sim.track.slots.s1.position * view.zoom
	view._gui_input(pointer)
	equal(game.sim.state.gold, gold, "Touching the board previews the placement for free")
	pointer.pressed = false
	pointer.position = Vector2(-10, -10)
	view._gui_input(pointer)
	check(game.sim.state.towers.is_empty() and not game.catalog_build.is_empty(), "Releasing outside cancels the gesture")
	pointer.pressed = true
	pointer.position = game.sim.track.slots.s1.position * view.zoom
	view._gui_input(pointer)
	var motion := InputEventMouseMotion.new()
	motion.position = game.sim.track.slots.s2.position * view.zoom
	view._gui_input(motion)
	equal(view.hover_slot, "s2")
	pointer.position = motion.position
	pointer.pressed = false
	view._gui_input(pointer)
	equal(game.sim.state.towers.size(), 1)
	equal(game.sim.state.towers.s2.kind, "arrow")
	equal(game.sim.state.gold, gold - int(DataDB.read("towers").arrow.cost))
	check(view.placement_preview.is_empty())
	game.queue_free()
	await runner.process_frame

func test_scene_smoke_and_touch_layout() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	runner.root.add_child(game)
	game.set_process(false)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.size = Vector2(720, 1000)
	await runner.process_frame
	await runner.process_frame
	check(not game.wide)
	check(game.round_controls.visible)
	near(game.start_button.modulate.a * game.round_controls.modulate.a, 1.0)
	check(game.preview_row.get_global_rect().end.y <= game.field.get_global_rect().position.y)
	check(game.preview_row.size.y <= 54)
	var build_board: Rect2 = game.field.get_global_rect()
	game._site_pressed("s1")
	game._apply({"type": "build", "slot": "s1", "kind": "arrow"})
	game._apply({"type": "start_wave"})
	for tick: int in range(300):
		game.sim.step()
		game._take_events()
	for frame: int in range(3):
		await runner.process_frame
	equal(game.sim.state.phase, "wave")
	check(not game.round_controls.visible, "Round controls hide while the wave is underway")
	equal(game.field.get_global_rect(), build_board, "Hiding the round controls does not resize the board")
	check(int(game.sim.state.tick) >= 300)
	check(game.field.size.y > 320, "Portrait assault keeps the battlefield visible (%s)" % game.field.size)
	check(game.combat_status.size.x > 80, "The combat header uses available width")
	check(not game.sim.state.mobs.is_empty(), "Live enemies are present in the visible battlefield")
	check(game.field.aim_by_slot.has("s1"), "Tower aims at an enemy it fired at")
	equal(game.tower_stats.get_node("Damage/Value").text, "13")
	equal(game.tower_stats.get_node("Range/Value").text, "3.7")
	equal(game.tower_stats.get_node("Speed/Value").text, "1.2/s")
	var battlefield_rect: Rect2 = game.field.get_global_rect()
	var gold_before: int = game.sim.state.gold
	var original_button: Rect2 = game.upgrade_button.get_global_rect()
	_check_tower_toolbar(game)
	game._show_upgrade_preview()
	await runner.process_frame
	await runner.process_frame
	equal(game.upgrade_button.get_global_rect(), original_button, "Confirm stays on the original Upgrade button")
	equal(game.field.get_global_rect(), battlefield_rect, "Upgrade preview keeps the board in place")
	equal(game.overlay_type, "", "Upgrade does not open a modal")
	check(game.tower_comparison.visible)
	equal(game.sim.state.gold, gold_before, "Upgrade preview is free")
	var panel_text := PackedStringArray()
	for label: Label in game.tower_comparison.find_children("*", "Label", true, false):
		panel_text.append(label.text)
	check("Current · Lv 1" in panel_text and "After upgrade · Lv 2" in panel_text)
	check(is_instance_valid(game.tower_comparison.find_child("Damage", true, false)))
	game._apply({"type": "upgrade", "slot": "s1"})
	equal(game.tower_stats.get_node("Damage/Value").text, "20.8", "The inspector updates after a live upgrade")
	game._site_pressed("s2")
	check(game.site_actions.get_child_count() > 0, "Build buttons appear on an open tile during combat")
	await runner.process_frame
	await runner.process_frame
	equal(game.field.get_global_rect(), battlefield_rect, "Switching between the tower and build panels keeps the board in place")
	var battlefield: BattlefieldView = game.field
	game._show_pause()
	check(game.paused)
	check(game.overlay_type == "pause")
	game.size = Vector2(1280, 720)
	await runner.process_frame
	check(game.wide)
	equal(game.field, battlefield, "Rotating the game preserves active battlefield animations")
	equal(game.overlay_type, "pause")
	game._resume()
	check(not game.paused)
	game._site_pressed("s1")
	await runner.process_frame
	_check_tower_toolbar(game)
	game._show_preview(10)
	equal(game.overlay_type, "preview")
	game.sim.state.phase = "build"
	game.sim.state.mobs.clear()
	game.sim.state.spawn_queue.clear()
	game.sim.state.selection_pending = true
	game._show_selection()
	equal(game.overlay_type, "select")
	var found_slow: bool = false
	for button: Button in game.overlay.find_children("*", "Button", true, false):
		if button.text == "Slow 15% · 2s":
			found_slow = button.tooltip_text.contains("15% for 2 s") and button.get_theme_color("font_color") == StatusInfo.accent("Slow")
	check(found_slow, "Element selection exposes color-coded potency and duration")
	game._apply({"type": "select_element", "element": "fire", "tier": 1})
	equal(game.overlay_type, "")
	equal(game.sim.state.trial.element, "fire")
	equal(game.sim.state.phase, "wave", "Choosing a spirit starts the solo round immediately")
	equal(game.sim.state.spawn_queue.size(), 1)
	check(BattlefieldView.spirit_radius(1) < BattlefieldView.spirit_radius(2) and BattlefieldView.spirit_radius(2) < BattlefieldView.spirit_radius(3))
	game.queue_free()
	await runner.process_frame

func _check_tower_toolbar(game: GameScreen) -> void:
	var upgrade: Rect2 = game.upgrade_button.get_global_rect()
	var target: Rect2 = game.target_button.get_global_rect()
	var move: Rect2 = game.move_button.get_global_rect()
	var sell: Rect2 = game.secondary_button.get_global_rect()
	check(upgrade.end.x < target.position.x, "Target separates Upgrade from Move and Sell")
	check(move.position.x - target.end.x > sell.position.x - move.end.x, "Move and Sell are grouped with a gap from Target")
	near(sell.end.x, game.tower_toolbar.get_global_rect().end.x, "Sell is flush with the right edge")

func test_combat_feedback_uses_the_awarded_gold() -> void:
	var sim := Sim.new()
	check(sim.apply({"type": "build", "kind": "arrow", "slot": "s1"}).ok)
	sim.state.phase = "wave"
	var group: Dictionary = Waves.generate(1, 1).groups[0].duplicate()
	group.hp = 1.0
	sim.schedule(group, 60)
	Combat.spawn(sim, group, 10)
	var view := BattlefieldView.new()
	view.sim = sim
	var gold: int = sim.state.gold
	sim.step()
	for event: Dictionary in sim.events:
		view.animate(event)
	equal(view.shots.size(), 1)
	equal(view.rewards.size(), 1)
	equal(view.rewards[0].gold, int(sim.state.gold) - gold)
	near(sim.state.towers.s1.damage_dealt, 1.0, "Direct-hit damage excludes overkill")
	equal(sim.state.towers.s1.kills, 1)
	check(view.aim_by_slot.has("s1"))
	view.free()

func test_upgrade_badges_and_pure_crystal_confirmation() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	runner.root.add_child(game)
	game.set_process(false)
	var sim: Sim = game.sim
	sim.state.gold = 3000
	sim.state.tiers.fire = 3
	game._apply({"type": "build", "slot": "s1", "kind": "arrow"})
	game._apply({"type": "build_pure", "slot": "s2", "kind": "fire"})
	sim.state.tiers.nature = 3
	game._apply({"type": "build", "slot": "s3", "kind": "nature"})
	sim.state.towers.s3.level = 6
	check(game.field.upgrade_ready.has("s1") and not game.field.upgrade_ready.has("s2"))
	sim.state.gold = 0
	game._update_hud()
	check(game.field.upgrade_ready.is_empty(), "The grid responds to current gold")
	sim.state.wave = 29
	sim.state.phase = "wave"
	sim.step()
	game._take_events()
	check(game.stats.text.contains("◈ 1") and game.message.contains("+1 Pure Crystal"))
	check(game.field.upgrade_ready.has("s2"), "The Pure tower gains an upgrade badge when a crystal is earned")
	check(game.field.upgrade_ready.has("s3"), "A max-level Nature tower can spend the milestone crystal")
	game._site_pressed("s3")
	check(game.upgrade_button.text.begins_with("Use Crystal") and not game.upgrade_button.disabled)
	game._upgrade_pressed()
	check(game.tower_comparison.visible and game.upgrade_button.text.begins_with("Confirm"))
	equal(sim.pure_crystals(), 1)
	game._upgrade_pressed()
	check(game.upgrade_button.disabled and not game.field.upgrade_ready.has("s3"))
	equal(sim.state.towers.s3.level, 6)
	equal(sim.state.towers.s3.crystals, 1)
	check(game.stats.text.contains("◈ 0") and game.tower_effects.tooltip_text.contains("damage by 25%"))
	game.queue_free()
	await runner.process_frame

func test_countdown_pauses_and_uses_real_time_at_quadruple_speed() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	runner.root.add_child(game)
	game.set_process(false)
	check(game.start_button.text.contains("30s"))
	game._toggle_speed()
	equal(game.speed, 2)
	game._toggle_speed()
	equal(game.speed, 3)
	game._toggle_speed()
	equal(game.speed, 4)
	game._process(19)
	near(game.sim.intermission_left, 11.0)
	game._toggle_timer()
	check(game.timer_button.text.begins_with("Resume"))
	game._process(45)
	near(game.sim.intermission_left, 11.0)
	check(SaveStore.decode(SaveStore.encode(game.sim)).intermission_paused)
	game._toggle_timer()
	game._show_pause()
	game._process(15)
	near(game.sim.intermission_left, 11.0)
	game._resume()
	game._process(11)
	equal(game.sim.state.phase, "wave")
	game._process(1.0 / 30)
	equal(game.sim.state.tick, 4, "Combat advances at quadruple speed")
	game._toggle_speed()
	equal(game.speed, 1)
	game._show_status_help()
	equal(game.overlay_type, "statuses")
	check(StatusInfo.description("phasing").contains("2 seconds every 5 seconds"))
	game._open_legend()
	equal(game.overlay_type, "legend")
	equal(game.element_status.get_child_count(), 0, "Locked elements stay out of the HUD")
	game.sim.state.tiers.fire = 1
	game.sim.state.tiers.nature = 2
	game._render_element_status()
	equal(game.element_status.get_child_count(), 2)
	for element: String in DataDB.ELEMENTS:
		check(is_instance_valid(game.overlay.find_child("Overview" + element.capitalize(), true, false)))
		equal(is_instance_valid(game.element_status.find_child("Tier" + element.capitalize(), true, false)), element in ["fire", "nature"])
	game._select_legend_element("light")
	var titles := PackedStringArray()
	for entry: Button in game.overview.gallery.find_children("*", "Button", true, false):
		if entry.has_meta("tower_name"):
			titles.append(entry.get_meta("tower_name"))
	equal(titles.size(), 17, "Elemental and Pure towers, five duals, and ten triples for each element")
	check(titles.has("Pure Light"))
	check(titles.has("Daystar Bloom") and titles.has("Bloom") and not titles.has("Steam"))
	game.overview._select_tower("bloom")
	check(game.overview.details.find_children("*", "Label", true, false).any(func(line: Label) -> bool:
		return line.text.contains("Only the strongest repair applies") and line.text.contains("fills the barrier")))
	check(game.overview.details.find_children("*", "Button", true, false).any(func(button: Button) -> bool:
		return button.text == "Moon Orchid"))
	game.queue_free()
	await runner.process_frame

func test_synthesized_audio_cues() -> void:
	var arrow: AudioStreamWAV = GameAudio.stream_for("arrow")
	var cannon: AudioStreamWAV = GameAudio.stream_for("cannon")
	check(arrow.get_length() > .06)
	check(cannon.get_length() > .2)
	check(arrow.data != cannon.data)
	check(arrow.data.count(0) < arrow.data.size())

func test_status_animations_trail_the_mob_and_expire() -> void:
	var fx := StatusVfx.new()
	fx.advance(.15)
	fx.observe(1, Vector2(1, 1), PackedStringArray(["burn", "poison"]))
	fx.finish_frame()
	equal(fx.bursts.size(), 2)
	equal(fx.trails.size(), 2)
	fx.advance(.16)
	fx.observe(1, Vector2(1.2, 1), PackedStringArray(["burn", "poison"]))
	fx.finish_frame()
	equal(fx.trails.size(), 4)
	equal(fx.bursts.size(), 2, "Existing effects do not replay their application burst")
	fx.advance(1.0)
	fx.finish_frame()
	check(fx.trails.is_empty() and fx.bursts.is_empty() and fx.tracked.is_empty())
