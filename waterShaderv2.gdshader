shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// -----------------------------------------------------------------------------
// Base Colors
// -----------------------------------------------------------------------------
/**
 * The base water color used as the primary tint of the water surface.
 */
uniform vec3 water_color  : source_color = vec3(0.0, 0.3, 0.5);

/**
 * The valley color used for slope-based blending, representing lower or recessed areas.
 */
uniform vec3 valley_color : source_color = vec3(0.0, 0.2, 0.4);

/**
 * The peak color used for slope-based blending, representing elevated or convex areas.
 */
uniform vec3 peak_color   : source_color = vec3(0.0, 0.4, 0.7);

// -----------------------------------------------------------------------------
// Foam Parameters (NEW: Separate noise texture)
// -----------------------------------------------------------------------------
/**
 * Threshold for foam appearance on wave crests. Typical values range from 0.7 to 0.95.
 */
uniform float foam_peak_threshold = 0.85;

/**
 * Threshold for foam appearance in wave valleys.
 */
uniform float foam_valley_threshold = 0.15;

/**
 * The color of the foam that appears on the water surface.
 */
uniform vec3 foam_color : source_color = vec3(0.95, 0.95, 0.9);

/**
 * A separate noise texture used to generate dynamic foam patterns.
 */
uniform sampler2D foam_noise_texture;

/**
 * The depth range over which foam blending is applied based on vertical distance.
 */
uniform float foam_depth_range = 0.15;

/**
 * The starting slope value for foam application, defining where foam begins to appear.
 */
uniform float foam_slope_start = 0.3;

/**
 * The ending slope value for foam application, defining where foam influence saturates.
 */
uniform float foam_slope_end = 0.6;

/**
 * Scales the UV coordinates for the foam noise texture, affecting foam detail density.
 */
uniform float foam_noise_scale = 8.0;

/**
 * Controls the animation speed of the foam noise texture.
 */
uniform float foam_speed = 0.15;

// -----------------------------------------------------------------------------
// Glow/Emission Settings
// -----------------------------------------------------------------------------
/**
 * The glow color used for the water's emission effect.
 */
uniform vec3 glow_color  : source_color = vec3(0.0, 0.5, 1.0);

/**
 * Scales the intensity of the water's emission effect.
 */
uniform float emission_strength = 1.5;

/**
 * Adjusts the influence of environmental lighting on the emission effect.
 */
uniform float env_light_factor  = 1.0;

// -----------------------------------------------------------------------------
// Slope Factor
// -----------------------------------------------------------------------------
/**
 * Multiplier applied to slope calculations, enhancing visual contrast in water shading.
 */
uniform float slope_factor = 10.0;

// -----------------------------------------------------------------------------
// Wave Parameters
// -----------------------------------------------------------------------------
/**
 * The amplitude of the water waves, controlling their vertical displacement.
 */
uniform float wave_amplitude = 0.09;

/**
 * Frequency of the primary wave component, influencing the repetition of wave patterns.
 */
uniform float wave_frequency1 = 2.415;

/**
 * Frequency of the secondary wave component, adding variation to the wave pattern.
 */
uniform float wave_frequency2 = 2.975;

/**
 * Speed at which the primary wave component propagates over the water surface.
 */
uniform float wave_speed1 = 1.0;

/**
 * Speed at which the secondary wave component propagates over the water surface.
 */
uniform float wave_speed2 = 1.2;

/**
 * Direction vector for the primary wave component.
 */
uniform vec2 wave_dir1 = vec2(1.0, -1.0);

/**
 * Direction vector for the secondary wave component.
 */
uniform vec2 wave_dir2 = vec2(-1.0, -1.0);

// -----------------------------------------------------------------------------
// Domain Warp (Original Noise)
// -----------------------------------------------------------------------------
/**
 * Noise texture used to create a domain warp effect, adding detail and variation to the wave pattern.
 */
uniform sampler2D wave_noise_texture;

/**
 * Speed at which the noise texture animates, affecting the dynamic nature of the domain warp.
 */
uniform float noise_speed = 0.01;

/**
 * Scale factor for the noise texture coordinates in the domain warp calculation.
 */
uniform float noise_scale = 2.0;

/**
 * The amplitude of the domain warp effect, controlling the strength of the wave distortion.
 */
uniform float warp_amplitude = 0.065;

/**
 * Frequency used in the domain warp calculations, determining the detail of the warp.
 */
uniform float warp_frequency = 0.655;

/**
 * Toggles the domain warp effect on or off.
 */
uniform bool use_domain_warp = true;

// -----------------------------------------------------------------------------
// Coordinate System
// -----------------------------------------------------------------------------
/**
 * Determines whether UV coordinates or world-space coordinates are used for wave calculations.
 */
uniform bool use_uv_for_waves = true;

/**
 * Defines the width of the water surface when using world-space coordinates.
 */
uniform float water_width = 5.0;

// -----------------------------------------------------------------------------
// Depth Blending
// -----------------------------------------------------------------------------
/**
 * Color used to represent deep water, blended into the final water color.
 */
uniform vec4 color_deep : source_color;

/**
 * Color used to represent shallow water, blended into the final water color.
 */
uniform vec4 color_shallow : source_color;

/**
 * The distance over which depth blending transitions between shallow and deep water colors.
 */
uniform float depth_distance = 4.0;

/**
 * Factor used in Beer’s law to simulate water absorption, affecting depth-based color blending.
 */
uniform float beers_law_factor = 12.0;

/**
 * Controls the overall transparency of the water surface.
 */
uniform float water_transparency : hint_range(0.0, 1.0, 0.1) = 0.05;

// -----------------------------------------------------------------------------
// Screen & Depth Textures
// -----------------------------------------------------------------------------
/**
 * The screen texture used for blending the water surface with the rendered scene.
 */
uniform sampler2D screen_texture : hint_screen_texture;

/**
 * The depth texture used for reconstructing depth values for water effects.
 */
uniform sampler2D depth_texture : hint_depth_texture;

// -----------------------------------------------------------------------------
// Edge Locking
// -----------------------------------------------------------------------------
/**
 * Defines the margin from the edge of the texture within which edge locking is applied.
 */
uniform float edge_margin = 0;

/**
 * Determines the falloff range for edge locking, providing a gradual transition at the edges.
 */
uniform float edge_falloff = 0;

// -----------------------------------------------------------------------------
// Displacement Toggle
// -----------------------------------------------------------------------------
/**
 * Enables or disables vertex displacement on the water surface.
 */
uniform bool apply_displacement = true;

/**
 * Additional control parameter for displacement, typically used for fine-tuning the effect.
 */
uniform float DisplacementToggle = 1.0;

// -----------------------------------------------------------------------------
// Varyings
// -----------------------------------------------------------------------------
varying float v_render;
varying float v_disp;
varying vec3 v_world_pos;

void vertex() {
    vec2 orig_uv = UV;
    vec2 uv = UV;
    
    if (use_domain_warp) {
        vec2 warp_uv = uv * warp_frequency * noise_scale + vec2(TIME * noise_speed, TIME * noise_speed);
        vec2 warp_offset = texture(wave_noise_texture, warp_uv).rg * 2.0 - 1.0;
        uv += warp_offset * warp_amplitude;
    }
    
    vec2 coord;
    if (use_uv_for_waves) {
        coord = uv - vec2(0.5);
    } else {
        coord = VERTEX.xz / water_width;
    }
    
    v_render = (abs(NORMAL.y) >= 0.9) ? 1.0 : 0.0;
    
    float edge_factor_x = smoothstep(edge_margin, edge_margin + edge_falloff, min(orig_uv.x, 1.0 - orig_uv.x));
    float edge_factor_y = smoothstep(edge_margin, edge_margin + edge_falloff, min(orig_uv.y, 1.0 - orig_uv.y));
    float geometry_edge = edge_factor_x * edge_factor_y;
    
    float displacement = 0.0;
    if (v_render > 0.5) {
        float angle1 = dot(coord, normalize(wave_dir1)) * wave_frequency1 * 6.2831 + TIME * wave_speed1;
        float angle2 = dot(coord, normalize(wave_dir2)) * wave_frequency2 * 6.2831 + TIME * wave_speed2;
        float wave1 = sin(angle1);
        float wave2 = sin(angle2);
        displacement = (wave1 + 0.5 * wave2) * wave_amplitude;
        float center_disp = ( sin(TIME * wave_speed1) + 0.5 * sin(TIME * wave_speed2) ) * wave_amplitude;
        displacement -= center_disp;
        displacement *= geometry_edge;
        if (apply_displacement && (DisplacementToggle > 0.5)) {
            VERTEX.y += displacement;
        }
    }
    if (!apply_displacement || (DisplacementToggle <= 0.5)) {
        displacement = 0.0;
    }
    v_disp = displacement;
    
    // NEW: Store world position
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    if (v_render < 0.5) discard;
	
    // --- Screen Space Reconstruction ---
    float depth = texture(depth_texture, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    vec4 view_pos = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc,1.0);
    float depth_texture_y = view_pos.y / view_pos.w;
	float vertex_y = (INV_VIEW_MATRIX * vec4(VERTEX,1.0)).y;
	
	//depth blend
	float depth_blend = clamp((vertex_y - depth_texture_y) / depth_distance, 0.0, 1.0);
	depth_blend = exp(-depth_blend * beers_law_factor);
    
    // --- World Space Position ---
    vec4 scene_world_pos = INV_VIEW_MATRIX * view_pos;

    // --- Wave Displacement Reconstruction (Fragment Precision) ---
    vec2 frag_uv = UV;
    if (use_domain_warp) {
        vec2 warp_uv = frag_uv * warp_frequency * noise_scale + vec2(TIME * noise_speed);
        vec2 warp_offset = texture(wave_noise_texture, warp_uv).rg * 2.0 - 1.0;
        frag_uv += warp_offset * warp_amplitude;
    }

    vec2 frag_coord;
    if (use_uv_for_waves) {
        frag_coord = frag_uv - vec2(0.5);
    } else {
        frag_coord = v_world_pos.xz / water_width;
    }

    // Raw wave calculation (matches vertex shader exactly)
    float angle1 = dot(frag_coord, normalize(wave_dir1)) * wave_frequency1 * 6.2831 + TIME * wave_speed1;
    float angle2 = dot(frag_coord, normalize(wave_dir2)) * wave_frequency2 * 6.2831 + TIME * wave_speed2;
    float raw_disp = (sin(angle1) + 0.5 * sin(angle2)) * wave_amplitude;
    float disp_norm = clamp((raw_disp / wave_amplitude) * 0.5 + 0.5, 0.0, 1.0);

    // --- Slope Calculation ---
    float ddx = dFdx(v_disp);
    float ddy = dFdy(v_disp);
    float slope = clamp(length(vec2(ddx, ddy)) * slope_factor, 0.0, 1.0);

    // ======================
    // FOAM SYSTEM - CORE LOGIC
    // ======================
    // 1. Displacement-based Foam
    float peak_foam = smoothstep(foam_peak_threshold, 1.0, disp_norm);
    float valley_foam = 1.0 - smoothstep(0.0, foam_valley_threshold, disp_norm);
    float displacement_foam = clamp(peak_foam + valley_foam, 0.0, 1.0);

    // 2. Depth Masking
    float vertical_distance = abs(v_world_pos.y - scene_world_pos.y);
    float depth_mask = 1.0 - smoothstep(0.02, foam_depth_range, vertical_distance);

    // 3. Slope Masking
    float slope_mask = smoothstep(foam_slope_start, foam_slope_end, slope);

    // 4. Animated Noise
    vec2 foam_uv = UV * foam_noise_scale + vec2(TIME * foam_speed, TIME * foam_speed * 0.7);
    float foam_noise = smoothstep(0.4, 0.6, texture(foam_noise_texture, foam_uv).r);

    // 5. Final Composition
    float foam = displacement_foam * depth_mask * slope_mask * foam_noise;
    foam = clamp(foam * 1.5, 0.0, 0.8);
	
	    // ======================
    // FRESNEL EMISSION
    // ======================
    vec3 fake_normal = normalize(vec3(-ddx * slope_factor, 1.0, -ddy * slope_factor));
    float fresnel = pow(1.0 - dot(fake_normal, normalize(VIEW)), 3.0);
    vec3 emission = glow_color * emission_strength / env_light_factor;

    // ======================
    // COLOR BLENDING (FIXED)
    // ======================
    // 1. Base water color with slope variation
    vec3 modulated_color = mix(valley_color, peak_color, slope);
    vec3 water_effect = mix(water_color, modulated_color, 0.5);

    // 2. Apply foam to water color
    vec3 water_with_foam = mix(water_effect, foam_color, foam);

    // 3. Depth-based color blending (shallow to deep)
    vec3 depth_color = mix(color_shallow.rgb, color_deep.rgb, depth_blend);
    
    // 4. Combine depth color with foamy water
    vec3 final_water_color = mix(water_with_foam, depth_color, depth_blend * 0.7);

    // 5. Screen blending with transparency
    vec3 screen = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
    vec3 transparent_blend = mix(final_water_color, screen, water_transparency * depth_blend);

    ALBEDO = mix(transparent_blend, screen, depth_blend * (1.0 - fresnel));
	ALBEDO = clamp(ALBEDO + emission, 0.0, 1.0);

    // 7. Emission with fresnel falloff
    EMISSION = vec3(0.0);
}