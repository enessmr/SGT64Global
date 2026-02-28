shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_metallic : filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_roughness : filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_emission : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_ao : filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_heightmap : filter_linear_mipmap, repeat_enable;

uniform vec3 uv1_scale = vec3(3.0, 2.0, 3.0);
uniform float heightmap_scale = 1.0;
uniform float alpha_scissor_threshold = 0.5;

// hole
// CSGBox world pos: 0.135 + 1.128 = 1.263 on x, 0.165 + 1.128 = 1.293 on z
// hole size: 6.384 x 5.808
// ceiling world size: 35.8 x 33.7
// ceiling world origin: 1.128 x 1.128

const float u_min = ((1.263 - 1.128) - 6.384/2.0) / 35.8; // = -0.085
const float u_max = ((1.263 - 1.128) + 6.384/2.0) / 35.8; // = 0.093
const float v_min = ((1.293 - 1.128) - 5.808/2.0) / 33.7; // = -0.081
const float v_max = ((1.293 - 1.128) + 5.808/2.0) / 33.7; // = 0.091

void fragment() {
    vec2 uv = UV * uv1_scale.xy;

    // CUT THE HOLE BYE BYEEE 💀
    vec2 raw_uv = UV;
    if(raw_uv.x > u_min && raw_uv.x < u_max && raw_uv.y > v_min && raw_uv.y < v_max) {
        discard;
    }

    // heightmap parallax
    float height = texture(texture_heightmap, uv).r;
    vec2 parallax_offset = VIEW.xy * (height * heightmap_scale * 0.01);
    uv += parallax_offset;

    vec4 albedo = texture(texture_albedo, uv);
    if(albedo.a < alpha_scissor_threshold) discard;

    float metallic = texture(texture_metallic, uv).a;
    float roughness = texture(texture_roughness, uv).a;
    vec3 emission = texture(texture_emission, uv).rgb;
    vec3 normal = texture(texture_normal, uv).rgb;
    float ao = texture(texture_ao, uv).a;

    ALBEDO = albedo.rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    EMISSION = emission;
    NORMAL_MAP = normal;
    AO = ao;
}