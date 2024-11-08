extends Node3D
class_name RockStructure


@export var rock_scene: PackedScene
@export var rock_mesh: PackedScene


func generate_rock_shapes():
	_generate_rocks(RockType.SHAPE)


func generate_rock_mesh_transforms() -> PackedVector3Array:
	return _generate_rocks(RockType.MESH)


enum RockType { MESH, SHAPE }
func _generate_rocks(type: RockType):
	var rock_transforms: PackedVector3Array
	for x_offset in range(0, Global.STRUCTURE_SIZE, Global.ROCK_SPACING):
		for z_offset in range(0, Global.STRUCTURE_SIZE, Global.ROCK_SPACING):
			var rock_value = Global.ROCK_NOISE.get_noise_2d(
				position.x + x_offset, position.z + z_offset)
			if rock_value >= 0.4:
				var rock
				if type == RockType.SHAPE:
					rock = rock_scene.instantiate()
				elif type == RockType.MESH:
					rock = rock_mesh.instantiate()
				
				rock.position = Vector3()
				rock.position.x = x_offset
				rock.position.z = z_offset
				rock.position.y = (
					Global.get_terrain_height_from_x_z(
						position.x + rock.position.x, position.z + rock.position.z)
						- position.y - 5 * rock_value
					)
				
				rock.scale *= (rock_value - 0.4) / 6 * 10
				rock.rotation.y = rock_value * PI * 200
				
				if type == RockType.SHAPE:
					add_child(rock)
				elif type == RockType.MESH:
					rock_transforms.append(rock.transform.basis.x)
					rock_transforms.append(rock.transform.basis.y)
					rock_transforms.append(rock.transform.basis.z)
					rock_transforms.append(rock.transform.origin + transform.origin)
	
	if type == RockType.MESH:
		return rock_transforms
