shader_type spatial;
render_mode depth_draw_always;


uniform vec4 albedo: source_color;

const float near_to_far_seam_start = 200.0;
const float near_to_far_seam_end = 150.0;


void vertex() {
	float distance_to_cam = length(VERTEX - CAMERA_POSITION_WORLD);
	if (distance_to_cam < near_to_far_seam_start && distance_to_cam > near_to_far_seam_end) {
		COLOR.a =
			(distance_to_cam - near_to_far_seam_end)
			/ (near_to_far_seam_start - near_to_far_seam_end);
	} else if (distance_to_cam < near_to_far_seam_end) {
		COLOR.a = 0.0;
	}
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = COLOR.a;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
