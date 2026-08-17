## Exercises the Commander's nuke: the charge, the detonation, and the cancel.
##
## Builds a small two-team arena in code rather than loading a scene, so the roster
## is explicit and the expectations below cannot drift with scene defaults.
##
##     godot --headless --script tests/nuke_test.gd
extends SceneTree

const MARINE := "res://scenes/player/marine.tscn"
const CHARGE := 6.0

## Must be members, not locals: GDScript lambdas capture locals by value.
var detonations := 0


func _init() -> void:
	_run.call_deferred()


func spawn(team: Marine3D.Team, position_id: String) -> Marine3D:
	var marine: Marine3D = load(MARINE).instantiate()
	marine.team = team
	root.add_child(marine)
	marine.apply_position(load("res://resources/positions/%s.tres" % position_id))
	marine.activate()
	return marine


func lives_of(marines: Array) -> String:
	var out := PackedStringArray()
	for m in marines:
		out.append("%d" % m.lives)
	return ", ".join(out)


func states_of(marines: Array) -> String:
	var out := PackedStringArray()
	for m in marines:
		out.append(str(m.state_machine.current_state.name))
	return ", ".join(out)


func _run() -> void:
	await process_frame

	var commander := spawn(Marine3D.Team.RED, "commander")
	await process_frame

	# Blue team: a healthy scout, a heavy, and one scout already down to 2 lives so
	# the "at or under lives_taken dies" rule has something to bite.
	var healthy := spawn(Marine3D.Team.BLUE, "scout")
	var heavy := spawn(Marine3D.Team.BLUE, "heavy")
	var doomed := spawn(Marine3D.Team.BLUE, "scout")
	# A red teammate, to prove the blast is team-aware.
	var teammate := spawn(Marine3D.Team.RED, "medic")
	await process_frame

	doomed.lives = 2
	var enemies := [healthy, heavy, doomed]

	print("=== 1. teams resolve through node groups ===")
	print("  commander team = %s, enemy_team = %s   (expect RED / BLUE)" % [
		Marine3D.Team.keys()[commander.team], Marine3D.Team.keys()[commander.enemy_team()]])
	print("  commander sees %d enemies   (expect 3 -- the blue marines only)"
		% commander.get_enemy_marines().size())
	print("  teammate excluded? %s   (expect true)"
		% (not teammate in commander.get_enemy_marines()))
	print("  a marine never counts itself: %s   (expect true)"
		% (not commander in commander.get_enemy_marines()))

	print("\n=== 2. activating starts the charge, and does no damage yet ===")
	var runner: SpecialAbilityRunner = commander.special_runner
	var nuke := runner.get_ability() as Nuke
	print("  ability = %s, charge = %.1fs, takes %d lives" % [
		nuke.displayname, nuke.charge_time, nuke.lives_taken])
	print("  cancel_on_deactivate = %s   (expect true)" % nuke.cancel_on_deactivate)
	print("  enemy lives before: %s   (expect 8, 10, 2)" % lives_of(enemies))
	print("  try_activate() = %s" % runner.try_activate())
	print("  running? %s   (expect true)" % runner.is_running())
	print("  pack flashing? %s   (expect true)" % commander.pack_lights.is_flashing())
	print("  enemy lives immediately after: %s   (expect unchanged -- it is a charge)"
		% lives_of(enemies))

	print("\n=== 3. mid-charge, still nothing ===")
	await create_timer(CHARGE * 0.5).timeout
	print("  still running at 3s? %s   (expect true)" % runner.is_running())
	print("  enemy lives: %s   (expect still 8, 10, 2)" % lives_of(enemies))

	print("\n=== 4. it detonates ===")
	await create_timer(CHARGE * 0.5 + 0.3).timeout
	print("  running? %s   (expect false)" % runner.is_running())
	print("  pack flashing? %s   (expect false)" % commander.pack_lights.is_flashing())
	print("  enemy lives: %s   (expect 5, 7, 0)" % lives_of(enemies))
	print("  enemy states: %s   (expect Deactivated, Deactivated, Dead)" % states_of(enemies))
	print("  armor was bypassed: Heavy has armor %d but still lost %d   (expect 3 / 3)"
		% [heavy.get_armor(), 10 - heavy.lives])
	print("  teammate untouched: lives %d, state %s   (expect 20 / Activated)"
		% [teammate.lives, teammate.state_machine.current_state.name])

	print("\n=== 5. it reaches enemies who were already down ===")
	# Reset, put one enemy in Deactivated, and confirm the blast still lands --
	# take_hit() would have been swallowed by that state.
	for m in enemies:
		m.reset_gear()
		m.activate()
	healthy.deactivate()
	commander.special_points = 30
	print("  healthy is %s with %d lives" % [
		healthy.state_machine.current_state.name, healthy.lives])
	runner.try_activate()
	await create_timer(CHARGE + 0.3).timeout
	print("  after the blast: %d lives   (expect 5 -- deactivated is not immune)"
		% healthy.lives)

	print("\n=== 5b. and it restarts the respawn timer of someone already down ===")
	for m in enemies:
		m.reset_gear()
		m.activate()
	commander.special_points = 30
	# Put one enemy down with only a sliver of respawn left, then nuke. If the blast
	# were ignored by the state machine (a Deactivated -> Deactivated no-op) he would
	# pop back up almost immediately; the nuke is supposed to pin him down again.
	healthy.deactivate(0.5)
	runner.try_activate()
	await create_timer(CHARGE + 0.3).timeout
	print("  state right after the blast = %s   (expect Deactivated)"
		% healthy.state_machine.current_state.name)
	await create_timer(1.0).timeout
	print("  still down 1s later? %s   (expect Deactivated -- his 0.5s timer was reset)"
		% healthy.state_machine.current_state.name)
	await create_timer(nuke.deactivate_duration).timeout
	print("  back up after the nuke's %.1fs? %s   (expect Activated)"
		% [nuke.deactivate_duration, healthy.state_machine.current_state.name])

	print("\n=== 6. tagging the commander cancels it ===")
	for m in enemies:
		m.reset_gear()
		m.activate()
	commander.special_points = 30
	print("  try_activate() = %s" % runner.try_activate())
	print("  pack flashing? %s   (expect true)" % commander.pack_lights.is_flashing())
	var points_after_spend: int = commander.special_points
	await create_timer(1.0).timeout
	# His armor soaks the first hits, so a Commander mid-charge takes exactly `armor`
	# shot_power-1 tags to stop -- the nuke survives everything his armor eats.
	for i in commander.get_armor() - 1:
		commander.take_hit(null)
	print("  after %d tags (all soaked by armor): running? %s   (expect true)"
		% [commander.get_armor() - 1, runner.is_running()])
	commander.take_hit(null)          # the one that empties the armor and puts him down
	print("  commander state = %s   (expect Deactivated)"
		% commander.state_machine.current_state.name)
	print("  running? %s   (expect false -- cancelled)" % runner.is_running())
	print("  pack flashing? %s   (expect false)" % commander.pack_lights.is_flashing())
	await create_timer(CHARGE).timeout
	print("  enemy lives well past the charge: %s   (expect 8, 10, 8 -- untouched)"
		% lives_of(enemies))
	print("  points still spent? %d   (expect %d -- a cancel is not a refund)"
		% [commander.special_points, points_after_spend])

	print("\n=== 7. a cancelled commander can nuke again once he is back up ===")
	commander.activate()
	commander.special_points = 30
	print("  try_activate() = %s   (expect true -- not stuck 'running')" % runner.try_activate())
	runner.end()

	quit()
