shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
#include "res://shaders/native_character_math.gdshaderinc"

// Recovered normal-weather shader equations and original per-appearance values.
// Both the original client (PlayerSettings m_ActiveColorSpace=0) and this
// project's Compatibility renderer shade in sRGB/Gamma. Do not add a second
// gamma conversion here. OUTPUT_IS_SRGB is true on the shipped Web renderer.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D lightmap_texture : filter_linear_mipmap, repeat_disable;
uniform sampler2D face_mask_texture : filter_linear_mipmap, repeat_disable;
uniform bool has_lightmap = false;
uniform bool has_face_mask = false;
uniform bool use_alpha_clip = false;
uniform float alpha_clip_threshold = 0.1;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool has_emission_texture = false;
uniform vec3 native_emission_tint = vec3(1.0);
uniform float native_emission_strength = 0.0;
uniform float native_hue_offset = 0.0;
uniform float native_value_offset = 0.0;
uniform bool use_backface_uv2 = false;
uniform int material_kind = 0;
uniform float face_part_depth_bias = 0.0005;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec3 key_direction = vec3(-0.45, 0.72, 0.56);
uniform vec3 face_forward = vec3(0.0, 0.0, 1.0);
uniform vec3 face_right = vec3(1.0, 0.0, 0.0);
uniform vec3 face_up = vec3(0.0, 1.0, 0.0);
// Serialized native multipliers, not display colors: no source_color hint.
uniform vec3 material_tint = vec3(1.0);
uniform vec3 environment_tint = vec3(1.0);
uniform vec3 backface_tint = vec3(1.0);
uniform vec3 shadow_tint = vec3(0.937255, 0.764706, 0.780392);
uniform vec3 shadow_color_2 = vec3(0.713668, 0.755436, 0.882353);
uniform vec3 shadow_color_3 = vec3(0.911765, 0.766123, 0.610078);
uniform vec3 shadow_color_4 = vec3(0.926699, 0.885327, 0.963235);
uniform vec3 shadow_color_5 = vec3(0.708694, 0.739241, 0.830882);
uniform vec3 second_shadow_tint = vec3(0.66, 0.71, 0.84);
uniform bool use_shadow_regions = false;
uniform float light_area = 0.51;
uniform float second_shadow_area = 0.51;
uniform float shininess = 10.0;
uniform float specular_strength = 0.0;
uniform vec3 specular_color = vec3(1.0);
uniform bool soft_specular = false;
uniform float specular_smoothness = 0.04;
uniform float face_shadow_feather = 0.001;
uniform float flash_amount = 0.0;
uniform float ghost_amount = 0.0;
uniform vec4 ghost_tint : source_color = vec4(0.28, 0.64, 0.79, 1.0);
varying vec3 world_normal;
varying vec3 world_position;
varying float native_half_lambert;

void vertex() {
	// Equivalent layering to the native Face Part polygon offset.
	if (material_kind == 3) { VERTEX += NORMAL * face_part_depth_bias; }
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	native_half_lambert = hi3_native_half_lambert(world_normal, normalize(key_direction));
}

vec3 eye_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w-q.y)/(6.0*d+0.000001)),d/(q.x+0.000001),q.x);
}
vec3 eye_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0/3.0, 1.0/3.0))*6.0-3.0);
	return c.z * mix(vec3(1.0),clamp(p-1.0,0.0,1.0),c.y);
}
void fragment() {
	vec2 raw_uv = !FRONT_FACING && use_backface_uv2 ? UV2 : UV;
	vec4 base = texture(albedo_texture, raw_uv * uv_scale + uv_offset);
	if (use_alpha_clip && base.a < alpha_clip_threshold) { discard; }
	if (material_kind == 3 && base.a < 0.35) { discard; }
	// Original costume eye offsets on its shared blue atlas. HSV is adapted
	// here; alpha, white sclera and dark outlines retain their source pixels.
	if (material_kind == 3 && abs(native_hue_offset) > 0.0001) {
		vec3 hsv = eye_hsv(base.rgb);
		if (hsv.y > 0.03) {
			hsv.x = fract(hsv.x + native_hue_offset);
			hsv.z = clamp(hsv.z + native_value_offset,0.0,1.0);
			base.rgb = eye_rgb(hsv);
		}
	}
	vec4 mask = has_lightmap ? texture(lightmap_texture, raw_uv) : vec4(0.0, 1.0, 0.0, 0.0);
	vec3 n = normalize(world_normal);
	vec3 l = normalize(key_direction);
	vec3 v = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 color = base.rgb;
	if (material_kind == 0 || material_kind == 1) {
		vec3 tint = shadow_tint;
		if (material_kind == 0) {
			if (use_shadow_regions) {
				int region = hi3_native_body_region(mask.a);
				if (region == 4) { tint = shadow_color_5; }
				else if (region == 3) { tint = shadow_color_4; }
				else if (region == 2) { tint = shadow_color_3; }
				else if (region == 1) { tint = shadow_color_2; }
			}
			float lit = hi3_native_body_lit(mask.g, COLOR.r, native_half_lambert, light_area);
			tint = mix(tint, vec3(1.0), lit);
		} else {
			tint = hi3_native_common_shadow(mask.g, COLOR.r, native_half_lambert,
				light_area, second_shadow_area, shadow_tint, second_shadow_tint);
		}
		float nh = dot(n, normalize(l + v));
		vec3 specular = soft_specular ?
			hi3_native_soft_specular(mask.rgb, nh, shininess, specular_strength, specular_color, specular_smoothness) :
			hi3_native_hard_specular(mask.rgb, nh, shininess, specular_strength, specular_color);
		color = (base.rgb * tint + specular) * material_tint * environment_tint;
		if (!FRONT_FACING) { color *= backface_tint; }
	} else if (material_kind == 2) {
		// Native object axes X=right, Y=up, Z=front. Preserve its YZ projection.
		vec3 object_light = vec3(dot(l, normalize(face_right)), dot(l, normalize(face_up)), dot(l, normalize(face_forward)));
		vec3 lookup = hi3_native_face_lookup(raw_uv, object_light, length(key_direction));
		float face_alpha = has_face_mask ? texture(face_mask_texture, lookup.xy).a : 1.0;
		float lit = hi3_native_face_lit(face_alpha, mask.g, lookup.z, face_shadow_feather);
		color = hi3_native_face_color(base.rgb, shadow_tint, lit, material_tint, environment_tint);
	}
	// Preserve painted face and cloth values on opponents, with a restrained tint.
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	vec3 echo_color = mix(ghost_tint.rgb * 0.10, ghost_tint.rgb, sqrt(max(luminance, 0.0)));
	float echo_weight = material_kind >= 2 ? 0.08 : 0.32;
	color = mix(color, echo_color, ghost_amount * echo_weight);
	float edge_flash = smoothstep(0.44, 0.84, 1.0 - abs(dot(n, v)));
	float paper_flash = flash_amount * (0.17 + 0.57 * edge_flash);
	if (material_kind == 3) { paper_flash *= 0.2; }
	ALBEDO = mix(color, vec3(0.93, 0.98, 1.0), paper_flash);
	// Apply only audited emission-texture slots (the original Blood Moon
	// eclipse wing engraving), leaving all ordinary body materials unchanged.
	if (has_emission_texture) {
		EMISSION = texture(emission_texture, raw_uv).rgb * native_emission_tint * native_emission_strength;
	}
}
