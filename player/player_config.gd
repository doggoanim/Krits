class_name PlayerConfig
extends Resource
## All movement tunables in one place. Duplicate/edit the .tres to tweak the feel.

@export_group("Ground")
@export var walk_speed := 8.0
@export var ground_accel := 70.0
@export var ground_decel := 90.0
@export var turn_speed := 18.0
@export var crouch_speed := 3.0

@export_group("Air")
@export var gravity := 32.0
@export var fall_gravity_mult := 1.35
@export var terminal_velocity := 45.0
@export var air_speed := 8.0
@export var air_accel := 22.0
@export var air_steer_rate := 2.2          ## rad/s steering while carrying extra momentum
@export var momentum_drag := 1.5           ## speed lost per second above air_speed
@export var jump_velocity := 12.0          ## fixed height every jump — no variable height from holding
@export var coyote_time := 0.1
@export var jump_buffer := 0.12

@export_group("Roll / Long Jump")
@export var roll_speed := 15.0
@export var roll_time := 0.4              ## minimum roll duration
@export var roll_decay := 5.0              ## speed lost per second while rolling
@export var roll_stop_speed := 3.0         ## roll ends (stand up) below this speed
@export var roll_cooldown := 0.6           ## after a roll ends, before the next
@export var roll_steer := 3.0
@export var long_jump_speed := 18.0
@export var long_jump_velocity := 8.5
@export var long_jump_gravity_mult := 0.8

@export_group("Dive / Wall Bounce")
@export var dive_speed := 15.0
@export var dive_up := 4.5
@export var dive_cancel_velocity := 10.0   ## jump out of a dive (once per dive)
@export var wall_bounce_up := 12.5
@export var wall_bounce_push := 7.0
@export var wall_min_speed := 6.0

@export_group("Ground Pound")
@export var pound_windup := 0.22
@export var pound_speed := 42.0
@export var pound_recover := 0.4           ## window in which jump gives a pound jump
@export var pound_jump_velocity := 20.0

@export_group("Orbs")
@export var orb_bounce_velocity := 13.5
