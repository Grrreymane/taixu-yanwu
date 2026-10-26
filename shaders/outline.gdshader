shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;
#include "res://shaders/native_character_math.gdshaderinc"
uniform float outline_pixels = 0.75;
// Original _MaxOutlineZOffset * _Scale, opt-in per recovered material.
// COLOR.b authors the depth displacement independently of outline thickness.
uniform float outline_depth_offset = 0.0;
uniform vec3 outline_color : source_color = vec3(0.22, 0.18, 0.30);
uniform vec3 outline_color_2 : source_color = vec3(0.12, 0.11, 0.20);
uniform vec3 outline_color_3 : source_color = vec3(0.32, 0.14, 0.0);
uniform vec3 outline_color_4 : source_color = vec3(0.10, 0.10, 0.17);
uniform vec3 outline_color_5 : source_color = vec3(0.0, 0.05, 0.08);
uniform sampler2D lightmap_texture : filter_linear_mipmap, repeat_disable;
uniform bool use_color_regions = false;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform bool use_alpha_clip = false;
uniform float alpha_clip_threshold = 0.1;
// The native shared outline samples UV1 even when the body uses UV2 on backs.
void vertex() {
	// A tiny world-space extrusion became discontinuous subpixel marks in
	// battle view. Keep the silhouette width stable in render-target pixels.
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Hidden/Common_Avatar/Outline (recovered VS 017): push along the view
	// ray by _MaxOutlineZOffset * _Scale * (vertexColor.b - 0.5).
	// A double-sided cloth back otherwise fights its own coplanar outline.
	// The radial move preserves its projection and the existing pixel width.
	view_position.xyz += view_position.xyz / max(length(view_position.xyz), 0.0001)
		* outline_depth_offset * (COLOR.b - 0.5);
	vec4 clip_position = PROJECTION_MATRIX * view_position;
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 projected_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float projected_length = length(projected_normal);
	if (projected_length > 0.0001) {
		clip_position.xy += projected_normal / projected_length * outline_pixels * 2.0 / VIEWPORT_SIZE * clip_position.w;
	}
	POSITION = clip_position;
}
void fragment() {
	if (use_alpha_clip && texture(albedo_texture, UV * uv_scale + uv_offset).a < alpha_clip_threshold) { discard; }
	vec3 ink = outline_color;
	if (use_color_regions) {
		// Recovered Hidden/Common_Avatar/Outline uses the same +0.1 bias.
		int region = hi3_native_body_region(texture(lightmap_texture, UV).a);
		if (region == 4) { ink = outline_color_5; }
		else if (region == 3) { ink = outline_color_4; }
		else if (region == 2) { ink = outline_color_3; }
		else if (region == 1) { ink = outline_color_2; }
	}
	ALBEDO = ink;
}
