shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform sampler2D source_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec4 region=vec4(1.0,1.0,0.0,0.0);
uniform vec4 tint : source_color=vec4(1.0);
uniform vec4 haze : source_color=vec4(0.7,0.8,0.8,1.0);
uniform float haze_amount=0.3;
uniform bool flip_x=false;
void fragment() {
	vec2 uv=UV;
	if(flip_x)uv.x=1.0-uv.x;
	vec4 texel=texture(source_texture,clamp(uv*region.xy+region.zw,vec2(0.002,0.012),vec2(0.998,0.998)));
	float foot_mist=smoothstep(0.28,1.0,UV.y)*0.48;
	vec3 stone=mix(vec3(dot(texel.rgb,vec3(0.2126,0.7152,0.0722))),texel.rgb,0.58);
	ALBEDO=mix(stone*tint.rgb,haze.rgb,clamp(haze_amount+foot_mist,0.0,0.95));
	ALPHA=texel.a*tint.a*smoothstep(0.0,0.015,UV.y);
}
