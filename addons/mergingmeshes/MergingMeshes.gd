@icon("res://addons/mergingmeshes/icons8-mesh-32.png")
extends Node3D

@export var meshes : Array[MeshInstance3D]
@export var GeneralMaterial : Material
@export var HideSource : bool = true
@export var GenerateLightmapUVs : bool = true
@export var LightmapScale : float = 16.0  # Texels per unit for lightmap

func merge_multiple_meshes(meshes_to_merge: Array) -> ArrayMesh:
	var array_mesh = ArrayMesh.new()
	var surface_tool = SurfaceTool.new()

	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for mesh_instance in meshes_to_merge:
		if mesh_instance is MeshInstance3D and mesh_instance.mesh:
			var transform: Transform3D = mesh_instance.global_transform
			var source_mesh = mesh_instance.mesh
			
			# Check if source has lightmap UVs
			var has_lightmap_uvs = false
			for i in range(source_mesh.get_surface_count()):
				var arrays = source_mesh.surface_get_arrays(i)
				if arrays.size() > Mesh.ARRAY_TEX_UV2 and arrays[Mesh.ARRAY_TEX_UV2] != null:
					has_lightmap_uvs = true
					break
			
			# Append each surface
			for i in range(source_mesh.get_surface_count()):
				surface_tool.append_from(source_mesh, i, transform)
	
	surface_tool.generate_normals()
	surface_tool.generate_tangents()
	
	var merged_mesh = surface_tool.commit()
	
	# Generate lightmap UVs if needed
	if GenerateLightmapUVs:
		merged_mesh = generate_lightmap_uvs(merged_mesh)
	
	return merged_mesh

func generate_lightmap_uvs(mesh: ArrayMesh) -> ArrayMesh:
	# Create a new surface tool with lightmap UVs
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(mesh, 0)
	
	# Generate lightmap UVs
	surface_tool.generate_tangents()
	
	# Godot 4.x uses LightmapGI's built-in UV2 generation
	# But we need to set the hint
	var new_mesh = surface_tool.commit()
	
	# Set mesh flags for lightmap baking
	new_mesh.lightmap_size_hint = Vector2i(
		int(mesh.get_aabb().size.x * LightmapScale),
		int(mesh.get_aabb().size.y * LightmapScale)
	)
	
	return new_mesh

func _ready():
	# Create merged mesh
	var new_mesh = merge_multiple_meshes(meshes)
	
	# Create mesh instance
	var inst = MeshInstance3D.new()
	inst.name = "MergedMesh"
	add_child(inst)
	inst.mesh = new_mesh
	
	# Apply material if specified
	if GeneralMaterial != null:
		inst.material_override = GeneralMaterial
	
	# IMPORTANT: Set gi_mode for lightmap baking
	inst.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	
	# Kill lightmap scale
	# inst.lightmap_scale = GeometryInstance3D.LIGHTMAP_SCALE_1X  # or 0.5X, 2X, 4X, 8X
	
	# Hide source meshes if requested
	if HideSource:
		for mesh_inst in meshes:
			if is_instance_valid(mesh_inst):
				mesh_inst.visible = false
	
	# Optional: Print debug info
	print("Merged mesh created for LightmapGI baking")
	print("Mesh AABB: ", new_mesh.get_aabb())
	# print("Lightmap scale: ", inst.lightmap_scale)
