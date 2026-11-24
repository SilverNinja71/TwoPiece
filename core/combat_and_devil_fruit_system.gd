class_name CombatAndDevilFruitSystem
extends Node
## Action-RPG Combat, 3-Branch Haki & Devil Fruit System for Project "Blue Planet"
## Integrated with `SphericalPlayer`, `StoryCampaignManager`, `WorldRegistry`, and `ProceduralAudioManager`.
##
## Features:
## - 3-Branch Haki: Observation (`Mantra` dodge window & aura reveal), Armament (`Ryuo` multiplier + Logia hit),
##   and Conqueror (`Haoshoku` AoE willpower shockwave stun & Infusion).
## - Devil Fruit Registry & Active Skills: `gomu_gomu`, `mera_mera`, `ope_ope`, `gura_gura`, `pika_pika`
##   (eating a fruit permanently toggles `SphericalPlayer.devil_fruit_user` / `has_devil_fruit = true`).
## - Damage, Logia intangibility, Seastone bypass, and Bounty resolution API.

signal devil_fruit_eaten(fruit_id: String, fruit_data: Dictionary)
signal ability_triggered(ability_id: String, origin_pos: Vector3, power: float, metadata: Dictionary)
signal damage_resolved(target_name: String, raw_damage: float, final_damage: float, was_dodged: bool, logia_blocked: bool)
signal haki_pulse_emitted(haki_branch: String, tier: int, radius_m: float)
signal bounty_defeat_registered(enemy_name: String, new_bounty_beli: int, beli_loot: int)

# ==============================================================================
# 1. CANONICAL DEVIL FRUIT ENCYCLOPEDIA
# ==============================================================================
const DEVIL_FRUITS: Dictionary = {
	"gomu_gomu": {
		"id": "gomu_gomu",
		"name": "Gomu Gomu no Mi (Hito Hito no Mi, Model: Nika)",
		"category": "Paramecia / Mythical Zoan",
		"is_logia": false,
		"blunt_resistance": 0.65,
		"lightning_immune": true,
		"abilities": {
			"pistol_dash": {"name": "Gomu Gomu no Pistol / Rocket Dash", "cooldown_sec": 2.5, "base_damage": 65.0, "dash_speed_ms": 28.0},
			"gatling_barrage": {"name": "Gomu Gomu no Jet Gatling", "cooldown_sec": 6.0, "base_damage": 140.0, "radius_m": 10.0}
		}
	},
	"mera_mera": {
		"id": "mera_mera",
		"name": "Mera Mera no Mi (Flame-Flame Fruit)",
		"category": "Logia",
		"is_logia": true,
		"blunt_resistance": 0.0,
		"lightning_immune": false,
		"abilities": {
			"hiken_wave": {"name": "Hiken (Fire Fist Flame Wave)", "cooldown_sec": 4.0, "base_damage": 125.0, "radius_m": 22.0},
			"entei_nova": {"name": "Dai Enkai: Entei", "cooldown_sec": 12.0, "base_damage": 260.0, "radius_m": 40.0}
		}
	},
	"ope_ope": {
		"id": "ope_ope",
		"name": "Ope Ope no Mi (Op-Op Fruit)",
		"category": "Paramecia",
		"is_logia": false,
		"blunt_resistance": 0.0,
		"lightning_immune": false,
		"abilities": {
			"room_dome": {"name": "ROOM (Spatial Operating Dome)", "cooldown_sec": 8.0, "base_damage": 0.0, "radius_m": 38.0},
			"shambles_swap": {"name": "Shambles (Spatial Swap) & Gamma Knife", "cooldown_sec": 5.0, "base_damage": 150.0, "radius_m": 38.0}
		}
	},
	"gura_gura": {
		"id": "gura_gura",
		"name": "Gura Gura no Mi (Tremor-Tremor Fruit)",
		"category": "Paramecia",
		"is_logia": false,
		"blunt_resistance": 0.0,
		"lightning_immune": false,
		"abilities": {
			"kaishin_seaquake": {"name": "Kaishin (Seaquake Shockwave)", "cooldown_sec": 7.5, "base_damage": 210.0, "radius_m": 60.0},
			"kabutowari_crush": {"name": "Quake Bubble Strike", "cooldown_sec": 4.0, "base_damage": 145.0, "radius_m": 16.0}
		}
	},
	"pika_pika": {
		"id": "pika_pika",
		"name": "Pika Pika no Mi (Glint-Glint Fruit)",
		"category": "Logia",
		"is_logia": true,
		"blunt_resistance": 0.0,
		"lightning_immune": false,
		"abilities": {
			"light_blink": {"name": "Yata no Kagami (Light-Speed Blink)", "cooldown_sec": 3.0, "base_damage": 85.0, "blink_distance_m": 75.0},
			"yasakani_jewel": {"name": "Yasakani no Magatama", "cooldown_sec": 9.0, "base_damage": 195.0, "radius_m": 32.0}
		}
	}
}

# ==============================================================================
# 2. RUNTIME COMBAT, HAKI & COOLDOWN STATE
# ==============================================================================
@export var base_player_hp: float = 500.0
var current_player_hp: float = 500.0
var equipped_devil_fruit_id: String = ""
var player_is_logia: bool = false

## 3-Branch Haki Live State
var observation_active: bool = false
var observation_dodge_window_sec: float = 0.0
var armament_active: bool = false
var conqueror_cooldown_sec: float = 0.0
var ope_room_active_sec: float = 0.0
var ope_room_center_local: Vector3 = Vector3.ZERO
var ope_room_radius_m: float = 38.0

var _ability_cooldowns: Dictionary = {}
var _defeated_bounty_targets: Dictionary = {}

func _ready() -> void:
	name = "CombatAndDevilFruitSystem"
	var player: Node = _get_player()
	if player != null and player.has_signal("haki_state_changed"):
		player.connect("haki_state_changed", _on_player_haki_state_changed)

func _physics_process(delta: float) -> void:
	if observation_dodge_window_sec > 0.0:
		observation_dodge_window_sec = maxf(0.0, observation_dodge_window_sec - delta)
	if conqueror_cooldown_sec > 0.0:
		conqueror_cooldown_sec = maxf(0.0, conqueror_cooldown_sec - delta)
	if ope_room_active_sec > 0.0:
		ope_room_active_sec = maxf(0.0, ope_room_active_sec - delta)

	for ab_id in _ability_cooldowns.keys():
		var rem: float = float(_ability_cooldowns[ab_id]) - delta
		if rem <= 0.0:
			_ability_cooldowns.erase(ab_id)
		else:
			_ability_cooldowns[ab_id] = rem

func _get_player() -> Node3D:
	var p := get_parent()
	if p != null:
		return p.get_node_or_null("SphericalPlayer") as Node3D
	return null

func _get_audio_manager() -> Node:
	var p := get_parent()
	if p != null:
		return p.get_node_or_null("ProceduralAudioManager")
	return null

func _get_haki_tiers() -> Dictionary:
	var scm: Node = get_node_or_null("/root/StoryCampaignManager")
	if scm != null:
		var prog: Variant = scm.get("haki_progression")
		if prog is Dictionary:
			return prog
	return {"observation_tier": 1, "armament_tier": 1, "conqueror_tier": 1}

func _on_player_haki_state_changed(obs: bool, arm: bool, _conq: bool) -> void:
	observation_active = obs
	armament_active = arm
	if obs:
		activate_observation_haki()

# ==============================================================================
# 3. THREE-BRANCH HAKI MECHANICS (OBSERVATION, ARMAMENT, CONQUEROR)
# ==============================================================================
func activate_observation_haki() -> Dictionary:
	observation_active = true
	var tiers: Dictionary = _get_haki_tiers()
	var obs_tier: int = maxi(1, int(tiers.get("observation_tier", 1)))
	observation_dodge_window_sec = 3.5 + float(obs_tier) * 1.5
	var aura_range_m: float = 80.0 + float(obs_tier) * 45.0
	var auras: Array[Dictionary] = reveal_enemy_auras(aura_range_m)

	var audio: Node = _get_audio_manager()
	if audio != null and audio.has_method("play_haki_pulse"):
		audio.call("play_haki_pulse")
	haki_pulse_emitted.emit("observation", obs_tier, aura_range_m)
	return {
		"tier": obs_tier,
		"future_sight": obs_tier >= 3,
		"dodge_window_sec": observation_dodge_window_sec,
		"revealed_auras": auras
	}

func reveal_enemy_auras(scan_radius_m: float = 150.0) -> Array[Dictionary]:
	var auras: Array[Dictionary] = []
	var player: Node3D = _get_player()
	if player == null:
		return auras
	var tree: SceneTree = get_tree()
	if tree == null:
		return auras
	for enemy_node in tree.get_nodes_in_group("blue_planet_enemies"):
		if enemy_node is Node3D:
			var dist_m: float = player.global_position.distance_to((enemy_node as Node3D).global_position)
			if dist_m <= scan_radius_m:
				auras.append({
					"name": enemy_node.name,
					"distance_m": dist_m,
					"position": (enemy_node as Node3D).global_position
				})
	return auras

func toggle_armament_haki(force_state: int = -1) -> bool:
	if force_state == 0:
		armament_active = false
	elif force_state == 1:
		armament_active = true
	else:
		armament_active = not armament_active

	var player: Node = _get_player()
	if player != null:
		player.set("armament_haki_active", armament_active)
	if armament_active:
		var tiers: Dictionary = _get_haki_tiers()
		haki_pulse_emitted.emit("armament", maxi(1, int(tiers.get("armament_tier", 1))), 4.0)
	return armament_active

func get_armament_damage_multiplier() -> float:
	if not armament_active:
		return 1.0
	var tiers: Dictionary = _get_haki_tiers()
	var arm_tier: int = maxi(1, int(tiers.get("armament_tier", 1)))
	# Tier 1: 1.45x (Invisible Armor), Tier 2: 1.9x (Koka Hardening), Tier 3: 2.75x (Internal Destruction Ryuo)
	match arm_tier:
		1:
			return 1.45
		2:
			return 1.90
		_:
			return 2.75

func trigger_conqueror_burst(origin_pos: Vector3 = Vector3.ZERO, radius_m: float = 50.0) -> Dictionary:
	if conqueror_cooldown_sec > 0.0:
		return {"success": false, "reason": "Haoshoku recharging", "cooldown_sec": conqueror_cooldown_sec}

	var player: Node3D = _get_player()
	var center: Vector3 = origin_pos if origin_pos.length_squared() > 0.01 else (player.global_position if player != null else Vector3.ZERO)
	var tiers: Dictionary = _get_haki_tiers()
	var conq_tier: int = maxi(1, int(tiers.get("conqueror_tier", 1)))
	conqueror_cooldown_sec = 10.0

	var stun_duration_sec: float = 3.0 + float(conq_tier) * 2.0
	var infusion_damage: float = 160.0 if conq_tier >= 3 else 45.0
	var stunned_count: int = 0

	var tree: SceneTree = get_tree()
	if tree != null:
		for enemy_node in tree.get_nodes_in_group("blue_planet_enemies"):
			if enemy_node is Node3D and center.distance_to((enemy_node as Node3D).global_position) <= radius_m:
				stunned_count += 1
				if enemy_node.has_method("apply_stun"):
					enemy_node.call("apply_stun", stun_duration_sec)
				if infusion_damage > 0.0 and enemy_node.has_method("take_combat_damage"):
					enemy_node.call("take_combat_damage", infusion_damage, "CONQUEROR_INFUSION")

	var audio: Node = _get_audio_manager()
	if audio != null and audio.has_method("play_haki_pulse"):
		audio.call("play_haki_pulse")

	haki_pulse_emitted.emit("conqueror", conq_tier, radius_m)
	ability_triggered.emit("haoshoku_burst", center, infusion_damage, {"stunned_count": stunned_count, "tier": conq_tier})
	return {
		"success": true,
		"tier": conq_tier,
		"radius_m": radius_m,
		"stun_duration_sec": stun_duration_sec,
		"stunned_count": stunned_count
	}

# ==============================================================================
# 4. DEVIL FRUIT CONSUMPTION & ACTIVE SKILLS
# ==============================================================================
func eat_devil_fruit(fruit_id: String) -> Dictionary:
	if not DEVIL_FRUITS.has(fruit_id):
		return {"success": false, "reason": "Unknown Devil Fruit ID: " + fruit_id}
	if not equipped_devil_fruit_id.is_empty():
		return {
			"success": false,
			"reason": "Already consumed %s! Eating a second Devil Fruit destroys the body." % equipped_devil_fruit_id
		}

	var fruit_data: Dictionary = DEVIL_FRUITS[fruit_id]
	equipped_devil_fruit_id = fruit_id
	player_is_logia = bool(fruit_data.get("is_logia", false))

	var player: Node = _get_player()
	if player != null:
		player.set("devil_fruit_user", true)
		player.set("has_devil_fruit", true)

	devil_fruit_eaten.emit(fruit_id, fruit_data)
	return {
		"success": true,
		"fruit_id": fruit_id,
		"fruit_name": fruit_data["name"],
		"is_logia": player_is_logia,
		"ocean_penalty_active": true
	}

func trigger_ability(ability_id: String, target_pos: Vector3 = Vector3.ZERO, target_node: Node3D = null) -> Dictionary:
	if ability_id == "haoshoku_burst":
		return trigger_conqueror_burst(target_pos)

	if _ability_cooldowns.has(ability_id):
		return {"success": false, "reason": "Ability on cooldown", "remaining_sec": float(_ability_cooldowns[ability_id])}

	if equipped_devil_fruit_id.is_empty():
		return {"success": false, "reason": "No Devil Fruit consumed"}

	var fruit: Dictionary = DEVIL_FRUITS.get(equipped_devil_fruit_id, {})
	var abilities: Dictionary = fruit.get("abilities", {})
	if not abilities.has(ability_id):
		return {"success": false, "reason": "Ability '%s' not granted by %s" % [ability_id, equipped_devil_fruit_id]}

	var spec: Dictionary = abilities[ability_id]
	_ability_cooldowns[ability_id] = float(spec.get("cooldown_sec", 4.0))
	var base_dmg: float = float(spec.get("base_damage", 50.0)) * get_armament_damage_multiplier()
	var player: Node3D = _get_player()
	var origin: Vector3 = player.global_position if player != null else Vector3.ZERO
	var meta: Dictionary = {"fruit_id": equipped_devil_fruit_id}

	match ability_id:
		"pistol_dash":
			if player != null and player is CharacterBody3D:
				var fwd: Vector3 = -player.global_transform.basis.z.normalized()
				(player as CharacterBody3D).velocity += fwd * float(spec.get("dash_speed_ms", 28.0))
		"room_dome":
			ope_room_center_local = origin
			ope_room_radius_m = float(spec.get("radius_m", 38.0))
			ope_room_active_sec = 20.0
			meta["room_radius_m"] = ope_room_radius_m
		"shambles_swap":
			if ope_room_active_sec <= 0.0:
				return {"success": false, "reason": "Cast ROOM first before Shambles"}
			if player != null and is_instance_valid(target_node):
				var old_p: Vector3 = player.global_position
				player.global_position = target_node.global_position
				target_node.global_position = old_p
				meta["swapped_with"] = target_node.name
			elif player != null and target_pos.length_squared() > 0.01:
				if origin.distance_to(target_pos) <= ope_room_radius_m:
					player.global_position = target_pos
		"light_blink":
			if player != null:
				var blink_dir: Vector3 = (target_pos - origin).normalized() if target_pos.length_squared() > 0.01 else -player.global_transform.basis.z.normalized()
				var blink_dist: float = float(spec.get("blink_distance_m", 75.0))
				player.global_position = origin + blink_dir * blink_dist
		"kaishin_seaquake":
			var audio: Node = _get_audio_manager()
			if audio != null and audio.has_method("play_coup_de_burst_boom"):
				audio.call("play_coup_de_burst_boom")

	if is_instance_valid(target_node) and base_dmg > 0.0:
		apply_damage(target_node, base_dmg, "DEVIL_FRUIT", false, armament_active)

	ability_triggered.emit(ability_id, origin, base_dmg, meta)
	return {
		"success": true,
		"ability_id": ability_id,
		"effective_damage": base_dmg,
		"metadata": meta
	}

# ==============================================================================
# 5. DAMAGE, LOGIA INTANGIBILITY & BOUNTY RESOLUTION API
# ==============================================================================
func apply_damage(
	target: Variant,
	raw_damage: float,
	damage_type: String = "PHYSICAL",
	target_is_logia: bool = false,
	attacker_uses_armament: bool = false
) -> Dictionary:
	var target_name: String = str(target.name) if target is Node else str(target)
	var player: Node = _get_player()
	var is_player_target: bool = (player != null and target == player)

	# 1. Observation Haki Mantra Dodge Check (Player defending)
	if is_player_target and observation_dodge_window_sec > 0.0:
		var obs_tier: int = maxi(1, int(_get_haki_tiers().get("observation_tier", 1)))
		var dodge_prob: float = 0.85 if obs_tier >= 3 else 0.55
		if randf() < dodge_prob:
			damage_resolved.emit(target_name, raw_damage, 0.0, true, false)
			return {"final_damage": 0.0, "dodged": true, "logia_blocked": false}

	# 2. Logia Intangibility Check (Bypassed by Armament Haki, Seastone, or Water)
	var effective_is_logia: bool = target_is_logia or (is_player_target and player_is_logia)
	var bypass_logia: bool = attacker_uses_armament or damage_type in ["SEASTONE", "WATER", "CONQUEROR_INFUSION"]
	if effective_is_logia and not bypass_logia:
		damage_resolved.emit(target_name, raw_damage, 0.0, false, true)
		return {"final_damage": 0.0, "dodged": false, "logia_blocked": true}

	# 3. Compute Final Multiplier (Armament / Gomu blunt resist)
	var final_damage: float = raw_damage
	if not is_player_target and armament_active and attacker_uses_armament:
		final_damage *= get_armament_damage_multiplier()
	if is_player_target and equipped_devil_fruit_id == "gomu_gomu" and damage_type == "BLUNT":
		final_damage *= 0.35

	if is_player_target:
		current_player_hp = maxf(0.0, current_player_hp - final_damage)
	elif target is Node and target.has_method("take_combat_damage"):
		target.call("take_combat_damage", final_damage, damage_type)
	elif target is Dictionary and target.has("hp"):
		target["hp"] = maxf(0.0, float(target["hp"]) - final_damage)

	damage_resolved.emit(target_name, raw_damage, final_damage, false, false)
	return {
		"final_damage": final_damage,
		"dodged": false,
		"logia_blocked": false,
		"player_hp_remaining": current_player_hp
	}

func register_defeat_bounty(enemy_name: String, bounty_reward_beli: int, beli_loot: int = 0) -> Dictionary:
	_defeated_bounty_targets[enemy_name] = int(_defeated_bounty_targets.get(enemy_name, 0)) + 1

	var registry: Node = get_node_or_null("/root/WorldRegistry")
	if registry != null and beli_loot > 0 and registry.has_method("add_currency"):
		registry.call("add_currency", "Beli", beli_loot)

	var scm: Node = get_node_or_null("/root/StoryCampaignManager")
	var updated_bounty: int = bounty_reward_beli
	if scm != null:
		var current_bounty: int = int(scm.get("player_bounty_beli"))
		updated_bounty = maxi(current_bounty, current_bounty + bounty_reward_beli)
		scm.set("player_bounty_beli", updated_bounty)
		if scm.has_method("_refresh_epithet_from_bounty"):
			scm.call("_refresh_epithet_from_bounty")
		if scm.has_signal("bounty_updated"):
			scm.emit_signal("bounty_updated", updated_bounty, str(scm.get("player_epithet")))

	var audio: Node = _get_audio_manager()
	if audio != null and audio.has_method("play_beli_chime"):
		audio.call("play_beli_chime")

	bounty_defeat_registered.emit(enemy_name, updated_bounty, beli_loot)
	return {
		"enemy_name": enemy_name,
		"bounty_increase": bounty_reward_beli,
		"new_player_bounty_beli": updated_bounty,
		"beli_loot": beli_loot
	}
