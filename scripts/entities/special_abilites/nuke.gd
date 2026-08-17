## The Commander's nuke: a telegraphed strike on the whole enemy team.
##
## This is the reference example of a *charged* special. Activation does not do the
## damage -- it only starts the pack flashing and hands the runner a clock. The
## payoff lives in [method complete], which the runner reaches only if the charge
## ran its full length. That split is the cancel mechanic: tag the commander during
## his six seconds and the nuke never lands, while his points stay spent.
##
## Contrast with [RapidFire], which is sustained rather than charged: it does its
## work up front in `activate()` and never implements `complete()`.
class_name Nuke
extends SpecialAbility

## Seconds between the trigger and the blast. The commander's pack flashes for this
## whole window, so it is a warning to the enemy team as much as it is a timer --
## and it is the window in which they can stop him.
@export var charge_time := 6.0

## Amount of lives that the nuke takes from each enemy player. Unconditional: armor
## does not soak this and being deactivated does not dodge it. Anyone sitting on
## this many or fewer dies.
@export var lives_taken := 3

## How long survivors stay down afterwards. 0 leaves them down until something
## powers them back up.
@export var deactivate_duration := 5.0


func activate(runner: SpecialAbilityRunner) -> void:
	runner.marine.set_pack_flashing(true)
	runner.run_for(charge_time)


func complete(runner: SpecialAbilityRunner) -> void:
	for enemy in runner.marine.get_enemy_marines():
		enemy.take_lives(lives_taken, runner.marine)
		# take_lives() already sent anyone it emptied to Dead. Deactivating them now
		# would transition Dead -> Deactivated and quietly bring them back, so the
		# survivors are the only ones we touch again.
		if enemy.is_alive():
			enemy.deactivate(deactivate_duration)


## Runs on both endings, so the lights go out whether the nuke landed or was
## cancelled.
func deactivate(runner: SpecialAbilityRunner) -> void:
	runner.marine.set_pack_flashing(false)
