class_name TowerOverview
extends VBoxContainer

signal filter_changed(element: String)
signal build_requested(kind: String, pure: bool)

const CATEGORIES: Array[String] = ["Starter towers", "Elemental towers", "Pure towers", "Dual fusions", "Triple fusions"]

var sim: Sim
var element: String = ""
var selected_key: String = ""
var rank: int = 1
var entries: Dictionary = {}
var filters: HBoxContainer
var attributes: HFlowContainer
var gallery: VBoxContainer
var gallery_scroll: ScrollContainer
var details: VBoxContainer
var detail_scroll: ScrollContainer
var cards: Dictionary = {}
var purchase: Button
var build_kind: String = ""
var build_pure: bool = false
var last_unlocks: Dictionary = {}

func configure(run: Sim, active_element: String, landscape: bool, viewport_height: float) -> void:
	sim = run
	last_unlocks = sim.state.tiers.duplicate()
	element = active_element
	add_theme_constant_override("separation", 7)
	for kind: String in ["arrow", "cannon"]:
		entries[kind] = TowerRules.create(0, "", kind, "normal", "", 0)
	for kind: String in DataDB.ELEMENTS:
		entries[kind] = TowerRules.create(0, "", "pure", kind, "", 0)
		entries["pure_" + kind] = TowerRules.create(0, "", "ascended", kind, "", 0)
	for table: String in ["duals", "triples"]:
		for id: String in DataDB.read(table):
			entries[id] = TowerRules.fusion_result(id)

	filters = UIKit.row(4)
	add_child(filters)
	attributes = HFlowContainer.new()
	attributes.add_theme_constant_override("h_separation", 12)
	add_child(attributes)
	var panes: BoxContainer = UIKit.row(9) if landscape else UIKit.column(7)
	add_child(panes)
	var gallery_height: float = minf(450, viewport_height * .59) if landscape else minf(340, viewport_height * .30)
	var detail_height: float = gallery_height if landscape else minf(280, viewport_height * .32)
	gallery_scroll = _pane(panes, gallery_height, 1.25 if landscape else 1.0)
	gallery = UIKit.column(6)
	gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_scroll.add_child(gallery)
	detail_scroll = _pane(panes, detail_height)
	details = UIKit.column(5)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(details)
	_select_filter(element)

func _pane(parent: BoxContainer, height: float, stretch: float = 1.0) -> ScrollContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.add_theme_stylebox_override("panel", UIKit.style(Color("#eff5e5"), UIKit.BORDER, 13, 6))
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = height
	panel.add_child(scroll)
	return scroll

func _select_filter(next: String) -> void:
	element = next
	filter_changed.emit(element)
	rank = 1
	selected_key = "arrow" if element.is_empty() else element
	_render_filters()
	_render_gallery()
	_render_detail()

func _render_filters() -> void:
	UIKit.clear(filters)
	for filter: String in [""] + DataDB.ELEMENTS:
		var caption: String = "All" if filter.is_empty() else filter.capitalize()
		var button: Button = UIKit.button(caption, _select_filter.bind(filter), element == filter, 47)
		button.name = "Overview" + caption
		button.add_theme_font_size_override("font_size", 15)
		if not filter.is_empty():
			UIKit.element_button(button, filter, true, true)
			if filter == element:
				var highlight: StyleBoxFlat = UIKit.raised(Glyphs.hue(filter).lerp(UIKit.SURFACE, .50), Glyphs.hue(filter).darkened(.45))
				highlight.content_margin_top = 27
				highlight.content_margin_left = 2
				highlight.content_margin_right = 2
				highlight.content_margin_bottom = 4
				button.add_theme_stylebox_override("normal", highlight)
		filters.add_child(button)
	UIKit.clear(attributes)
	attributes.visible = not element.is_empty()
	if not element.is_empty():
		var tier: int = int(sim.state.tiers[element])
		var unlocked: String = "Locked" if tier == 0 else "Tier " + TowerRules.roman(tier)
		attributes.add_child(UIKit.label(unlocked + " · " + String(DataDB.read("elements")[element].role), 15, UIKit.MINT))
		_add_matchups(attributes, {element: 1.0}, false)

func _add_matchups(parent: Container, split: Dictionary, adaptive: bool) -> void:
	if split.is_empty() or split.has("normal"):
		return
	for target: String in DataDB.ELEMENTS:
		var multiplier: float = Damage.blend(split, target)
		if adaptive:
			multiplier = maxf(Damage.matchup("light", target), Damage.matchup("dark", target))
		if is_equal_approx(multiplier, 1.0):
			continue
		var stronger: bool = multiplier > 1.0
		parent.add_child(UIKit.label("×%s vs %s" % [TowerInspector.number(multiplier), target.capitalize()], 15,
			UIKit.MINT if stronger else UIKit.WARN))

func _category(tower: Dictionary) -> int:
	return {"pure": 1, "ascended": 2, "dual": 3, "triple": 4}.get(tower.kind, 0)

func _render_gallery() -> void:
	UIKit.clear(gallery)
	gallery_scroll.scroll_vertical = 0
	cards.clear()
	for category: int in range(CATEGORIES.size()):
		if category == 2 and not element.is_empty():
			continue
		var grid: GridContainer
		for key: String in entries:
			var tower: Dictionary = entries[key]
			var tower_category: int = _category(tower)
			if not element.is_empty() and tower_category == 2:
				tower_category = 1
			if tower_category != category or (not element.is_empty() and not TowerRules.ingredients(tower).has(element)):
				continue
			if grid == null:
				var heading: Label = UIKit.label("Elemental & Pure" if category == 1 and not element.is_empty() else CATEGORIES[category], 16, UIKit.MINT)
				heading.add_theme_font_override("font", UIKit.heading())
				gallery.add_child(heading)
				grid = GridContainer.new()
				grid.columns = 4
				grid.add_theme_constant_override("h_separation", 5)
				grid.add_theme_constant_override("v_separation", 5)
				gallery.add_child(grid)
			grid.add_child(_gallery_card(key, tower))
	_update_card_styles()

func _gallery_card(key: String, tower: Dictionary) -> Button:
	var title: String = TowerRules.display_name(tower)
	var button: Button = UIKit.button("", _select_tower.bind(key), false, 85)
	button.name = "Record_" + key
	button.set_meta("tower_name", title)
	button.set_meta("tower_key", key)
	button.tooltip_text = title
	cards[key] = button
	var stack: VBoxContainer = UIKit.column(0)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(stack)
	stack.add_child(UIKit.portrait(tower, 38))
	var caption: Label = UIKit.label(title, 15, UIKit.INK)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(caption)
	var available: bool = _requirements(tower).is_empty()
	var tag: Label = UIKit.label("Unlocked" if available else "Locked", 13, UIKit.MINT if available else UIKit.MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(tag)
	return button

func _update_card_styles() -> void:
	var tower: Dictionary = entries[selected_key]
	var ingredients: PackedStringArray = _source_keys(tower)
	var upgrades: PackedStringArray = _fusion_results(tower)
	for key: String in cards:
		var card: Button = cards[key]
		var fill: Color = UIKit.SURFACE
		var edge: Color = UIKit.BORDER
		var link: String = ""
		if key == selected_key:
			fill = Color("#cee8db")
			edge = UIKit.MINT
		elif ingredients.has(key):
			fill = Color("#fff3d0")
			edge = Color("#d6b16d")
			link = " · Ingredient"
		elif upgrades.has(key):
			fill = Color("#edf5de")
			edge = Color("#9fbe8a")
			link = " · Fusion result"
		card.add_theme_stylebox_override("normal", UIKit.raised(fill, edge))
		card.tooltip_text = TowerRules.display_name(entries[key]) + link

func _select_tower(key: String) -> void:
	selected_key = key
	rank = 1
	if not cards.has(key):
		element = ""
		filter_changed.emit(element)
		_render_filters()
		_render_gallery()
	else:
		_update_card_styles()
	_render_detail()

func _requirements(tower: Dictionary) -> String:
	var tier: int = 3 if tower.kind == "ascended" else 1
	var missing := PackedStringArray()
	for ingredient: String in TowerRules.ingredients(tower):
		if int(sim.state.tiers[ingredient]) < tier:
			missing.append(ingredient.capitalize())
	return ", ".join(missing)

func _render_detail() -> void:
	UIKit.clear(details)
	detail_scroll.scroll_vertical = 0
	purchase = null
	var tower: Dictionary = entries[selected_key].duplicate()
	tower.level = rank
	var header: HBoxContainer = UIKit.row(5)
	details.add_child(header)
	header.add_child(UIKit.portrait(tower, 56))
	var names: VBoxContainer = UIKit.column(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(names)
	names.add_child(UIKit.label(TowerRules.display_name(tower), 23, UIKit.INK, true))
	names.add_child(UIKit.composition(tower, 19))
	var missing: String = _requirements(tower)
	if not missing.is_empty():
		details.add_child(UIKit.label("Requires " + missing + (" Tier III" if tower.kind == "ascended" else " Tier I"), 15, UIKit.WARN, true))
	var profile: Dictionary = TowerRules.attack_profile(tower, sim.spirit_victories())
	var role: String = TowerRules.stats(tower).get("role", DataDB.read("elements").get(tower.element, {}).get("role", ""))
	if not role.is_empty():
		details.add_child(UIKit.label(role, 15, UIKit.MUTED, true))
	var levels: int = TowerRules.progression(tower).damage.size()
	if levels > 1:
		var ranks: HBoxContainer = UIKit.row(4)
		details.add_child(ranks)
		for level: int in range(1, levels + 1):
			var button: Button = UIKit.button(str(level), _set_rank.bind(level), level == rank, 37)
			button.add_theme_font_size_override("font_size", 15)
			var requirement: String = TowerRules.rank_requirement(tower, level, sim.state.tiers)
			button.tooltip_text = "Tower level %d" % level if requirement.is_empty() else requirement
			ranks.add_child(button)
		var rank_requirement: String = TowerRules.rank_requirement(tower, rank, sim.state.tiers)
		if rank > 1 and not rank_requirement.is_empty():
			details.add_child(UIKit.label(rank_requirement, 15, UIKit.WARN, true))
	details.add_child(UIKit.label(TowerInspector.metrics(tower, sim.spirit_victories()), 16, UIKit.INK, true))
	var all_tiers: Dictionary = sim.state.tiers.duplicate()
	for id: String in DataDB.ELEMENTS:
		all_tiers[id] = 3
	if float(profile.rate) > 0.0:
		var traits: Dictionary = TowerRules.trait_profile(tower, all_tiers)
		details.add_child(UIKit.label(TowerInspector.damage_type(tower, traits), 15, UIKit.MINT, true))
		var matchup: HFlowContainer = HFlowContainer.new()
		details.add_child(matchup)
		_add_matchups(matchup, TowerRules.damage_split(tower), traits.has("adaptive"))
	for effect: Dictionary in TowerInspector.effect_entries(tower, all_tiers):
		var line: Label = UIKit.label(effect.detail, 15, effect.tint, true)
		details.add_child(line)
	if not TowerRules.is_fusion(tower) and missing.is_empty():
		build_kind = tower.element if tower.kind in ["pure", "ascended"] else tower.kind
		build_pure = tower.kind == "ascended"
		var cost: int = int(sim.cfg.pure_tower_cost) if build_pure else int(TowerRules.stats(tower).cost)
		purchase = UIKit.button(("Place Pure tower · %d g" if build_pure else "Place level-1 tower · %d g") % cost, _request_build, true, 45)
		purchase.tooltip_text = "Choose a build tile on the battlefield."
		details.add_child(purchase)
		refresh_purchase()
	var sources: PackedStringArray = _source_keys(tower)
	var required: int = int(sim.cfg.fuse_min_level)
	var recipe_hint: String = "Add a level-%d element to a level-%d dual" % [required, required] if tower.kind == "triple" else "Built from level-%d towers" % required
	_link_row(recipe_hint, sources)
	_link_row("Fuses into", _fusion_results(tower))

func _set_rank(level: int) -> void:
	rank = level
	_render_detail()

func _source_keys(tower: Dictionary) -> PackedStringArray:
	var ingredients: PackedStringArray = TowerRules.ingredients(tower)
	if tower.kind == "dual":
		return ingredients
	var pairs := PackedStringArray()
	if tower.kind == "triple":
		for i: int in range(ingredients.size()):
			for j: int in range(i + 1, ingredients.size()):
				pairs.append(TowerRules.recipe(ingredients[i], ingredients[j]))
	return pairs

func _fusion_results(tower: Dictionary) -> PackedStringArray:
	var results := PackedStringArray()
	if not TowerRules.can_fuse(tower):
		return results
	var ingredients: PackedStringArray = TowerRules.ingredients(tower)
	var kind: String = "dual" if tower.kind == "pure" else "triple"
	for key: String in entries:
		var result: Dictionary = entries[key]
		if result.kind != kind:
			continue
		var recipe: PackedStringArray = TowerRules.ingredients(result)
		var includes_all: bool = true
		for id: String in ingredients:
			includes_all = includes_all and recipe.has(id)
		if includes_all:
			results.append(key)
	return results

func _link_row(title: String, keys: PackedStringArray) -> void:
	if keys.is_empty():
		return
	details.add_child(UIKit.label(title, 15, UIKit.MINT, true))
	var links := HFlowContainer.new()
	details.add_child(links)
	for key: String in keys:
		var button: Button = UIKit.button(TowerRules.display_name(entries[key]), _select_tower.bind(key), false, 38)
		button.add_theme_font_size_override("font_size", 15)
		button.size_flags_horizontal = Control.SIZE_FILL
		links.add_child(button)

func refresh_purchase() -> void:
	if not is_instance_valid(purchase):
		return
	var cost: int = int(sim.cfg.pure_tower_cost) if build_pure else int(DataDB.read("towers")[build_kind].cost)
	purchase.disabled = int(sim.state.gold) < cost or (build_pure and sim.pure_count() >= int(sim.cfg.pure_tower_limit))
	purchase.tooltip_text = "Requires %d gold." % cost if int(sim.state.gold) < cost else "Choose a build tile on the battlefield."
	if build_pure and sim.pure_count() >= int(sim.cfg.pure_tower_limit):
		purchase.tooltip_text = "All Pure slots are in use."

func refresh_unlocks() -> void:
	if last_unlocks == sim.state.tiers:
		return
	last_unlocks = sim.state.tiers.duplicate()
	_render_filters()
	_render_gallery()
	_render_detail()

func _request_build() -> void:
	build_requested.emit(build_kind, build_pure)

