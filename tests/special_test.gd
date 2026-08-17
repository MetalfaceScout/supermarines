## Exercises the special-ability plumbing through the Scout's Rapid Fire.
##
## Pins Scout deliberately: it is the only position that currently grants an
## ability, and its 0.25s cooldown makes the buffed rate easy to read.
##
##     godot --headless --script tests/special_test.gd
extends SceneTree

## Must be members, not locals: GDScript lambdas capture locals by value, so
## incrementing inside a signal handler would only touch a private copy.
var activated := 0
var ended := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame

	var marine: Marine3D = load("res://scenes/player/marine.tscn").instantiate()
	root.add_child(marine)
	await process_frame

	marine.apply_position(load("res://resources/positions/scout.tres"))
	var runner: SpecialAbilityRunner = marine.special_runner
	runner.special_activated.connect(func(_a): activated += 1)
	runner.special_ended.connect(func(_a): ended += 1)

	print("=== 1. the Scout's position grants Rapid Fire ===")
	var ability := runner.get_ability()
	print("  ability = %s   (expect Rapid Fire)" % (ability.displayname if ability else "<none>"))
	print("  is RapidFire? %s   (expect true)" % (ability is RapidFire))
	print("  cost = %d, marine has %d/%d points" % [
		ability.special_points_cost, marine.special_points, marine.special_points_max])
	print("  running? %s   (expect false)" % runner.is_running())

	print("\n=== 2. baseline fire rate, before any special ===")
	marine.activate()
	print("  cooldown = %.3fs   (expect 0.250 -- the Scout's own)" % marine.get_shot_cooldown())
	print("  full_auto = %s   (expect false)" % marine.full_auto)

	print("\n=== 3. activating spends the points and buffs the gear ===")
	var points_before: int = marine.special_points
	print("  try_activate() = %s   (expect true)" % runner.try_activate())
	print("  points %d -> %d   (expect a drop of %d)" % [
		points_before, marine.special_points, ability.special_points_cost])
	print("  running? %s   (expect true)" % runner.is_running())
	print("  cooldown = %.3fs   (expect 0.100 = 0.25 * 0.4)" % marine.get_shot_cooldown())
	print("  full_auto = %s   (expect true)" % marine.full_auto)
	print("  special_activated fired %d time(s)   (expect 1)" % activated)

	print("\n=== 4. the faster cooldown actually gates the trigger ===")
	# 0.15s is longer than the buffed 0.10s but shorter than the Scout's own
	# 0.25s, so a shot landing here proves the buff is what let it through.
	print("  shot 1: %s   (expect true)" % marine.shoot())
	print("  shot 2 immediately: %s   (expect false -- still cooling)" % marine.shoot())
	await create_timer(0.15).timeout
	print("  shot 3 after 0.15s: %s   (expect true -- unbuffed this would fail)" % marine.shoot())

	print("\n=== 5. it does not stack ===")
	points_before = marine.special_points
	print("  try_activate() again = %s   (expect false)" % runner.try_activate())
	print("  points %d -> %d   (expect unchanged -- a refused activation is free)" % [
		points_before, marine.special_points])

	print("\n=== 6. it runs indefinitely -- no timer ends it ===")
	await create_timer(0.5).timeout
	print("  still running after 0.5s? %s   (expect true)" % runner.is_running())

	print("\n=== 7. end() restores the gear ===")
	# This is the hook a resupply will call once Ammo/Medic exist.
	runner.end()
	print("  running? %s   (expect false)" % runner.is_running())
	print("  cooldown = %.3fs   (expect back to 0.250)" % marine.get_shot_cooldown())
	print("  full_auto = %s   (expect false)" % marine.full_auto)
	print("  special_ended fired %d time(s)   (expect 1)" % ended)
	runner.end()
	print("  end() again is a no-op: ended = %d   (expect still 1)" % ended)

	print("\n=== 8. an activation you cannot afford changes nothing ===")
	marine.special_points = 0
	print("  try_activate() = %s   (expect false)" % runner.try_activate())
	print("  full_auto = %s   (expect false)" % marine.full_auto)

	print("\n=== 9. a position with no ability declines cleanly ===")
	marine.apply_position(load("res://resources/positions/heavy.tres"))
	print("  Heavy ability = %s   (expect <none>)" % runner.get_ability())
	print("  try_activate() = %s   (expect false, no crash)" % runner.try_activate())

	print("\n=== 10. changing position drops a running special ===")
	marine.apply_position(load("res://resources/positions/scout.tres"))
	marine.activate()
	runner.try_activate()
	print("  running as Scout? %s   (expect true)" % runner.is_running())
	marine.apply_position(load("res://resources/positions/heavy.tres"))
	print("  after swap to Heavy: running? %s   (expect false)" % runner.is_running())
	print("  full_auto = %s   (expect false -- gear was restored)" % marine.full_auto)
	print("  cooldown = %.3fs   (expect 0.650 -- the Heavy's own)" % marine.get_shot_cooldown())

	quit()
