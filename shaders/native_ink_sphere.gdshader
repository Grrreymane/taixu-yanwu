shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;

// Godot adaptation of the C5 SM_Q material: its original SFX_Noise_310,
// SFX_Mask_306 and measured UV velocities. Unity shader binaries are not reused.
uniform sampler2D ink_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D smoke_mask : filter_linear, repeat_enable;
uniform float age = 0.0;
uniform float opacity = 0.0;
uniform float stretch = 0.0;
uniform vec4 dark_ink : source_color = vec4(0.025,0.03,0.04,1.0);
uniform vec4 light_ink : source_color = vec4(0.94,0.96,0.98,1.0);
varying vec3 local_normal;

void vertex() {
	local_normal = NORMAL;
	VERTEX.y *= 1.0 + stretch;
}

void fragment() {
	vec2 uv = UV;
	float r = texture(ink_noise,uv + vec2(1.0,0.5)*age*0.3).r;
	float g = texture(ink_noise,uv + vec2(-0.5,-0.2)*age*0.3).g;
	// SFX_Mask_306 has opaque alpha: its gray RGB carries the original mask.
	float mask = smoothstep(0.36,0.92,texture(smoke_mask,uv).r);
	float threshold = smoothstep(0.32,0.66,r*0.65+g*0.35 + local_normal.x*0.12);
	float edge = 1.0-smoothstep(0.02,0.09,abs(r-g));
	vec3 color = mix(dark_ink.rgb,light_ink.rgb,threshold);
	color = mix(color,light_ink.rgb,edge*0.12);
	ALBEDO = color;
	float soft_rim = smoothstep(0.03,0.48,abs(dot(normalize(NORMAL),normalize(VIEW))));
	float smoke = smoothstep(0.20,0.56,mix(r,g,0.42));
	// Keep black ink in the core: dark noise is pigment, not empty space.
	// The view rim still reaches zero so the original mesh has no hard outline.
	float core_alpha = mix(0.45,1.0,mask) * mix(0.65,1.0,smoke);
	ALPHA = opacity * soft_rim * core_alpha;
}
