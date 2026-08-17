## Checks that firing makes the phaser's white material emissive, and that the
## glow fades back down afterwards.
##
##     godot --headless --script tests/glow_test.gd
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame

	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame

	var body: Node = player.get_node("CharacterBody3D")
	var marine: Marine3D = body.get_node("Marine")
	var phaser: Node3D = body.get_node("head/Phaser")
	var glow: MaterialFlash = phaser.get_node("barrelglow")

	print("=== 1. the material was found and copied ===")
	var material: BaseMaterial3D = glow.get_material()
	print("  material found? %s   (expect true)" % (material != null))
	if material == null:
		# _claim_material() has already pushed an error naming what it did see.
		quit(1)
		return
	print("  name = '%s'   (expect '%s')" % [material.resource_name, glow.material_name])
	print("  emission_enabled = %s   (expect true)" % material.emission_enabled)
	print("  starts dark? %s   (expect true)" % is_zero_approx(material.emission_energy_multiplier))

	print("\n=== 2. the shared original was left alone ===")
	# Every phaser in the world draws from the same imported material, so the
	# one we animate must not be that one.
	var mesh: MeshInstance3D = phaser.find_children("*", "MeshInstance3D", true, false)[0]
	var is_shared := false
	for surface in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_material(surface) == material:
			is_shared = true
	print("  copy is its own resource? %s   (expect true)" % (not is_shared))

	print("\n=== 3. firing lights it up ===")
	# player.tscn leaves the marine's position unset, so gear must be handed in
	# before there is anything to shoot.
	marine.apply_position(load("res://resources/positions/commander.tres"))
	marine.activate()
	print("  shoot() = %s   (expect true)" % marine.shoot())
	# The tween writes its starting value on its first processed frame, not when
	# the signal fires, so the glow is one frame behind the shot.
	await process_frame
	var lit: float = material.emission_energy_multiplier
	print("  emission = %.2f   (expect > 0, near %.1f -- it starts decaying at once)"
		% [lit, glow.flash_energy])

	print("\n=== 4. and it fades back down ===")
	await create_timer(glow.flash_decay + 0.1).timeout
	print("  emission = %.2f   (expect back to 0)" % material.emission_energy_multiplier)

	print("\n=== 5. a trigger pull that fires nothing does not glow ===")
	# Deactivated rather than out of shots: a spent magazine would also be
	# blocked by the shot cooldown, which would pass this for the wrong reason.
	marine.deactivate()
	var before: float = material.emission_energy_multiplier
	print("  shoot() = %s   (expect false)" % marine.shoot())
	await process_frame
	print("  emission %.2f -> %.2f   (expect no change)"
		% [before, material.emission_energy_multiplier])

	quit()
