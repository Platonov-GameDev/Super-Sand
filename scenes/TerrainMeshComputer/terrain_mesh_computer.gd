extends Node


var rd := RenderingServer.create_local_rendering_device()

var shader_file := load("res://compute shaders/compute_terrain_mesh.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)


func compute_mesh(
	input_array: PackedFloat32Array, side_invocations_count: int
) -> PackedFloat32Array:
	var input_bytes := input_array.to_byte_array()
	
	var buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)
	
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0
	uniform.add_id(buffer)
	var uniform_set := rd.uniform_set_create([uniform], shader, 0)
	
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	var side_groups_count = int(side_invocations_count / 8.0)
	rd.compute_list_dispatch(compute_list, side_groups_count, side_groups_count, 1)
	rd.compute_list_end()
	
	rd.submit()
	rd.sync()
	
	var output_bytes := rd.buffer_get_data(buffer)
	var output_array := output_bytes.to_float32_array()
	
	rd.free_rid(buffer)
	rd.free_rid(pipeline)
	
	return output_array
