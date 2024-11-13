shader_type spatial;
render_mode depth_draw_always, wireframe;


uniform vec4 albedo: source_color;
uniform float seam_start = 200.0;
uniform float seam_end = 150.0;


void vertex() {
	float distance_to_cam = length(VERTEX - CAMERA_POSITION_WORLD);
	if (seam_end < seam_start) {
		if (distance_to_cam < seam_start && distance_to_cam > seam_end) {
			COLOR.a =
				(distance_to_cam - seam_end)
				/ (seam_start - seam_end);
		} else if (distance_to_cam < seam_end) {
			COLOR.a = 0.0;
		}
	} else {
		if (distance_to_cam < seam_end && distance_to_cam > seam_start) {
			COLOR.a =
				(seam_end - distance_to_cam)
				/ (seam_end - seam_start);
		} else if (distance_to_cam > seam_start) {
			COLOR.a = 0.0;
		}
	}
}

void fragment() {
	ALBEDO = albedo.rgb / 2.0;
	ALPHA = COLOR.a;
	EMISSION = albedo.rgb / 2.0;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
