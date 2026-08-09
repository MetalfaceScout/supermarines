extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame

	var marine: Marine3D = load("res://scenes/player/marine.tscn").instantiate()
	root.add_child(marine)
	await process_frame

	marine.state_changed.connect(func(f, t): print("  state: %s -> %s" % [f if f != &"" else "<none>", t]))
	marine.tagged.connect(func(_s, l): print("  tagged, lives left: %d" % l))
	marine.died.connect(func(): print("  DIED"))
	marine.out_of_shots.connect(func(): print("  click (empty)"))

	print("sensors found: %d" % marine.sensors.size())
	print("start state: %s   sensors live: %s" % [marine.state_machine.current_state.name, marine.sensors[0].is_enabled()])

	print("\n-- shooting while deactivated --")
	print("  shot went out: %s" % marine.shoot())
	marine.take_hit(null)
	print("  lives after hit while down: %d (expect 15)" % marine.lives)

	print("\n-- activating --")
	marine.activate()
	print("  sensors live: %s" % marine.sensors[0].is_enabled())
	print("  shot went out: %s   shots left: %d" % [marine.shoot(), marine.shots])

	print("\n-- taking a hit (should drop to Deactivated for respawn_delay) --")
	marine.take_hit(null)
	print("  sensors live: %s (expect false)" % marine.sensors[0].is_enabled())

	print("\n-- draining lives to zero --")
	marine.activate()
	marine.lives = 1
	marine.take_hit(null)
	print("  shot while dead: %s" % marine.shoot())
	marine.take_hit(null)
	print("  lives while dead: %d (expect 0)" % marine.lives)

	print("\n-- reset + reactivate --")
	marine.reset_gear()
	marine.activate()
	print("  lives: %d  shots: %d" % [marine.lives, marine.shots])

	print("\n-- empty magazine --")
	marine.shots = 0
	print("  shot went out: %s" % marine.shoot())

	print("\n-- unknown state name --")
	marine.state_machine.transition_to(&"Nope")

	quit()
