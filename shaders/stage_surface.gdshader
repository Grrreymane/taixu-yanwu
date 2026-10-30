shader_type spatial;
global uniform float stage_exposure;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.55,0.58,0.57,1.0);
uniform vec4 shade_color : source_color = vec4(0.30,0.35,0.36,1.0);
uniform float grain_scale = 2.3;
uniform float grain_strength = 0.08;
uniform float weathering = 0.18;
uniform float wind_strength = 0.0;
uniform float elapsed = 0.0;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_texture = false;
uniform float texture_scale = 0.5;
uniform float texture_saturation = 0.7;
uniform float texture_contrast = 1.0;
uniform vec4 native_region = vec4(1.0,1.0,0.0,0.0);
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 a=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1)),f.x),f.y);
}
void vertex() {
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.x+=sin(elapsed*0.65+world.x*0.55+world.y*0.7)*wind_strength;
	world_position=world;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 n=abs(normalize(world_normal));
	vec2 plane=n.y>0.6 ? world_position.xz : (n.z>n.x ? world_position.xy : world_position.zy);
	float cloud=noise(plane*grain_scale*0.32);
	float grain=noise(plane*grain_scale*12.0)-0.5;
	float brushed=noise(plane*vec2(2.0,17.0)+cloud*0.7);
	vec3 color=mix(base_color.rgb,shade_color.rgb,(1.0-cloud)*weathering);
	color*=1.0+grain*grain_strength+(brushed-0.5)*grain_strength*0.4;
	if(use_texture) {
		vec2 source_uv=fract(plane*texture_scale)*native_region.xy+native_region.zw;
		vec3 texel=texture(surface_texture,source_uv).rgb;
		texel=mix(vec3(dot(texel,vec3(0.2126,0.7152,0.0722))),texel,texture_saturation);
		texel=mix(vec3(0.60),texel,texture_contrast);
		color*=mix(vec3(1.0),texel*1.5,0.55);
	}
	ALBEDO=color*COLOR.rgb*stage_exposure;
	ROUGHNESS=0.95;
}
