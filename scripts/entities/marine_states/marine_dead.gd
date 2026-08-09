## Out of lives. Cannot shoot, cannot be tagged, and will not come back on its
## own -- something external has to call [method Marine3D.reset_gear] and then
## [method Marine3D.activate], e.g. at the start of the next round.
##
## Both verbs stay inherited no-ops, which is exactly the behaviour we want.
extends MarineState


func enter(_previous: StringName, _data: Dictionary = {}) -> void:
	marine.set_sensors_enabled(false)
	marine.died.emit()
