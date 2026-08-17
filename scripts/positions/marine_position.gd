## One playable position (Commander, Heavy, Scout, Ammo, Medic).
##
## Pure data -- no nodes, no behaviour. Each position is saved as a .tres under
## res://resources/positions/ and assigned to a [Marine3D], which copies the
## stats into its gear on ready. Swapping the resource swaps the whole loadout,
## which is what makes between-round position changes cheap.
class_name MarinePosition
extends Resource

## Name shown on scoreboards and the position-select screen.
@export var display_name := "Marine"

## How many of this position one team may field. Every position is 1 except
## Scout, which is 2. Enforcement belongs to a roster manager, not here -- this
## is just the number it will check against.
@export var team_slots := 1

## Seconds between shots. Lower is faster.
@export var shot_cooldown := 0.5

## Armor. A pool the shooter's [member shot_power] eats into, refilled on every
## respawn. Emptying it is what puts this marine down: the shot that takes the last
## point is the one that costs a life. Armor 0 means every tag costs a life.
##
## So a Commander (armor 3) goes down on the third hit from a shot_power-1 phaser,
## but on the *first* from a Heavy's shot_power-3 one.
@export var armor := 1

## Shot Power. The amount of armor that each shot taken by this marine removes from their opponent.
@export var shot_power := 1

@export var lives_max := 20
@export var shots_max := 50

## What a marine spawns with. Authored per position rather than derived from the
## maxima, so each one can be tuned independently. Deliberately below the maxima
## to leave headroom for a Medic or Ammo -- a marine that spawns full has nothing
## to resupply.
@export var starting_lives := 10
@export var starting_shots := 25


## Lives this position gets from a medic.
@export var resupply_lives := 3

## Shots this position gets from an ammo.
@export var resupply_shots := 3

## Special flag that marks this position as being able to give ammo. For ammos.
@export var can_give_shots := false

## Special flag that marks this position as having unlimited ammo. For ammos.
@export var unlimited_ammo := false

## Special flag that marks this position as being able to give lives. For medics.
@export var can_give_lives := false

## Amount of missiles this postion has. 0 Defaults to "This position doesn't have missiles"
@export var missiles_max := 0

## Current amount of special points that this position has.
@export var special_points := 0

## Max amount of special points that this position can hold.
@export var special_points_max := 99

## The special ability assigned to this position.
@export var special_ability: SpecialAbility
