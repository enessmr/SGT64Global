shader_type spatial;
render_mode depth_draw_always;

uniform vec3 albedo : source_color;
uniform vec3 albedo2 : source_color;
uniform float metallic : hint_range(0.0, 1.0) = 0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D texture_normal;
uniform sampler2D texture_normal2;
uniform sampler2D wave;
uniform vec2 wave_direction = vec2(2.0,0.0);
uniform vec2 wave_direction2 = vec2(0.0,1.0);
uniform float time_scale : hint_range(0.0, 0.2, 0.005) = 0.025;
uniform float noise_scale = 10.0;
uniform float height_scale = 0.15;

uniform vec4 color_deep : source_color;
uniform vec4 color_shallow : source_color;
uniform float beers_law = 2.0;
uniform float depth_offset = -0.75;

// REMOVED: edge_scale and edge_color uniforms

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

varying float height;
varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    height = texture(wave, world_pos.xz / noise_scale + TIME * time_scale).r;
    VERTEX.y += height * height_scale;
}

float fresnel(float amount, vec3 normal, vec3 view) {
    return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void fragment() {
    // ==== CORRECTED DEPTH CALCULATION (replaces broken original) ====
    float depth_raw = texture(depth_texture, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float depth_texture_y = view.y;
    
    // Get camera-space position of current fragment
    float vertex_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
    
    // Correct depth difference calculation
    float depth_diff = vertex_y - depth_texture_y;
    
    // ==== ORIGINAL COLOR BLENDING (works fine) ====
    float depth_blend = exp(depth_diff * -beers_law);
    depth_blend = clamp(depth_blend, 0.0, 1.0);
    float depth_blend_power = clamp(pow(1.0 - depth_blend, 2.5), 0.0, 1.0);
    
    // Underwater color mixing
    vec3 screen_color = textureLod(screen_texture, SCREEN_UV, depth_blend_power * 2.5).rgb;
    vec3 depth_color = mix(color_shallow.rgb, color_deep.rgb, depth_blend_power);
    vec3 water_color = mix(screen_color * depth_color, depth_color * 0.25, depth_blend_power * 0.5);
    
    // Surface fresnel
    vec2 time = (TIME * wave_direction) * time_scale;
    vec2 time2 = (TIME * wave_direction2) * time_scale;
    float fresnel_val = fresnel(5.0, NORMAL, VIEW);
    vec3 surface_color = mix(albedo, albedo2, fresnel_val);
    
    // ==== FINAL COLOR (NO EDGE FOAM) ====
    vec3 final_color = surface_color + water_color;
    
    ALBEDO = clamp(final_color, vec3(0.0), vec3(1.0));
    vec3 normal_blend = mix(texture(texture_normal, world_pos.xz + time).rgb, texture(texture_normal2, world_pos.xz + time2).rgb, 0.5);
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL_MAP = normal_blend;
}
