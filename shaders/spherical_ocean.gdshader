shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Camera-relative 64-bit floating origin uniforms (32-bit GPU-safe offsets from R = 16,000,000.0m)
uniform vec3 camera_relative_chunk_offset = vec3(0.0);
uniform vec3 u_chunk_camera_offset = vec3(0.0);
uniform vec3 u_camera_planet_up = vec3(0.0, 1.0, 0.0);
uniform float u_planet_radius = 16000000.0;
uniform float u_time = 0.0;

// Maritime & Atmospheric Zone Parameters
uniform float u_calm_belt_factor : hint_range(0.0, 1.0) = 0.0;
uniform float u_storm_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float u_sky_sea_blend : hint_range(0.0, 1.0) = 0.0;
uniform float u_abyss_depth_factor : hint_range(0.0, 1.0) = 0.0;
uniform float u_knock_up_vortex : hint_range(0.0, 1.0) = 0.0;

// Visual Palette Uniforms
uniform vec4 u_deep_blue_color : source_color = vec4(0.015, 0.085, 0.22, 1.0);
uniform vec4 u_shallow_turquoise_color : source_color = vec4(0.06, 0.38, 0.52, 1.0);
uniform vec4 u_calm_belt_color : source_color = vec4(0.03, 0.24, 0.26, 1.0);
uniform vec4 u_storm_crest_color : source_color = vec4(0.14, 0.24, 0.34, 1.0);
uniform vec4 u_foam_color : source_color = vec4(0.88, 0.94, 0.98, 1.0);
uniform vec4 u_sky_cloud_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 u_sky_cloud_shadow : source_color = vec4(0.68, 0.78, 0.92, 1.0);
uniform vec4 u_abyss_eve_glow : source_color = vec4(0.12, 0.65, 0.72, 1.0);

varying vec3 v_world_rel_pos;
varying float v_wave_height;
varying float v_foam_factor;

float gerstner_wave(vec2 pos, vec2 dir, float steepness, float wavelength, float speed, float time_val) {
	float k = 6.28318530718 / max(wavelength, 0.5);
	float c = sqrt(9.81 / k) * speed;
	vec2 d = normalize(dir);
	float f = k * (dot(d, pos) - c * time_val);
	return steepness * sin(f);
}

void vertex() {
	// Combine both camera-relative offset aliases for full compatibility with PlanetSphere & GrandLineSimulator
	vec3 chunk_offset = camera_relative_chunk_offset + u_chunk_camera_offset;
	vec3 local_pos = VERTEX + chunk_offset;

	// Apply planetary spherical curvature drop relative to tangent horizon: drop = d^2 / (2 * R)
	vec3 up_dir = normalize(u_camera_planet_up);
	vec3 horiz = local_pos - up_dir * dot(local_pos, up_dir);
	float horiz_dist_sq = dot(horiz, horiz);
	float curvature_drop = horiz_dist_sq / (2.0 * max(u_planet_radius, 1000.0));

	// Coordinate proxy on local tangent plane for seamless 64-bit-safe wave phase
	vec2 wave_uv = local_pos.xz * 0.045;
	float calm_damp = clamp(1.0 - u_calm_belt_factor, 0.0, 1.0);
	float amp_scale = mix(0.65, 3.8, u_storm_intensity) * calm_damp;

	// Blue Sea swells (zeroed to mirror-still water inside Calm Belts)
	float w1 = gerstner_wave(wave_uv, vec2(1.0, 0.35), 0.55 * amp_scale, 38.0, 1.0, u_time);
	float w2 = gerstner_wave(wave_uv, vec2(-0.6, 0.8), 0.35 * amp_scale, 21.0, 1.25, u_time);
	float w3 = gerstner_wave(wave_uv, vec2(0.25, -0.95), 0.22 * amp_scale, 11.0, 1.5, u_time);
	float sea_wave = w1 + w2 + w3;

	// +7,000m / +10,000m White-White Sea Pyrobloin cloud-ocean billowing
	float cloud_billow = (
		sin(wave_uv.x * 0.35 + u_time * 0.4) * cos(wave_uv.y * 0.35 - u_time * 0.3) * 2.6
		+ sin((wave_uv.x + wave_uv.y) * 0.8 + u_time * 0.7) * 0.9
	) * u_sky_sea_blend;

	// Knock Up Stream geothermal vortex depression & central surge
	float radial_dist = length(horiz);
	float vortex_funnel = 0.0;
	if (u_knock_up_vortex > 0.01) {
		float funnel_mask = exp(-radial_dist * 0.00018);
		float swirl = sin(atan(horiz.z, horiz.x) * 6.0 - u_time * 4.5) * 2.5;
		vortex_funnel = (funnel_mask * 18.0 + swirl * funnel_mask) * u_knock_up_vortex;
	}

	float total_disp = mix(sea_wave, cloud_billow, u_sky_sea_blend) + vortex_funnel;
	VERTEX = local_pos + up_dir * (total_disp - curvature_drop);

	v_world_rel_pos = VERTEX;
	v_wave_height = total_disp;
	v_foam_factor = clamp((sea_wave / max(amp_scale * 0.95, 0.1)) * u_storm_intensity, 0.0, 1.0);
}

void fragment() {
	vec3 view_dir = normalize(VIEW);
	vec3 norm = normalize(NORMAL);
	float fresnel = pow(1.0 - clamp(dot(norm, view_dir), 0.0, 1.0), 4.0);

	// Procedural fine ripple normal perturbation (suppressed in Calm Belt for mirror-still glass water)
	float calm_damp = 1.0 - u_calm_belt_factor;
	vec2 ripple_uv = v_world_rel_pos.xz * 0.32;
	float r_x = sin(ripple_uv.x * 2.3 + u_time * 1.9) * cos(ripple_uv.y * 1.7 - u_time * 1.4);
	float r_z = cos(ripple_uv.x * 1.9 - u_time * 1.6) * sin(ripple_uv.y * 2.5 + u_time * 2.1);
	vec3 ripple_normal = normalize(vec3(r_x * 0.14 * calm_damp, 1.0, r_z * 0.14 * calm_damp));
	NORMAL_MAP = ripple_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.65 * calm_damp, 0.18, u_sky_sea_blend);

	// Base Blue Sea -> Storm -> Calm Belt color blending
	vec3 sea_base = mix(u_deep_blue_color.rgb, u_shallow_turquoise_color.rgb, clamp(v_wave_height * 0.12 + 0.25, 0.0, 1.0));
	sea_base = mix(sea_base, u_storm_crest_color.rgb, u_storm_intensity * 0.55);
	sea_base = mix(sea_base, u_calm_belt_color.rgb, u_calm_belt_factor * 0.85);

	// Foam whitecaps on Grand Line storms & Knock Up Stream vortex
	float foam_mask = smoothstep(0.55, 0.92, v_foam_factor + u_knock_up_vortex * 0.45) * calm_damp;
	sea_base = mix(sea_base, u_foam_color.rgb, foam_mask);

	// White-White Sea Pyrobloin cloud ocean appearance (+7km/+10km)
	float cloud_shade = clamp(v_wave_height * 0.2 + 0.5, 0.0, 1.0);
	vec3 cloud_col = mix(u_sky_cloud_shadow.rgb, u_sky_cloud_color.rgb, cloud_shade);

	// Abyssal -10,000m Sunlight Tree Eve glow
	vec3 final_albedo = mix(sea_base, cloud_col, u_sky_sea_blend);
	final_albedo = mix(final_albedo, u_abyss_eve_glow.rgb * 0.55, u_abyss_depth_factor * 0.65);

	ALBEDO = mix(final_albedo, vec3(0.75, 0.88, 0.98), fresnel * 0.45 * (1.0 - u_sky_sea_blend));
	ROUGHNESS = mix(mix(0.14, 0.02, u_calm_belt_factor), 0.88, u_sky_sea_blend);
	METALLIC = mix(0.08, 0.0, u_sky_sea_blend);
	SPECULAR = mix(0.75, 0.15, u_sky_sea_blend);
	EMISSION = u_abyss_eve_glow.rgb * (u_abyss_depth_factor * 0.38) + u_foam_color.rgb * (u_knock_up_vortex * 0.12);
}
