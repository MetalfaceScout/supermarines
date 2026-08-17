## Exercises the Marine3D state machine in isolation (marine.tscn standalone).
## Pins the Scout position so results do not shift when scene defaults or
## position balance change: Scout is armor 0 (every hit costs a life) and starts
## at 8/15 lives, 20/40 shots.
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame

	var marine: Marine3D = load("res://scenes/player/marine.tscn").instantiate()
	root.add_child(marine)
	await process_frame

	marine.apply_position(load("res://resources/positions/scout.tres"))

	marine.state_changed.connect(func(f, t): print("  state: %s -> %s" % [f if f != &"" else "<none>", t]))
	marine.tagged.connect(func(_s, l): print("  tagged, lives left: %d" % l))
	marine.died.connect(func(): print("  DIED"))
	marine.out_of_shots.connect(func(): print("  click (empty)"))

	print("position: %s   lives %d/%d  shots %d/%d  armor %d" % [
		marine.marine_position.display_name, marine.lives, marine.lives_max,
		marine.shots, marine.shots_max, marine.get_armor()])
	print("sensors found: %d" % marine.sensors.size())
	print("start state: %s   sensors live: %s" % [marine.state_machine.current_state.name, marine.sensors[0].is_enabled()])

	print("\n-- shooting while deactivated --")
	print("  shot went out: %s" % marine.shoot())
	marine.take_hit(null)
	print("  lives after hit while down: %d (expect 8)" % marine.lives)

	print("\n-- activating --")
	marine.activate()
	print("  sensors live: %s" % marine.sensors[0].is_enabled())
	print("  shot went out: %s   shots left: %d (expect 19)" % [marine.shoot(), marine.shots])

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
	print("  lives: %d  shots: %d (expect 8 / 20)" % [marine.lives, marine.shots])

	print("\n-- empty magazine --")
	marine.shots = 0
	print("  shot went out: %s" % marine.shoot())

	print("\n-- unknown state name --")
	marine.state_machine.transition_to(&"Nope")

	quit()
