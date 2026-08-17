## Verifies the MarinePosition resources load, that Marine3D adopts their stats
## and starting supply, and that the position-driven rules (fire rate, armor)
## actually bite.
extends SceneTree

const POSITIONS := ["commander", "heavy", "scout", "ammo", "medic"]

## Must be a member, not a local: GDScript lambdas capture locals by value, so
## `absorbed += 1` inside a closure would only touch a private copy.
var absorbed := 0

func _init() -> void:
	_run.call_deferred()

func load_position(id: String) -> MarinePosition:
	return load("res://resources/positions/%s.tres" % id)

func _run() -> void:
	await process_frame

	print("=== 1. all five positions load ===")
	print("  %-11s %-6s %-9s %-6s %-9s %-9s %-8s %s" % \
		["name", "slots", "cooldown", "armor", "lives", "shots", "re:lives", "re:shots"])
	var total_slots := 0
	for id in POSITIONS:
		var p := load_position(id)
		total_slots += p.team_slots
		print("  %-11s %-6d %-9.2f %-6d %-9s %-9s %-8d %d" % [
			p.display_name, p.team_slots, p.shot_cooldown, p.armor,
			"%d/%d" % [p.starting_lives, p.lives_max],
			"%d/%d" % [p.starting_shots, p.shots_max],
			p.resupply_lives, p.resupply_shots])
	print("  team size = %d   (expect 6: Scout counts twice)" % total_slots)
	print("  Scout slots = %d   (expect 2)" % load_position("scout").team_slots)

	print("\n=== 2. every position spawns with the resupply headroom it can use ===")
	# The two resupply roles are not symmetric, so this is two rules rather than one.
	# An Ammo tops up anybody, so every position must start below its shots max.
	# A Medic cannot heal themselves and a team never fields two (team_slots 1), so
	# the position that gives lives is deliberately authored full on them -- nobody
	# could ever spend that headroom. Keyed off can_give_lives rather than the name,
	# so a second healing position would inherit the exemption.
	var shots_ok := true
	var lives_ok := true
	for id in POSITIONS:
		var p := load_position(id)
		if p.starting_shots >= p.shots_max:
			shots_ok = false
			print("  %s has no shots headroom" % p.display_name)
		if not p.can_give_lives and p.starting_lives >= p.lives_max:
			lives_ok = false
			print("  %s has no lives headroom" % p.display_name)
	print("  all five leave room for an Ammo: %s   (expect true)" % shots_ok)
	print("  everyone a Medic can heal leaves room for it: %s   (expect true)" % lives_ok)
	var the_medic := load_position("medic")
	print("  Medic starts full on lives: %d/%d   (expect 20/20 -- by design, nothing can heal them)"
		% [the_medic.starting_lives, the_medic.lives_max])

	print("\n=== 3. Marine3D adopts the position's supply ===")
	var marine: Marine3D = load("res://scenes/player/marine.tscn").instantiate()
	root.add_child(marine)
	await process_frame
	print("  scene default: %s  lives %d/%d  shots %d/%d  (expect Scout 8/15, 20/40)" % [
		marine.marine_position.display_name, marine.lives, marine.lives_max,
		marine.shots, marine.shots_max])

	marine.apply_position(load_position("medic"))
	print("  after swap to Medic: lives %d/%d  shots %d/%d  (expect 20/20, 15/30)" % [
		marine.lives, marine.lives_max, marine.shots, marine.shots_max])

	print("\n=== 4. fire rate gates the trigger ===")
	marine.apply_position(load_position("scout"))
	marine.activate()
	var start_shots: int = marine.shots
	print("  Scout cooldown = %.2fs, starting shots = %d (expect 20)" % [marine.get_shot_cooldown(), start_shots])
	print("  shot 1 immediately: %s   (expect true)" % marine.shoot())
	print("  shot 2 immediately: %s   (expect false -- on cooldown)" % marine.shoot())
	print("  shots used = %d   (expect 1)" % (start_shots - marine.shots))
	await create_timer(0.35).timeout
	print("  shot 3 after 0.35s: %s   (expect true)" % marine.shoot())

	print("\n=== 5. armor is a pool, and emptying it is what puts you down ===")
	marine.hit_absorbed.connect(func(_s, _left): absorbed += 1)
	marine.apply_position(load_position("heavy"))
	marine.deactivate()
	marine.activate()          # re-enter so armor initialises from the new position
	print("  Heavy armor = %d, starting lives = %d (expect 3 / 10)" % [marine.get_armor(), marine.lives])
	marine.take_hit(null)
	marine.take_hit(null)
	print("  after 2 tags: lives = %d, absorbed = %d   (expect 10 / 2)" % [marine.lives, absorbed])
	marine.take_hit(null)
	print("  after the 3rd: lives = %d, absorbed = %d   (expect 9 / 2 -- armor reached 0)"
		% [marine.lives, absorbed])
	print("  state = %s   (expect Deactivated)" % marine.state_machine.current_state.name)

	print("\n=== 6. armor refreshes on respawn ===")
	marine.activate()
	absorbed = 0
	marine.take_hit(null)
	marine.take_hit(null)
	print("  after 2 tags on a fresh spawn: lives = %d, absorbed = %d   (expect 9 / 2)" % [marine.lives, absorbed])

	print("\n=== 6b. shot_power decides how fast armor drains ===")
	# take_hit(null) above is the shot_power-1 case. A Heavy's shot_power-3 phaser
	# should empty another Heavy's 3 armor in a single tag.
	var shooter: Marine3D = load("res://scenes/player/marine.tscn").instantiate()
	root.add_child(shooter)
	await process_frame
	shooter.apply_position(load_position("heavy"))
	marine.deactivate()
	marine.activate()
	absorbed = 0
	var lives_before: int = marine.lives
	print("  shooter shot_power = %d, target armor = %d" % [
		shooter.marine_position.shot_power, marine.get_armor()])
	marine.take_hit(shooter)
	print("  after 1 tag: lives %d -> %d, absorbed = %d   (expect a drop / 0)" % [
		lives_before, marine.lives, absorbed])

	print("\n=== 7. resupply values are carried, not yet spent ===")
	var ammo := load_position("ammo")
	var medic := load_position("medic")
	print("  Ammo  gives %d shots, %d lives" % [ammo.resupply_shots, ammo.resupply_lives])
	print("  Medic gives %d shots, %d lives" % [medic.resupply_shots, medic.resupply_lives])

	quit()
