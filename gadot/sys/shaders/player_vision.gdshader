shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap_anisotropic;
uniform float quantizeStrength: hint_range(0.0, 1024.0, 0.1) = 128.0;

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV, 0.0);
    color *= quantizeStrength;
    color = round(color);
    color /= quantizeStrength;
    COLOR = color;
    COLOR.a = 1.0;
}