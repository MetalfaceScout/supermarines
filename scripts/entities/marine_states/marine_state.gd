## Base class for every state a [Marine3D]'s pack can be in.
##
## This is where the marine's *verbs* live. Each verb is a no-op here, and each
## state overrides only the ones it actually allows. That is the whole point of
## the pattern: instead of Marine3D asking "am I dead? am I deactivated?" before
## every action, it just forwards the verb and lets the current state answer.
class_name MarineState
extends State

## Typed view of [member State.agent]. No backing storage -- it just casts.
var marine: Marine3D:
	get: return agent as Marine3D


## The trigger was pulled. Returns true if a shot actually left the phaser, so
## the caller knows whether to bother resolving a hit. Default: nothing happens.
func shoot() -> bool:
	return false


## One of this marine's sensors was tagged by [param source].
## Default: ignore it, the pack is not live.
func take_hit(_source: Node) -> void:
	pass
