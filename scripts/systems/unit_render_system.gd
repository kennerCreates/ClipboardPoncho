extends Node3D
class_name UnitRenderSystem
## Renders all units using MultiMesh with frustum culling
##
## Performance: Renders 200-300 visible units with only 3 draw calls
## (one per unit type) instead of 300 individual draw calls.
##
## Frustum culling: Only renders units visible to camera (200-300 of 1000 total).
## LOD can be added later based on camera zoom level.

# MultiMesh instances per unit type
# Structure: unit_type -> MultiMeshInstance3D
var multimeshes: Dictionary = {}

# Track which MultiMesh instance index maps to which unit data index
class UnitMapping:
	var unit_to_instance: Dictionary = {}  # unit_idx -> instance_idx
	var instance_to_unit: Dictionary = {}  # instance_idx -> unit_idx
	var active_count: int = 0  # How many instances are currently active

var mappings: Dictionary = {}  # unit_type -> UnitMapping

# Reference to unit data
var unit_data: UnitDataSystem

func initialize(data: UnitDataSystem) -> void:
	unit_data = data
	_initialize_multimeshes()

## Set up MultiMesh instances for each unit type
func _initialize_multimeshes() -> void:
	# Create MultiMesh for each unit type
	for unit_type in UnitDataSystem.UnitType.values():
		var unit_type_name = UnitDataSystem.UnitType.keys()[unit_type]

		# Create MultiMeshInstance3D
		var mmi = MultiMeshInstance3D.new()
		mmi.name = "MultiMesh_%s" % unit_type_name

		# Create and configure MultiMesh
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = 0  # Start with 0, will be set during update
		mm.visible_instance_count = -1  # All instances visible

		# TODO: Load actual model meshes based on unit type
		# For now, use placeholder
		mm.mesh = _create_placeholder_mesh(unit_type)

		mmi.multimesh = mm
		add_child(mmi)

		multimeshes[unit_type] = mmi

		# Initialize mapping
		mappings[unit_type] = UnitMapping.new()

## Create placeholder mesh (replace with actual models later)
func _create_placeholder_mesh(unit_type: int) -> Mesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 2.0, 1.0)

	# Different colors for different unit types
	var material = StandardMaterial3D.new()
	match unit_type:
		UnitDataSystem.UnitType.WORKER:
			material.albedo_color = Color(0.8, 0.8, 0.2)  # Yellow
		UnitDataSystem.UnitType.MARINE:
			material.albedo_color = Color(0.2, 0.8, 0.2)  # Green
		UnitDataSystem.UnitType.TANK:
			material.albedo_color = Color(0.8, 0.2, 0.2)  # Red

	mesh.material = material
	return mesh

## Main update function - called every frame
## Only renders units visible to camera (frustum culling)
func update(camera: Camera3D) -> void:
	if not unit_data:
		return

	# Get camera frustum for culling
	var frustum_planes = camera.get_frustum()

	# Reset all mappings
	for unit_type in multimeshes.keys():
		var mapping: UnitMapping = mappings[unit_type]
		mapping.unit_to_instance.clear()
		mapping.instance_to_unit.clear()
		mapping.active_count = 0

	# Process each unit
	for i in range(unit_data.unit_count):
		# Skip dead units
		if unit_data.states[i] == UnitDataSystem.UnitState.DEAD:
			continue

		var pos = unit_data.positions[i]

		# FRUSTUM CULLING - Skip off-screen units entirely
		# This is the KEY optimization for isometric camera
		if not _is_in_frustum(frustum_planes, pos):
			continue

		# Add to appropriate MultiMesh
		var unit_type = unit_data.unit_types[i]
		_add_instance(unit_type, i, pos, unit_data.rotations[i])

	# Update MultiMesh instance counts
	for unit_type in multimeshes.keys():
		var mm: MultiMeshInstance3D = multimeshes[unit_type]
		var mapping: UnitMapping = mappings[unit_type]
		mm.multimesh.instance_count = mapping.active_count

## Add an instance to a MultiMesh
func _add_instance(unit_type: int, unit_idx: int, pos: Vector3, rotation_y: float) -> void:
	var mapping: UnitMapping = mappings[unit_type]
	var mm: MultiMeshInstance3D = multimeshes[unit_type]

	var instance_idx = mapping.active_count
	mapping.active_count += 1

	# Track mapping
	mapping.unit_to_instance[unit_idx] = instance_idx
	mapping.instance_to_unit[instance_idx] = unit_idx

	# Create transform
	var unit_transform = Transform3D()
	unit_transform = unit_transform.rotated(Vector3.UP, rotation_y)
	unit_transform.origin = pos

	# Apply selection highlight
	if unit_data.is_selected(unit_idx):
		# TODO: Modify instance color for selection
		# Could use per-instance custom data in MultiMesh
		pass

	# Set instance transform
	mm.multimesh.set_instance_transform(instance_idx, unit_transform)

## Check if position is within camera frustum
## This prevents rendering units that are off-screen
func _is_in_frustum(frustum_planes: Array[Plane], pos: Vector3) -> bool:
	# A point is inside the frustum if it's on the correct side of all 6 planes
	for plane in frustum_planes:
		# Use a margin of 2.0 to account for unit size
		if plane.distance_to(pos) < -2.0:
			return false
	return true

## Debug: Get total visible units being rendered
func get_visible_unit_count() -> int:
	var total = 0
	for mapping in mappings.values():
		total += mapping.active_count
	return total

## Debug: Get unit count by type
func get_unit_count_by_type() -> Dictionary:
	var counts = {}
	for unit_type in mappings.keys():
		var type_name = UnitDataSystem.UnitType.keys()[unit_type]
		counts[type_name] = mappings[unit_type].active_count
	return counts
