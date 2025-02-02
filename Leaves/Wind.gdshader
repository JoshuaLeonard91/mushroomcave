shader_type spatial;

// Add a noise texture uniform
uniform float wind_strength : hint_range(0.0, 1.0) = 0.1;
uniform float wind_speed : hint_range(0.0, 10.0) = 2.0;
uniform float wind_frequency : hint_range(0.0, 10.0) = 5.0;

uniform sampler2D noise_texture : hint_default_white;

void vertex() {
    // Sample the noise texture
    float noise_value = texture(noise_texture, vec2(VERTEX.x, VERTEX.y)).r;

    // Apply wind displacement with noise
    float wind = sin(TIME * wind_speed + VERTEX.x * wind_frequency + noise_value) * wind_strength;

    // Apply wind displacement to the vertex position
    VERTEX.x += wind;
    VERTEX.y += wind * 0.2;
}
