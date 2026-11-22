extends Control

const GAME = preload("res://scenes/game.tscn")
var profile: Dictionary
var checkpoint: Sim
var layout: Control
var overlay: Control
var wide: bool

func _ready() -> void:
	profile = SaveStore.profile()
	checkpoint = SaveStore.resume()
	wide = size.x > size.y * 1.25
	_build()
	resized.connect(_resized)

func _resized() -> void:
	if (size.x > size.y * 1.25) != wide:
		wide = size.x > size.y * 1.25
		_build()

func _build() -> void:
	UIKit.clear(self)
	overlay = null
	UIKit.screen_background(self)
	var margins: MarginContainer = UIKit.screen_margin(self, 22)
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margins.add_child(scroller)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.add_child(center)
	layout = UIKit.row(28) if wide else UIKit.column(16)
	center.add_child(layout)

	var art := MenuArt.new()
	var content_width: float = clampf(size.x - 66.0, 360.0, 650.0)
	art.custom_minimum_size = Vector2(350, 440) if wide else Vector2(content_width, content_width * .73)
	layout.add_child(art)
	var buttons: VBoxContainer = UIKit.column(9)
	buttons.custom_minimum_size.x = 420 if wide else content_width
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(buttons)
	var title: Label = UIKit.label(DataDB.text("title"), 59)
	var record: Label = UIKit.label(DataDB.text("best_wave") % (str(profile.best_wave) if int(profile.best_wave) > 0 else "—"), 17, UIKit.MINT)
	if not wide:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(title)
	buttons.add_child(record)

	if checkpoint != null:
		var title_key: String = "continue_wave" if checkpoint.state.trial.is_empty() else "continue_bonus"
		var title_args: Variant = checkpoint.state.wave if checkpoint.state.trial.is_empty() else String(checkpoint.state.trial.element).capitalize()
		buttons.add_child(UIKit.button(DataDB.text(title_key) % title_args, _open_game.bind(checkpoint), true, 68))
	buttons.add_child(UIKit.button("New Run", _new_run, checkpoint == null, 68))
	var foot: HBoxContainer = UIKit.row(7)
	foot.add_child(UIKit.button(DataDB.text("how"), _help, false, 47))
	foot.add_child(UIKit.button("Settings", _show_settings, false, 47))
	buttons.add_child(foot)
	_build_recent(buttons)

func _build_recent(parent: VBoxContainer) -> void:
	var archive := PanelContainer.new()
	archive.add_theme_stylebox_override("panel", UIKit.style(Color("#e4efd8"), Color("#c2d6b7"), 17, 9))
	parent.add_child(archive)
	var rows: VBoxContainer = UIKit.column(5)
	archive.add_child(rows)
	var heading: Label = UIKit.label("Recent runs", 18, UIKit.INK)
	heading.add_theme_font_override("font", UIKit.heading())
	rows.add_child(heading)
	var runs: Array = profile.recent_runs
	if runs.is_empty():
		rows.add_child(UIKit.label("Finished runs appear here.", 15, UIKit.MUTED))
	for run: Dictionary in runs:
		var labels: Dictionary = {"win": "Victory", "banked": "Banked", "lost": "Lost"}
		var mode: String = run.get("mode", "legacy")
		var summary: String = "Wave %d" % int(run.reached) if mode == "legacy" else "%s · %s · %d waves" % [
			mode.capitalize(), labels.get(run.get("outcome", ""), ""), int(run.cleared)]
		var label: String = "%s  ·  %d kills   ›\n%s" % [summary, int(run.kills), run.date]
		var button: Button = UIKit.button(label, _show_run.bind(run), false, 53)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		rows.add_child(button)

func _show_run(run: Dictionary) -> void:
	_close()
	var dialog: Dictionary = UIKit.dialog(self, 555)
	overlay = dialog.overlay
	var body: VBoxContainer = dialog.body
	body.add_child(UIKit.label("Wave %d reached" % int(run.reached), 30))
	body.add_child(UIKit.label(run.date, 16, UIKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	body.add_child(grid)
	var elapsed: int = int(run.seconds)
	var stats_list: Array = [["Waves cleared", str(int(run.cleared))], ["Enemies defeated", str(int(run.kills))],
		["Total damage", TowerInspector.number(run.damage)], ["Bosses defeated", str(int(run.bosses))],
		["Spirits defeated", "%d / %d" % [int(run.spirits_defeated), int(run.trials)]], ["Fusions", str(int(run.fusions))],
		["Enemies through", str(int(run.leaks))], ["Gold left", str(int(run.gold))], ["Pure towers built", str(int(run.get("pures", 0)))],
		["Combat time", "%d:%02d" % [floori(elapsed / 60.0), elapsed % 60]]]
	for stat: Array in stats_list:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UIKit.style(Color("#f1f5e6"), UIKit.BORDER, 11, 6))
		grid.add_child(panel)
		var text: VBoxContainer = UIKit.column(0)
		panel.add_child(text)
		text.add_child(UIKit.label(stat[0], 15, UIKit.MUTED))
		text.add_child(UIKit.label(stat[1], 22, UIKit.INK))
	var elements: HBoxContainer = UIKit.row(9)
	body.add_child(elements)
	for element: String in DataDB.ELEMENTS:
		var tier: int = int(run.tiers.get(element, 0))
		if tier > 0:
			elements.add_child(UIKit.badge(element, 23))
			elements.add_child(UIKit.label(TowerRules.roman(tier), 15, Glyphs.hue(element).darkened(.58)))
	if not run.top.is_empty():
		body.add_child(UIKit.label("Top tower   ·   %s   ·   %s damage" % [run.top.name, TowerInspector.number(run.top.damage)], 17, UIKit.MINT, true))
	body.add_child(UIKit.button(DataDB.text("close"), _close, true, 49))

func _show_settings() -> void:
	_close()
	var dialog: Dictionary = UIKit.dialog(self, 435)
	overlay = dialog.overlay
	var body: VBoxContainer = dialog.body
	body.add_child(UIKit.label("Settings", 30))
	body.add_child(UIKit.toggle_row("Music", profile.music, _toggle_setting.bind("music")))
	body.add_child(UIKit.toggle_row("Sound effects", profile.sound, _toggle_setting.bind("sound")))
	body.add_child(UIKit.toggle_row("Haptics", profile.haptics, _toggle_setting.bind("haptics")))
	body.add_child(UIKit.toggle_row("Gate at top", profile.gate_on_top, _toggle_setting.bind("gate_on_top")))
	body.add_child(UIKit.button(DataDB.text("close"), _close, true, 51))

func _toggle_setting(key: String) -> void:
	profile[key] = not bool(profile[key])
	SaveStore.write_profile(profile)
	_show_settings()


func _help() -> void:
	var popup: Dictionary = UIKit.dialog(self, 570)
	overlay = popup.overlay
	var body: VBoxContainer = popup.body
	body.add_child(UIKit.label(DataDB.text("how"), 33))
	body.add_child(UIKit.label(DataDB.text("help"), 24, UIKit.MUTED, true))
	body.add_child(UIKit.label(DataDB.text("spirit_help"), 24, UIKit.MUTED, true))
	body.add_child(UIKit.button(DataDB.text("close"), _close, true))

func _new_run() -> void:
	_close()
	var popup: Dictionary = UIKit.dialog(self, 555)
	overlay = popup.overlay
	var body: VBoxContainer = popup.body
	body.add_child(UIKit.label("Choose a run", 33))
	if checkpoint != null:
		body.add_child(UIKit.label(DataDB.text("new_info"), 19, UIKit.MUTED, true))
	for mode: String in ["quick", "standard", "endless"]:
		var length: int = Sim.RUN_LENGTHS[mode]
		var detail: String = "%d waves + finale" % length if length > 0 else "Bank after any 15-wave act"
		var choice: Button = UIKit.button("%s\n%s" % [mode.capitalize(), detail], _open_game.bind(null, mode), mode == "standard", 72)
		choice.name = "Run" + mode.capitalize()
		body.add_child(choice)
	body.add_child(UIKit.button(DataDB.text("cancel"), _close, false, 48))

func _close() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

func _open_game(saved: Sim = null, mode: String = "endless") -> void:
	var game: Control = GAME.instantiate()
	game.sim = saved if saved != null else Sim.campaign(int(randi()), mode)
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	queue_free()
