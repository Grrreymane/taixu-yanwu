shader_type canvas_item;
render_mode unshaded;

uniform vec2 center = vec2(0.5);
uniform float aspect = 1.6;
uniform float weight = 0.0;
uniform float pulse = 0.0;
uniform bool ink = false;
uniform vec4 accent : source_color = vec4(0.7, 0.85, 0.9, 1.0);

void fragment() {
	vec2 p = (UV - center) * vec2(aspect, 1.0);
	float radius = length(p);
	float edge = smoothstep(0.29, 0.85, radius);
	float angle = atan(p.y, p.x);
	float sector = floor((angle + PI) * 11.0);
	float variation = fract(sin(sector * 21.73) * 173.31);
	float spoke = abs(fract((angle + PI) * 11.0) - 0.5);
	float ray = (1.0 - smoothstep(0.006, 0.02, spoke)) * step(0.56, variation);
	ray *= smoothstep(0.35, 0.72, radius) * pulse;
	vec3 shade = ink ? vec3(0.05, 0.08, 0.1) : vec3(0.025, 0.025, 0.05);
	float veil = edge * (ink ? 0.09 : 0.35);
	float line_alpha = ray * (ink ? 0.18 : 0.22);
	vec3 color = mix(shade, ink ? shade : accent.rgb, line_alpha / max(veil + line_alpha, 0.001));
	COLOR = vec4(color, min(0.45, veil + line_alpha) * weight);
}
