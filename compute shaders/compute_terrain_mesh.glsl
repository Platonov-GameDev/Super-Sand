#[compute]
#version 450


layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer DataBuffer {
	float data[];
}
data_buffer;


void add_point_to_array(vec3 point, uint start_offset) {
	data_buffer.data[start_offset] = point.x;
	data_buffer.data[start_offset + 1] = point.y;
	data_buffer.data[start_offset + 2] = point.z;
}

void main() {
	uint heights_array_size = uint(data_buffer.data[0]);
	uint heights_array_offset = 1;
	
	uint params_offset = heights_array_offset + heights_array_size;
	float range_min = data_buffer.data[params_offset];
	float range_max = data_buffer.data[params_offset + 1];
	vec3 origin = vec3(0);
	origin.x = data_buffer.data[params_offset + 2];
	origin.y = data_buffer.data[params_offset + 3];
	origin.z = data_buffer.data[params_offset + 4];
	float step = data_buffer.data[params_offset + 5];
	
	uint out_vertex_array_size = heights_array_size * 6 * 3;
	uint out_vertex_array_offset = params_offset + 6;
	uint out_normals_array_offset = out_vertex_array_offset + out_vertex_array_size;
	
	uint side_point_count = uint((range_max - range_min) / step);
	uint x_index = gl_GlobalInvocationID.x;
	uint z_index = gl_GlobalInvocationID.y;
	uint invo_index = x_index * side_point_count + z_index;
	
	float x_offset = range_min + step * x_index;
	float z_offset = range_min + step * z_index;
	
	vec3 bot_left = origin;
	bot_left.x += x_offset;
	bot_left.z += z_offset;
	bot_left.y = data_buffer.data[heights_array_offset + invo_index];
	
	vec3 bot_right = bot_left;
	bot_right.x += step;
	bot_right.y = data_buffer.data[heights_array_offset + invo_index + side_point_count];
	
	vec3 top_left = bot_left;
	top_left.z += step;
	top_left.y = data_buffer.data[heights_array_offset + invo_index + 1];
	
	vec3 top_right = top_left;
	top_right.x += step;
	top_right.y = data_buffer.data[heights_array_offset + invo_index + side_point_count + 1];
	
	uint invo_vertex_array_offset = out_vertex_array_offset + invo_index * 6 * 3;
	add_point_to_array(bot_left, invo_vertex_array_offset);
	add_point_to_array(top_right, invo_vertex_array_offset + 3 * 1);
	add_point_to_array(top_left, invo_vertex_array_offset + 3 * 2);
	add_point_to_array(bot_left, invo_vertex_array_offset + 3 * 3);
	add_point_to_array(bot_right, invo_vertex_array_offset + 3 * 4);
	add_point_to_array(top_right, invo_vertex_array_offset + 3 * 5);
	
	vec3 normal1 = cross(top_left - bot_left, top_right - bot_left);
	vec3 normal2 = cross(top_right - bot_left, bot_right - bot_left);
	uint invo_normals_array_offset = out_normals_array_offset + invo_index * 6 * 3;
	add_point_to_array(normal1, invo_normals_array_offset);
	add_point_to_array(normal1, invo_normals_array_offset + 3 * 1);
	add_point_to_array(normal1, invo_normals_array_offset + 3 * 2);
	add_point_to_array(normal2, invo_normals_array_offset + 3 * 3);
	add_point_to_array(normal2, invo_normals_array_offset + 3 * 4);
	add_point_to_array(normal2, invo_normals_array_offset + 3 * 5);
}
