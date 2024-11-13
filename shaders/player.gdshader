shader_type spatial;
render_mode wireframe, depth_draw_always;


uniform vec4 albedo: source_color;


void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb;
	ALPHA = 1.0;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
