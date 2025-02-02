shader_type spatial;
render_mode unshaded, cull_disabled; // No external lighting, full control

// UNIFORMS (Customizable Settings)
uniform vec3 cave_color = vec3(0.02, 0.02, 0.05); // Extremely dark blue-gray cave floor
uniform float roughness_factor = 0.9;  // Rough ground texture
uniform float dampness_intensity = 0.2; // Simulates damp reflections

void fragment() {
    // Base dark cave color
    vec3 final_color = cave_color;

    // Simulated damp patches (adds slight variation)
    float dampness = sin(UV.x * 5.0 + UV.y * 7.0) * dampness_intensity;
    final_color += vec3(dampness * 0.05); // Faint reflections in wet areas

    // Output final colors
    ALBEDO = final_color;
    ROUGHNESS = roughness_factor; // Makes the surface look rocky and matte
}
