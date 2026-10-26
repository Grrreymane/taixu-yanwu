// Recovered from the local BH3 9.1 Face shader DXBC, not a generic toon recipe.
// Evidence: hi3-fuhua-extract/exports/c5-material-reference/shader-audit/
// Face/022-vs_4_0.asm and Face/001-ps_4_0.asm. Shader PathID 8679466564415281629.
// object_light is the original renderer's world-to-object transformed light;
// the compiled shader projects its YZ components, NOT world XZ. Caller must
// supply the corresponding basis after its engine/model coordinate conversion.
// source_light_length is the length BEFORE the world-to-object conversion.
// Output: raw FaceMap sample UV in xy and directional alpha threshold in z.
vec3 hi3_native_face_lookup(vec2 raw_uv, vec3 object_light, float source_light_length) {
	if (source_light_length < 0.9) {
		return vec3(0.0, 1.0, 0.0);
	}
	vec3 l = normalize(object_light);
	float tilted_y = 0.98481 * l.y + 0.17365 * l.z;
	float tilted_z = -0.17365 * l.y + 0.98481 * l.z;
	// DXBC uses a polynomial atan2 approximation. This is its analytic
	// equivalent; approximation error has not been folded into the texture.
	float angle = atan(tilted_z, tilted_y);
	float threshold = clamp(abs(angle) / 3.141592653589793, 0.0001, 0.9999);
	vec2 face_uv = angle < 0.0 ? vec2(1.0 - raw_uv.x, raw_uv.y) : raw_uv;
	return vec3(face_uv, threshold);
}

// Original FaceMap uses ALPHA; FaceLightMap uses GREEN. Native feather=.001.
// Normal weather/effect state, without cascaded scene-shadow attenuation.
float hi3_native_face_lit(float face_map_alpha, float face_lightmap_green, float threshold, float feather) {
	float lower = max(threshold - feather, 0.0001);
	float upper = min(threshold + feather, 0.9999);
	float t = clamp((face_map_alpha - lower) / (upper - lower), 0.0, 1.0);
	float shaped = t * t * (3.0 - 2.0 * t);
	return face_lightmap_green * shaped;
}

vec3 hi3_native_face_color(vec3 albedo, vec3 shadow_color, float lit, vec3 main_color, vec3 env_color) {
	return albedo * mix(shadow_color, vec3(1.0), lit) * main_color * env_color;
}

// AvatarGS/155-ps_4_0.asm and 300-ps_4_0.asm: the inspector labels omit
// this +0.1 bias. CommonOutline/031-ps_4_0.asm confirms the same bias
// for MORE_OUTLINE_COLOR. Return the zero-based native color region.
int hi3_native_body_region(float lightmap_alpha) {
	float region = lightmap_alpha + 0.1;
	if (region >= 0.8) { return 4; }
	if (region >= 0.6) { return 3; }
	if (region >= 0.4) { return 2; }
	if (region >= 0.2) { return 1; }
	return 0;
}

// The original vertex shader computes this before interpolation. Passing a
// per-fragment normal changes interpolation slightly and is an engine adaptation.
float hi3_native_half_lambert(vec3 normal, vec3 light_direction) {
	return dot(normal, light_direction) * 0.4975 + 0.5;
}

float hi3_native_shadow_metric(float lightmap_green, float vertex_red, float interpolated_half_lambert) {
	float mask = lightmap_green * vertex_red;
	float adjusted = mask >= 0.5 ? mask * 1.2 - 0.1 : mask * 1.25 - 0.125;
	return 0.5 * (adjusted + interpolated_half_lambert);
}

// Active AvatarGS SHADOWRAMPTEXUSED branch uses the regional first shadow only.
float hi3_native_body_lit(float lightmap_green, float vertex_red, float interpolated_half_lambert, float light_area) {
	return step(light_area, hi3_native_shadow_metric(lightmap_green, vertex_red, interpolated_half_lambert));
}

// Character_Common/Avatar (Hair/038-ps_4_0.asm), normal weather/custom effects
// disabled, BackFaceUseUV2=0. Its darkest mask values have a second-shadow branch.
vec3 hi3_native_common_shadow(float lightmap_green, float vertex_red, float interpolated_half_lambert, float light_area, float second_shadow_area, vec3 first_shadow, vec3 second_shadow) {
	float mask = lightmap_green * vertex_red;
	if (mask < 0.09) {
		return 0.5 * (mask + interpolated_half_lambert) < second_shadow_area ? second_shadow : first_shadow;
	}
	return hi3_native_shadow_metric(lightmap_green, vertex_red, interpolated_half_lambert) < light_area ? first_shadow : vec3(1.0);
}

// Normal-light branch H=normalize(V+L). The original custom-light branch has
// separate half-vector logic; compute that outside these mask functions if used.
vec3 hi3_native_hard_specular(vec3 lightmap, float normal_dot_half, float shininess, float spec_multi, vec3 spec_color) {
	float lobe = pow(max(normal_dot_half, 0.0), shininess);
	return step(1.0 - lightmap.b, lobe) * lightmap.r * spec_multi * spec_color;
}

// AvatarGS SPECULAR keyword. _Smooth=.04 on C5_04_02's original Body material.
vec3 hi3_native_soft_specular(vec3 lightmap, float normal_dot_half, float shininess, float spec_multi, vec3 spec_color, float softness) {
	float lobe = pow(max(normal_dot_half, 0.0), shininess * lightmap.b);
	vec3 amount = lightmap.r * spec_multi * spec_color * lobe;
	return smoothstep(vec3(0.5 - softness), vec3(0.5 + softness), amount);
}
