## Makes one named material glow, then fade -- the phaser's casing lighting up
## as it fires.
##
## Like [OmniLight3D]-based muzzle flashes, this knows nothing about marines or
## shooting: something else calls [method flash]. That keeps it reusable for
## pack lights, hit indicators, or anything else that needs a surface to pulse.
##
## It sits beside the mesh rather than on it, because the mesh comes from an
## imported .blend and nodes inside an instanced scene cannot be given scripts
## from the scene that instances them. On ready it finds the surface wearing
## [member material_name] and swaps in its own copy of that material. The copy
## matters -- the imported material is shared by every phaser in the world, so
## writing to the original would light all of them up at once.
class_name MaterialFlash
extends Node

## Where to hunt for the mesh, searched recursively. Defaults to this node's
## parent, which is the phaser root.
@export var mesh_root: Node3D

## Which material glows, by the name it carries in Blender. Matching on the name
## rather than on a surface index means re-exporting the model cannot silently
## start flashing a different part of the gun.
@export var material_name := "White Plastic"

## Colour the surface emits. Emission adds on top of the material's own albedo,
## so white on white plastic reads as the plastic being lit from within.
@export var emission_color := Color.WHITE

## Emission strength at the instant of firing. Values above 1 bloom, since glow
## is enabled on the world environment.
@export var flash_energy := 4.0

## Seconds for the glow to fade back down. A little longer than the barrel
## light's, so the casing is still cooling off once the muzzle flash is gone.
@export var flash_decay := 0.12

## Our private copy of the material. Null if the surface was never found, which
## is the one case where [method flash] does nothing.
var _material: BaseMaterial3D

## What the material glowed at before we touched it -- normally nothing, but a
## material that was already emissive fades back to its own level, not to black.
var _rest_energy := 0.0

var _tween: Tween


func _ready() -> void:
	if mesh_root == null:
		mesh_root = get_parent() as Node3D
	if mesh_root == null:
		push_error("MaterialFlash '%s' has no mesh_root to search." % name)
		return

	_material = _claim_material()
	if _material == null:
		return

	_rest_energy = _material.emission_energy_multiplier if _material.emission_enabled else 0.0
	# Enabled here rather than on the first shot: switching emission on rebuilds
	# the material's shader, and that hitch belongs at load, not mid-firefight.
	_material.emission_enabled = true
	_material.emission = emission_color
	_material.emission_energy_multiplier = _rest_energy


## Light the material up once. Safe to call again while a previous flash is
## still fading.
func flash() -> void:
	if _material == null:
		return

	# A Tween is single-use, so `_tween` may be finished (invalid) or, on the
	# very first shot, still null.
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_material, "emission_energy_multiplier", _rest_energy, flash_decay) \
		.from(flash_energy)


## The copy of the material this node drives, for anything that wants to read or
## re-tint the flashing surface. Null until [method _ready] has claimed it.
func get_material() -> BaseMaterial3D:
	return _material


# -- Internals -----------------------------------------------------------------

## Takes over the surface wearing [member material_name] and returns a private
## copy of its material, or null -- having said why -- if there is no such
## surface.
func _claim_material() -> BaseMaterial3D:
	var seen := PackedStringArray()

	for mesh_instance in _collect_meshes():
		if mesh_instance.mesh == null:
			continue

		for surface in mesh_instance.mesh.get_surface_count():
			# An override, where the scene set one, is what actually gets drawn.
			var current: Material = mesh_instance.get_surface_override_material(surface)
			if current == null:
				current = mesh_instance.mesh.surface_get_material(surface)
			if current == null:
				continue

			if current.resource_name != material_name:
				seen.append(current.resource_name)
				continue

			# A ShaderMaterial would cast to null here: no emission to drive.
			var copy := current.duplicate() as BaseMaterial3D
			if copy == null:
				push_error("MaterialFlash '%s': '%s' is not a BaseMaterial3D."
					% [name, material_name])
				return null

			mesh_instance.set_surface_override_material(surface, copy)
			return copy

	push_error("MaterialFlash '%s' found no material named '%s'. Saw: %s."
		% [name, material_name, ", ".join(seen)])
	return null


## Finds meshes by type rather than by hardcoded node path, so re-exporting the
## model -- or moving it in the scene -- needs no code change.
func _collect_meshes() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	# find_children() never returns the node it was called on, so a mesh_root
	# that is itself the mesh has to be added by hand.
	var root_mesh := mesh_root as MeshInstance3D
	if root_mesh != null:
		found.append(root_mesh)
	for node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		found.append(node)
	return found
