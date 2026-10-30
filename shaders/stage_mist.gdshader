shader_type spatial;
global uniform float stage_exposure;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 tint : source_color = vec4(0.78,0.83,0.80,0.45);
uniform float elapsed=0.0;
uniform float phase=0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 a=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1)),f.x),f.y);
}
void fragment() {
	vec2 p=UV;
	float grain=noise(p*vec2(9.0,3.0)+vec2(elapsed*0.012+phase,phase));
	float layered=noise(p*vec2(21.0,6.0)+vec2(-elapsed*0.018,phase));
	float edge=pow(max(0.0,sin(p.y*PI)),2.2)*smoothstep(0.0,0.15,p.x)*(1.0-smoothstep(0.85,1.0,p.x));
	ALBEDO=tint.rgb*stage_exposure;
	ALPHA=edge*(grain*0.55+layered*0.25+0.20)*tint.a;
}
