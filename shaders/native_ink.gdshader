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
uniform float source_gain = 1.0;
uniform bool vertex_color = false;
uniform vec4 source_atlas = vec4(1.0, 1.0, 0.0, 0.0);
uniform sampler2D source_mask_texture : filter_linear_mipmap, repeat_disable;
uniform bool use_source_mask = false;
uniform bool native_smoke = false;
uniform float smoke_progress = 0.0;
uniform float smoke_threshold = 0.525;
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
	uv = uv * source_atlas.xy + source_atlas.zw;
	vec4 texel = texture(source_texture, uv);
	float mask = source_mask(texel);
	if (use_dissolve) {
		float noise = texture(dissolve_texture, UV * noise_uv_transform.xy + noise_uv_transform.zw + noise_velocity * age).r;
		noise = clamp((noise - 0.10) * 2.4, 0.0, 1.0);
		mask *= smoothstep(dissolve, dissolve + dissolve_softness, noise);
	}
	ALBEDO = (source_rgb ? texel.rgb : vec3(1.0)) * tint.rgb;
	ALBEDO *= vertex_color ? COLOR.rgb : vec3(1.0);
	mask *= vertex_color ? COLOR.a : 1.0;
	if (use_source_mask) mask *= texture(source_mask_texture, UV).r;
	if (native_smoke) {
		// DLCSmoke combines source noise channels before its alpha threshold.
		// The unavailable custom-stream bias is driven by particle lifetime here.
		vec2 noise_uv = UV * noise_uv_transform.xy + noise_uv_transform.zw + noise_velocity * age;
		vec3 noise = texture(dissolve_texture, noise_uv).rgb;
		float density = (noise.r + noise.g) * noise.b - mix(0.02, 0.9, smoke_progress);
		mask *= smoothstep(1.0 - smoke_threshold, smoke_threshold, density);
		// Keep static cone boundaries soft while custom vertex streams
		// remain adapted for the Web renderer.
		mask *= smoothstep(0.0, 0.10, UV.y) * (1.0-smoothstep(0.82,1.0,UV.y));
		mask *= 1.0-smoothstep(0.55,1.0,smoke_progress);
	}
	if (energy_core) {
		vec2 step_uv = 1.5 / vec2(textureSize(source_texture, 0));
		float fringe = max(max(source_mask(texture(source_texture, uv + vec2(step_uv.x, 0.0))), source_mask(texture(source_texture, uv - vec2(step_uv.x, 0.0)))),
			max(source_mask(texture(source_texture, uv + vec2(0.0, step_uv.y))), source_mask(texture(source_texture, uv - vec2(0.0, step_uv.y)))));
		ALBEDO = mix(ALBEDO, vec3(1.0, 0.97, 0.92), smoothstep(0.30, 0.92, mask) * 0.75);
		mask = max(mask, fringe * 0.35);
	}
	vec3 radiance = ALBEDO * source_gain;
	ALBEDO = min(radiance, vec3(1.0));
	EMISSION = max(radiance - vec3(1.0), vec3(0.0));
	ALPHA = clamp(mask * tint.a * opacity, 0.0, 1.0);
}
