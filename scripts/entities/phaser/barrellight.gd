## A light that flashes once and fades out -- the phaser's muzzle flash.
##
## This script is attached to the light itself, so `self` is the thing being
## animated. It knows nothing about marines, shooting, or input: something else
## calls [method flash]. That keeps it reusable for hit indicators, pack lights,
## or anything else that needs a blink.
extends OmniLight3D

## Brightness at the instant of firing. Values above 1 bloom, since glow is
## enabled on the world environment.
@export var flash_energy := 6.0

## Seconds for the flash to fade back to black.
@export var flash_decay := 0.08

var _tween: Tween


func _ready() -> void:
	# Start dark. Whatever energy is set in the inspector is only there so the
	# light is visible while you position it in the editor.
	light_energy = 0.0


## Fire one flash. Safe to call again while a previous flash is still fading.
func flash() -> void:
	# A Tween is single-use, so `_tween` may be finished (invalid) or, on the
	# very first shot, still null.
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "light_energy", 0.0, flash_decay).from(flash_energy)
