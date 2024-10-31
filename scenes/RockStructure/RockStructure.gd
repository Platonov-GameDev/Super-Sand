extends Node3D
class_name RockStructure


@export var rock_scene: PackedScene


func generate_rocks():
	for x_offset in range(0, Global.STRUCTURE_SIZE, Global.ROCK_SPACING):
		for z_offset in range(0, Global.STRUCTURE_SIZE, Global.ROCK_SPACING):
			var rock_value = Global.ROCK_NOISE.get_noise_2d(
				position.x + x_offset, position.z + z_offset)
			if rock_value >= 0.4:
				var rock = rock_scene.instantiate()
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
				
				add_child(rock)
