shader_type spatial;

// Texture uniforms - your noise.png goes here
uniform sampler2D cloudNoise : source_color, filter_linear, repeat_enable;
uniform float time_scale = 1.0;

// Cloud parameters
uniform float CLOUD_THICKNESS : hint_range(0.0, 25.0) = 12.0;
uniform float CLOUD_DETAIL : hint_range(0.0, 21.0) = 10.0;
uniform float CLOUD_DENSITY : hint_range(0.0, 8.0) = 4.0;
uniform float CLOUD_AMOUNT : hint_range(0.0, 20.0) = 10.0;
uniform float CLOUD_STRETCH : hint_range(0.0, 500.0) = 1.0;
uniform float CLOUD_SPEED : hint_range(0.0, 10.0) = 1.0;
uniform float CLOUD_HEIGHT : hint_range(0.0, 512.0) = 192.0;
uniform float CLOUD_SCALE : hint_range(0.0, 20.0) = 1.0;
uniform float CLOUD_OPACITY : hint_range(0.0, 1.0) = 1.0;
uniform float CLOUD_BRIGHTNESS : hint_range(0.0, 2.0) = 1.0;

// Weather/environment
uniform float rain_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sun_coverage : hint_range(0.0, 1.0) = 0.0;

// Cloud base type selector
// 0 = Perlin, 1 = Worley, 2 = Blocky
uniform int CLOUD_BASE_TYPE : hint_range(0, 2) = 0;

// Helper functions
float cloud_sample_base_perlin(vec2 coord) {
    float noise_base = texture(cloudNoise, coord).r;
    return noise_base;
}

float cloud_sample_base_worley(vec2 coord) {
    float noise_base = texture(cloudNoise, coord).g;
    noise_base = pow(1.0 - noise_base, 2.0) * 0.5 + 0.25;
    return noise_base;
}

float cloud_sample_base_blocky(vec2 coord) {
    float noise_res = 512.0;
    
    vec2 coord_scaled = coord * noise_res - 0.5;
    
    vec2 flr = floor(coord_scaled);
    vec2 frc = coord_scaled - flr;
    
    frc = clamp(frc * 5.0 - 2.0, vec2(0.0), vec2(1.0));
    frc = frc * frc * (3.0 - 2.0 * frc);
    
    coord_scaled = (flr + frc + 0.5) / noise_res;
    
    float noise_base = texture(cloudNoise, coord_scaled).a;
    noise_base = (1.0 - noise_base) * 4.0;
    
    float noise_rain = texture(cloudNoise, coord_scaled + vec2(0.5, 0.0)).a;
    noise_rain = (1.0 - noise_rain) * 4.0 * smoothstep(0.0, 0.5, rain_strength);
    
    noise_base = min(noise_base + noise_rain, 1.0);
    
    return noise_base;
}

float cloud_sample_detail(vec2 coord, float cloud_gradient) {
    float detail_z = floor(cloud_gradient * CLOUD_THICKNESS) * 0.04;
    float detail_frac = fract(cloud_gradient * CLOUD_THICKNESS);
    
    float noise_detail_low = texture(cloudNoise, coord + vec2(0.0, detail_z)).b;
    float noise_detail_high = texture(cloudNoise, coord + vec2(0.0, detail_z + 0.04)).b;
    
    float noise_detail = mix(noise_detail_low, noise_detail_high, detail_frac);
    
    return noise_detail;
}

float cloud_coverage_default(float cloud_gradient) {
    float noise_coverage = abs(cloud_gradient - 0.125);
    
    noise_coverage *= cloud_gradient > 0.125 ? (2.14 - CLOUD_AMOUNT * 0.1) : 8.0;
    noise_coverage = noise_coverage * noise_coverage * 4.0;
    
    return noise_coverage;
}

float cloud_coverage_blocky(float cloud_gradient) {
    float noise_coverage = abs(cloud_gradient - 0.5) * 2.0;
    
    noise_coverage *= noise_coverage;
    noise_coverage *= noise_coverage;
    
    return noise_coverage;
}

float cloud_apply_density(float noise) {
    noise *= CLOUD_DENSITY * 0.125;
    noise *= (1.0 - 0.75 * rain_strength);
    noise = noise / sqrt(noise * noise + 0.5);
    
    return noise;
}

float cloud_combine_default(float noise_base, float noise_detail, float noise_coverage, float sun_cov) {
    float noise = mix(noise_base, noise_detail, 0.0476 * CLOUD_DETAIL) * 21.0;
    
    noise = mix(noise - noise_coverage, 21.0 - noise_coverage * 2.5, 0.33 * rain_strength);
    noise = max(noise - (sun_cov * 3.0 + CLOUD_AMOUNT), 0.0);
    
    noise = cloud_apply_density(noise);
    
    return noise;
}

float cloud_combine_blocky(float noise_base, float noise_coverage) {
    float noise = (noise_base - noise_coverage) * 2.0;
    
    noise = max(noise, 0.0);
    
    noise = cloud_apply_density(noise);
    
    return noise;
}

float cloud_sample(vec2 coord, vec2 wind, float cloud_gradient, float sun_cov, float dither) {
    coord *= 0.004 * CLOUD_STRETCH;
    
    if (CLOUD_BASE_TYPE == 0) {
        // Perlin mode
        vec2 base_coord = coord * 0.25 + wind;
        vec2 detail_coord = coord * 0.5 - wind * 2.0;
        
        float noise_base = cloud_sample_base_perlin(base_coord);
        float noise_detail = cloud_sample_detail(detail_coord, cloud_gradient);
        float noise_coverage = cloud_coverage_default(cloud_gradient);
        
        float noise = cloud_combine_default(noise_base, noise_detail, noise_coverage, sun_cov);
        
        return noise;
    } else if (CLOUD_BASE_TYPE == 1) {
        // Worley mode
        vec2 base_coord = coord * 0.5 + wind * 2.0;
        vec2 detail_coord = coord * 0.5 - wind * 2.0;
        
        float noise_base = cloud_sample_base_worley(base_coord);
        float noise_detail = cloud_sample_detail(detail_coord, cloud_gradient);
        float noise_coverage = cloud_coverage_default(cloud_gradient);
        
        float noise = cloud_combine_default(noise_base, noise_detail, noise_coverage, sun_cov);
        
        return noise;
    } else {
        // Blocky mode
        vec2 base_coord = coord * 0.125 + wind * 0.5;
        
        float noise_base = cloud_sample_base_blocky(base_coord);
        float noise_coverage = cloud_coverage_blocky(cloud_gradient);
        
        float noise = cloud_combine_blocky(noise_base, noise_coverage);
        
        return noise;
    }
}

float inv_lerp(float v, float l, float h) {
    return clamp((v - l) / (h - l), 0.0, 1.0);
}

// Simple noise function for effects
float get_noise(vec2 pos) {
    return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

void fragment() {
    // Calculate wind based on TIME
    vec2 wind = vec2(
        TIME * CLOUD_SPEED * 0.0005 * time_scale,
        sin(TIME * CLOUD_SPEED * 0.001 * time_scale) * 0.005
    ) * 0.667;
    
    // Use UV coordinates for cloud sampling
    vec2 cloud_coord = UV;
    
    // Sample cloud noise with gradient
    float cloud_gradient = 0.5; // Middle of cloud layer
    float dither = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
    
    float cloud_density = cloud_sample(cloud_coord, wind, cloud_gradient, sun_coverage, dither);
    
    // Output cloud color
    vec3 cloud_color = vec3(1.0) * CLOUD_BRIGHTNESS;
    float alpha = cloud_density * CLOUD_OPACITY;
    
    ALBEDO = cloud_color;
    ALPHA = alpha;
    EMISSION = cloud_color * cloud_density * 0.1;
}
