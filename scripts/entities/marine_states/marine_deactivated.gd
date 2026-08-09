## Pack is powered down: cannot shoot, cannot be tagged.
##
## Covers both "the round has not started yet" and "you just got tagged and are
## sitting out your respawn delay". The difference is only whether a duration
## was handed in:
##   deactivate()             -> stays down until something reactivates it
##   deactivate(5.0)          -> powers back up after 5 seconds
extends MarineState

var _time_left := 0.0


func enter(_previous: StringName, data: Dictionary = {}) -> void:
	marine.set_sensors_enabled(false)
	_time_left = data.get("duration", 0.0)


func update(delta: float) -> void:
	if _time_left <= 0.0:
		return  # Indefinite -- wait for an external activate().
	_time_left -= delta
	if _time_left <= 0.0:
		transition_to(&"Activated")
