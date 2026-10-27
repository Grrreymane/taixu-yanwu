shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

// Source textures are copied unchanged from the local HI3 C5 effect bundle.
// Mask mode is selected from the source material, never inferred from its name.
uniform sampler2D source_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D dissolve_texture : filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(0.015, 0.023, 0.027, 1.0);
uniform vec4 uv_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec2 uv_velocity = vec2(0.0);
uniform int mask_mode = 0;
uniform bool source_rgb = false;
// Optional native-energy presentation: preserve the source silhouette but add
// a small colored fringe and pale core for Web builds without screen bloom.
uniform bool energy_core = false;
uniform bool flip_x = false;
uniform bool wrap_uv = false;
uniform bool use_dissolve = false;
uniform float age = 0.0;
uniform float opacity = 0.0;
uniform float dissolve = 0.0;
uniform float dissolve_softness = 0.12;
uniform vec4 noise_uv_transform = vec4(1.0, 0.5, 0.0, 0.0);
uniform vec2 noise_velocity = vec2(0.0, -0.05);

float source_mask(vec4 value) {
	if (mask_mode == 1) return value.r;
	if (mask_mode == 2) return value.r * value.a;
	if (mask_mode == 3) return (1.0 - value.r) * value.a;
	return value.a;
}

void fragment() {
	vec2 uv = UV;
	if (flip_x) uv.x = 1.0 - uv.x;
	uv = uv * uv_transform.xy + uv_transform.zw + uv_velocity * age;
	if (wrap_uv) uv = fract(uv);
	vec4 texel = texture(source_texture, uv);
	float mask = source_mask(texel);
	if (use_dissolve) {
		float noise = texture(dissolve_texture, UV * noise_uv_transform.xy + noise_uv_transform.zw + noise_velocity * age).r;
		noise = clamp((noise - 0.10) * 2.4, 0.0, 1.0);
		mask *= smoothstep(dissolve, dissolve + dissolve_softness, noise);
	}
	ALBEDO = (source_rgb ? texel.rgb : vec3(1.0)) * tint.rgb;
	if (energy_core) {
		vec2 step_uv = 1.5 / vec2(textureSize(source_texture, 0));
		float fringe = max(max(source_mask(texture(source_texture, uv + vec2(step_uv.x, 0.0))), source_mask(texture(source_texture, uv - vec2(step_uv.x, 0.0)))),
			max(source_mask(texture(source_texture, uv + vec2(0.0, step_uv.y))), source_mask(texture(source_texture, uv - vec2(0.0, step_uv.y)))));
		ALBEDO = mix(ALBEDO, vec3(1.0, 0.97, 0.92), smoothstep(0.30, 0.92, mask) * 0.75);
		mask = max(mask, fringe * 0.35);
	}
	ALPHA = clamp(mask * tint.a * opacity, 0.0, 1.0);
}
