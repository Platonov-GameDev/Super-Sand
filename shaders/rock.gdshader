shader_type spatial;
render_mode depth_draw_always;


uniform vec4 albedo: source_color;


void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = 0.7;
	EMISSION = albedo.rgb;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
