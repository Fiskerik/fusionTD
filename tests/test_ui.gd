extends "res://tests/test_base.gd"

func test_survival_menu_and_hud_library_keep_combat_live() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	runner.root.add_child(menu)
	menu.checkpoint = Sim.campaign(7, "quick")
	menu._new_run()
	check(menu.overlay.find_child("RunSurvival", true, false) is Button)
	equal(menu.overlay.find_children("*", "Button", true, false).size(), 2)
	menu.queue_free()
	await runner.process_frame
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	game.sim = Sim.campaign(7)
	runner.root.add_child(game)
	game.set_process(false)
	check(game.event_status.text.begins_with("Next event in 4 waves"))
	game._apply({"type": "start_wave"})
	var library: Button = game.find_child("HudLibrary", true, false)
	equal(library.text, "")
	equal(library.get_index(), game.speed_button.get_index() + 1)
	library.pressed.emit()
	equal(game.overlay_type, "legend")
	check(not game.paused)
	game._process(.25)
	check(int(game.sim.state.tick) > 0)
	game._close_reference()
	game._show_pause()
	var paused_tick: int = game.sim.state.tick
	game._process(.25)
	equal(game.sim.state.tick, paused_tick)
	game.queue_free()
	await runner.process_frame

func test_pre_boss_spirit_picker_starts_the_trial_and_keeps_the_boss_in_forecast() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	game.sim = Sim.campaign(7)
	game.sim.state.wave = 9
	game.sim.state.phase = "wave"
	game.sim.step()
	runner.root.add_child(game)
	game.set_process(false)
	equal(game.event_status.text, "Spirit trial · Boss next")
	game.start_button.pressed.emit()
	equal(game.overlay_type, "select")
	var spirit_option: Button = game.overlay.find_child("ChooseFire", true, false)
	check(is_instance_valid(spirit_option))
	spirit_option.pressed.emit()
	equal(game.sim.state.phase, "wave")
	equal(game.wave_label.text, "Spirit trial · Wave 10")
	equal(game.sim.state.spawn_queue.size(), 1)
	equal(game.sim.state.spawn_queue[0].group.kind, "spirit")
	check(game.preview_row.get_child(1).tooltip_text.contains("Warlock"))
	game.queue_free()
	await runner.process_frame

func test_tower_details_can_scroll_when_the_screen_is_short() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	runner.root.add_child(game)
	game.set_process(false)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.size = Vector2(850, 322)
	game.sim.state.towers.s1 = TowerRules.fusion_result("moonglacier", "s1", game.sim.next_id())
	game._site_pressed("s1")
	game._show_tower_details()
	await runner.process_frame
	await runner.process_frame
	var scroll: ScrollContainer = game.overlay.find_child("TowerDetailsScroll", true, false)
	var scrollbar: VScrollBar = scroll.get_v_scroll_bar()
	check(scrollbar.max_value > scrollbar.page, "Tower effects and stat rows extend below the visible scroll area")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = scroll.get_global_rect().get_center()
	runner.root.push_input(wheel, true)
	check(scroll.scroll_vertical > 0, "Scrolling reveals more of the tower details")
	game.queue_free()
	await runner.process_frame

func test_boon_hud_shows_the_active_effect_and_boss_rewards_let_you_keep_it() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	game.sim = Sim.campaign(7)
	game.sim.state.tiers.fire = 1
	runner.root.add_child(game)
	game.set_process(false)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.size = Vector2(720, 1000)
	await runner.process_frame
	await runner.process_frame
	check(not game.hud_boon.visible)
	var board: Rect2 = game.field.get_global_rect()
	game.sim.state.wave = 10
	game.sim.record_boss_kill()
	game._show_intermission_choice()
	equal(game.overlay_type, "boon_choice")
	var first: Array[Node] = game.overlay.find_children("*", "Button", true, false)
	equal(first.size(), 3)
	for index: int in range(first.size()):
		equal(first[index].name, "BoonOffer%d" % (index + 1))
	var choose: Button = first[0]
	choose.pressed.emit()
	var active: Dictionary = game.sim.state.active_boon.duplicate()
	var boon: Dictionary = DataDB.read("run_boons")[active.id]
	var description: String = RunBoons.describe(boon, float(active.potency))
	check(game.hud_boon.visible and game.hud_boon.tooltip_text.contains(description.get_slice("\n", 0)))
	check(game.hud_boon_value.text.begins_with("+"))
	await runner.process_frame
	equal(game.field.get_global_rect(), board)
	game.hud_boon.pressed.emit()
	equal(game.overlay_type, "boon_details")
	check(game.overlay.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text == description))
	game.sim.state.wave = 20
	game.sim.record_boss_kill()
	game._show_intermission_choice()
	var next: Array[Node] = game.overlay.find_children("*", "Button", true, false)
	equal(next.size(), 4)
	var keep: Button = next[0]
	equal(keep.name, "KeepBoon")
	check(keep.tooltip_text.begins_with(boon.name))
	keep.pressed.emit()
	equal(game.sim.state.active_boon, active)
	equal(game.overlay_type, "")
	game.queue_free()
	await runner.process_frame

func test_boss_heading_eases_into_bends_and_follows_the_inverted_board() -> void:
	var field := BattlefieldView.new()
	field.sim = Sim.new()
	var boss: Dictionary = field.sim.preview(10).boss
	var bend: float = field.sim.track.lengths[1]
	equal(field._enemy_heading(boss, bend - .4), Vector2.RIGHT)
	var approaching: Vector2 = field._enemy_heading(boss, bend - .16)
	check(approaching.x > approaching.y and approaching.y > 0.0)
	var turning: Vector2 = field._enemy_heading(boss, bend)
	near(turning.x, turning.y)
	equal(field._enemy_heading(boss, bend + .4), Vector2.DOWN)
	var ram: Dictionary = field.sim.preview(20).boss
	ram.corner = 1
	equal(field._enemy_heading(ram, bend, 0.1), Vector2.RIGHT)
	near(field._enemy_heading(ram, bend, 1.0).angle_to(Vector2.DOWN), 0.0)
	field.gate_on_top = true
	equal(field._enemy_heading(boss, bend - .4), Vector2.LEFT)
	equal(field._enemy_heading(boss, bend + .4), Vector2.UP)
	field.free()

func test_tower_details_show_active_support_bonuses() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	game.sim = Sim.new()
	runner.root.add_child(game)
	game.set_process(false)
	var arrow: Dictionary = TowerRules.create(game.sim.next_id(), "s1", "arrow", "normal", "", 50)
	var forge: Dictionary = TowerRules.fusion_result("forge", "s2", game.sim.next_id())
	var spring: Dictionary = TowerRules.fusion_result("spring", "tile_6_2", game.sim.next_id())
	game.sim.state.towers = {arrow.slot: arrow, forge.slot: forge, spring.slot: spring}
	game.sim.state.active_boon = {"id": "general_damage", "wave": 10, "potency": 1.0}
	game.sim.refresh_boon()
	var spring_effect: Dictionary = TowerRules.stats(spring).effect
	spring_effect.aura_range = .13
	game._site_pressed("s1")
	game._show_tower_details()
	var row: HFlowContainer = game.tower_detail_stats
	var expected := {"Damage": "+25%", "Speed": "+25%", "Range": "+13%"}
	for stat: String in expected:
		var badge: Label = row.get_node_or_null(stat + "/SupportBonus")
		check(badge != null and badge.text == expected[stat], "Shows the " + stat.to_lower() + " support bonus")
	equal(row.get_node("Damage/BoonBonus").text, "+7%")
	forge.stun = 10
	game._update_hud()
	check(not row.has_node("Damage/SupportBonus") and row.has_node("Speed/SupportBonus"))
	spring_effect.erase("aura_range")
	game.queue_free()
	await runner.process_frame

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

func test_landscape_keeps_the_full_height_board_left_of_the_controls() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	game.sim = Sim.campaign(7)
	for element: String in DataDB.ELEMENTS:
		game.sim.state.tiers[element] = 3
	runner.root.add_child(game)
	game.set_process(false)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.size = Vector2(1280, 720)
	for frame: int in range(3):
		await runner.process_frame
	var board: Rect2 = game.field.get_global_rect()
	check(game.wide)
	check(board.position.x < 20 and board.position.y < 20)
	check(board.end.y >= game.size.y - 20)
	near(board.size.x, ceilf(game.field.width_for_height(board.size.y)))
	for control: Control in [game.speed_button, game.preview_row, game.round_controls, game.inspector_panel]:
		check(control.get_global_rect().position.x > board.end.x, "Landscape controls stay to the right of the board")
	game._apply({"type": "start_wave"})
	for frame: int in range(3):
		await runner.process_frame
	equal(game.field.get_global_rect(), board, "Starting a wave leaves the full-height board in place")
	game.size = Vector2(900, 720)
	for frame: int in range(3):
		await runner.process_frame
	check(game.wide and game.field.size.x < board.size.x, "Narrow landscape adjusts the width without changing orientation")
	check(game.inspector_panel.get_global_rect().end.x <= game.size.x, "Narrow landscape keeps the palette on screen (%s)" % game.inspector_panel.get_global_rect())
	check(game.speed_button.get_global_rect().position.x > game.field.get_global_rect().end.x, "Narrow landscape keeps speed controls to the right")
	check(game.field.get_global_rect().end.y >= game.size.y - 20, "Narrow landscape preserves the canvas height")
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
	equal(game.tower_stats.get_node("Damage/Value").text, "21.84", "The inspector updates after a live upgrade")
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
	game._show_preview(10, false, true)
	equal(game.overlay_type, "")
	var boss: Dictionary = game.sim.preview(10).boss
	var weakness_label: String = "Weak to %s · +50%%" % String(boss.weakness).capitalize()
	var shown_weakness: bool = false
	for label: Label in game.forecast_panel.find_children("*", "Label", true, false):
		shown_weakness = shown_weakness or label.text == weakness_label
	check(shown_weakness, "The forecast shows the boss's rolled weakness and damage bonus")
	game.sim.state.tiers.fire = 1
	game.sim.state.tiers.water = 1
	game.sim.state.tiers.earth = 1
	game._show_preview(40, false, true)
	var form_cards: int = 0
	var earth_weakness: bool = false
	for button: Button in game.forecast_panel.find_children("*", "Button", true, false):
		if button.tooltip_text.begins_with("Fire form.") or button.tooltip_text.begins_with("Water form."):
			form_cards += 1
		if button.tooltip_text.begins_with("Earth form."):
			form_cards += 1
			earth_weakness = button.tooltip_text.contains("Nature")
	equal(form_cards, 3, "The Prismheart forecast exposes all unlocked forms")
	check(earth_weakness)
	game.sim.state.tiers.earth = 0
	game._show_preview(60, false, true)
	var shows_neutral: bool = false
	for label: Label in game.forecast_panel.find_children("*", "Label", true, false):
		shows_neutral = shows_neutral or label.text == "Weak to Neutral · +100%"
	check(shows_neutral, "The Ironwood forecast distinguishes neutral damage from elemental weaknesses")
	game.sim.state.tiers.fire = 0
	game.sim.state.tiers.water = 0
	game.sim.state.tiers.electric = 1
	game.sim.state.wave = 10
	game.sim.state.phase = "build"
	game.sim.state.mobs.clear()
	game.sim.state.spawn_queue.clear()
	game.sim.state.selection_pending = true
	game._show_selection()
	equal(game.overlay_type, "select")
	equal(game.overlay.find_child("ChooseFire", true, false).get_node("Difficulty").text, "★")
	equal(game.overlay.find_child("ChooseElectric", true, false).get_node("Difficulty").text, "★★★")
	var found_slow: bool = false
	for button: Button in game.overlay.find_children("*", "Button", true, false):
		if button.text == "Slow 15% · 2s":
			found_slow = button.tooltip_text.contains("15% for 2 s") and button.get_theme_color("font_color") == StatusInfo.accent("Slow")
	check(found_slow, "Element selection exposes color-coded potency and duration")
	game.sim.state.wave = 25
	game._show_selection()
	equal(game.overlay.find_child("ChooseElectric", true, false).get_node("Difficulty").text, "★★")
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
	sim.state.towers.s2 = TowerRules.create(sim.next_id(), "s2", "ascended", "fire", "", 1600)
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
	check(game.crystal_status.text == "×1" and game.message.contains("+1 Pure Crystal"))
	check(not game.field.upgrade_ready.has("s2"), "A level-7 Pure tower stays maxed when a crystal is earned")
	game._site_pressed("s2")
	check(game.upgrade_button.disabled and game.upgrade_button.text == DataDB.text("max_level"))
	check(not game.field.upgrade_ready.has("s3"), "A crystal alone does not pay for ascension")
	sim.state.gold = 1500
	game._update_hud(true)
	check(game.field.upgrade_ready.has("s3"), "A max-level Nature tower can spend the milestone crystal")
	game._site_pressed("s3")
	check(game.upgrade_button.text.begins_with("Use Crystal") and not game.upgrade_button.disabled)
	game._upgrade_pressed()
	check(game.tower_comparison.visible and game.upgrade_button.text.begins_with("Confirm"))
	var after: Control = game.tower_comparison.get_child(1)
	var after_labels: PackedStringArray = []
	for label: Label in after.find_children("*", "Label", true, false):
		after_labels.append(label.text)
	check(after_labels.has("After upgrade · Pure ★7"))
	check(after_labels.has(TowerInspector.number(418.5 * 1.15 * 1.05)) and after_labels.has("4.5") and after_labels.has("0.93/s"))
	equal(sim.pure_crystals(), 1)
	game._upgrade_pressed()
	equal(game.overlay_type, "ascend")
	equal(sim.pure_crystals(), 1, "Opening confirmation never consumes the crystal")
	equal(sim.state.towers.s3.kind, "pure")
	for button: Button in game.overlay.find_children("*", "Button", true, false):
		if button.text == DataDB.text("cancel"):
			button.pressed.emit()
	equal(sim.pure_crystals(), 1)
	game._upgrade_pressed()
	var use_crystal: Button = game.overlay.find_child("ConfirmPureCrystal", true, false)
	use_crystal.pressed.emit()
	equal(sim.state.gold, 0, "Ascension charges 1500 gold on confirmation")
	check(game.upgrade_button.disabled and game.upgrade_button.text == DataDB.text("max_level"))
	check(not game.field.upgrade_ready.has("s3"))
	equal(sim.state.towers.s3.kind, "ascended")
	check(not game.tower_special.visible)
	check(game.crystal_status.text == "×0" and game.info.text.contains("Verdant Sanctum") and game.info.text.contains("7"))
	game.queue_free()
	await runner.process_frame

func test_a_right_swipe_away_from_start_wave_starts_combat() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	runner.root.add_child(game)
	game.set_process(false)
	await runner.process_frame
	await runner.process_frame
	var center: Vector2 = game.start_button.get_global_rect().get_center()
	var pointer := InputEventMouseButton.new()
	pointer.device = InputEvent.DEVICE_ID_EMULATION
	pointer.button_index = MOUSE_BUTTON_LEFT
	for travel: Vector2 in [Vector2(-85, 0), Vector2(75, 80), Vector2(150, 0)]:
		var origin: Vector2 = center
		if travel == Vector2(150, 0):
			origin = game.field.get_global_rect().get_center()
			check(not game.start_button.get_global_rect().has_point(origin))
		pointer.pressed = true
		pointer.position = origin
		runner.root.push_input(pointer, true)
		equal(game.sim.state.phase, "build", "Wait for the player to finish the gesture")
		pointer.pressed = false
		pointer.position = origin + travel
		runner.root.push_input(pointer, true)
		equal(game.sim.state.phase, "wave" if travel == Vector2(150, 0) else "build")
	equal(game.sim.history.back().action.type, "start_wave")
	game.sim.state.phase = "build"
	game.sim.state.spawn_queue.clear()
	game._refresh()
	await runner.process_frame
	pointer.position = game.start_button.get_global_rect().get_center()
	pointer.canceled = false
	pointer.pressed = true
	runner.root.push_input(pointer, true)
	pointer.pressed = false
	runner.root.push_input(pointer, true)
	equal(game.sim.state.phase, "wave", "A tap still starts the wave")
	game.queue_free()
	await runner.process_frame

func test_tactical_gestures_and_the_ten_second_round_countdown() -> void:
	var game: GameScreen = load("res://scenes/game.tscn").instantiate()
	game.persistence_enabled = false
	runner.root.add_child(game)
	game.set_process(false)
	game.sim.state.tiers.fire = 1
	game.sim.state.tiers.water = 1
	game.sim.state.towers.s1 = TowerRules.create(game.sim.next_id(), "s1", "arrow", "normal", "", 50)
	game.sim.state.towers.s2 = TowerRules.create(game.sim.next_id(), "s2", "pure", "fire", "", 110)
	game._refresh()
	await runner.process_frame
	await runner.process_frame
	check(game.interest_status.text.contains("+6"))
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	check(game.find_child("SwapArrow", true, false) == null)
	equal(game.stone_status.text, "×3")
	equal(game.crystal_status.text, "×0")
	game._open_forecast(59)
	equal(game.overlay_type, "")
	check(not game.paused and not game.forecast_expanded)
	check(game.forecast_panel.find_child("ForecastEnemies", true, false) == null)
	var expand: Button = game.forecast_panel.find_child("ExpandForecast", true, false)
	expand.pressed.emit()
	check(game.forecast_expanded and is_instance_valid(game.forecast_panel.find_child("ForecastEnemies", true, false)))
	game._toggle_forecast_matchups()
	game._close_forecast()
	check(game.field.matchups.is_empty())
	game._apply({"type": "start_wave"})
	check(game.interest_toast.visible and game.interest_toast_text.text == "Interest +6 g")
	game._show_selection()
	check(game.interest_toast.visible and game.interest_toast.get_parent().layer > 0)
	game._close_overlay()
	var tile: Vector2i = game.sim.track.road_tiles.keys()[0]
	pointer.canceled = false
	pointer.position = game.field._board_transform() * game.sim.track.road_tiles[tile]
	for tap: int in range(2):
		pointer.pressed = true
		game.field._gui_input(pointer)
		pointer.pressed = false
		game.field._gui_input(pointer)
	equal(game.sim.state.stone_blocks, 2)
	game.sim.state.spawn_queue.clear()
	game.sim.step()
	game._take_events()
	near(game.sim.intermission_left, 10.0)
	game._process(9.9)
	equal(game.sim.state.phase, "build")
	game._process(.11)
	equal(game.sim.state.phase, "wave")
	check(game.sim.state.mobs.is_empty() and game.interest_toast_text.text.begins_with("Interest +"))
	game._process(3.1)
	check(not game.interest_toast.visible)
	check(game.interest_status.text == "Interest +%d g" % game.sim.state.last_interest)
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
	equal(game.round_controls.get_child_count(), 1, "Start Wave is the only round control")
	game._show_pause()
	check(is_instance_valid(game.overlay.find_child("Status effects", true, false)))
	check(is_instance_valid(game.overlay.find_child("Legend", true, false)))
	game._process(15)
	near(game.sim.intermission_left, 11.0)
	game._resume()
	game._process(11)
	equal(game.sim.state.phase, "wave")
	game._process(1.0 / 30)
	equal(game.sim.state.tick, 4, "Combat advances at quadruple speed")
	game._toggle_speed()
	equal(game.speed, 1)
	game._show_pause()
	(game.overlay.find_child("Status effects", true, false) as Button).pressed.emit()
	equal(game.overlay_type, "statuses")
	check(StatusInfo.description("phasing").contains("2 seconds every 5 seconds"))
	game._close_reference()
	equal(game.overlay_type, "pause")
	check(game.paused)
	(game.overlay.find_child("Legend", true, false) as Button).pressed.emit()
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
	equal(titles.size(), 23, "Elemental and Pure towers, six duals, and fifteen triples for each element")
	check(titles.has("Sunspire"))
	check(titles.has("Daystar") and titles.has("Daybloom") and not titles.has("Steamworks"))
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
