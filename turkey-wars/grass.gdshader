shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_top : source_color = vec3(0.5, 0.8, 0.2);
uniform vec3 albedo_bottom : source_color = vec3(0.1, 0.4, 0.1);
uniform float sway_speed = 1.5;
uniform float sway_strength = 0.3;

void vertex() {
    // UV.y is 1 at bottom, 0 at top for QuadMesh
    float height_factor = 1.0 - UV.y;
    
    // Calculate sway using world position and time
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float sway = sin(world_pos.x * 2.0 + TIME * sway_speed) * cos(world_pos.z * 1.5 + TIME * sway_speed * 0.8);
    
    // Apply sway only to top, bottom stays still
    VERTEX.x += sway * sway_strength * height_factor;
    VERTEX.z += sway * sway_strength * 0.5 * height_factor;
}

void fragment() {
    float height_factor = 1.0 - UV.y;
    ALBEDO = mix(albedo_bottom, albedo_top, height_factor);
    ROUGHNESS = 0.8;
}
