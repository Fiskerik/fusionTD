class_name GameScreen
extends Control

var sim: Sim
var persistence_enabled: bool = true
var profile: Dictionary
var field: BattlefieldView
var audio: GameAudio
var speed_button: Button
var status: Label
var stats: Label
var wave_label: Label
var wave_effects: HFlowContainer
var element_status: HBoxContainer
var gate_charge: int = 0
var life_bar: ProgressBar
var barrier_bar: ProgressBar
var preview_row: HBoxContainer
var info: Label
var inspector_panel: PanelContainer
var inspector_portrait: UIKit.TowerPortrait
var tower_metrics: Label
var tower_composition: HBoxContainer
var tower_effects: HBoxContainer
var tower_history: Label
var tower_comparison: HBoxContainer
var upgrade_slot: String = ""
var tower_toolbar: HBoxContainer
var upgrade_button: Button
var secondary_button: Button
var target_button: Button
var move_button: Button
var move_origin: String = ""
var catalog_build: Dictionary = {}
var tower_special: Button
var pure_tab: Button
var pure_palette: bool = false
var detail_button: Button
var site_actions: GridContainer
var action_buttons: Dictionary = {}
var overlay_actions: Dictionary = {}
var last_gold: int = -1
var footer: HBoxContainer
var start_button: Button
var timer_button: Button
var fuse_button: Button
var last_countdown: int = -1
var combat_status: Label
var overlay: Control
var selected: String = ""
var fuse_origin: String = ""
var paused: bool = false
var wide: bool = false
var speed: int = 1
var accumulator: float = 0.0
var message: String = ""
var overlay_type: String = ""
var overlay_wave: int = 0
var overlay_bonus: bool = false
var overlay_partner: String = ""
var legend_element: String = ""
var overview: TowerOverview
var inspected_enemy: int = -1
var enemy_signature: String = ""
var enemy_detail_metrics: Label
var enemy_detail_rows: VBoxContainer
var enemy_detail_signature: String = ""
var leaderboard_rows: VBoxContainer
var leaderboard_signature: String = ""
var leaderboard_next_refresh: int = 0

func _ready() -> void:
	if sim == null:
		sim = Sim.new(int(randi()))
	profile = SaveStore.profile() if persistence_enabled else {"seen": [], "haptics": false, "best_wave": 0, "sound": false, "music": false, "speed": 1}
	speed = clampi(int(profile.speed), 1, 4)
	wide = _is_wide()
	_build_layout()
	_hint(0)
	_checkpoint()
	if sim.state.selection_pending:
		_show_selection()
	elif sim.state.phase == "build" and not sim.state.trial.is_empty():
		_apply({"type": "start_wave"})
	resized.connect(_resized)

func _is_wide() -> bool:
	return size.x > size.y * 1.17

func _resized() -> void:
	if wide == _is_wide() or sim == null:
		return
	wide = _is_wide()
	var previous: String = overlay_type
	_build_layout()
	match previous:
		"select": _show_selection()
		"pause": _show_pause()
		"end": _show_game_over()
		"preview": _show_preview(overlay_wave, overlay_bonus)
		"tower": _show_tower_details()
		"leaderboard": _show_leaderboard()
		"statuses": _show_status_help()
		"legend": _show_legend()
		"enemy": _show_enemy_details()
		"infuse": _show_infusion()
		"fusion": _show_fusion(overlay_partner)
		"restart": _confirm_restart()

func _build_layout() -> void:
	action_buttons.clear()
	overlay_actions.clear()
	if field != null:
		field.get_parent().remove_child(field)
	if audio != null:
		remove_child(audio)
	UIKit.clear(self)
	if audio == null:
		audio = GameAudio.new()
		audio.enabled = bool(profile.sound)
	add_child(audio)
	audio.set_music(bool(profile.music))
	overlay = null
	overlay_type = ""
	overview = null
	UIKit.screen_background(self)
	var margin: MarginContainer = UIKit.screen_margin(self, 14)
	var stack: VBoxContainer = UIKit.column(8)
	margin.add_child(stack)
	var hud := PanelContainer.new()
	hud.add_theme_stylebox_override("panel", UIKit.style(Color("#284c40"), Color("#487763"), 16, 7))
	stack.add_child(hud)
	var header_stack: VBoxContainer = UIKit.column(4)
	hud.add_child(header_stack)
	var header: HBoxContainer = UIKit.row(10)
	header_stack.add_child(header)
	var heading: VBoxContainer = UIKit.column(0)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	wave_label = UIKit.label("", 28, Color("#fff4d6"))
	heading.add_child(wave_label)
	stats = UIKit.label("", 18, Color("#d6e7bf"))
	heading.add_child(stats)
	var meters: VBoxContainer = UIKit.column(3)
	meters.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meters.custom_minimum_size.x = 250
	heading.add_child(meters)
	life_bar = ProgressBar.new()
	life_bar.max_value = float(sim.cfg.start_lives)
	life_bar.show_percentage = false
	life_bar.custom_minimum_size.y = 12
	life_bar.add_theme_stylebox_override("background", UIKit.style(Color("#536858"), Color("#30483d"), 8, 0))
	life_bar.add_theme_stylebox_override("fill", UIKit.style(UIKit.gate_fill(1.0), Color("#30483d"), 8, 0))
	meters.add_child(life_bar)
	barrier_bar = ProgressBar.new()
	barrier_bar.max_value = float(sim.cfg.gate_barrier_cap)
	barrier_bar.show_percentage = false
	barrier_bar.custom_minimum_size.y = 8
	barrier_bar.add_theme_stylebox_override("background", UIKit.style(Color("#3e6267"), Color("#30483d"), 8, 0))
	barrier_bar.add_theme_stylebox_override("fill", UIKit.style(Color("#87dcf5"), Color("#30483d"), 8, 0))
	barrier_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	meters.add_child(barrier_bar)
	var controls: HBoxContainer = UIKit.row(8)
	header.add_child(controls)
	speed_button = UIKit.button(DataDB.text("speed_value") % speed, _toggle_speed, false, 54)
	speed_button.custom_minimum_size.x = 68
	speed_button.tooltip_text = DataDB.text("speed_tip")
	controls.add_child(speed_button)
	var pause_button: Button = UIKit.icon_button("pause", DataDB.text("pause"), _show_pause, 54)
	pause_button.custom_minimum_size.x = 58
	controls.add_child(pause_button)
	var ribbon: HBoxContainer = UIKit.row(8)
	header_stack.add_child(ribbon)
	wave_effects = HFlowContainer.new()
	wave_effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_effects.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wave_effects.add_theme_constant_override("h_separation", 5)
	wave_effects.add_theme_constant_override("v_separation", 3)
	ribbon.add_child(wave_effects)
	element_status = UIKit.row(4)
	ribbon.add_child(element_status)

	var play: BoxContainer = UIKit.row(14) if wide else UIKit.column(8)
	play.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(play)
	if field == null:
		field = BattlefieldView.new()
		field.sim = sim
		field.size_flags_vertical = Control.SIZE_EXPAND_FILL
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.site_pressed.connect(_site_pressed)
		field.enemy_pressed.connect(_enemy_pressed)
	play.add_child(field)
	field.gate_on_top = bool(profile.get("gate_on_top", false))

	var dock: VBoxContainer = UIKit.column(8)
	if wide:
		dock.custom_minimum_size.x = clampf(size.x * .33, 365, 520)
		dock.alignment = BoxContainer.ALIGNMENT_CENTER
	play.add_child(dock)
	var forecast_heading: HBoxContainer = UIKit.row(8)
	dock.add_child(forecast_heading)
	status = UIKit.label("", 19, UIKit.MINT)
	status.custom_minimum_size.y = 29
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	forecast_heading.add_child(status)
	combat_status = UIKit.label("", 18, UIKit.MUTED)
	forecast_heading.add_child(combat_status)
	var status_help: Button = UIKit.icon_button("info", DataDB.text("status_help"), _show_status_help, 46)
	forecast_heading.add_child(status_help)
	var legend_button: Button = UIKit.icon_button("book", DataDB.text("legend"), _open_legend, 46)
	legend_button.tooltip_text = "Tower overview"
	forecast_heading.add_child(legend_button)
	preview_row = UIKit.row(7)
	dock.add_child(preview_row)
	inspector_panel = PanelContainer.new()
	inspector_panel.add_theme_stylebox_override("panel", UIKit.style(UIKit.SURFACE, UIKit.BORDER, 19, 10))
	dock.add_child(inspector_panel)
	var panel_layout: VBoxContainer = UIKit.column(4)
	inspector_panel.add_child(panel_layout)
	var inspector_heading: HBoxContainer = UIKit.row(8)
	panel_layout.add_child(inspector_heading)
	inspector_portrait = UIKit.TowerPortrait.new()
	inspector_portrait.custom_minimum_size = Vector2(49, 49)
	inspector_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector_heading.add_child(inspector_portrait)
	info = UIKit.label("", 22)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inspector_heading.add_child(info)
	pure_tab = UIKit.button("", _toggle_pure_palette, false, 45)
	pure_tab.add_theme_font_size_override("font_size", 16)
	pure_tab.size_flags_horizontal = Control.SIZE_FILL
	inspector_heading.add_child(pure_tab)
	tower_special = UIKit.button("", _tower_special_pressed, false, 45)
	tower_special.size_flags_horizontal = Control.SIZE_FILL
	tower_special.add_theme_font_size_override("font_size", 16)
	inspector_heading.add_child(tower_special)
	inspector_heading.add_child(UIKit.icon_button("chart", "Top 5 damage", _show_leaderboard))
	detail_button = UIKit.icon_button("info", DataDB.text("tower_details"), _show_inspector_details)
	inspector_heading.add_child(detail_button)
	tower_composition = UIKit.row(3)
	panel_layout.add_child(tower_composition)
	tower_metrics = UIKit.label("", 18, UIKit.MINT)
	tower_metrics.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel_layout.add_child(tower_metrics)
	tower_effects = UIKit.row(4)
	tower_effects.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_layout.add_child(tower_effects)
	tower_history = UIKit.label("", 16, UIKit.MINT)
	panel_layout.add_child(tower_history)
	tower_comparison = UIKit.row(6)
	panel_layout.add_child(tower_comparison)
	site_actions = GridContainer.new()
	site_actions.columns = 3
	site_actions.add_theme_constant_override("h_separation", 6)
	site_actions.add_theme_constant_override("v_separation", 6)
	site_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_layout.add_child(site_actions)
	tower_toolbar = UIKit.row(6)
	panel_layout.add_child(tower_toolbar)
	upgrade_button = UIKit.button("", _upgrade_pressed, false, 53)
	upgrade_button.name = "TowerUpgrade"
	upgrade_button.add_theme_font_size_override("font_size", 16)
	_style_upgrade(upgrade_button)
	tower_toolbar.add_child(upgrade_button)
	target_button = UIKit.button("", _target_pressed, false, 53)
	target_button.add_theme_font_size_override("font_size", 16)
	tower_toolbar.add_child(target_button)
	var action_gap := Control.new()
	action_gap.custom_minimum_size.x = 12
	action_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower_toolbar.add_child(action_gap)
	move_button = UIKit.button("", _toggle_move, false, 53)
	move_button.name = "MoveTower"
	move_button.add_theme_font_size_override("font_size", 16)
	tower_toolbar.add_child(move_button)
	secondary_button = UIKit.button("", _secondary_tower_action, false, 53)
	secondary_button.add_theme_font_size_override("font_size", 16)
	tower_toolbar.add_child(secondary_button)

	footer = UIKit.row(8)
	dock.add_child(footer)
	_refresh()

func _process(delta: float) -> void:
	if sim == null or paused:
		return
	if sim.state.phase == "build":
		_count_down(delta)
		return
	if sim.state.phase != "wave":
		return
	var timestep: float = 1.0 / sim.hz
	accumulator += minf(delta, .25) * speed
	var steps: int = 0
	while accumulator + 1e-9 >= timestep and steps < 24 and sim.state.phase == "wave":
		accumulator = maxf(0.0, accumulator - timestep)
		sim.step()
		steps += 1
		_take_events()
	field.fraction = clampf(accumulator / timestep, 0.0, 1.0)
	if steps > 0:
		_update_enemy_inspector()
		_update_hud()

func _count_down(delta: float) -> void:
	if sim.intermission_paused or sim.state.selection_pending or not sim.state.trial.is_empty():
		return
	sim.intermission_left = maxf(0.0, sim.intermission_left - delta)
	if sim.intermission_left == 0.0:
		_apply({"type": "start_wave"})
		return
	var seconds: int = ceili(sim.intermission_left)
	if seconds != last_countdown:
		_update_countdown()
		if seconds <= 3:
			audio.play("countdown")

func _update_countdown() -> void:
	if not is_instance_valid(start_button) or sim.state.selection_pending or not sim.state.trial.is_empty():
		return
	last_countdown = ceili(sim.intermission_left)
	start_button.text = DataDB.text("start_countdown") % last_countdown
	start_button.tooltip_text = DataDB.text("start_early")
	if is_instance_valid(timer_button):
		timer_button.text = "Resume\ntimer" if sim.intermission_paused else "Pause\ntimer"
		timer_button.set_pressed_no_signal(sim.intermission_paused)

func _toggle_timer() -> void:
	if sim.state.phase != "build" or sim.state.selection_pending or not sim.state.trial.is_empty():
		return
	sim.intermission_paused = not sim.intermission_paused
	_update_countdown()
	_checkpoint()
	audio.play("ui")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_checkpoint()
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT] and is_node_ready():
		if sim.state.phase != "game_over" and not paused:
			_show_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay_type == "pause":
			_resume()
		elif overlay_type == "restart":
			_show_pause()
		elif overlay_type == "fusion":
			_cancel_fusion()
		elif overlay_type == "leaderboard":
			_close_leaderboard()
		elif overlay_type not in ["end", ""]:
			_close_overlay()
		elif not upgrade_slot.is_empty():
			_cancel_upgrade()
		elif not move_origin.is_empty():
			_cancel_move()
		elif not catalog_build.is_empty():
			_cancel_catalog_build()
		elif sim.state.phase != "game_over":
			_show_pause()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	field.selected = selected
	gate_charge = sim.gate_repair_per_cycle()
	field.move_targets.clear()
	field.placement_preview = {}
	if not catalog_build.is_empty():
		var kind: String = catalog_build.kind
		var elemental: bool = DataDB.ELEMENTS.has(kind)
		var tower_kind: String = "pure" if elemental else kind
		if catalog_build.type == "build_pure":
			tower_kind = "ascended"
		field.placement_preview = TowerRules.create(0, "", tower_kind, kind if elemental else "normal", "", 0)
	if not move_origin.is_empty() or not catalog_build.is_empty():
		for slot: String in sim.track.slots:
			if not sim.state.towers.has(slot):
				field.move_targets[slot] = true
	field.partners.clear()
	if fuse_origin != "":
		for slot: String in sim.state.towers:
			var action: Dictionary = {"type": "fuse", "slot_a": fuse_origin, "slot_b": slot}
			if sim.describe(action, true).ok:
				field.partners.append(slot)
	UIKit.clear(footer)
	start_button = null
	timer_button = null
	var building: bool = sim.state.phase == "build"
	inspector_panel.visible = sim.state.phase != "game_over"
	footer.visible = building
	if building:
		var undo: Button = UIKit.button(DataDB.text("undo") % sim.undo_stack.size(), _apply.bind({"type": "undo"}), false, 68)
		undo.add_theme_font_size_override("font_size", 17)
		undo.disabled = sim.undo_stack.is_empty()
		undo.tooltip_text = sim.describe({"type": "undo"}).reason
		footer.add_child(undo)
		var choose: bool = sim.state.selection_pending
		if not choose and sim.state.trial.is_empty():
			timer_button = UIKit.button("", _toggle_timer, false, 68)
			timer_button.name = "WaveTimer"
			timer_button.toggle_mode = true
			timer_button.tooltip_text = "Hold the countdown while you build. Start Wave still works."
			timer_button.add_theme_font_size_override("font_size", 17)
			footer.add_child(timer_button)
		var action: Callable = _show_selection if choose else _apply.bind({"type": "start_wave"})
		var start_key: String = "choose_spirit" if choose else ("start_bonus" if not sim.state.trial.is_empty() else "start_wave")
		start_button = UIKit.button(DataDB.text(start_key), action, true, 68)
		start_button.size_flags_stretch_ratio = 2.0
		footer.add_child(start_button)
		_update_countdown()
	_update_hud(true)
	_render_wave_heading()
	_render_element_status()
	_render_preview()
	_render_site()
	if is_instance_valid(overview):
		overview.refresh_unlocks()

func _update_hud(refresh_upgrades: bool = false) -> void:
	stats.text = DataDB.text("hud_stats") % [sim.state.lives, sim.cfg.start_lives, sim.state.gold]
	if int(sim.state.barrier) > 0 or gate_charge > 0:
		stats.text += "   ·   Barrier %d/%d" % [int(sim.state.barrier), int(sim.cfg.gate_barrier_cap)]
	var details := PackedStringArray()
	if gate_charge > 0:
		details.append("Next gate repair +%d after wave %d." % [gate_charge, sim.next_gate_repair()])
	if int(sim.state.wave) >= int(sim.cfg.pure_crystal_every):
		var crystals: int = sim.pure_crystals()
		stats.text += "   ·   ◈ %d" % crystals
		details.append("%d Pure Crystals available. Earn one on reaching each %d-wave milestone." % [crystals, int(sim.cfg.pure_crystal_every)])
	stats.tooltip_text = "\n".join(details)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE if details.is_empty() else Control.MOUSE_FILTER_STOP
	life_bar.value = float(sim.state.lives)
	barrier_bar.value = float(sim.state.barrier)
	barrier_bar.tooltip_text = "Barrier %d/%d · Absorbs damage before gate health." % [sim.state.barrier, sim.cfg.gate_barrier_cap]
	var fill: StyleBoxFlat = life_bar.get_theme_stylebox("fill")
	var life_color: Color = UIKit.gate_fill(life_bar.value / life_bar.max_value)
	if fill.bg_color != life_color:
		fill.bg_color = life_color
	status.text = DataDB.text("next_waves") if message.is_empty() else message
	combat_status.visible = sim.state.phase == "wave"
	if combat_status.visible:
		var remaining: int = sim.state.mobs.size() + sim.state.spawn_queue.size()
		if remaining == 1:
			combat_status.text = DataDB.text("spirit_remaining" if not sim.state.trial.is_empty() else "enemy_remaining")
		else:
			combat_status.text = DataDB.text("enemies_remaining") % remaining
	var gold_changed: bool = last_gold != int(sim.state.gold)
	if refresh_upgrades or gold_changed:
		field.upgrade_ready.clear()
		for tower: Dictionary in sim.state.towers.values():
			if sim.describe(_tower_upgrade_action(tower)).ok:
				field.upgrade_ready[tower.slot] = true
	if gold_changed:
		last_gold = sim.state.gold
		for collection: Dictionary in [action_buttons, overlay_actions]:
			for button: Button in collection:
				if is_instance_valid(button):
					_update_action_button(button, collection[button])
		_update_fuse_button()
		_update_move_button()
		if is_instance_valid(overview):
			overview.refresh_purchase()
	_update_tower_history()
	if overlay_type == "leaderboard":
		_update_leaderboard()

func _render_element_status() -> void:
	UIKit.clear(element_status)
	for element: String in DataDB.ELEMENTS:
		var tier: int = int(sim.state.tiers[element])
		var button: Button = UIKit.button("", _select_legend_element.bind(element), false, 39)
		button.name = "Tier" + element.capitalize()
		button.custom_minimum_size.x = 52
		button.size_flags_horizontal = Control.SIZE_FILL
		var tint: Color = Glyphs.hue(element) if tier > 0 else Color("#8eaa9e")
		button.add_theme_stylebox_override("normal", UIKit.style(tint.lerp(UIKit.SURFACE, .65), tint.darkened(.26), 9, 3))
		button.tooltip_text = "%s · %s" % [element.capitalize(), "Locked" if tier == 0 else "Tier " + TowerRules.roman(tier)]
		var content: HBoxContainer = UIKit.row(2)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge: Control = UIKit.badge(element, 21)
		if tier == 0:
			badge.modulate = Color("#81968aaa")
		content.add_child(badge)
		content.add_child(UIKit.label("–" if tier == 0 else TowerRules.roman(tier), 15, UIKit.INK))
		button.add_child(content)
		element_status.add_child(button)

func _render_wave_heading() -> void:
	var wave: int = int(sim.state.wave)
	wave_label.text = ("Current wave %d" if sim.state.phase == "wave" else "Upcoming wave %d") % wave
	UIKit.clear(wave_effects)
	var summary: Dictionary = sim.preview(wave)
	if not summary.spirit.is_empty():
		var spirit: Dictionary = summary.spirit
		_effect_chip(wave_effects, "%s %s · Solo spirit" % [String(spirit.element).capitalize(), TowerRules.roman(spirit.tier)],
			Glyphs.hue(spirit.element).darkened(.55), spirit.element)
		return
	if sim.state.selection_pending:
		_effect_chip(wave_effects, "Spirit trial first", UIKit.UPGRADE, "light")
	if summary.bosses.size() > 1:
		var names := PackedStringArray()
		for boss: Dictionary in summary.bosses:
			names.append(StatusInfo.enemy_name(boss))
		_effect_chip(wave_effects, "%d bosses" % names.size(), UIKit.WARN, "dark", " · ".join(names))
	elif summary.bosses.size() == 1:
		var boss: Dictionary = summary.bosses[0]
		_effect_chip(wave_effects, "%s · Boss" % StatusInfo.enemy_name(boss), UIKit.WARN, "dark")
		var trait_id: String = StatusInfo.enemy_traits(boss)[0]
		var ability: Array = StatusInfo.TRAITS[trait_id]
		_effect_chip(wave_effects, ability[0], Glyphs.hue(ability[2]).darkened(.57), ability[2],
			StatusInfo.trait_description(trait_id))
	var resistance: float = EnemyRules.control_resistance(wave)
	if resistance > 0.0:
		_effect_chip(wave_effects, "%s tenacity" % TowerInspector.percent(resistance),
			UIKit.WARN, "normal", StatusInfo.trait_description("resistance"))
	var seen: Dictionary = {}
	for group: Dictionary in summary.groups:
		var element: String = group.element
		if element != "none" and not seen.has(element):
			seen[element] = true
			_effect_chip(wave_effects, element.capitalize(), Glyphs.hue(element).darkened(.57), element)
		for id: String in group.props:
			if not seen.has(id):
				seen[id] = true
				var property_info: Array = StatusInfo.TRAITS[id]
				_effect_chip(wave_effects, property_info[0], Glyphs.hue(property_info[2]).darkened(.57), property_info[2],
					StatusInfo.trait_description(id))
	if wave_effects.get_child_count() == 0:
		var group: Dictionary = summary.groups[0]
		_effect_chip(wave_effects, "%s · %d enemies" % [StatusInfo.enemy_name(group), int(group.count)], UIKit.MINT)

func _render_preview() -> void:
	UIKit.clear(preview_row)
	var bonus: bool = not sim.state.trial.is_empty()
	if bonus:
		var chip: Button = UIKit.button(DataDB.text("bonus_chip") % TowerRules.roman(sim.state.trial.tier),
			_show_preview.bind(int(sim.state.wave), true), false, 74)
		chip.add_theme_font_size_override("font_size", 18)
		UIKit.element_button(chip, sim.state.trial.element)
		UIKit.forecast_icons(chip, PackedStringArray([sim.state.trial.element]))
		preview_row.add_child(chip)
	var first: int = int(sim.state.wave) + (1 if sim.state.phase == "wave" and not bonus else 0)
	for wave: int in range(first, first + (2 if bonus else 3)):
		var preview: Dictionary = sim.preview(wave, false)
		var total: int = preview.bosses.size()
		var icons := PackedStringArray()
		var descriptions := PackedStringArray()
		for group: Dictionary in preview.groups:
			total += int(group.count)
			if group.element != "none" and not icons.has(group.element):
				icons.append(group.element)
				descriptions.append(String(group.element).capitalize())
			if group.props.has("phasing") and not icons.has("phasing"):
				icons.append("phasing")
				descriptions.append(StatusInfo.title("phasing"))
		var chip: Button = UIKit.button("", _show_preview.bind(wave), false, 90)
		UIKit.creature_forecast(chip, preview.groups[0], wave, total, icons, preview.bosses)
		if not descriptions.is_empty():
			chip.tooltip_text += " · " + " / ".join(descriptions)
		preview_row.add_child(chip)

func _render_site() -> void:
	UIKit.clear(site_actions)
	UIKit.clear(tower_composition)
	UIKit.clear(tower_effects)
	UIKit.clear(tower_comparison)
	tower_comparison.hide()
	tower_history.hide()
	tower_toolbar.hide()
	pure_tab.hide()
	tower_special.hide()
	tower_effects.tooltip_text = ""
	action_buttons.clear()
	fuse_button = null
	field.hover_kind = ""
	site_actions.columns = 3
	site_actions.show()
	enemy_signature = ""
	inspector_portrait.hide()
	if inspected_enemy >= 0:
		_update_enemy_inspector()
		return
	var tower: Dictionary = sim.state.towers.get(selected, {})
	if upgrade_slot != selected or tower.is_empty():
		upgrade_slot = ""
	detail_button.tooltip_text = "Tower details"
	detail_button.visible = not tower.is_empty()
	tower_metrics.visible = not tower.is_empty()
	tower_effects.visible = not tower.is_empty()
	if tower.is_empty():
		if not catalog_build.is_empty():
			info.text = "Place %s%s" % ["Pure " if catalog_build.type == "build_pure" else "", String(catalog_build.kind).capitalize()]
			_site_button("Cancel placement", _cancel_catalog_build)
			return
		_render_palette()
		return

	info.text = TowerRules.display_name(tower) if tower.kind == "ascended" else DataDB.text("tower_level") % [TowerRules.display_name(tower), tower.level, ""]
	inspector_portrait.tower = tower
	inspector_portrait.show()
	inspector_portrait.queue_redraw()
	tower_composition.add_child(UIKit.composition(tower))
	if tower.infusion != "":
		var tier: int = TowerRules.infusion_tier(tower.level, sim.state.tiers[tower.infusion])
		tower_composition.add_child(UIKit.label(TowerRules.roman(tier), 15, UIKit.MUTED))
	tower_composition.show()
	tower_metrics.text = TowerInspector.metrics(tower, sim.spirit_victories())
	tower_history.show()
	_update_tower_history()
	_add_tower_effects(tower_effects, tower)
	tower_effects.tooltip_text = "\n".join(TowerInspector.effects(tower, sim.state.tiers))
	var upgrade: Dictionary = _tower_upgrade_action(tower)
	var quote: Dictionary = sim.describe(upgrade, true)
	if not quote.ok:
		upgrade_slot = ""
	_render_tower_toolbar(tower, upgrade, quote)
	if not move_origin.is_empty():
		tower_metrics.text = "Tap a highlighted tile · %d gold" % Economy.move_fee(tower.invested)
		site_actions.hide()
		return
	if not upgrade_slot.is_empty():
		_render_upgrade(tower)
		return
	if tower.kind in ["arrow", "cannon"]:
		tower_special.show()
		tower_special.text = DataDB.text("infuse")
		tower_special.disabled = int(tower.level) < int(sim.cfg.infusion.min_levels[0]) or _unlocked().is_empty()
		tower_special.tooltip_text = DataDB.text("infuse_requires_level") if int(tower.level) < int(sim.cfg.infusion.min_levels[0]) else (DataDB.text("infuse_requires_trial") if _unlocked().is_empty() else DataDB.text("infusion_title"))
	if TowerRules.can_fuse(tower):
		tower_special.show()
		fuse_button = tower_special
		_update_fuse_button()
	if sim.state.phase == "wave" and int(tower.stun) > 0:
		_action_button(DataDB.text("rally"), {"type": "rally", "slot": selected})
	site_actions.visible = site_actions.get_child_count() > 0

func _tower_special_pressed() -> void:
	var tower: Dictionary = sim.state.towers.get(selected, {})
	if TowerRules.can_fuse(tower):
		_begin_fusion()
	elif not tower.is_empty():
		_show_infusion()

func _toggle_pure_palette() -> void:
	pure_palette = not pure_palette
	_render_site()

func _render_palette() -> void:
	var eligible: bool = sim.state.tiers.values().has(3)
	pure_palette = pure_palette and eligible
	pure_tab.visible = eligible
	pure_tab.text = "Standard" if pure_palette else "Pure %d/%d" % [sim.pure_count(), int(sim.cfg.pure_tower_limit)]
	pure_tab.tooltip_text = "Three shared Pure slots. Each build requires that element's Tier III."
	site_actions.columns = 3 if pure_palette else 4
	info.text = "Pure towers · %d/%d" % [sim.pure_count(), int(sim.cfg.pure_tower_limit)] if pure_palette else ("Build a tower" if selected.is_empty() else "Build on this tile")
	var kinds: Array = DataDB.ELEMENTS if pure_palette else ["arrow", "cannon"] + DataDB.ELEMENTS
	var quote_slot: String = selected
	if selected.is_empty():
		for slot: String in sim.track.slots:
			if not sim.state.towers.has(slot):
				quote_slot = slot
				break
	for kind: String in kinds:
		var rule: Dictionary = DataDB.read("towers")[kind]
		var locked: bool = int(sim.state.tiers.get(kind, 1)) < (3 if pure_palette else 1)
		var price: int = int(sim.cfg.pure_tower_cost) if pure_palette else int(rule.cost)
		var price_label: String = ("Tier III" if pure_palette else "Locked") if locked else "%d g" % price
		var action: Dictionary = {"type": "build_pure" if pure_palette else "build", "slot": quote_slot, "kind": kind}
		var title: String = "%s\n%s" % [rule.name, price_label]
		var button: Button
		if selected.is_empty():
			button = _site_button(title, _begin_catalog_build.bind(kind, pure_palette))
			action_buttons[button] = action
			_update_action_button(button, action)
		else:
			button = _action_button(title, action)
		button.name = ("BuildPure" if pure_palette else "Build") + kind.capitalize()
		button.add_theme_font_size_override("font_size", 15)
		UIKit.element_button(button, kind, true, true)
		button.mouse_entered.connect(_preview_range.bind(kind))
		button.focus_entered.connect(_preview_range.bind(kind))
		var role: String = String(rule.get("role", DataDB.read("elements").get(kind, {}).get("role", "")))
		button.tooltip_text = role + (("\n" + button.tooltip_text) if not button.tooltip_text.is_empty() else "")
	field.hover_kind = "arrow" if not selected.is_empty() and not pure_palette else ""

func _render_tower_toolbar(tower: Dictionary, upgrade: Dictionary, quote: Dictionary) -> void:
	tower_toolbar.show()
	var previewing: bool = not upgrade_slot.is_empty()
	var use_crystal: bool = upgrade.type == "empower_pure"
	var title: String = "Use Crystal" if use_crystal else "Upgrade"
	var price: String = "1 Crystal" if use_crystal else "%d g" % int(quote.cost)
	upgrade_button.text = "%s\n%s" % ["Confirm" if previewing else title, price]
	upgrade_button.disabled = not quote.ok
	upgrade_button.tooltip_text = quote.reason
	if quote.ok:
		upgrade_button.tooltip_text = "Preview a permanent damage boost from one Pure Crystal." if use_crystal else DataDB.text("upgrade_preview_tip")
	elif not use_crystal:
		upgrade_button.text = "Max level" if quote.reason == DataDB.text("max_level") else "Upgrade\nTier locked"
	if previewing:
		action_buttons[upgrade_button] = upgrade
		_update_action_button(upgrade_button, upgrade)
	secondary_button.text = "Cancel" if previewing else "Sell\n+%d g" % Economy.refund(tower.invested)
	target_button.text = "Target\n%s" % tower.target.capitalize()
	target_button.disabled = previewing
	if not move_origin.is_empty():
		upgrade_button.disabled = true
		secondary_button.disabled = true
		target_button.disabled = true
	else:
		secondary_button.disabled = false
	_update_move_button()

func _update_move_button() -> void:
	var tower: Dictionary = sim.state.towers.get(selected, {})
	if not is_instance_valid(move_button) or tower.is_empty():
		return
	var fee: int = Economy.move_fee(tower.invested)
	move_button.text = "Cancel\nmove" if not move_origin.is_empty() else "Move\n%d g" % fee
	move_button.disabled = move_origin.is_empty() and (not upgrade_slot.is_empty() or int(sim.state.gold) < fee or sim.state.towers.size() >= sim.track.slots.size())
	move_button.tooltip_text = "Move to an empty tile for 10% of invested gold, rounded up."

func _toggle_move() -> void:
	if not move_origin.is_empty():
		_cancel_move()
		return
	move_origin = selected
	fuse_origin = ""
	message = "Choose any highlighted tile."
	_refresh()

func _cancel_move() -> void:
	move_origin = ""
	message = ""
	_refresh()

func _cancel_catalog_build() -> void:
	catalog_build.clear()
	message = ""
	_refresh()

func _tower_upgrade_action(tower: Dictionary) -> Dictionary:
	return {"type": "empower_pure" if TowerRules.can_socket_crystal(tower) else "upgrade", "slot": tower.slot}

func _upgrade_pressed() -> void:
	if not upgrade_slot.is_empty():
		_apply(_tower_upgrade_action(sim.state.towers[upgrade_slot]))
	else:
		_show_upgrade_preview()

func _secondary_tower_action() -> void:
	if not upgrade_slot.is_empty():
		_cancel_upgrade()
	else:
		_apply({"type": "sell", "slot": selected})

func _target_pressed() -> void:
	var tower: Dictionary = sim.state.towers[selected]
	var mode: String = "strongest" if tower.target == "first" else "first"
	_apply({"type": "set_target", "slot": selected, "mode": mode})

func _add_tower_effects(row: HBoxContainer, tower: Dictionary) -> void:
	var labels: PackedStringArray = TowerInspector.effect_labels(tower, sim.state.tiers)
	for i: int in range(mini(2, labels.size())):
		_effect_chip(row, labels[i], StatusInfo.accent(labels[i]))
	if labels.size() > 2:
		_effect_chip(row, "+%d" % (labels.size() - 2), UIKit.MUTED)

func _update_tower_history() -> void:
	if tower_history == null or not tower_history.visible:
		return
	var tower: Dictionary = sim.state.towers.get(selected, {})
	if not tower.is_empty():
		tower_history.text = TowerInspector.history(tower)
		var restore: int = int(TowerRules.trait_profile(tower, sim.state.tiers).get("wall_heal", 0))
		if restore > 0:
			tower_history.text += "\nGate repair +%d · after wave %d" % [restore, sim.next_gate_repair()]

func _show_leaderboard() -> void:
	var body: VBoxContainer = _dialog("Top 5 damage", 580)
	overlay_type = "leaderboard"
	body.add_child(UIKit.label("Towers on the field", 17, UIKit.MUTED))
	leaderboard_rows = UIKit.column(7)
	body.add_child(leaderboard_rows)
	leaderboard_signature = ""
	leaderboard_next_refresh = 0
	_update_leaderboard()
	body.add_child(UIKit.button(DataDB.text("close"), _close_leaderboard, true, 52))

func _close_leaderboard() -> void:
	if sim.state.phase == "game_over":
		_show_game_over()
	else:
		_close_overlay()

func _update_leaderboard() -> void:
	var now: int = Time.get_ticks_msec()
	if now < leaderboard_next_refresh:
		return
	leaderboard_next_refresh = now + 150
	var towers: Array = sim.top_damage()
	var scores := PackedStringArray()
	for tower: Dictionary in towers:
		scores.append("%d %s" % [tower.id, TowerInspector.history(tower)])
	var signature: String = "|".join(scores)
	if leaderboard_signature == signature and leaderboard_rows.get_child_count() > 0:
		return
	leaderboard_signature = signature
	UIKit.clear(leaderboard_rows)
	if towers.is_empty():
		leaderboard_rows.add_child(UIKit.label("Build a tower to start tracking damage.", 18, UIKit.MUTED))
	for rank: int in range(towers.size()):
		var tower: Dictionary = towers[rank]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UIKit.style(Color("#f3f7eb"), UIKit.BORDER, 12, 5))
		leaderboard_rows.add_child(panel)
		var row: HBoxContainer = UIKit.row(8)
		panel.add_child(row)
		row.add_child(UIKit.label("%d" % (rank + 1), 18, UIKit.UPGRADE))
		row.add_child(UIKit.portrait(tower, 44))
		var identity: VBoxContainer = UIKit.column(2)
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(identity)
		var tile: Vector2 = sim.track.slots[tower.slot].position
		var title: String = TowerRules.display_name(tower)
		if tower.kind != "ascended":
			title += " · Lv " + str(tower.level)
		identity.add_child(UIKit.label("%s  [%d, %d]" % [title, int(tile.x) + 1, int(tile.y) + 1], 17, UIKit.INK, true))
		identity.add_child(UIKit.composition(tower, 17, false))
		var scores_column: VBoxContainer = UIKit.column(2)
		row.add_child(scores_column)
		scores_column.add_child(UIKit.label(TowerInspector.number(float(tower.get("damage_dealt", 0.0))) + " damage", 17, UIKit.INK))
		scores_column.add_child(UIKit.label("%d kills" % int(tower.get("kills", 0)), 15, UIKit.MUTED))

func _effect_chip(parent: Container, title: String, tint: Color, icon: String = "", hint: String = "") -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if hint.is_empty() else Control.MOUSE_FILTER_STOP
	panel.tooltip_text = hint
	var style: StyleBoxFlat = UIKit.style(tint.lerp(UIKit.SURFACE, .92), tint.lerp(UIKit.SURFACE, .75), 9, 3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var row: HBoxContainer = UIKit.row(3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if not icon.is_empty():
		row.add_child(UIKit.badge(icon, 16))
	row.add_child(UIKit.label(title, 14, tint))

func _style_upgrade(button: Button) -> void:
	button.add_theme_stylebox_override("normal", UIKit.raised(Color("#fbebbf"), Color("#d9b473")))
	button.add_theme_stylebox_override("hover", UIKit.raised(Color("#fff3d2"), Color("#b7803c")))
	button.add_theme_stylebox_override("pressed", UIKit.style(Color("#eed196"), Color("#b7803c"), 16, 8))
	button.add_theme_color_override("font_color", UIKit.UPGRADE)

func _enemy_pressed(id: int) -> void:
	if paused or sim.state.phase != "wave":
		return
	Haptics.play(8, profile.haptics)
	audio.play("ui")
	inspected_enemy = id
	upgrade_slot = ""
	field.inspected_enemy = id
	selected = ""
	field.selected = ""
	_render_site()

func _current_enemy() -> Dictionary:
	if inspected_enemy >= 0:
		for enemy: Dictionary in sim.state.mobs:
			if int(enemy.id) == inspected_enemy:
				return enemy
	return {}

func _update_enemy_inspector() -> void:
	if inspected_enemy < 0:
		return
	var enemy: Dictionary = _current_enemy()
	if enemy.is_empty():
		inspected_enemy = -1
		field.inspected_enemy = -1
		if overlay_type == "enemy":
			_close_overlay()
		_render_site()
		return
	var traits: PackedStringArray = StatusInfo.enemy_traits(enemy)
	var active: PackedStringArray = StatusInfo.active(enemy, sim.state.tick, sim.hz)
	var metrics: String = "%d / %d HP   ·   %s armor   ·   %s tiles/s" % [
		ceili(enemy.hp), ceili(enemy.max_hp), TowerInspector.number(maxf(0.0, float(enemy.armor) - float(enemy.shred))),
		TowerInspector.number(0.0 if int(enemy.root_time) > 0 or int(enemy.freeze_time) > 0 else float(enemy.speed) * (1.0 - float(enemy.slow)) * Effects.slip_speed(enemy))]
	tower_metrics.text = metrics
	tower_metrics.show()
	if is_instance_valid(enemy_detail_metrics):
		enemy_detail_metrics.text = metrics
		_render_enemy_details(enemy, traits, active)
	var signature: String = " / ".join(traits) + "|" + " / ".join(active)
	if enemy_signature == signature:
		return
	enemy_signature = signature
	site_actions.hide()
	info.text = StatusInfo.enemy_name(enemy)
	detail_button.tooltip_text = "Enemy details"
	detail_button.show()
	UIKit.clear(tower_composition)
	UIKit.clear(tower_effects)
	if enemy.element != "none":
		tower_composition.add_child(UIKit.badge(enemy.element))
		tower_composition.add_child(UIKit.label(String(enemy.element).capitalize(), 15, Glyphs.hue(enemy.element).darkened(.6)))
	var remaining: int = 4
	for key: String in active:
		if remaining == 0:
			break
		var title: String = StatusInfo.title(key)
		_effect_chip(tower_effects, title, StatusInfo.accent(title), StatusInfo.ICONS[key])
		remaining -= 1
	for key: String in traits:
		if remaining == 0:
			break
		if active.has(key):
			continue
		var property_info: Array = StatusInfo.TRAITS[key]
		_effect_chip(tower_effects, StatusInfo.trait_title(key, enemy), Glyphs.hue(property_info[2]).darkened(.57), property_info[2])
		remaining -= 1
	if remaining == 4:
		_effect_chip(tower_effects, "No active effects", UIKit.MUTED)
	tower_effects.tooltip_text = StatusInfo.describe_enemy(enemy, sim.state.tick, sim.hz)
	tower_effects.show()

func _show_inspector_details() -> void:
	if inspected_enemy >= 0:
		_show_enemy_details()
	else:
		_show_tower_details()

func _show_enemy_details() -> void:
	var enemy: Dictionary = _current_enemy()
	if enemy.is_empty():
		return
	var body: VBoxContainer = _dialog(StatusInfo.enemy_name(enemy), 620)
	overlay_type = "enemy"
	enemy_detail_metrics = UIKit.label("", 19, UIKit.MINT, true)
	body.add_child(enemy_detail_metrics)
	if enemy.element != "none":
		var element_row: HBoxContainer = UIKit.row(5)
		element_row.add_child(UIKit.badge(enemy.element))
		element_row.add_child(UIKit.label(String(enemy.element).capitalize(), 18, Glyphs.hue(enemy.element).darkened(.56)))
		body.add_child(element_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(310.0, get_viewport_rect().size.y * .45)
	body.add_child(scroll)
	enemy_detail_rows = UIKit.column(7)
	enemy_detail_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(enemy_detail_rows)
	enemy_detail_signature = ""
	_update_enemy_inspector()
	body.add_child(UIKit.button(DataDB.text("close"), _close_overlay, true, 52))

func _render_enemy_details(enemy: Dictionary, traits: PackedStringArray, active: PackedStringArray) -> void:
	var lines := PackedStringArray()
	for id: String in active:
		lines.append("%s  ·  %s" % [StatusInfo.title(id), StatusInfo.state_value(enemy, id, sim.state.tick, sim.hz)])
	var signature: String = "\n".join(lines)
	if signature == enemy_detail_signature and enemy_detail_rows.get_child_count() > 0:
		return
	enemy_detail_signature = signature
	UIKit.clear(enemy_detail_rows)
	for id: String in traits:
		var property_info: Array = StatusInfo.TRAITS[id]
		_enemy_detail_line(StatusInfo.trait_title(id, enemy), StatusInfo.trait_description(id), property_info[2])
	for i: int in range(active.size()):
		var id: String = active[i]
		_enemy_detail_line(lines[i], StatusInfo.description(id), StatusInfo.ICONS[id])
	if traits.is_empty() and active.is_empty():
		enemy_detail_rows.add_child(UIKit.label("No traits or active effects.", 18, UIKit.MUTED))

func _enemy_detail_line(title: String, description: String, icon: String) -> void:
	var row: HBoxContainer = UIKit.row(7)
	enemy_detail_rows.add_child(row)
	var badge: Control = UIKit.badge(icon)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	var column: VBoxContainer = UIKit.column(0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(UIKit.label(title, 18, StatusInfo.accent(title), true))
	column.add_child(UIKit.label(description, 16, UIKit.MUTED, true))

func _site_button(title: String, callback: Callable) -> Button:
	var button: Button = UIKit.button(title, callback, false, 51)
	button.add_theme_font_size_override("font_size", 16)
	site_actions.add_child(button)
	return button

func _action_button(title: String, action: Dictionary) -> Button:
	var button: Button = _site_button(title, _apply.bind(action))
	action_buttons[button] = action
	_update_action_button(button, action)
	return button

func _update_action_button(button: Button, action: Dictionary) -> void:
	var result: Dictionary = sim.describe(action)
	button.disabled = not result.ok
	button.tooltip_text = result.reason if not result.ok else button.text.replace("\n", " · ")

func _preview_range(kind: String) -> void:
	field.hover_kind = kind

func _site_pressed(slot: String) -> void:
	if paused or sim.state.phase == "game_over":
		return
	if not move_origin.is_empty():
		_apply({"type": "move", "slot": move_origin, "to": slot})
		return
	if not catalog_build.is_empty():
		var placement: Dictionary = catalog_build.duplicate()
		placement.slot = slot
		_apply(placement)
		return
	if fuse_origin != "":
		if field.partners.has(slot):
			_show_fusion(slot)
			return
		fuse_origin = ""
		message = ""
	if selected != slot or inspected_enemy >= 0:
		Haptics.play(8, profile.haptics)
		upgrade_slot = ""
	inspected_enemy = -1
	field.inspected_enemy = -1
	selected = slot
	if sim.state.phase == "wave" and int(sim.state.towers.get(slot, {}).get("stun", 0)) > 0:
		_apply({"type": "rally", "slot": slot})
	_refresh()

func _apply(action: Dictionary) -> void:
	var result: Dictionary = sim.apply(action)
	if not result.ok:
		message = result.reason
		_update_hud()
		return
	message = ""
	if action.type in ["select_element", "fuse", "infuse", "remove_infusion"]:
		_close_overlay()
	if action.type in ["upgrade", "empower_pure", "sell", "fuse"]:
		upgrade_slot = ""
	if action.type != "start_wave":
		fuse_origin = ""
	if action.type == "move":
		move_origin = ""
		selected = action.to
		Haptics.play(18, profile.haptics)
		audio.play("build")
	elif action.type != "start_wave":
		move_origin = ""
	if action.type in ["build", "build_pure"]:
		if not catalog_build.is_empty():
			catalog_build.clear()
			selected = action.slot
		Haptics.play(16, profile.haptics)
		audio.play("build")
		field.animate({"type": "tower_placed", "data": {"slot": action.slot}})
		_hint(1)
	elif action.type in ["upgrade", "empower_pure"]:
		Haptics.play(22, profile.haptics)
		audio.play("upgrade")
		field.animate({"type": "tower_upgraded", "data": {"slot": action.slot}})
	elif action.type in ["infuse", "remove_infusion"]:
		Haptics.play(21, profile.haptics)
		audio.play("infuse")
		field.animate({"type": "infusion_changed", "data": {"slot": action.slot, "element": action.get("element", "")}})
	elif action.type == "sell":
		audio.play("sell")
	elif action.type == "start_wave" and not sim.state.towers.has(selected):
		selected = ""
	elif action.type == "select_element":
		message = DataDB.text("trial_queued") % [String(action.element).capitalize(), TowerRules.roman(int(action.tier))]
		sim.apply({"type": "start_wave"})
	_checkpoint()
	_take_events()
	_refresh()

func _take_events() -> void:
	for event: Dictionary in sim.events:
		field.animate(event)
		match event.type:
			"wave_started":
				accumulator = 0.0
				audio.play("spirit" if event.data.bonus else "wave")
				if not event.data.bonus and int(sim.state.wave) % int(sim.cfg.boss_every) == 0:
					_hint(7)
			"wave_cleared":
				audio.play("clear")
				Haptics.play(18, profile.haptics)
				_hint(2)
				if event.data.pure_crystal:
					message = "◈ +1 Pure Crystal"
				_checkpoint()
				_refresh()
				if sim.state.selection_pending:
					_hint(3)
					_show_selection()
			"special_spawned":
				if event.data.kind == "spirit":
					_hint(4)
			"bonus_finished":
				_checkpoint()
				_refresh()
			"element_unlocked":
				audio.play("unlock")
				Haptics.play(36, profile.haptics)
				message = DataDB.text("unlocked") % [String(event.data.element).capitalize(), TowerRules.roman(event.data.tier)]
				if bool(event.data.defeated) and int(event.data.tier) >= 2:
					message += " · +10% elemental damage"
				if int(event.data.lost) > 0:
					message += "  ·  −%d lives" % int(event.data.lost)
				if int(event.data.absorbed) > 0:
					message += "  ·  −%d barrier" % int(event.data.absorbed)
				_hint(5)
				if _unlocked().size() >= 2:
					_hint(6)
			"mob_leaked":
				audio.play("gate")
				Haptics.play(50, profile.haptics)
			"gate_restored":
				if int(event.data.barrier) > 0:
					message = "Gate barrier +%d" % int(event.data.barrier)
				elif int(event.data.lives) > 0:
					message = "Gate restored +%d HP" % int(event.data.lives)
			"tower_fired":
				if event.data.primary:
					var tower: Dictionary = sim.state.towers[event.data.slot]
					audio.play("cannon" if tower.kind == "cannon" else ("arrow" if tower.kind == "arrow" and tower.infusion == "" else "magic"))
			"mob_killed":
				if int(event.data.gold) > 0 and event.data.kind != "spirit":
					audio.play("coin")
			"tower_stunned":
				if selected == event.data.slot:
					_render_site()
			"fused":
				audio.play("fuse")
				Haptics.play(36, profile.haptics)
				message = DataDB.text("fused") % TowerRules.stats(sim.state.towers[event.data.slot]).name
			"game_over":
				if persistence_enabled:
					SaveStore.finish(sim, profile)
				_refresh()
				_show_game_over()
	sim.events.clear()

func _hint(index: int) -> bool:
	if profile.seen.has(index):
		return false
	profile.seen.append(index)
	if message == "":
		message = DataDB.read("strings_en").hints[index]
	if persistence_enabled:
		SaveStore.write_profile(profile)
	return true

func _checkpoint() -> void:
	if persistence_enabled and sim.state.phase != "game_over" and SaveStore.checkpoint(sim) != OK:
		message = DataDB.text("checkpoint_failed")
		if status != null:
			status.text = message

func _toggle_speed() -> void:
	speed = speed % 4 + 1
	speed_button.text = DataDB.text("speed_value") % speed
	profile.speed = speed
	if persistence_enabled:
		SaveStore.write_profile(profile)
	audio.play("ui")

func _toggle_sound() -> void:
	profile.sound = not bool(profile.sound)
	audio.set_sound(profile.sound)
	_settings_changed()

func _toggle_music() -> void:
	profile.music = not bool(profile.music)
	audio.set_music(profile.music)
	_settings_changed()

func _toggle_haptics() -> void:
	profile.haptics = not bool(profile.haptics)
	_settings_changed()

func _toggle_gate_view() -> void:
	profile.gate_on_top = not field.gate_on_top
	field.gate_on_top = profile.gate_on_top
	_settings_changed()

func _settings_changed() -> void:
	if persistence_enabled:
		SaveStore.write_profile(profile)
	audio.play("ui")
	Haptics.play(12, profile.haptics)
	_show_pause()

func _dialog(title: String, width: float = 570) -> VBoxContainer:
	_close_overlay()
	var dialog: Dictionary = UIKit.dialog(self, width)
	overlay = dialog.overlay
	var body: VBoxContainer = dialog.body
	body.add_child(UIKit.label(title, 32))
	return body

func _close_overlay() -> void:
	overlay_actions.clear()
	overview = null
	enemy_detail_metrics = null
	enemy_detail_rows = null
	leaderboard_rows = null
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	overlay = null
	overlay_type = ""

func _show_selection() -> void:
	var body: VBoxContainer = _dialog(DataDB.text("choose_spirit"), 820 if wide else 670)
	overlay_type = "select"
	body.add_child(UIKit.label(DataDB.text("trial_intro"), 18, UIKit.MUTED, true))
	var choices: Array[Dictionary] = sim.choices()
	var grid: GridContainer = _choice_grid(body, 3 if wide else 2, choices.size())
	var hint: Label = _choice_effect_hint(body)
	for choice: Dictionary in choices:
		var element: Dictionary = DataDB.read("elements")[choice.element]
		var tiers: Array = DataDB.read("spirits").tiers
		var recommended: int = int(tiers[int(choice.tier) - 1].recommended)
		var threat: String = DataDB.text("threat_ready")
		if int(sim.state.wave) < recommended:
			threat = DataDB.text("threat_extreme") if int(sim.state.wave) < recommended - int(DataDB.read("spirits").extreme_margin) else DataDB.text("threat_risky")
		var chosen: Dictionary = {"type": "select_element", "element": choice.element, "tier": choice.tier}
		var title: String = "%s %s\n%s · Weak to %s" % [element.name, TowerRules.roman(choice.tier), threat, String(element.weak).capitalize()]
		var button: Button = _choice_button(title, choice.element, _apply.bind(chosen))
		button.name = "Choose" + String(choice.element).capitalize()
		button.tooltip_text = DataDB.text("trial_recommended") % recommended if recommended > 0 else ""
		var tower: Dictionary = TowerRules.create(0, "", "pure", choice.element, "", 0)
		tower.level = int(sim.cfg.pure_caps[int(choice.tier) - 1]) + 1
		var unlocked_tiers: Dictionary = sim.state.tiers.duplicate()
		unlocked_tiers[choice.element] = choice.tier
		_add_element_choice(grid, button, TowerInspector.effect_entries(tower, unlocked_tiers), hint)
	body.add_child(UIKit.button(DataDB.text("decide_later"), _close_overlay, false, 52))

func _choice_grid(body: VBoxContainer, columns: int, count: int) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(ceilf(float(count) / columns) * 202.0, get_viewport_rect().size.y * .59)
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	return grid

func _choice_effect_hint(body: VBoxContainer) -> Label:
	var hint: Label = UIKit.label("Tap or hover an effect for exact values.", 16, UIKit.MUTED, true)
	hint.custom_minimum_size.y = 46
	body.add_child(hint)
	return hint

func _choice_button(text: String, element: String, callback: Callable) -> Button:
	var button: Button = UIKit.button(text, callback, false, 66)
	button.add_theme_font_size_override("font_size", 15)
	UIKit.element_button(button, element, true, true)
	return button

func _add_element_choice(grid: GridContainer, choice: Button, effects: Array[Dictionary], hint: Label) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIKit.style(Color("#f0f5e7"), UIKit.BORDER, 13, 5))
	grid.add_child(panel)
	var column: VBoxContainer = UIKit.column(3)
	panel.add_child(column)
	column.add_child(choice)
	for effect: Dictionary in effects:
		var button: Button = UIKit.button(effect.label, _read_effect.bind(hint, effect), false, 28)
		for state: String in ["normal", "hover", "pressed"]:
			var background: Color = Color(effect.tint).lerp(UIKit.SURFACE, .93 if state == "normal" else .83)
			var border: Color = Color(effect.tint).lerp(UIKit.SURFACE, .74)
			button.add_theme_stylebox_override(state, UIKit.style(background, border, 8, 3))
		for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color, effect.tint)
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = effect.detail
		column.add_child(button)

func _read_effect(label: Label, effect: Dictionary) -> void:
	label.text = effect.detail
	label.add_theme_color_override("font_color", effect.tint)


func _show_preview(wave: int, bonus: bool = false) -> void:
	var preview: Dictionary = sim.preview(wave, bonus)
	var title: String = DataDB.text("bonus_forecast") if bonus else DataDB.text("forecast_title") % wave
	var body: VBoxContainer = _dialog(title, 650)
	overlay_type = "preview"
	overlay_wave = wave
	overlay_bonus = bonus
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.custom_minimum_size.y = minf(360, maxf(115, float(preview.groups.size() + 2) * 58))
	body.add_child(scroller)
	var list: VBoxContainer = UIKit.column(7)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(list)
	var entries: Array = preview.groups.duplicate()
	entries = preview.bosses + entries
	if not preview.spirit.is_empty():
		entries.push_front(preview.spirit)
	for group: Dictionary in entries:
		var family: Dictionary = DataDB.read("mobs").families.get(group.get("family", ""), {})
		var name: String = family.get("name", DataDB.text("grunt"))
		if group.element != "none":
			name = String(group.element).capitalize() + " " + name
		var subject: String = DataDB.text("enemy_group") % [group.count, name]
		if group.kind == "spirit":
			subject = DataDB.text("spirit_group") % [group.element.capitalize(), TowerRules.roman(group.tier)]
		elif group.kind == "boss":
			subject = "%s · %d g" % [DataDB.read("bosses")[group.boss_type].name, int(group.gold)]
		var tint: Color = Glyphs.hue(group.element) if group.element != "none" else Color(family.get("color", "#b0cbb9"))
		list.add_child(UIKit.label(DataDB.text("enemy_stats") % [subject, roundi(group.hp), group.speed, group.armor], 20, tint.darkened(.54), true))
		for key: String in StatusInfo.enemy_traits(group):
			var property_info: Array = StatusInfo.TRAITS[key]
			list.add_child(UIKit.label("%s · %s" % [StatusInfo.trait_title(key, group), StatusInfo.trait_description(key)],
				17, Glyphs.hue(property_info[2]).darkened(.58), true))
	body.add_child(UIKit.button(DataDB.text("close"), _close_overlay, true))

func _show_tower_details() -> void:
	var tower: Dictionary = sim.state.towers.get(selected, {})
	if tower.is_empty():
		return
	var body: VBoxContainer = _dialog(info.text, 625)
	overlay_type = "tower"
	body.add_child(UIKit.composition(tower, 29))
	body.add_child(UIKit.label(TowerInspector.history(tower), 17, UIKit.MINT, true))
	var profile_data: Dictionary = TowerRules.trait_profile(tower, sim.state.tiers)
	body.add_child(UIKit.label(TowerInspector.metrics(tower, sim.spirit_victories()), 20, UIKit.MINT, true))
	var boost: float = TowerRules.spirit_multiplier(tower, sim.spirit_victories()) - 1.0
	if boost > 0.0:
		body.add_child(UIKit.label("Spirit victories   ·   +%s damage" % TowerInspector.percent(boost), 17, UIKit.UPGRADE))
	body.add_child(UIKit.label(DataDB.text("tower_damage_type") % TowerInspector.damage_type(tower, profile_data), 19, UIKit.MUTED, true))
	var lines: PackedStringArray = TowerInspector.effects(tower, sim.state.tiers)
	var effects: VBoxContainer = body
	if lines.size() > 3:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size.y = minf(320, lines.size() * 66.0)
		body.add_child(scroll)
		effects = UIKit.column(10)
		effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(effects)
	for line: String in lines:
		effects.add_child(UIKit.label(line, 20, StatusInfo.accent(line), true))
	body.add_child(UIKit.label(DataDB.text("base_stats"), 17, UIKit.MUTED, true))
	body.add_child(UIKit.button(DataDB.text("close"), _close_overlay, true))

func _show_upgrade_preview() -> void:
	var tower: Dictionary = sim.state.towers.get(selected, {})
	if tower.is_empty() or not sim.describe(_tower_upgrade_action(tower), true).ok:
		return
	upgrade_slot = selected
	_render_site()

func _cancel_upgrade() -> void:
	upgrade_slot = ""
	_render_site()

func _render_upgrade(tower: Dictionary) -> void:
	tower_metrics.hide()
	tower_effects.hide()
	tower_comparison.show()
	var future: Dictionary = tower.duplicate()
	if TowerRules.can_socket_crystal(tower):
		future.crystals = int(tower.get("crystals", 0)) + 1
	else:
		future.level += 1
	_comparison_card(tower_comparison, tower, DataDB.text("upgrade_current"), false)
	_comparison_card(tower_comparison, future, DataDB.text("upgrade_after"), true)
	site_actions.hide()

func _comparison_card(parent: HBoxContainer, tower: Dictionary, caption: String, upgraded: bool, fusion: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIKit.style(Color("#fffae2") if upgraded else Color("#f0f5e7"),
		Color("#d1b661") if upgraded else UIKit.BORDER, 13, 7))
	parent.add_child(panel)
	var column: VBoxContainer = UIKit.column(3)
	panel.add_child(column)
	var heading: Color = UIKit.UPGRADE if upgraded else UIKit.INK
	var font_size: int = 17 if fusion else 15
	var crystals: int = int(tower.get("crystals", 0))
	var rank: String = "Lv %d" % int(tower.level)
	if tower.kind == "ascended":
		rank = "◈ %d" % crystals
	elif crystals > 0:
		rank += " · ◈ %d" % crystals
	var level: Label = UIKit.label(caption + " · " + rank, font_size, heading, true)
	level.add_theme_font_override("font", UIKit.heading())
	column.add_child(level)
	if fusion:
		column.add_child(UIKit.portrait(tower, 44))
		column.add_child(UIKit.composition(tower, 20, false))

	var profile_data: Dictionary = TowerRules.attack_profile(tower, sim.spirit_victories())
	var reach: String = DataDB.text("whole_map") if is_inf(float(profile_data.range)) else TowerInspector.number(profile_data.range)
	var damage: String = "Hit %s   ·   %s/s" % [TowerInspector.number(profile_data.damage), TowerInspector.number(profile_data.rate)]
	if float(profile_data.rate) == 0.0:
		damage = "Support aura"
	column.add_child(UIKit.label(damage, font_size, heading, true))
	var coverage: String = "Range " + reach
	if float(profile_data.splash) > 0.0:
		coverage += "   ·   Splash " + TowerInspector.number(profile_data.splash)
	column.add_child(UIKit.label(coverage, font_size, UIKit.MUTED, true))
	if fusion:
		var profile_traits: Dictionary = TowerRules.trait_profile(tower, sim.state.tiers)
		column.add_child(UIKit.label(TowerInspector.damage_type(tower, profile_traits), font_size, UIKit.MINT, true))
		column.add_child(UIKit.label(TowerInspector.history(tower), 14, UIKit.MUTED, true))
	for entry: Dictionary in TowerInspector.effect_entries(tower, sim.state.tiers):
		var effect: Label = UIKit.label(entry.detail if fusion else entry.label, 16 if fusion else 14, entry.tint, true)
		effect.mouse_filter = Control.MOUSE_FILTER_STOP
		effect.tooltip_text = entry.detail
		column.add_child(effect)


func _show_status_help() -> void:
	var body: VBoxContainer = _dialog(DataDB.text("status_help"), 620)
	overlay_type = "statuses"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(420.0, get_viewport_rect().size.y * .59)
	body.add_child(scroll)
	var entries: VBoxContainer = UIKit.column(13)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(entries)
	for key: String in StatusInfo.ICONS:
		var row: HBoxContainer = UIKit.row(9)
		entries.add_child(row)
		var badge := UIKit.ElementBadge.new()
		badge.element = StatusInfo.ICONS[key]
		badge.custom_minimum_size = Vector2(32, 32)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(badge)
		var label: Label = UIKit.label(StatusInfo.tooltip(PackedStringArray([key])), 20, StatusInfo.accent(StatusInfo.title(key)), true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
	body.add_child(UIKit.button(DataDB.text("close"), _close_overlay, true))

func _open_legend() -> void:
	_show_legend()

func _select_legend_element(element: String) -> void:
	legend_element = element
	Haptics.play(8, profile.haptics)
	_show_legend()

func _show_legend() -> void:
	var body: VBoxContainer = _dialog("Tower overview", 1000)
	overlay_type = "legend"
	overview = TowerOverview.new()
	body.add_child(overview)
	overview.filter_changed.connect(func(element: String) -> void: legend_element = element)
	overview.build_requested.connect(_begin_catalog_build)
	overview.configure(sim, legend_element, wide, get_viewport_rect().size.y)
	body.add_child(UIKit.button(DataDB.text("close"), _close_overlay, true, 48))

func _begin_catalog_build(kind: String, pure: bool) -> void:
	_close_overlay()
	fuse_origin = ""
	move_origin = ""
	upgrade_slot = ""
	inspected_enemy = -1
	field.inspected_enemy = -1
	selected = ""
	catalog_build = {"type": "build_pure" if pure else "build", "kind": kind}
	message = "Touch a tile, slide to aim, then release."
	Haptics.play(8, profile.haptics)
	_refresh()


func _unlocked() -> Array[String]:
	var result: Array[String] = []
	for element: String in DataDB.ELEMENTS:
		if int(sim.state.tiers[element]) > 0:
			result.append(element)
	return result

func _show_infusion() -> void:
	var body: VBoxContainer = _dialog(DataDB.text("infusion_title"), 690)
	overlay_type = "infuse"
	body.add_child(UIKit.label(DataDB.text("infusion_explainer"), 17, UIKit.MUTED, true))
	var available: Array[String] = _unlocked()
	var grid: GridContainer = _choice_grid(body, 3 if wide else 2, available.size())
	var hint: Label = _choice_effect_hint(body)
	var tower: Dictionary = sim.state.towers[selected]
	for element: String in available:
		var tier: int = TowerRules.infusion_tier(tower.level, sim.state.tiers[element])
		var action: Dictionary = {"type": "infuse", "slot": selected, "element": element}
		var result: Dictionary = sim.describe(action)
		var title: String = "%s %s\n%s" % [element.capitalize(), TowerRules.roman(tier),
			"Active" if tower.infusion == element else "%d g" % int(result.cost)]
		var button: Button = _choice_button(title, element, _apply.bind(action))
		overlay_actions[button] = action
		_update_action_button(button, action)
		var infused: Dictionary = tower.duplicate()
		infused.infusion = element
		var entries: Array[Dictionary] = TowerInspector.effect_entries(infused, sim.state.tiers)
		_add_element_choice(grid, button, entries, hint)
	if tower.infusion != "":
		body.add_child(UIKit.button(DataDB.text("remove_infusion"), _apply.bind({"type": "remove_infusion", "slot": selected}), false, 48))
	body.add_child(UIKit.button(DataDB.text("close"), _close_overlay, false, 48))


func _fusion_options(origin: String) -> Array[String]:
	var valid: Array[String] = []
	for slot: String in sim.state.towers:
		if sim.describe({"type": "fuse", "slot_a": origin, "slot_b": slot}, true).ok:
			valid.append(slot)
	return valid

func _update_fuse_button() -> void:
	if not is_instance_valid(fuse_button):
		return
	var tower: Dictionary = sim.state.towers.get(selected, {})
	if tower.is_empty():
		return
	var label: String = DataDB.text("fusion_action")
	var reason: String = ""
	if int(tower.level) < int(sim.cfg.fuse_min_level):
		reason = DataDB.text("requires_fuse_level") % sim.cfg.fuse_min_level
	elif _fusion_options(selected).is_empty():
		reason = DataDB.text("fusion_partner_help") % sim.cfg.fuse_min_level
	fuse_button.text = label
	fuse_button.disabled = not reason.is_empty()
	fuse_button.tooltip_text = reason if not reason.is_empty() else DataDB.text("fusion_tip")

func _begin_fusion() -> void:
	fuse_origin = selected
	message = DataDB.text("fusion_tip")
	_refresh()

func _cancel_fusion() -> void:
	_close_overlay()
	fuse_origin = ""
	message = ""
	_refresh()

func _show_fusion(partner: String) -> void:
	var action: Dictionary = {"type": "fuse", "slot_a": fuse_origin, "slot_b": partner}
	var first: Dictionary = sim.state.towers.get(fuse_origin, {})
	var second: Dictionary = sim.state.towers.get(partner, {})
	var id: String = TowerRules.fusion_recipe(first, second)
	if id.is_empty():
		_cancel_fusion()
		return
	var result: Dictionary = TowerRules.combine(id, first, second, sim.state.tiers, sim.spirit_victories())
	var rule: Dictionary = TowerRules.stats(result)
	var body: VBoxContainer = _dialog(DataDB.text("fusion_title") % String(rule.name), 780)
	overlay_type = "fusion"
	overlay_partner = partner
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var max_height: float = minf(get_viewport_rect().size.y * .58, 445)
	scroll.custom_minimum_size.y = max_height
	body.add_child(scroll)
	var compare: HBoxContainer = UIKit.row(8)
	compare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(compare)
	compare.minimum_size_changed.connect(_size_fusion_scroll.bind(scroll, compare, max_height))
	_comparison_card(compare, first, TowerRules.stats(first).name, false, true)
	_comparison_card(compare, second, TowerRules.stats(second).name, false, true)
	_comparison_card(compare, result, rule.name, true, true)
	var matchups := PackedStringArray()
	var wave: Dictionary = sim.preview(sim.state.wave)
	var groups: Array = wave.groups.duplicate()
	if not wave.spirit.is_empty():
		groups.append(wave.spirit)
	var seen: Array[String] = []
	for group: Dictionary in groups:
		if seen.has(group.element) or float(rule.rate) <= 0:
			continue
		seen.append(group.element)
		var value: float = Damage.blend(rule.split, group.element)
		if rule.effect.has("adaptive"):
			value = maxf(Damage.matchup("light", group.element), Damage.matchup("dark", group.element))
		matchups.append("%s ×%.2f" % [group.element.capitalize() if group.element != "none" else DataDB.text("neutral"), value])
	if not matchups.is_empty():
		body.add_child(UIKit.label(DataDB.text("fusion_matchup") % " / ".join(matchups), 16, UIKit.MUTED, true))
	var controls: HBoxContainer = UIKit.row()
	controls.add_child(UIKit.button(DataDB.text("cancel"), _cancel_fusion))
	var cost: int = TowerRules.fusion_cost(first, second)
	var confirm: Button = UIKit.button(DataDB.text("fusion_confirm") % cost, _apply.bind(action), true)
	overlay_actions[confirm] = action
	_update_action_button(confirm, action)
	controls.add_child(confirm)
	body.add_child(controls)

func _size_fusion_scroll(scroll: ScrollContainer, compare: HBoxContainer, max_height: float) -> void:
	scroll.custom_minimum_size.y = clampf(compare.get_combined_minimum_size().y + 4.0, 140.0, max_height)

func _show_pause() -> void:
	if not paused:
		_checkpoint()
	paused = true
	field.animation_paused = true
	var body: VBoxContainer = _dialog(DataDB.text("paused"), 485)
	overlay_type = "pause"
	body.add_child(UIKit.button(DataDB.text("resume"), _resume, true, 76))
	body.add_child(UIKit.toggle_row("Music", profile.music, _toggle_music))
	body.add_child(UIKit.toggle_row("Sound effects", profile.sound, _toggle_sound))
	body.add_child(UIKit.toggle_row("Haptics", profile.haptics, _toggle_haptics))
	body.add_child(UIKit.toggle_row("Gate at top", field.gate_on_top, _toggle_gate_view))
	var navigation: HBoxContainer = UIKit.row(8)
	navigation.add_child(UIKit.button(DataDB.text("restart"), _confirm_restart, false, 54))
	navigation.add_child(UIKit.button(DataDB.text("menu"), _menu, false, 54))
	body.add_child(navigation)

func _resume() -> void:
	paused = false
	field.animation_paused = false
	_close_overlay()
	if sim.state.selection_pending:
		_show_selection()

func _confirm_restart() -> void:
	var body: VBoxContainer = _dialog(DataDB.text("restart_title"), 510)
	overlay_type = "restart"
	body.add_child(UIKit.label(DataDB.text("restart_info"), 22, UIKit.MUTED, true))
	var controls: HBoxContainer = UIKit.row()
	controls.add_child(UIKit.button(DataDB.text("cancel"), _show_pause))
	controls.add_child(UIKit.button(DataDB.text("restart"), _restart, true))
	body.add_child(controls)

func _restart() -> void:
	_close_overlay()
	paused = false
	sim = Sim.new(int(randi()))
	selected = ""
	upgrade_slot = ""
	pure_palette = false
	inspected_enemy = -1
	field.inspected_enemy = -1
	fuse_origin = ""
	move_origin = ""
	catalog_build.clear()
	accumulator = 0
	message = ""
	field.sim = sim
	field.reset_animation()
	_checkpoint()
	_refresh()

func _show_game_over() -> void:
	var body: VBoxContainer = _dialog(DataDB.text("game_over"), 490)
	overlay_type = "end"
	body.add_child(UIKit.label(DataDB.text("game_over_wave") % [sim.state.wave, profile.best_wave], 25, UIKit.MINT))
	body.add_child(UIKit.label(DataDB.text("game_over_stats") % [
		int(sim.state.wave) - 1, sim.state.stats.kills, sim.state.stats.spirits, sim.state.stats.fusions,
	], 22, UIKit.MUTED))
	body.add_child(UIKit.button(DataDB.text("retry"), _restart, true, 76))
	body.add_child(UIKit.button("Top 5 damage", _show_leaderboard, false, 52))
	body.add_child(UIKit.button(DataDB.text("menu"), _menu))

func _menu() -> void:
	_checkpoint()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
