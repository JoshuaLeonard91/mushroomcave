shader_type spatial;
render_mode unshaded, cull_disabled;

// **Foam Control Variables**
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.5;  // ✅ Controls when foam appears
uniform float foam_fade : hint_range(0.0, 1.0) = 0.3;       // ✅ Controls foam transparency fade
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0); // ✅ White foam
uniform float foam_noise_scale = 2.5;                        // ✅ Adds randomness to foam pattern

// **Foam Texture (Use a Noise or Flowmap)**
uniform sampler2D foam_noise_texture; // ✅ Use a noise or wave texture

// **Depth & Screen-Space Textures (For Interaction with Water)**
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
    // **Get Depth Info**
    float scene_depth = texture(depth_texture, SCREEN_UV).r;
    float depth_factor = clamp(scene_depth, 0.0, 1.0);

    // **Get Foam Noise Texture**
    vec2 foam_uv = SCREEN_UV * foam_noise_scale;
    float foam_noise = texture(foam_noise_texture, foam_uv).r;

    // **Foam Threshold Based on Depth & Noise**
    float foam_intensity = smoothstep(foam_threshold - foam_fade, foam_threshold + foam_fade, depth_factor + foam_noise);

    // **Final Foam Color**
    ALBEDO = foam_color;
    ALPHA = foam_intensity;
}
