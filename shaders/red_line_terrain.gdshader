shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Camera-relative 64-bit floating origin uniforms (32-bit GPU-safe offsets from R = 16,000,000.0m)
uniform vec3 camera_relative_chunk_offset = vec3(0.0);
uniform vec3 u_chunk_camera_offset = vec3(0.0);
uniform vec3 u_camera_planet_up = vec3(0.0, 1.0, 0.0);
uniform float u_planet_radius = 16000000.0;

// Macro-Geographic & Biome Weights
uniform float u_red_line_mask : hint_range(0.0, 1.0) = 0.0;
uniform float u_altitude_m = 0.0;
uniform float u_biome_sand : hint_range(0.0, 1.0) = 0.0;
uniform float u_biome_jungle : hint_range(0.0, 1.0) = 0.35;
uniform float u_biome_snow : hint_range(0.0, 1.0) = 0.0;
uniform float u_biome_volcanic : hint_range(0.0, 1.0) = 0.0;
uniform float u_biome_totto_candy : hint_range(0.0, 1.0) = 0.0;
uniform float u_biome_wano_ink : hint_range(0.0, 1.0) = 0.0;

// Canonical Palette Colors
uniform vec4 u_red_line_crimson_rock : source_color = vec4(0.56, 0.16, 0.11, 1.0);
uniform vec4 u_red_line_ochre_strata : source_color = vec4(0.72, 0.32, 0.18, 1.0);
uniform vec4 u_red_line_summit_grass : source_color = vec4(0.28, 0.44, 0.22, 1.0);
uniform vec4 u_alabasta_sand : source_color = vec4(0.86, 0.72, 0.45, 1.0);
uniform vec4 u_little_garden_jungle : source_color = vec4(0.14, 0.38, 0.16, 1.0);
uniform vec4 u_drum_snow : source_color = vec4(0.92, 0.95, 0.98, 1.0);
uniform vec4 u_volcanic_basalt : source_color = vec4(0.16, 0.13, 0.14, 1.0);
uniform vec4 u_totto_confection : source_color = vec4(0.88, 0.56, 0.68, 1.0);
uniform vec4 u_wano_ink_slate : source_color = vec4(0.18, 0.21, 0.24, 1.0);

varying vec3 v_rel_pos;
varying vec3 v_local_normal;
varying float v_local_alt_m;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	vec3 chunk_offset = camera_relative_chunk_offset + u_chunk_camera_offset;
	vec3 local_pos = VERTEX + chunk_offset;

	// Planetary spherical curvature drop relative to camera tangent horizon
	vec3 up_dir = normalize(u_camera_planet_up);
	vec3 horiz = local_pos - up_dir * dot(local_pos, up_dir);
	float horiz_dist_sq = dot(horiz, horiz);
	float curvature_drop = horiz_dist_sq / (2.0 * max(u_planet_radius, 1000.0));

	VERTEX = local_pos - up_dir * curvature_drop;
	v_rel_pos = local_pos;
	v_local_normal = normalize(NORMAL);
	v_local_alt_m = u_altitude_m + dot(local_pos, up_dir);
}

void fragment() {
	vec3 up_dir = normalize(u_camera_planet_up);
	float slope = 1.0 - clamp(abs(dot(normalize(v_local_normal), up_dir)), 0.0, 1.0);

	// Procedural geological noise & sedimentary strata bands (for +10,000m Red Line cliffs)
	float rock_noise = value_noise(v_rel_pos.xz * 0.025) * 0.6 + value_noise(v_rel_pos.xz * 0.11) * 0.4;
	float strata_band = sin(v_local_alt_m * 0.045 + rock_noise * 4.2) * 0.5 + 0.5;

	// Red Line sheer crimson sedimentary cliff blend (+10,000m plateau)
	vec3 rl_rock = mix(u_red_line_crimson_rock.rgb, u_red_line_ochre_strata.rgb, strata_band);
	float plateau_top = smoothstep(9600.0, 10000.0, v_local_alt_m) * (1.0 - smoothstep(0.15, 0.45, slope));
	vec3 red_line_col = mix(rl_rock, u_red_line_summit_grass.rgb, plateau_top * 0.75);

	// Island biome blend (Alabasta sand, Little Garden/Zou jungle, Drum/Ringo snow, Punk Hazard volcanic, Totto Land, Wano)
	vec3 biome_col = u_little_garden_jungle.rgb;
	biome_col = mix(biome_col, u_alabasta_sand.rgb, u_biome_sand);
	biome_col = mix(biome_col, u_little_garden_jungle.rgb, u_biome_jungle);
	biome_col = mix(biome_col, u_drum_snow.rgb, u_biome_snow);
	biome_col = mix(biome_col, u_volcanic_basalt.rgb, u_biome_volcanic);
	biome_col = mix(biome_col, u_totto_confection.rgb, u_biome_totto_candy);

	// Wano sumi-e ink-wash cliff edge darkening
	float ink_rim = smoothstep(0.45, 0.85, slope) * u_biome_wano_ink;
	biome_col = mix(biome_col, u_wano_ink_slate.rgb * 0.4, ink_rim);

	// High-altitude snow cap above +4,500m (Drum Rockies / Wano peaks / Elbaf)
	float alt_snow = smoothstep(4200.0, 5200.0, v_local_alt_m) * (1.0 - u_red_line_mask) * (1.0 - slope * 0.7);
	biome_col = mix(biome_col, u_drum_snow.rgb, alt_snow);

	// Exposed cliff faces on islands show layered sedimentary rock
	vec3 cliff_tint = mix(biome_col, rl_rock * 0.85, smoothstep(0.35, 0.75, slope) * 0.6);

	vec3 final_col = mix(cliff_tint, red_line_col, u_red_line_mask);
	final_col *= (0.85 + 0.3 * rock_noise);

	ALBEDO = final_col;
	ROUGHNESS = mix(0.86, 0.42, u_biome_snow * (1.0 - slope));
	METALLIC = 0.02;
}
