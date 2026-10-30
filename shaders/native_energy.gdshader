shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

// Source textures are copied unchanged from the local HI3 C5 effect bundle.
// Mask mode is selected from the source material, never inferred from its name.
uniform sampler2D source_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D dissolve_texture : filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(0.015, 0.023, 0.027, 1.0);
uniform vec4 uv_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec2 uv_velocity = vec2(0.0);
uniform int mask_mode = 0;
uniform bool source_rgb = false;
uniform bool channel_tints = false;
uniform vec4 channel_0 : source_color = vec4(1.0);
uniform vec4 channel_1 : source_color = vec4(1.0);
uniform vec4 channel_2 : source_color = vec4(1.0);
uniform float source_gain = 1.0;
uniform bool vertex_color = false;
uniform vec4 source_atlas = vec4(1.0, 1.0, 0.0, 0.0);
uniform sampler2D source_mask_texture : filter_linear_mipmap, repeat_disable;
uniform bool use_source_mask = false;
// Small source-texture halo for Compatibility, without a full-screen bloom pass.
uniform float source_glow = 0.0;
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
	// Original Particle_Channel_Mix_New: R/G interpolate colors; B is coverage.
	// Summing RGB masks destroys the narrow lightning silhouette.
	if (channel_tints) {
		ALBEDO = mix(mix(channel_0.rgb, channel_1.rgb, texel.r), channel_2.rgb, texel.g) * tint.rgb;
		mask = texel.b;
	}
	ALBEDO *= vertex_color ? COLOR.rgb : vec3(1.0);
	mask *= vertex_color ? COLOR.a : 1.0;
	if (use_source_mask) mask *= texture(source_mask_texture, UV).r;
	if (source_glow > 0.0) {
		vec2 radius = vec2(0.012) * source_atlas.xy;
		vec4 a = texture(source_texture, uv + vec2(radius.x, 0.0));
		vec4 b = texture(source_texture, uv - vec2(radius.x, 0.0));
		vec4 c = texture(source_texture, uv + vec2(0.0, radius.y));
		vec4 d = texture(source_texture, uv - vec2(0.0, radius.y));
		float halo = channel_tints ? (a.b+b.b+c.b+d.b)*0.25 : (source_mask(a)+source_mask(b)+source_mask(c)+source_mask(d))*0.25;
		halo *= source_glow * (vertex_color ? COLOR.a : 1.0);
		ALBEDO = mix(tint.rgb * 0.7, ALBEDO, mask/max(mask+halo*0.35,0.001));
		mask = max(mask,halo*0.35);
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
