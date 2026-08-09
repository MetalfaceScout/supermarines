## Pack is live: sensors register hits and the phaser fires.
extends MarineState

## Seconds the pack stays down after taking a hit, before coming back up.
@export var respawn_delay := 5.0


func enter(_previous: StringName, _data: Dictionary = {}) -> void:
	marine.set_sensors_enabled(true)


func exit() -> void:
	marine.set_sensors_enabled(false)


func shoot() -> bool:
	if marine.shots <= 0:
		marine.out_of_shots.emit()
		return false
	marine.shots -= 1
	marine.shot_fired.emit(marine.shots)
	return true


func take_hit(source: Node) -> void:
	marine.lives -= 1
	marine.tagged.emit(source, marine.lives)

	if marine.lives <= 0:
		transition_to(&"Dead")
	else:
		transition_to(&"Deactivated", {"duration": respawn_delay})
