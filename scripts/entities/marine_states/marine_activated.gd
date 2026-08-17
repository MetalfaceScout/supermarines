## Pack is live: sensors register hits and the phaser fires.
##
## Both rate of fire and armor come from the marine's [MarinePosition], so a
## Scout and a Heavy share this script and differ only by resource.
extends MarineState

## Seconds the pack stays down after taking a hit, before coming back up.
@export var respawn_delay := 5.0

## Time left before the phaser can fire again.
var _cooldown := 0.0

## Hits still soakable before one costs a life.
var _armor_left := 0


func enter(_previous: StringName, _data: Dictionary = {}) -> void:
	marine.set_sensors_enabled(true)
	# Both refresh on every respawn, not just at the start of a round.
	_cooldown = 0.0
	_armor_left = marine.get_armor()


func exit() -> void:
	marine.set_sensors_enabled(false)
	# Leaving the live state is the nuke's cancel. The runner decides whether the
	# ability actually dies -- Rapid Fire opts out and survives a respawn.
	marine.special_runner.on_pack_down()


func update(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func shoot() -> bool:
	if _cooldown > 0.0:
		return false

	if marine.shots <= 0:
		marine.out_of_shots.emit()
		return false

	marine.shots -= 1
	_cooldown = marine.get_shot_cooldown()
	marine.shot_fired.emit(marine.shots)
	return true


## Armor is a pool the shooter's [member MarinePosition.shot_power] eats into, not a
## count of hits. Emptying it is what puts a marine down, so the shot that takes the
## last of it is also the shot that costs a life -- a Commander with 3 armor goes
## down on the third hit from a shot_power-1 phaser, not the fourth.
func take_hit(source: Node) -> void:
	_armor_left -= _shot_power_of(source)
	if _armor_left > 0:
		marine.hit_absorbed.emit(source, _armor_left)
		return

	marine.lives -= 1
	marine.tagged.emit(source, marine.lives)

	if marine.lives <= 0:
		transition_to(&"Dead")
	else:
		transition_to(&"Deactivated", {"duration": respawn_delay})


## How hard [param source] hits. Falls back to 1 for a tag with no marine behind it
## -- a test, or damage from something that is not a phaser.
func _shot_power_of(source: Node) -> int:
	var shooter := source as Marine3D
	if shooter == null or shooter.marine_position == null:
		return 1
	return maxi(shooter.marine_position.shot_power, 1)

func use_special() -> void:
	marine.special_runner.try_activate()
