shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

// Procedural enemy warnings and arena accents. Player ink uses native_ink.gdshader.
uniform vec4 tint : source_color = vec4(0.12, 0.75, 0.84, 1.0);
uniform vec4 secondary : source_color = vec4(0.98, 0.76, 0.32, 1.0);
uniform int shape = 0;
uniform float progress = 0.0;
uniform float opacity = 1.0;
uniform float seed = 0.0;
uniform float spin = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float c = cos(spin), s = sin(spin);
	p = mat2(vec2(c, s), vec2(-s, c)) * p;
	float r = length(p);
	float a = atan(p.y, p.x);
	float aa = max(fwidth(r) * 1.05, 0.003);
	float alpha = 0.0;
	vec3 color = tint.rgb;
	float fade = pow(max(0.0, 1.0 - progress), 1.15);
	if (shape == 0) {
		// A tapered brush arc, not a full hoop around the face.
		float along = (a + 1.25) / 2.8;
		float taper = pow(max(0.0, sin(clamp(along, 0.0, 1.0) * PI)), 0.75);
		float radius = 0.66 + sin(a * 2.2 + seed) * 0.035;
		float width = 0.085 * taper;
		float stroke = 1.0 - smoothstep(width - aa, width + aa, abs(r - radius));
		float hairline = 1.0 - smoothstep(aa, aa * 2.5, abs(r - radius - 0.11));
		float gate = smoothstep(0.0, 0.07, along) * (1.0 - smoothstep(0.92, 1.0, along));
		alpha = (stroke + hairline * 0.42) * gate * fade;
		color = mix(tint.rgb, secondary.rgb, pow(taper, 5.0) * 0.4);
	} else if (shape == 1) {
		// Directional impact rays, with a compact warm core.
		float horizontal = (1.0 - smoothstep(0.01, max(0.011, 0.095 * (1.0 - abs(p.x))) + aa, abs(p.y))) * (1.0 - smoothstep(0.6, 0.98, abs(p.x)));
		float vertical = (1.0 - smoothstep(0.004, max(0.005, 0.055 * (1.0 - abs(p.y))) + aa, abs(p.x))) * (1.0 - smoothstep(0.25, 0.78, abs(p.y)));
		float core = 1.0 - smoothstep(0.0, 0.22, r);
		alpha = max(max(horizontal, vertical), core) * fade;
		color = mix(tint.rgb, secondary.rgb, core);
	} else if (shape == 2) {
		// Irregular ink wash; the outer edge breaks up as it disperses.
		float grain = noise(p * 10.0 + seed);
		float radius = 0.55 + sin(a * 7.0 + seed) * 0.045 + sin(a * 13.0) * 0.035;
		float edge = radius + (grain - 0.5) * 0.16;
		alpha = (1.0 - smoothstep(edge - 0.16, edge + 0.06, r)) * (0.65 + grain * 0.35);
		alpha *= fade * (0.7 + smoothstep(0.0, 0.10, progress) * 0.3);
	} else if (shape == 3) {
		// Ground shock wave: two thin, expanding edges and broken ink accents.
		float radius = mix(0.10, 0.94, 1.0 - pow(1.0 - progress, 2.0));
		float width = mix(0.035, 0.010, progress);
		float outer = 1.0 - smoothstep(width, width + aa, abs(r - radius));
		float inner = 1.0 - smoothstep(0.008, 0.008 + aa, abs(r - radius * 0.79));
		float breaks = smoothstep(-0.55, 0.0, sin(a * 13.0 + seed));
		alpha = (outer + inner * breaks * 0.55) * fade;
	} else if (shape == 4) {
		// A Taiji ink wheel with eight small, broken trigram strokes.
		float circle = 1.0 - smoothstep(0.61 - aa, 0.61 + aa, r);
		float yin = step(0.0, p.x);
		yin = mix(yin, 0.0, 1.0 - smoothstep(0.305 - aa, 0.305 + aa, length(p - vec2(0.0, 0.305))));
		yin = mix(yin, 1.0, 1.0 - smoothstep(0.305 - aa, 0.305 + aa, length(p + vec2(0.0, 0.305))));
		float dot_top = 1.0 - smoothstep(0.055 - aa, 0.055 + aa, length(p - vec2(0.0, 0.305)));
		float dot_bottom = 1.0 - smoothstep(0.055 - aa, 0.055 + aa, length(p + vec2(0.0, 0.305)));
		yin = mix(yin, 1.0, dot_top);
		yin = mix(yin, 0.0, dot_bottom);
		color = mix(tint.rgb, secondary.rgb, yin);
		float ring = 1.0 - smoothstep(0.008, 0.008 + aa, abs(r - 0.68));
		float sector = mod(a + PI / 8.0, PI / 4.0) - PI / 8.0;
		float bar_radius = 0.77 + floor(clamp((r - 0.73) / 0.06, 0.0, 2.0)) * 0.06;
		float bars = (1.0 - smoothstep(0.012, 0.012 + aa, abs(r - bar_radius))) * (1.0 - smoothstep(0.11, 0.15, abs(sector)));
		bars *= mix(1.0, smoothstep(0.025, 0.045, abs(sector)), step(0.5, fract(floor((a + PI) / (PI / 4.0)) * 0.618)));
		alpha = (circle * 0.42 + ring + bars * 0.8) * smoothstep(0.0, 0.13, progress) * (1.0 - smoothstep(0.70, 1.0, progress));
	} else if (shape == 5) {
		// Enemy ground telegraph: directional wedge with an explicit leading edge.
		float width = 0.14 + (p.x + 0.85) * 0.32;
		float edge = max(abs(p.y) - width, max(-0.85 - p.x, p.x - 0.88));
		float fill = 1.0 - smoothstep(-aa, aa, edge);
		float border = 1.0 - smoothstep(0.015, 0.015 + aa, abs(edge));
		float bars = smoothstep(0.78, 0.9, fract((p.x - p.y * 0.3) * 5.0 - progress * 2.0));
		float leading = 1.0 - smoothstep(0.025, 0.04, abs(p.x - mix(-0.8, 0.85, progress)));
		alpha = fill * (0.15 + bars * 0.13 + leading * 0.35) + border * (0.45 + progress * 0.4);
	} else if (shape == 6) {
		// Long tapered brush streak for dodge speed and condensed energy.
		float taper = pow(max(0.0, 1.0 - abs(p.x)), 0.65);
		float width = taper * 0.19;
		alpha = (1.0 - smoothstep(width, width + aa, abs(p.y))) * taper * fade;
		color = mix(tint.rgb, secondary.rgb, smoothstep(0.35, 0.85, p.x) * 0.5);
	} else if (shape == 7) {
		// A narrow falling light column, never a screen-filling white rectangle.
		float width = 0.09 + (1.0 - UV.y) * 0.13;
		float core = 1.0 - smoothstep(width * 0.4, width, abs(p.x));
		float filaments = (1.0 - smoothstep(0.012, 0.025, abs(abs(p.x) - 0.30))) * 0.4;
		alpha = (core + filaments) * smoothstep(0.0, 0.1, UV.y) * (1.0 - smoothstep(0.7, 1.0, UV.y)) * fade;
		color = mix(tint.rgb, secondary.rgb, core);
	}
	ALBEDO = color;
	ALPHA = clamp(alpha * tint.a * opacity, 0.0, 0.94);
}
