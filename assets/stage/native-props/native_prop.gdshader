shader_type spatial;
global uniform float stage_exposure;
render_mode unshaded, cull_back;

// Recovered local BH3 9.1 basic baked-light equations:
// AirLightMap/012-ps_4_0.asm and SceneMatcap/072-ps_4_0.asm.
// Original ShadowTex is packed RGBA: RGB*A*2 + (1-A), not RGB brightness.
// Native Gamma color arithmetic is retained on Compatibility. This shader
// Restores the baked-light and base Matcap terms; separate additive GGX,
// Matcap-specular, Fresnel, native fog and postprocess remain outside this pass.
uniform sampler2D main_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shadow_tex : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec2 shadow_uv_scale = vec2(1.0);
uniform vec2 shadow_uv_offset = vec2(0.0);
uniform bool has_shadow_tex = false;
uniform float lightmap_intensity : hint_range(0.0, 4.0) = 1.0;
// AirEffect=1. Scene_Air_LightMap_Matcap=2*_Color.rgb*_EnvColor.rgb.
// Raw original Gamma-domain values: intentionally no source_color annotation.
uniform vec3 material_factor = vec3(1.0);
uniform float exposure : hint_range(0.0, 3.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);

uniform bool use_matcap = false;
uniform sampler2D matcap_tex : source_color, filter_linear_mipmap, repeat_disable;
// Native mask uses MainTex UV/ST and its red channel; a missing mask is white.
uniform sampler2D matcap_mask_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float matcap_metal_ref : hint_range(0.0, 1.0) = 0.639;
uniform bool use_normal_tex = false;
// Do not request Godot normal-map channel reconstruction: the native shader
// explicitly unpacks R*A and G. The exported PNG keeps all original channels.
uniform sampler2D normal_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 normal_uv_scale = vec2(1.0);
uniform vec2 normal_uv_offset = vec2(0.0);

varying vec3 native_incident_tangent;
varying vec3 native_view_tangent;
varying vec3 native_view_binormal;
varying vec3 native_view_normal;

void vertex() {
 if (use_matcap) {
  vec3 camera_object = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
  vec3 incident_object = VERTEX - camera_object;
  // Source XYZ is mirrored on X and tangent.w is negated on import. Godot's
  // cross(N,T)*w therefore supplies the original mirrored bitangent directly.
  native_incident_tangent = normalize(vec3(dot(TANGENT, incident_object), dot(BINORMAL, incident_object), dot(NORMAL, incident_object)));
  native_view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
  native_view_tangent = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
  float handedness = sign(dot(cross(NORMAL, TANGENT), BINORMAL));
  native_view_binormal = cross(native_view_normal, native_view_tangent) * handedness;
 }
}

float native_prop_srgb_to_linear_channel(float value) {
 return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}
float native_prop_linear_to_srgb_channel(float value) {
 return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}
vec3 native_prop_srgb_to_linear(vec3 value) {
 return vec3(native_prop_srgb_to_linear_channel(value.r), native_prop_srgb_to_linear_channel(value.g), native_prop_srgb_to_linear_channel(value.b));
}
vec3 native_prop_linear_to_srgb(vec3 value) {
 return vec3(native_prop_linear_to_srgb_channel(value.r), native_prop_linear_to_srgb_channel(value.g), native_prop_linear_to_srgb_channel(value.b));
}
vec3 native_prop_decode_lightmap(vec4 packed_light) {
 return 2.0 * packed_light.rgb * packed_light.a + vec3(1.0 - packed_light.a);
}

void fragment() {
 vec2 main_uv = UV * uv_scale + uv_offset;
 vec3 color = texture(main_tex, main_uv).rgb;
 vec3 art_tint = tint.rgb;
 if (!OUTPUT_IS_SRGB) {
  color = native_prop_linear_to_srgb(color);
  art_tint = native_prop_linear_to_srgb(art_tint);
 }
 if (use_matcap) {
  vec3 mapped_normal = vec3(0.0, 0.0, 1.0);
  if (use_normal_tex) {
   vec4 packed_normal = texture(normal_tex, UV * normal_uv_scale + normal_uv_offset);
   mapped_normal.xy = vec2(packed_normal.r * packed_normal.a, packed_normal.g) * 2.0 - 1.0;
   mapped_normal.z = sqrt(1.0 - min(dot(mapped_normal.xy, mapped_normal.xy), 1.0));
  }
  vec3 normal_view = native_view_tangent * mapped_normal.x + native_view_binormal * mapped_normal.y + native_view_normal * mapped_normal.z;
  // Deliberately retain the original mixed-space expression and interpolated
  // inputs: its PS reflects tangent-space incidence against a view-space
  // normal, then normalizes only the reflected vector (072-ps lines 100-113).
  vec3 reflected = normalize(native_incident_tangent - 2.0 * dot(native_incident_tangent, normal_view) * normal_view);
  vec2 matcap_uv = 0.5 + 0.5 * mix(normal_view.xy, reflected.xy, matcap_metal_ref);
  matcap_uv.y = 1.0 - matcap_uv.y; // Unity texture UV to original exported PNG.
  vec3 matcap_color = texture(matcap_tex, matcap_uv).rgb;
  if (!OUTPUT_IS_SRGB) {
   matcap_color = native_prop_linear_to_srgb(matcap_color);
  }
  float matcap_mask = texture(matcap_mask_tex, main_uv).r;
  color *= mix(vec3(1.0), matcap_color, matcap_mask);
 }
 vec3 baked = vec3(1.0);
 if (has_shadow_tex) {
  baked = native_prop_decode_lightmap(texture(shadow_tex, UV2 * shadow_uv_scale + shadow_uv_offset));
 }
 color *= baked * lightmap_intensity * material_factor * art_tint * exposure;
 if (!OUTPUT_IS_SRGB) {
  color = native_prop_srgb_to_linear(color);
 }
 ALBEDO = color * stage_exposure;
}
