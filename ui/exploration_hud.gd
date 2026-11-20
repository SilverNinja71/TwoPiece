class_name ExplorationHUD
extends CanvasLayer
## Procedural Exploration HUD for Project "Blue Planet"
## Self-contained UI builder constructing all Control nodes in `_ready()` (zero external .tres dependencies).
##
## Features:
## - Single-Needle / Triple-Needle Log Pose, Eternal Pose & Vivre Card Compass Widget
##   (live telemetry from `WorldRegistry.compute_navigation_reading()`).
## - Toggleable 2D/Spherical Nami Cartography Sextant Map Overlay displaying discovered 2x2 deg
##   sectors, Red Line / Grand Line bands, discovered islands, and 4 Road Poneglyph triangulation arcs.
## - Multi-Currency Wallet HUD (`Beli`, `Extol`, `Gor`, `WanoSilverRyo`, `WanoGoldRyo`, `WanoPlatinumRyo`).
## - Interactive Shop Transaction Drawer & Branching NPC Dialogue Panel.

signal shop_item_purchased(island_id: String, shop_name: String, item_id: String, price: int, currency: String)
signal dialogue_choice_selected(npc_id: String, choice_id: String)
signal navigation_mode_changed(new_mode: int)

# ==============================================================================
# 1. EMBEDDED CUSTOM CANVAS: NAMI CARTOGRAPHY & PONEGLYPH TRIANGULATION MAP
# ==============================================================================
class NamiCartographyCanvas extends Control:
	var tracked_lat_deg: float = 24.0
	var tracked_lon_deg: float = 42.0

	func _draw() -> void:
		var rect_size: Vector2 = size
		if rect_size.x < 10.0 or rect_size.y < 10.0:
			return

		# 1. Uncharted Ocean Background
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.04, 0.11, 0.22, 0.96), true)

		# 2. Latitude / Longitude Grid (every 30 deg)
		var grid_color := Color(0.25, 0.45, 0.65, 0.25)
		for lon_step in range(-180, 181, 30):
			var gx: float = ((float(lon_step) + 180.0) / 360.0) * rect_size.x
			draw_line(Vector2(gx, 0.0), Vector2(gx, rect_size.y), grid_color, 1.0)
		for lat_step in range(-90, 91, 30):
			var gy: float = ((90.0 - float(lat_step)) / 180.0) * rect_size.y
			draw_line(Vector2(0.0, gy), Vector2(rect_size.x, gy), grid_color, 1.0)

		# 3. Grand Line (-45 deg) & Red Line (+45 deg) Great Circle Curves
		_draw_great_circle_band(rect_size, -45.0, Color(0.20, 0.65, 0.90, 0.35), 14.0)
		_draw_great_circle_band(rect_size, 45.0, Color(0.76, 0.22, 0.18, 0.65), 8.0)

		# 4. Discovered 2x2 Degree Cartography Sectors (Fog-of-War Clearings)
		var registry: Node = get_node_or_null("/root/WorldRegistry")
		if registry != null:
			var sectors: Variant = registry.get("revealed_map_sectors")
			if sectors is Dictionary:
				var cell_w: float = maxf(2.0, rect_size.x / 180.0)
				var cell_h: float = maxf(2.0, rect_size.y / 90.0)
				for sector_key in sectors.keys():
					var parts: PackedStringArray = str(sector_key).split("_")
					if parts.size() == 2:
						var lat_deg: float = float(parts[0]) * 2.0
						var lon_deg: float = float(parts[1]) * 2.0
						var px: float = ((lon_deg + 180.0) / 360.0) * rect_size.x
						var py: float = ((90.0 - lat_deg) / 180.0) * rect_size.y
						draw_rect(
							Rect2(px - cell_w * 0.5, py - cell_h * 0.5, cell_w, cell_h),
							Color(0.32, 0.78, 0.62, 0.32),
							true
						)

			# 5. Discovered Islands & Poneglyph Triangulation Lines
			var islands: Variant = registry.get("islands_by_id")
			var discovered: Variant = registry.get("discovered_island_ids")
			if islands is Dictionary:
				for iid in islands.keys():
					var irec: Dictionary = islands[iid]
					var is_disc: bool = (discovered is Dictionary and discovered.has(iid))
					var p: Vector2 = _lat_lon_to_px(float(irec.get("lat_deg", 0.0)), float(irec.get("lon_deg", 0.0)), rect_size)
					var dot_col: Color = Color(0.98, 0.85, 0.32, 0.95) if is_disc else Color(0.55, 0.65, 0.75, 0.25)
					draw_circle(p, 3.5 if is_disc else 1.8, dot_col)

			# 6. Road Poneglyph Geodesic Intersection Lines -> Laugh Tale
			var deciphered: Variant = registry.get("deciphered_poneglyph_ids")
			var poneglyph_db: Variant = registry.get("poneglyph_database")
			if deciphered is Dictionary and poneglyph_db is Dictionary:
				var rp_ids: Array[String] = [
					"road_poneglyph_1_zou",
					"road_poneglyph_2_whole_cake",
					"road_poneglyph_3_wano",
					"road_poneglyph_4_elbaf"
				]
				var bearings: Array[Vector2] = []
				for rpid in rp_ids:
					if deciphered.has(rpid) and poneglyph_db.has(rpid):
						var rprec: Dictionary = poneglyph_db[rpid]
						var bp: Vector2 = _lat_lon_to_px(
							float(rprec.get("encrypted_bearing_lat_deg", 0.0)),
							float(rprec.get("encrypted_bearing_lon_deg", 0.0)),
							rect_size
						)
						bearings.append(bp)
						draw_circle(bp, 5.0, Color(0.95, 0.2, 0.25, 0.95))

				if bearings.size() >= 2:
					draw_line(bearings[0], bearings[1], Color(1.0, 0.3, 0.3, 0.85), 2.0)
				if bearings.size() >= 4:
					draw_line(bearings[2], bearings[3], Color(1.0, 0.3, 0.3, 0.85), 2.0)

			if bool(registry.get("laugh_tale_unlocked")):
				var lt: Variant = registry.get("laugh_tale_coordinates")
				if lt is Dictionary and lt.has("lat_deg"):
					var lt_px: Vector2 = _lat_lon_to_px(float(lt["lat_deg"]), float(lt["lon_deg"]), rect_size)
					draw_circle(lt_px, 7.5, Color(1.0, 0.9, 0.15, 1.0))
					draw_arc(lt_px, 12.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.2, 0.9), 2.0)

		# 7. Player / Ship Current Coordinate Marker
		var player_px: Vector2 = _lat_lon_to_px(tracked_lat_deg, tracked_lon_deg, rect_size)
		draw_circle(player_px, 5.5, Color(0.2, 1.0, 0.45, 1.0))
		draw_arc(player_px, 9.0, 0.0, TAU, 20, Color.WHITE, 1.5)

	func _draw_great_circle_band(rect_size: Vector2, tilt_deg: float, color: Color, width_px: float) -> void:
		var prev_pt := Vector2.ZERO
		var has_prev: bool = false
		var tilt_rad: float = deg_to_rad(tilt_deg)
		for lon_i in range(-180, 181, 6):
			var lon_rad: float = deg_to_rad(float(lon_i))
			var lat_rad: float = atan(tan(tilt_rad) * sin(lon_rad))
			var pt: Vector2 = _lat_lon_to_px(rad_to_deg(lat_rad), float(lon_i), rect_size)
			if has_prev and absf(pt.x - prev_pt.x) < rect_size.x * 0.5:
				draw_line(prev_pt, pt, color, width_px)
			prev_pt = pt
			has_prev = true

	func _lat_lon_to_px(lat_deg: float, lon_deg: float, rect_size: Vector2) -> Vector2:
		var x: float = ((wrapf(lon_deg, -180.0, 180.0) + 180.0) / 360.0) * rect_size.x
		var y: float = ((90.0 - clampf(lat_deg, -90.0, 90.0)) / 180.0) * rect_size.y
		return Vector2(x, y)

# ==============================================================================
# 2. HUD NODE REFERENCES & STATE
# ==============================================================================
var _root_margin: MarginContainer = null
var _compass_label: Label = null
var _compass_details_label: Label = null
var _wallet_label: Label = null
var _telemetry_label: Label = null
var _bounty_label: Label = null

var _cartography_panel: PanelContainer = null
var _nami_canvas: NamiCartographyCanvas = null
var _cartography_stats_label: Label = null

var _shop_panel: PanelContainer = null
var _shop_title_label: Label = null
var _shop_items_box: VBoxContainer = null
var _shop_feedback_label: Label = null

var _dialogue_panel: PanelContainer = null
var _dialogue_speaker_label: Label = null
var _dialogue_body_label: Label = null
var _dialogue_choices_box: VBoxContainer = null

var _tracked_actor: Node3D = null
var _active_shop_island_id: String = ""
var _active_shop_name: String = ""
var _active_dialogue_npc_id: String = ""
var _hud_refresh_accum_sec: float = 0.0

# ==============================================================================
# 3. LIFECYCLE & PROCEDURAL UI CONSTRUCTION
# ==============================================================================
func _ready() -> void:
	layer = 10
	_build_procedural_hud()
	_connect_registry_signals()
	_refresh_wallet_and_campaign_hud()
	_refresh_shop_for_current_island()

func _process(delta: float) -> void:
	_hud_refresh_accum_sec += delta
	if _hud_refresh_accum_sec >= 0.2:
		_hud_refresh_accum_sec = 0.0
		_update_live_navigation_and_telemetry()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("survey_sextant"):
		_on_sextant_survey_pressed()

func _build_procedural_hud() -> void:
	var root_ctrl := Control.new()
	root_ctrl.name = "HUDRoot"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	_root_margin = MarginContainer.new()
	_root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_margin.add_theme_constant_override("margin_left", 16)
	_root_margin.add_theme_constant_override("margin_right", 16)
	_root_margin.add_theme_constant_override("margin_top", 14)
	_root_margin.add_theme_constant_override("margin_bottom", 14)
	_root_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_root_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_margin.add_child(main_vbox)

	# --- TOP BAR: COMPASS WIDGET (LEFT) + WALLET & TELEMETRY (RIGHT) ---
	var top_hbox := HBoxContainer.new()
	top_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_hbox)

	# Top-Left: Log Pose / Vivre Card Compass Panel
	var compass_panel := _create_styled_panel(Color(0.06, 0.10, 0.17, 0.86))
	compass_panel.custom_minimum_size = Vector2(410.0, 128.0)
	top_hbox.add_child(compass_panel)

	var compass_vbox := VBoxContainer.new()
	compass_panel.add_child(compass_vbox)

	_compass_label = Label.new()
	_compass_label.text = "LOG POSE: Calibrating..."
	_compass_label.add_theme_font_size_override("font_size", 16)
	compass_vbox.add_child(_compass_label)

	_compass_details_label = Label.new()
	_compass_details_label.text = "Needle Bearing: -- | Distance: -- km"
	_compass_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compass_vbox.add_child(_compass_details_label)

	var nav_btn_row := HBoxContainer.new()
	compass_vbox.add_child(nav_btn_row)
	var nav_modes: Array[Array] = [
		["Compass", 0],
		["1-Log", 1],
		["3-Log", 2],
		["Eternal", 3],
		["Vivre", 4]
	]
	for mode_pair in nav_modes:
		var btn := Button.new()
		btn.text = str(mode_pair[0])
		var mode_idx: int = int(mode_pair[1])
		btn.pressed.connect(_on_nav_mode_button_pressed.bind(mode_idx))
		nav_btn_row.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_child(spacer)

	# Top-Right: Multi-Currency Wallet + Spherical Geodesy Telemetry
	var wallet_panel := _create_styled_panel(Color(0.06, 0.10, 0.17, 0.86))
	wallet_panel.custom_minimum_size = Vector2(460.0, 128.0)
	top_hbox.add_child(wallet_panel)

	var wallet_vbox := VBoxContainer.new()
	wallet_panel.add_child(wallet_vbox)

	_bounty_label = Label.new()
	_bounty_label.text = "Bounty: 0 Beli | Uncharted Rookie"
	_bounty_label.add_theme_font_size_override("font_size", 15)
	wallet_vbox.add_child(_bounty_label)

	_wallet_label = Label.new()
	_wallet_label.text = "Beli: 5,000 | Extol: 0 | Gor: 0 | Wano Ryo (Ag/Au/Pt): 0/0/0"
	_wallet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wallet_vbox.add_child(_wallet_label)

	_telemetry_label = Label.new()
	_telemetry_label.text = "Lat: 24.00° | Lon: 42.00° | Alt: 0.0 m | East Blue"
	wallet_vbox.add_child(_telemetry_label)

	var action_btn_row := HBoxContainer.new()
	wallet_vbox.add_child(action_btn_row)

	var map_btn := Button.new()
	map_btn.text = "Nami World Chart [M]"
	map_btn.pressed.connect(toggle_cartography_overlay)
	action_btn_row.add_child(map_btn)

	var shop_btn := Button.new()
	shop_btn.text = "Island Market"
	shop_btn.pressed.connect(toggle_shop_drawer)
	action_btn_row.add_child(shop_btn)

	# --- MIDDLE SECTION: NAMI CARTOGRAPHY OVERLAY & SHOP DRAWER ---
	var mid_hbox := HBoxContainer.new()
	mid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(mid_hbox)

	# Shop Drawer (Bottom-Left / Side)
	_shop_panel = _create_styled_panel(Color(0.07, 0.09, 0.14, 0.92))
	_shop_panel.custom_minimum_size = Vector2(390.0, 320.0)
	_shop_panel.visible = false
	mid_hbox.add_child(_shop_panel)

	var shop_vbox := VBoxContainer.new()
	_shop_panel.add_child(shop_vbox)

	_shop_title_label = Label.new()
	_shop_title_label.text = "Harbor Marketplace"
	_shop_title_label.add_theme_font_size_override("font_size", 16)
	shop_vbox.add_child(_shop_title_label)

	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_vbox.add_child(shop_scroll)

	_shop_items_box = VBoxContainer.new()
	_shop_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_scroll.add_child(_shop_items_box)

	_shop_feedback_label = Label.new()
	_shop_feedback_label.text = "Select an item to purchase."
	shop_vbox.add_child(_shop_feedback_label)

	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_hbox.add_child(mid_spacer)

	# Nami Cartography Sextant Map Overlay (Center-Right)
	_cartography_panel = _create_styled_panel(Color(0.05, 0.08, 0.13, 0.94))
	_cartography_panel.custom_minimum_size = Vector2(540.0, 320.0)
	_cartography_panel.visible = false
	mid_hbox.add_child(_cartography_panel)

	var map_vbox := VBoxContainer.new()
	_cartography_panel.add_child(map_vbox)

	var map_header := HBoxContainer.new()
	map_vbox.add_child(map_header)
	var map_title := Label.new()
	map_title.text = "Nami-Style Spherical Cartography (R = 16,000,000 m)"
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_header.add_child(map_title)

	var survey_btn := Button.new()
	survey_btn.text = "Sextant Survey"
	survey_btn.pressed.connect(_on_sextant_survey_pressed)
	map_header.add_child(survey_btn)

	_nami_canvas = NamiCartographyCanvas.new()
	_nami_canvas.custom_minimum_size = Vector2(510.0, 240.0)
	_nami_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_vbox.add_child(_nami_canvas)

	_cartography_stats_label = Label.new()
	_cartography_stats_label.text = "Sectors Revealed: 0 / 16,200 | Road Poneglyphs: 0 / 4"
	map_vbox.add_child(_cartography_stats_label)

	# --- BOTTOM CENTER: NPC DIALOGUE PANEL ---
	_dialogue_panel = _create_styled_panel(Color(0.05, 0.07, 0.12, 0.94))
	_dialogue_panel.custom_minimum_size = Vector2(760.0, 160.0)
	_dialogue_panel.visible = false
	main_vbox.add_child(_dialogue_panel)

	var dlg_vbox := VBoxContainer.new()
	_dialogue_panel.add_child(dlg_vbox)

	var dlg_header := HBoxContainer.new()
	dlg_vbox.add_child(dlg_header)

	_dialogue_speaker_label = Label.new()
	_dialogue_speaker_label.text = "Speaker"
	_dialogue_speaker_label.add_theme_font_size_override("font_size", 16)
	_dialogue_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlg_header.add_child(_dialogue_speaker_label)

	var dlg_close_btn := Button.new()
	dlg_close_btn.text = "Close"
	dlg_close_btn.pressed.connect(close_dialogue_panel)
	dlg_header.add_child(dlg_close_btn)

	_dialogue_body_label = Label.new()
	_dialogue_body_label.text = ""
	_dialogue_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_vbox.add_child(_dialogue_body_label)

	_dialogue_choices_box = VBoxContainer.new()
	dlg_vbox.add_child(_dialogue_choices_box)

func _create_styled_panel(bg_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.75, 0.62, 0.30, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel

# ==============================================================================
# 4. LIVE TELEMETRY, LOG POSE COMPASS & MULTI-CURRENCY UPDATES
# ==============================================================================
func _connect_registry_signals() -> void:
	var registry: Node = get_node_or_null("/root/WorldRegistry")
	if registry != null:
		if registry.has_signal("currency_balance_changed"):
			registry.connect("currency_balance_changed", func(_c: String, _b: int) -> void: _refresh_wallet_and_campaign_hud())
		if registry.has_signal("map_sector_revealed"):
			registry.connect("map_sector_revealed", func(_s: String, _n: int) -> void: _refresh_cartography_stats())
		if registry.has_signal("poneglyph_deciphered"):
			registry.connect("poneglyph_deciphered", func(_p: String, _cat: String, _r: int) -> void: _refresh_cartography_stats())

	var scm: Node = get_node_or_null("/root/StoryCampaignManager")
	if scm != null and scm.has_signal("bounty_updated"):
		scm.connect("bounty_updated", func(_b: int, _e: String) -> void: _refresh_wallet_and_campaign_hud())

func _resolve_tracked_actor() -> Node3D:
	if is_instance_valid(_tracked_actor):
		return _tracked_actor
	var parent_node: Node = get_parent()
	if parent_node != null:
		var player := parent_node.get_node_or_null("SphericalPlayer") as Node3D
		if player != null:
			_tracked_actor = player
			return _tracked_actor
		var ship := parent_node.get_node_or_null("BuoyantShipVessel") as Node3D
		if ship != null:
			_tracked_actor = ship
			return _tracked_actor
	return null

func _update_live_navigation_and_telemetry() -> void:
	var actor: Node3D = _resolve_tracked_actor()
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var raw_pos: Vector3 = actor.global_position if actor != null else Vector3.ZERO
	var world_pos: Vector3 = raw_pos
	var coords: Dictionary
	if fo != null and raw_pos.length() < 1_000_000.0:
		coords = fo.call("local32_to_lat_lon_alt", raw_pos)
		world_pos = fo.call("local32_to_world_vec3", raw_pos)
	else:
		if actor == null:
			world_pos = PlanetSphere.lat_lon_alt_to_world(52.0, 74.0, 0.0)
		coords = PlanetSphere.world_to_lat_lon_alt(world_pos)

	if _nami_canvas != null:
		_nami_canvas.tracked_lat_deg = float(coords["lat_deg"])
		_nami_canvas.tracked_lon_deg = float(coords["lon_deg"])
		if _cartography_panel != null and _cartography_panel.visible:
			_nami_canvas.queue_redraw()

	var zone_name: String = "Open Ocean"
	var parent_node: Node = get_parent()
	var planet: Node = parent_node.get_node_or_null("PlanetSphere") if parent_node != null else null
	if planet != null and planet.has_method("classify_global_coordinates"):
		var zinfo: Dictionary = planet.call("classify_global_coordinates", world_pos)
		zone_name = "%s | %s" % [str(zinfo.get("region_name", "")), str(zinfo.get("vertical_layer_name", ""))]

	if _telemetry_label != null:
		_telemetry_label.text = "Lat: %.2f° | Lon: %.2f° | Alt: %.1f m | %s" % [
			float(coords["lat_deg"]),
			float(coords["lon_deg"]),
			float(coords["alt_m"]),
			zone_name
		]

	var registry: Node = get_node_or_null("/root/WorldRegistry")
	if registry != null and registry.has_method("compute_navigation_reading"):
		var nav: Dictionary = registry.call("compute_navigation_reading", world_pos)
		_render_navigation_reading(nav)

func _render_navigation_reading(nav: Dictionary) -> void:
	if _compass_label == null or _compass_details_label == null:
		return
	var mode_str: String = str(nav.get("mode", "UNKNOWN"))
	_compass_label.text = "NAVIGATION: %s" % mode_str

	match mode_str:
		"STANDARD_COMPASS":
			_compass_details_label.text = "Status: %s" % str(nav.get("status", "OK"))
		"SINGLE_LOG_POSE":
			_compass_details_label.text = "Target: %s (%.1f km) | Charge: %d%%" % [
				str(nav.get("target_name", "")),
				float(nav.get("distance_km", 0.0)),
				int(round(float(nav.get("charge_progress", 0.0)) * 100.0))
			]
		"TRIPLE_LOG_POSE":
			var lines: PackedStringArray = []
			for needle in nav.get("needles", []):
				lines.append("N%d -> %s (%.0f km | Jitter %.1f° [%s])" % [
					int(needle.get("needle_index", 1)),
					str(needle.get("target_island_id", "")),
					float(needle.get("distance_km", 0.0)),
					float(needle.get("danger_jitter_amplitude_deg", 0.0)),
					str(needle.get("stability_rating", ""))
				])
			_compass_details_label.text = "\n".join(lines)
		"ETERNAL_POSE":
			_compass_details_label.text = "Locked Forever -> %s (%.1f km)" % [
				str(nav.get("target_name", "")),
				float(nav.get("distance_km", 0.0))
			]
		"VIVRE_CARD":
			_compass_details_label.text = "Vivre Card -> %s (%.1f km | Vitality: %d%%)" % [
				str(nav.get("owner_name", "")),
				float(nav.get("distance_km", 0.0)),
				int(round(float(nav.get("life_force_ratio", 1.0)) * 100.0))
			]

func _refresh_wallet_and_campaign_hud() -> void:
	var registry: Node = get_node_or_null("/root/WorldRegistry")
	if registry != null and _wallet_label != null:
		var w: Variant = registry.get("wallet")
		if w is Dictionary:
			_wallet_label.text = "Beli: %d | Extol: %d | Gor: %d | Ryo (Ag/Au/Pt): %d/%d/%d" % [
				int(w.get("Beli", 0)),
				int(w.get("Extol", 0)),
				int(w.get("Gor", 0)),
				int(w.get("WanoSilverRyo", 0)),
				int(w.get("WanoGoldRyo", 0)),
				int(w.get("WanoPlatinumRyo", 0))
			]

	var scm: Node = get_node_or_null("/root/StoryCampaignManager")
	if scm != null and _bounty_label != null:
		_bounty_label.text = "Bounty: %d Beli | %s" % [
			int(scm.get("player_bounty_beli")),
			str(scm.get("player_epithet"))
		]

func _refresh_cartography_stats() -> void:
	var registry: Node = get_node_or_null("/root/WorldRegistry")
	if registry == null or _cartography_stats_label == null:
		return
	var sectors: Variant = registry.get("revealed_map_sectors")
	var sector_count: int = sectors.size() if sectors is Dictionary else 0
	var road_count: int = int(registry.call("get_deciphered_road_poneglyph_count")) if registry.has_method("get_deciphered_road_poneglyph_count") else 0
	_cartography_stats_label.text = "Sectors Revealed: %d / 16,200 (%.2f%%) | Road Poneglyphs: %d / 4" % [
		sector_count,
		(float(sector_count) / 16200.0) * 100.0,
		road_count
	]
	if _nami_canvas != null:
		_nami_canvas.queue_redraw()

# ==============================================================================
# 5. INTERACTIVE CONTROLS: COMPASS MODES, SEXTANT, SHOP DRAWER & NPC DIALOGUE
# ==============================================================================
func _on_nav_mode_button_pressed(mode_idx: int) -> void:
	var registry: Node = get_node_or_null("/root/WorldRegistry")
	if registry != null:
		registry.set("active_nav_mode", mode_idx)
		if mode_idx == 4 and str(registry.get("active_vivre_card_id")).is_empty():
			registry.set("active_vivre_card_id", "zunesha_zou")
		if mode_idx == 3 and str(registry.get("equipped_eternal_pose_island_id")).is_empty():
			registry.call("acquire_and_equip_eternal_pose", "alabasta")
	navigation_mode_changed.emit(mode_idx)
	_update_live_navigation_and_telemetry()

func toggle_cartography_overlay() -> void:
	if _cartography_panel != null:
		_cartography_panel.visible = not _cartography_panel.visible
		if _cartography_panel.visible:
			_refresh_cartography_stats()

func toggle_shop_drawer() -> void:
	if _shop_panel != null:
		_shop_panel.visible = not _shop_panel.visible
		if _shop_panel.visible:
			_refresh_shop_for_current_island()

func _on_sextant_survey_pressed() -> void:
	var actor: Node3D = _resolve_tracked_actor()
	if actor != null and actor.has_method("use_surveying_sextant"):
		actor.call("use_surveying_sextant")
	else:
		var registry: Node = get_node_or_null("/root/WorldRegistry")
		if registry != null and registry.has_method("record_sextant_survey"):
			registry.call("record_sextant_survey", 24.0, 42.0, 28.0, 30_000.0)
	_refresh_cartography_stats()

func _refresh_shop_for_current_island() -> void:
	if _shop_items_box == null:
		return
	for child in _shop_items_box.get_children():
		child.queue_free()

	var registry: Node = get_node_or_null("/root/WorldRegistry")
	var island_id: String = "dawn_island"
	var items: Array[Dictionary] = [
		{"id": "foosha_spiced_ale", "name": "Foosha Spiced Ale", "price": 250, "currency": "Beli"},
		{"id": "sextant_brass_kit", "name": "Navigator's Brass Sextant", "price": 1_200, "currency": "Beli"},
		{"id": "log_pose_case", "name": "Grand Line Log Pose Case", "price": 3_500, "currency": "Beli"}
	]
	if registry != null:
		var docked_id: String = str(registry.get("current_docked_island_id"))
		if not docked_id.is_empty():
			island_id = docked_id
		var islands_dict: Variant = registry.get("islands_by_id")
		if islands_dict is Dictionary and islands_dict.has(island_id):
			var rec: Dictionary = islands_dict[island_id]
			_active_shop_island_id = island_id
			var shops_arr: Variant = rec.get("shops", [])
			if shops_arr is Array and not shops_arr.is_empty():
				var first_shop: Variant = shops_arr[0]
				_active_shop_name = str(first_shop.get("name", "Port Market")) if first_shop is Dictionary else str(first_shop)
				if first_shop is Dictionary and first_shop.has("inventory"):
					items.clear()
					for inv in first_shop["inventory"]:
						if inv is Dictionary:
							items.append({
								"id": str(inv.get("item_id", inv.get("name", "item"))),
								"name": str(inv.get("name", inv.get("item", "Goods"))),
								"price": int(inv.get("price_beli", inv.get("price", 100))),
								"currency": str(inv.get("currency", rec.get("currency", "Beli")))
							})

	if _shop_title_label != null:
		_shop_title_label.text = "%s (%s)" % [_active_shop_name if not _active_shop_name.is_empty() else "Partys Bar", island_id]

	for entry in items:
		var row_btn := Button.new()
		var item_name: String = str(entry["name"])
		var price: int = int(entry["price"])
		var curr: String = str(entry["currency"])
		row_btn.text = "Buy %s — %d %s" % [item_name, price, curr]
		row_btn.pressed.connect(_on_buy_shop_item_pressed.bind(str(entry["id"]), item_name, price, curr))
		_shop_items_box.add_child(row_btn)

func _on_buy_shop_item_pressed(item_id: String, item_name: String, price: int, currency: String) -> void:
	var registry: Node = get_node_or_null("/root/WorldRegistry")
	var purchased: bool = false
	if registry != null and registry.has_method("spend_currency"):
		purchased = bool(registry.call("spend_currency", currency, price))
	if purchased:
		_shop_feedback_label.text = "Purchased %s for %d %s!" % [item_name, price, currency]
		shop_item_purchased.emit(_active_shop_island_id, _active_shop_name, item_id, price, currency)
	else:
		_shop_feedback_label.text = "Insufficient %s for %s (%d needed)." % [currency, item_name, price]
	_refresh_wallet_and_campaign_hud()

## Opens the NPC Dialogue Panel with speaker title, dialogue body, and branching choices.
func open_dialogue_session(npc_id: String, speaker_name: String, body_text: String, choices: Array[Dictionary] = []) -> void:
	_active_dialogue_npc_id = npc_id
	if _dialogue_speaker_label != null:
		_dialogue_speaker_label.text = speaker_name
	if _dialogue_body_label != null:
		_dialogue_body_label.text = body_text
	if _dialogue_choices_box != null:
		for child in _dialogue_choices_box.get_children():
			child.queue_free()
		for ch in choices:
			var btn := Button.new()
			btn.text = str(ch.get("label", "Continue"))
			var ch_id: String = str(ch.get("id", "continue"))
			btn.pressed.connect(_on_dialogue_choice_pressed.bind(ch_id))
			_dialogue_choices_box.add_child(btn)
	if _dialogue_panel != null:
		_dialogue_panel.visible = true

func _on_dialogue_choice_pressed(choice_id: String) -> void:
	dialogue_choice_selected.emit(_active_dialogue_npc_id, choice_id)

func close_dialogue_panel() -> void:
	if _dialogue_panel != null:
		_dialogue_panel.visible = false
