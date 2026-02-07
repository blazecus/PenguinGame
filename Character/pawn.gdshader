shader_type canvas_item;

instance uniform vec4 highlight_color : source_color = vec4(1.0,0.0,0.0, 1.0);
instance uniform float strength : hint_range(0.0, 1.0) = 0.0;
instance uniform float outline_size = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = mix(tex, highlight_color, strength);
	if(tex.a < 0.1){
		COLOR = highlight_color * float(
			texture(TEXTURE, UV - vec2(outline_size, 0.0) * TEXTURE_PIXEL_SIZE).a > 0.1 ||
			texture(TEXTURE, UV + vec2(outline_size, 0.0) * TEXTURE_PIXEL_SIZE).a > 0.1 ||
			texture(TEXTURE, UV - vec2(0.0, outline_size) * TEXTURE_PIXEL_SIZE).a > 0.1 ||
			texture(TEXTURE, UV + vec2(0.0, outline_size) * TEXTURE_PIXEL_SIZE).a > 0.1
		);
	}
}
