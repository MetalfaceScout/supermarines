class_name SpecialAbility

extends Resource

## Base definition of a Special Ability

@export var displayname := "Special"
@export var special_points_cost := 10
@export var cancel_on_deactivate := false

## Can we activate the ability?
func can_activate(_runner: SpecialAbilityRunner) -> bool:
	return true
	
## Activate the ability. Easy change for rapid fire, not so easy for nukes
func activate(_runner: SpecialAbilityRunner) -> void:
	pass
	
## Most abilities don't deactivate, but included for completeness
func deactivate(_runner: SpecialAbilityRunner) -> void:
	pass

## Abilities that do something on completion (nukes) activate here
func complete(_runner: SpecialAbilityRunner) -> void:
	pass
