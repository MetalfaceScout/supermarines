## Rapid Fire: the phaser cycles faster and the trigger holds down.
##
## This is the reference example of a *sustained* special -- one that changes
## something about the marine and leaves it changed until something else ends it.
## There is deliberately no timer: Rapid Fire runs until the Scout takes a
## resupply, which is the trade that balances it. You empty your magazine much
## faster than normal, and the moment you go to an Ammo to fix that, you lose the
## buff.
##
## The pattern to copy is the split: [method activate] only writes runtime fields
## on the marine, [method deactivate] puts them back, and [SpecialAbilityRunner]
## decides when each one happens. Nothing here touches the shared
## [MarinePosition], so a Scout running the special does not buff every other
## Scout on the map.
##
## Contrast with a one-shot special like [Nuke], which does all its work in
## [method activate] and never implements [method deactivate].
class_name RapidFire
extends SpecialAbility


## Multiplier on the position's own [member MarinePosition.shot_cooldown]. This is
## a *scale* rather than a flat cooldown so the ability stays position-agnostic:
## hand it to a Heavy and it speeds them up by the same proportion, without a
## Scout and a Heavy needing two separate resources.
##
## Note this is not zero and should not be: the shot cooldown is what makes full
## auto a fire *rate* instead of one shot per frame.
@export_range(0.05, 1.0, 0.05) var cooldown_scale := 0.4

## Whether holding the trigger keeps firing, instead of one shot per click. The
## rate limit is still the cooldown above -- full auto does not fire faster, it
## just saves the player's finger.
@export var full_auto := true


## No `can_activate` override: [method SpecialAbilityRunner.try_activate] already
## refuses while another special is running, so a stacking check here would be dead
## code. Override it only for a condition specific to *this* ability.


func activate(runner: SpecialAbilityRunner) -> void:
	var marine := runner.marine
	marine.shot_cooldown_scale = cooldown_scale
	marine.full_auto = full_auto
	# No run_for() call: leaving the runner's clock at zero is what makes this
	# special indefinite. See [method SpecialAbilityRunner.end] for who stops it.


func deactivate(runner: SpecialAbilityRunner) -> void:
	var marine := runner.marine
	marine.shot_cooldown_scale = 1.0
	marine.full_auto = false
