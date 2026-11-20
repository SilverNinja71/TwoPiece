shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_never;

// Rayleigh & Mie Planetary Atmosphere + Horizon Haze Shader
// Project "Blue Planet" — Transitions smoothly across:
//   - Sea Level (0m): Tropical Azure Sky & Warm Mie Sun Scattering
//   - Sky Seas (+7,000m / +10,000m): High-Altitude Cobalt & Radiant White-White Sea Haze
//   - Orbital Space (> +25,000m): Deep Orbital Space Void with Thin Horizon Limb Glow
//   - The Abyss (-200m to -10,000m): Pelagic Trench Indigo & Sunlight Tree Eve Teal

uniform vec3 u_sun_direction = vec3(0.45, 0.65, -0.60);
uniform vec3 u_planet_up = vec3(0.0, 1.0, 0.0);
uniform float u_altitude_m = 0.0;
uniform float u_storm_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float u_abyss_depth : hint_range(0.0, 1.0) = 0.0;

uniform vec4 u_zenith_color : source_color = vec4(0.11, 0.42, 0.88, 1.0);
uniform vec4 u_horizon_color : source_color = vec4(0.62, 0.84, 0.98, 1.0);
uniform vec4 u_sunset_mie_color : source_color = vec4(1.0, 0.88, 0.68, 1.0);
uniform vec4 u_storm_sky_color : source_color = vec4(0.18, 0.22, 0.30, 1.0);
uniform vec4 u_space_color : source_color = vec4(0.01, 0.02, 0.05, 1.0);
uniform vec4 u_abyss_color : source_color = vec4(0.02, 0.14, 0.24, 1.0);
uniform vec4 u_eve_biolum_color : source_color = vec4(0.12, 0.62, 0.68, 1.0);

varying vec3 v_world_dir;

void vertex() {
	v_world_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}

void fragment() {
	vec3 dir = normalize(v_world_dir);
	vec3 up = normalize(u_planet_up);
	vec3 sun = normalize(u_sun_direction);

	float elev_cos = clamp(dot(dir, up), -1.0, 1.0);
	float horizon_band = pow(1.0 - abs(elev_cos), 3.6);
	float upper_hemisphere = smoothstep(-0.08, 0.45, elev_cos);

	// Rayleigh scattering zenith -> horizon gradient
	vec3 rayleigh = mix(u_horizon_color.rgb, u_zenith_color.rgb, clamp(elev_cos * 1.15, 0.0, 1.0));

	// Mie forward sun scattering & solar disc
	float sun_dot = max(dot(dir, sun), 0.0);
	float mie_halo = pow(sun_dot, 10.0) * 0.42 + pow(sun_dot, 220.0) * 1.45;
	vec3 sky_col = rayleigh + u_sunset_mie_color.rgb * mie_halo * (0.4 + 0.6 * horizon_band);

	// High-altitude Sky Sea (+7,000m / +10,000m) thinning & orbital space (> +25,000m)
	float sky_sea_factor = smoothstep(5500.0, 11000.0, u_altitude_m);
	sky_col = mix(sky_col, mix(vec3(0.78, 0.90, 1.0), vec3(0.06, 0.22, 0.62), upper_hemisphere), sky_sea_factor * 0.45);

	float space_factor = smoothstep(14000.0, 45000.0, u_altitude_m);
	vec3 space_blend = mix(u_space_color.rgb, u_horizon_color.rgb * 0.75, horizon_band * 0.85);
	sky_col = mix(sky_col, space_blend, space_factor);

	// Grand Line Storm darkening
	sky_col = mix(sky_col, u_storm_sky_color.rgb, u_storm_intensity * 0.72 * (1.0 - space_factor * 0.5));

	// Abyssal -10,000m Fish-Man Island / Bathypelagic Trench atmosphere
	vec3 abyss_grad = mix(u_abyss_color.rgb, u_eve_biolum_color.rgb, horizon_band * 0.5 + pow(max(elev_cos, 0.0), 2.0) * 0.35);
	sky_col = mix(sky_col, abyss_grad, u_abyss_depth);

	// Crisp horizon glow band
	sky_col += u_horizon_color.rgb * (horizon_band * 0.14 * (1.0 - u_storm_intensity) * (1.0 - u_abyss_depth));

	ALBEDO = sky_col;
	ALPHA = 1.0;
}
