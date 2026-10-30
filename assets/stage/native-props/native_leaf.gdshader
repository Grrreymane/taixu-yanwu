shader_type spatial;
global uniform float stage_exposure;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

// Original source leaf material: _Cutoff = 0.5, _Culling = 0.
// The source had custom vertex-normal/fresnel shading; only cutout is reproduced here.
uniform sampler2D main_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float alpha_cutoff : hint_range(0.0,1.0) = 0.5;
uniform float exposure : hint_range(0.0,3.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 tex = texture(main_tex, UV * uv_scale + uv_offset);
	ALBEDO = tex.rgb * tint.rgb * exposure * stage_exposure;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
}
