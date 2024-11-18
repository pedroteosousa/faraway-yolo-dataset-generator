shader_type canvas_item;

uniform int sheet_columns: hint_range(1,16) = 10;
uniform int sheet_rows: hint_range(1,16) = 7;

uniform float corner_scale: hint_range(0., 1.) = 0.;

bool isOut(float x, float y) {
    return pow(x, 2.) + pow(y, 2.) > pow(corner_scale * .5, 2.);
}

void fragment() {
	vec2 sprite_sheet_size = vec2(textureSize(TEXTURE,0));
	vec2 frame_size;
	frame_size.x = sprite_sheet_size.x/float(sheet_columns);
	frame_size.y = sprite_sheet_size.y/float(sheet_rows);
	vec4 texture_color = texture(TEXTURE, UV);
	vec2 current_point = sprite_sheet_size * UV;
	float row = floor(current_point.y / frame_size.y);
	float column = floor(current_point.x / frame_size.x);
	vec2 corrected;
	corrected.x = (current_point.x - frame_size.x * column) / frame_size.x;
	corrected.y = (current_point.y - frame_size.y * row) / frame_size.y;
	
	float s = corner_scale * .5;
	
	if (
		(corrected.x < s      && corrected.y < s      && isOut(corrected.x - s,      corrected.y - s)) ||
		(corrected.x < s      && corrected.y > 1. - s && isOut(corrected.x - s,      corrected.y - 1. + s)) ||
		(corrected.x > 1. - s && corrected.y < s      && isOut(corrected.x - 1. + s, corrected.y - s)) ||
		(corrected.x > 1. - s && corrected.y > 1. - s && isOut(corrected.x - 1. + s, corrected.y - 1. + s))
	) {
		COLOR.a = 0.;
	}
}