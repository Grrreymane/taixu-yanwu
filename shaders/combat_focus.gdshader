shader_type canvas_item;
render_mode unshaded;

uniform vec2 center = vec2(0.5);
uniform float aspect = 1.6;
uniform float strength = 0.0;
uniform float direction = 1.0;
uniform bool parry = false;

void fragment() {
	vec2 p = (UV - center) * vec2(aspect, 1.0);
	float radius = length(p);
	float angle = atan(p.y, p.x * direction);
	// Leave a clear opening around both bodies and their contact silhouette.
	float surround = smoothstep(0.22, 0.68, radius);
	float veil = surround * 0.25;
	// Sparse tapered rays, fixed in simulation time: no random flicker or strobe.
	float sector = floor((angle + PI) * 8.0);
	float variation = fract(sin(sector * 41.73) * 173.31);
	float spoke = abs(fract((angle + PI) * 8.0) - 0.5);
	float tip = mix(0.32, 0.48, variation);
	float taper = smoothstep(tip, 0.92, radius);
	float ray = (1.0 - smoothstep(0.008, 0.012 + taper * 0.048, spoke));
	ray *= taper * step(0.30, variation) * (1.0 - smoothstep(0.9, 1.25, radius));
	vec3 ink = parry ? vec3(0.04, 0.12, 0.18) : vec3(0.04, 0.045, 0.075);
	COLOR = vec4(ink, clamp((veil + ray * 0.30) * strength, 0.0, 0.48));
}
