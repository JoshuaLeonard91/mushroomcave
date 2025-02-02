/*
    WaterShader.gdshader
    =====================
    This shader is designed for stylized water surfaces in Godot 4.3.
    
    FEATURES:
      • Wave Animation: Uses two sine-wave functions (with an optional domain warp via a noise texture)
        to animate the water surface. Two sine waves with different frequencies, speeds, and diagonal
        directions combine to create a natural wave pattern.
      • Anchored Displacement: The center (average) displacement is subtracted so that the overall vertical
        offset is zero—preventing the water from "flapping" like a flag.
      • Edge Locking: UV-based edge detection is applied so that the geometry near the borders remains flat,
        allowing for seamless alignment with shorelines.
      • Depth Blending: Depth blending is computed using Beer’s Law:
            I = I₀ · exp(–k · d)
        where I is the transmitted intensity, k is the absorption factor, and d is depth.
        This causes water (or objects below the surface) to gradually blend with the screen color as they submerge.
      • Fresnel Effect: A Fresnel term computed from the wave displacement derivatives adds a soft glow along the
        water's edges.
      
    UNIFORMS:
      - water_color, valley_color, peak_color: Define the water’s base tint and tonal variations.
      - glow_color, emission_strength, env_light_factor: Control the intensity and scaling of the Fresnel glow.
      - wave_amplitude, wave_frequency1/2, wave_speed1/2, wave_dir1/2: Control the animated waves.
      - use_domain_warp, noise_texture, noise_speed, noise_scale, warp_amplitude, warp_frequency:
          Control an optional domain warp for additional natural variation.
      - use_uv_for_waves, water_width: Choose the coordinate system for wave calculations.
      - depth_distance, beers_law_factor: Control the depth blending based on Beer’s Law.
      - screen_texture, depth_texture, inv_projection_matrix: Used for reconstructing view-space depth.
      - edge_margin, edge_falloff: Define the UV border within which geometry displacement is locked.
      - apply_displacement, DisplacementToggle: Toggle whether geometry is deformed (animated) or kept flat.
    
    USAGE:
      - Apply this shader to a MeshInstance3D representing your water surface.
      - Adjust the uniform parameters as needed to achieve your desired look.
    
    Author: [Your Name]
    License: [Your chosen license, e.g., MIT License]
*/

shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// -----------------------------------------------------------------------------
// Base Colors: Water tint and tonal variation.
// -----------------------------------------------------------------------------
uniform vec3 water_color  : source_color = vec3(0.0, 0.3, 0.5);
uniform vec3 valley_color : source_color = vec3(0.0, 0.2, 0.4);
uniform vec3 peak_color   : source_color = vec3(0.0, 0.4, 0.7);

// -----------------------------------------------------------------------------
// Glow / Emission Settings: Controls the Fresnel glow effect.
// -----------------------------------------------------------------------------
uniform vec3 glow_color  : source_color = vec3(0.0, 0.5, 1.0);
uniform float emission_strength = 1.5;
uniform float env_light_factor  = 1.0; // Used to scale the Fresnel glow

// -----------------------------------------------------------------------------
// Slope Factor: Amplifies the differences in displacement derivatives to modulate water color.
// -----------------------------------------------------------------------------
uniform float slope_factor = 10.0;

// -----------------------------------------------------------------------------
// Wave Parameters: Two sine waves create the animated water surface.
// -----------------------------------------------------------------------------
uniform float wave_amplitude = 0.09;
uniform float wave_frequency1 = 2.415;
uniform float wave_frequency2 = 2.975;
uniform float wave_speed1     = 1.0;
uniform float wave_speed2     = 1.2;
uniform vec2  wave_dir1       = vec2(1.0, -1.0);  // Wave 1 travels from top left to bottom right.
uniform vec2  wave_dir2       = vec2(-1.0, -1.0); // Wave 2 travels from top right to bottom left.

// -----------------------------------------------------------------------------
// Optional Domain Warp: Adds noise-based variation to the UVs.
// -----------------------------------------------------------------------------
uniform sampler2D noise_texture;
uniform float noise_speed    = 0.01;
uniform float noise_scale    = 2.0;   // Scales the UV coordinates in the warp.
uniform float warp_amplitude = 0.065;
uniform float warp_frequency = 0.655;
uniform bool use_domain_warp = true;

// -----------------------------------------------------------------------------
// Coordinate System for Wave Calculation: Choose UVs or object-space XZ.
// -----------------------------------------------------------------------------
uniform bool use_uv_for_waves = true;
uniform float water_width = 5.0; // Used if use_uv_for_waves is false.

// -----------------------------------------------------------------------------
// Depth Blending Parameters: Controls blending based on Beer’s Law.
// Beer’s Law: I = I₀ * exp(–k * d)
// -----------------------------------------------------------------------------
uniform float depth_distance   = 4.0;
uniform float beers_law_factor = 12.0;

// -----------------------------------------------------------------------------
// Screen & Depth Textures and Inverse Projection Matrix:
// Used to reconstruct view-space depth for depth blending.
// -----------------------------------------------------------------------------
uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D depth_texture  : hint_depth_texture;
uniform mat4 inv_projection_matrix;

// -----------------------------------------------------------------------------
// Edge Locking Parameters: Lock displacement near the UV borders for shoreline alignment.
// -----------------------------------------------------------------------------
uniform float edge_margin = 0.05;  // UV distance from edge where locking begins.
uniform float edge_falloff = 0.1;  // UV distance over which full displacement is achieved.

// -----------------------------------------------------------------------------
// Toggle for Displacement / Wave Effect:
// If apply_displacement is true and DisplacementToggle > 0.5, the vertex positions are deformed.
// -----------------------------------------------------------------------------
uniform bool apply_displacement = true;
uniform float DisplacementToggle = 1.0;

// -----------------------------------------------------------------------------
// Varyings:
// v_render: Flag set to 1.0 for top/bottom faces (|NORMAL.y| >= 0.9); else 0.0.
// v_disp: Computed wave displacement used for color modulation and Fresnel.
// -----------------------------------------------------------------------------
varying float v_render;
varying float v_disp;

void vertex() {
    // Save the original UV (range 0–1) for edge locking.
    vec2 orig_uv = UV;
    // Use UV for wave calculation.
    vec2 uv = UV;
    
    // --- Optional Domain Warp ---
    if (use_domain_warp) {
        // Compute warped UV coordinates with time-based animation.
        vec2 warp_uv = uv * warp_frequency * noise_scale + vec2(TIME * noise_speed, TIME * noise_speed);
        // Sample the noise texture and remap from [0,1] to [-1,1].
        vec2 warp_offset = texture(noise_texture, warp_uv).rg * 2.0 - 1.0;
        uv += warp_offset * warp_amplitude;
    }
    
    // --- Choose Coordinate System for Waves ---
    vec2 coord;
    if (use_uv_for_waves) {
        // Recenter the UV coordinates from [0,1] to [-0.5,0.5].
        coord = uv - vec2(0.5);
    } else {
        // Use object-space XZ coordinates scaled by water_width.
        coord = VERTEX.xz / water_width;
    }
    
    // --- Flag Top/Bottom Faces ---
    // Only animate faces with a near-vertical normal (|NORMAL.y| >= 0.9).
    v_render = (abs(NORMAL.y) >= 0.9) ? 1.0 : 0.0;
    
    // --- Compute Geometry Edge Factor ---
    // This factor is 0 at the very edge and ramps up to 1 inward.
    float edge_factor_x = smoothstep(edge_margin, edge_margin + edge_falloff, min(orig_uv.x, 1.0 - orig_uv.x));
    float edge_factor_y = smoothstep(edge_margin, edge_margin + edge_falloff, min(orig_uv.y, 1.0 - orig_uv.y));
    float geometry_edge = edge_factor_x * edge_factor_y;
    
    // --- Compute Sine-Wave Displacement (only on flagged faces) ---
    float displacement = 0.0;
    if (v_render > 0.5) {
        // Compute the angles for the two sine waves.
        float angle1 = dot(coord, normalize(wave_dir1)) * wave_frequency1 * 6.2831 + TIME * wave_speed1;
        float angle2 = dot(coord, normalize(wave_dir2)) * wave_frequency2 * 6.2831 + TIME * wave_speed2;
        float wave1 = sin(angle1);
        float wave2 = sin(angle2);
        // Combine the two waves.
        displacement = (wave1 + 0.5 * wave2) * wave_amplitude;
        // Anchor the displacement: subtract the center displacement so the average offset is zero.
        float center_disp = ( sin(TIME * wave_speed1) + 0.5 * sin(TIME * wave_speed2) ) * wave_amplitude;
        displacement -= center_disp;
        // Lock the edges by multiplying by the geometry edge factor.
        displacement *= geometry_edge;
        // Apply displacement if toggles are enabled.
        if (apply_displacement && (DisplacementToggle > 0.5)) {
            VERTEX.y += displacement;
        }
    }
    // If displacement is disabled, force it to zero.
    if (!apply_displacement || (DisplacementToggle <= 0.5)) {
        displacement = 0.0;
    }
    v_disp = displacement;
}

void fragment() {
    // --- Discard Non-Water Faces ---
    if (v_render < 0.5) {
        discard;
    }
    
    // --- Depth Blending ---
    // Sample the screen texture and depth texture.
    vec2 screen_uv = SCREEN_UV;
    vec3 screen_color = texture(screen_texture, screen_uv).rgb;
    float depth_sample = texture(depth_texture, screen_uv).r;
    // Reconstruct normalized device coordinates (NDC) from screen UV and depth.
    vec4 ndc = vec4(screen_uv * 2.0 - 1.0, depth_sample, 1.0);
    // Convert NDC to view space using the inverse projection matrix.
    vec4 view_pos = inv_projection_matrix * ndc;
    view_pos /= view_pos.w;
    // Compute linear depth (note: view-space z is negative).
    float linear_depth = abs(view_pos.z) / depth_distance;

    // Compute a blend factor using Beer’s Law:
    // I = I₀ * exp(–k * d) gives the intensity of transmitted light.
    float depth_blend = clamp(exp(-beers_law_factor * linear_depth), 0.0, 1.0);
    
    // --- Water Color Computation ---
    // Compute the derivatives of the wave displacement to obtain a "slope".
    float ddx = dFdx(v_disp);
    float ddy = dFdy(v_disp);
    float slope = clamp(length(vec2(ddx, ddy)) * slope_factor, 0.0, 1.0);
    // Modulate between valley_color and peak_color based on the computed slope.
    vec3 modulated_color = mix(valley_color, peak_color, slope);
    // Combine the base water color with the slope-based modulation.
    vec3 water_effect = mix(water_color, modulated_color, 0.5);
    
    // --- Combine with Depth Blending ---
    // For this version, we blend the water effect with the screen color at a fixed ratio.
    // (You can adjust the ratio as needed.)
    vec3 base_color = mix(water_effect, screen_color, 0.2);
    
    // --- Fresnel Effect ---
    // Compute a fake normal from the displacement derivatives.
    vec3 fake_normal = normalize(vec3(-ddx * slope_factor, 1.0, -ddy * slope_factor));
    // Fresnel term: the reflectivity increases with the angle between the view vector and the surface normal.
    float fresnel = pow(1.0 - dot(fake_normal, normalize(VIEW)), 3.0);
    vec3 emission = glow_color * emission_strength * fresnel;
    emission /= env_light_factor;
    
    // --- Final Color ---
    // The final water color is the combination of the base color and the Fresnel glow.
    vec3 final_color = clamp(base_color + emission, 0.0, 1.0);
    
   	ALBEDO = final_color;
    EMISSION = vec3(0.0);
}
