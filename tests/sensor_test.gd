extends SceneTree

func _init() -> void:
	_run.call_deferred()

func layer_of(s) -> int:
	return s.get_node("Area3D").collision_layer

func _run() -> void:
	await process_frame

	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame

	var body: Node = player.get_node("CharacterBody3D")
	var marine: Marine3D = body.get_node("Marine")
	var phaser_sensor: IREmitter3D = body.get_node("head/Phaser/sensorphaser")

	print("=== 1. registration ===")
	print("  sensors.size() = %d   (expect 5)" % marine.sensors.size())
	print("  phaser sensor in list? %s   (expect true)" % (phaser_sensor in marine.sensors))

	print("\n=== 2. all sensors under Activated ===")
	print("  state = %s" % marine.state_machine.current_state.name)
	for s in marine.sensors:
		print("    %-22s enabled=%s layer=%d" % [s.name, s.is_enabled(), layer_of(s)])

	print("\n=== 3. tagging the phaser sensor costs a life ===")
	# Pin Scout (armor 0) and re-enter Activated so armor is refreshed from the
	# new position. This test is about sensor routing, not armor -- the scene
	# default is Commander, whose armor would soak the first tag.
	marine.apply_position(load("res://resources/positions/scout.tres"))
	marine.deactivate()
	marine.activate()
	var before: int = marine.lives
	phaser_sensor.tag(null)
	print("  lives %d -> %d   (expect a drop)" % [before, marine.lives])

	print("\n=== 4. FSM reaches the phaser sensor ===")
	marine.activate()
	marine.deactivate()
	print("  deactivated: enabled=%s layer=%d  (expect false / 0)" \
		% [phaser_sensor.is_enabled(), layer_of(phaser_sensor)])
	marine.activate()
	print("  activated:   enabled=%s layer=%d  (expect true / 4)" \
		% [phaser_sensor.is_enabled(), layer_of(phaser_sensor)])

	print("\n=== 5. sensor registered while pack is DOWN must arrive disabled ===")
	marine.deactivate()
	var extra: IREmitter3D = load("res://scenes/player/sensor.tscn").instantiate()
	marine.add_child(extra)
	marine.register_sensor(extra)
	print("  pack state = %s" % marine.state_machine.current_state.name)
	print("  new sensor: enabled=%s layer=%d  (expect false / 0)" \
		% [extra.is_enabled(), layer_of(extra)])

	print("\n=== 6. unregister_sensor ===")
	print("  before: sensors.size() = %d" % marine.sensors.size())
	marine.unregister_sensor(extra)
	print("  after:  sensors.size() = %d   (expect one fewer)" % marine.sensors.size())

	print("\n=== 7. player cannot shoot their own phaser sensor ===")
	marine.activate()
	await physics_frame
	var shapecast: ShapeCast3D = body.get_node("head/playerShapecast")
	shapecast.force_shapecast_update()
	print("  phaser sensor enabled=%s layer=%d (must be live for this to mean anything)" \
		% [phaser_sensor.is_enabled(), layer_of(phaser_sensor)])
	print("  shapecast hits = %d   (expect 0)" % shapecast.get_collision_count())

	quit()
