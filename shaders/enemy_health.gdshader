shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;

uniform float health_ratio : hint_range(0.0,1.0) = 1.0;
uniform vec4 border_color : source_color = vec4(0.03137,0.08235,0.12157,1.0);
uniform vec4 empty_color : source_color = vec4(0.24314,0.16078,0.19608,1.0);
uniform vec4 health_color : source_color = vec4(0.93725,0.46275,0.32549,1.0);

void vertex() {
 // One camera-facing surface draws the frame, background and fill. Separate
 // depth-test-disabled opaque quads can reorder and cover a healthy fill.
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
 vec2 inset = vec2(0.04/1.12,0.0275/0.13);
 bool inner = all(greaterThanEqual(UV,inset)) && all(lessThanEqual(UV,vec2(1.0)-inset));
 float progress = (UV.x-inset.x)/(1.0-2.0*inset.x);
 ALBEDO = !inner ? border_color.rgb : progress < health_ratio ? health_color.rgb : empty_color.rgb;
}
