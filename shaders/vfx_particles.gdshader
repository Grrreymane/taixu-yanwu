shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 tint : source_color = vec4(0.95, 0.72, 0.30, 1.0);
uniform float age = 0.0;
uniform float lifetime = 0.45;
uniform float direction = 0.0;
uniform float spread = 1.6;
uniform float speed = 4.0;
uniform float gravity = 2.4;
uniform bool ink = false;
varying float particle_fade;
varying float particle_seed;

void vertex() {
	float duration = lifetime * mix(0.6, 1.0, COLOR.r);
	float t = clamp(age / duration, 0.0, 1.0);
	float angle = direction + (COLOR.g - 0.5) * spread;
	vec2 velocity = vec2(cos(angle), sin(angle)) * speed * mix(0.35, 1.0, COLOR.b);
	vec2 centre = velocity * age + vec2(0.0, -gravity * age * age);
	float length = mix(0.08, 0.24, COLOR.a) * (1.0 - t * 0.45);
	float width = (ink ? 0.065 : 0.018) * mix(0.6, 1.2, COLOR.r);
	vec2 q = VERTEX.xy * vec2(length, width);
	float c = cos(angle), s = sin(angle);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * q + centre;
	VERTEX.z += COLOR.b * 0.035;
	particle_fade = pow(1.0 - t, 0.65);
	particle_seed = COLOR.r;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float mask;
	if (ink) {
		float fracture = abs(p.y + p.x * (particle_seed - 0.5));
		mask = (1.0 - smoothstep(0.45, 0.85, fracture)) * (1.0 - smoothstep(0.65, 1.0, abs(p.x)));
	} else {
		mask = 1.0 - smoothstep(0.35, 1.0, abs(p.x) + abs(p.y));
	}
	ALBEDO = tint.rgb;
	ALPHA = mask * particle_fade * tint.a;
}
