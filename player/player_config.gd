class_name PlayerConfig
extends Resource
## All movement tunables in one place. Duplicate/edit the .tres to tweak the feel.

@export_group("Ground")
@export var walk_speed := 8.0
@export var ground_accel := 70.0
@export var ground_decel := 90.0
@export var turn_speed := 18.0
@export var crouch_speed := 3.0
@export var slide_min_speed := 4.0         ## must be moving at least this fast to trigger a slide
@export var slide_min_move_time := 0.8     ## must have been moving continuously this long first
@export var slide_turn_dot := -0.4         ## direction change sharper than this (dot product) triggers it
@export var slide_time := 0.25             ## how long the slide reaction pose plays
@export var slope_slide_angle_deg := 30.0  ## floor steeper than this forces a downhill slide —
                                            ## can't stand or walk normally on it (still well under
                                            ## floor_max_angle in player.gd, so it's still "floor",
                                            ## just too steep to stand on)
@export var slope_slide_speed := 10.0      ## top speed while sliding down a steep slope
@export var slope_slide_accel := 25.0      ## how quickly slope-sliding ramps up to that speed

@export_group("Side Flip")
## Jumping while skidding from a sharp direction reversal (a "skid turn",
## see GroundState's _slide_is_turn) does this instead of a plain jump —
## Mario 64's side somersault: a higher arc, launched toward the new
## direction instead of straight up.
@export var side_flip_jump_velocity := 18.0   ## higher than a plain jump (jump_velocity), 2 less
											   ## than pound_jump_velocity
@export var side_flip_speed := 6.5            ## horizontal speed toward the new direction — tuned
											   ## down from an earlier 10.0, which carried the arc
											   ## too far forward for the jump's height
@export var side_flip_hold_time := 0.6        ## how long side_jump plays before air control resumes
											   ## (shorter than the clip's own ~1.25s so a mistimed
											   ## trick doesn't strand you mid-air with no steering)
@export var side_flip_input_window := 0.4     ## grace window (from the moment a turn-skid starts)
                                               ## during which a buffered jump still triggers the
											   ## side flip — independent of the slide pose's own
											   ## (shorter) animation-hold duration, so a jump press
											   ## that lands a beat late still catches the trick

@export_group("Air")
@export var gravity := 32.0
@export var fall_gravity_mult := 1.35
@export var terminal_velocity := 45.0
@export var air_speed := 8.0
@export var air_accel := 22.0
@export var air_steer_rate := 2.2          ## rad/s steering while carrying extra momentum
@export var momentum_drag := 1.5           ## speed lost per second above air_speed
@export var jump_velocity := 12.0          ## fixed height every jump — no variable height from holding
@export var fall_pose_velocity := -14.0    ## AirState only switches to the falling pose once velocity.y
											## drops below this, not simply the instant it goes negative
											## at the jump's apex — holds the rising pose well into the
											## descent so falling doesn't flip in too early/abruptly
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export var min_air_time_for_land_squash := 0.12   ## skip the landing squash for brief floor-contact
													 ## flicker (slopes, stairs, small bumps) that isn't a real fall

@export_group("Roll / Long Jump")
@export var roll_speed := 15.0
@export var roll_time := 0.4              ## minimum roll duration
@export var roll_decay := 5.0              ## speed lost per second while rolling
@export var roll_stop_speed := 3.0         ## roll ends (stand up) below this speed
@export var roll_cooldown := 0.6           ## after a roll ends, before the next
@export var roll_steer := 3.0
@export var roll_collision_time := 0.35    ## how long the roll_collision reaction pose plays after bouncing off a wall mid-roll
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
@export var wall_bounce_roll_time := 0.4   ## how long the roll_collision reaction pose plays after a wall bounce

@export_group("Ground Pound")
@export var pound_windup := 0.22
@export var pound_speed := 42.0
@export var pound_recover := 0.4           ## window in which jump gives a pound jump
@export var pound_jump_velocity := 20.0

@export_group("Orbs")
@export var orb_bounce_velocity := 13.5
@export var orb_attack_hold_mult := 1.15   ## the orb-hit attack pose holds for this fraction of
											## the bounce's own time-to-apex (orb_bounce_velocity /
											## gravity), not a flat duration — so it always covers
											## the rise and lets go right around the peak, instead
											## of a fixed time that can cut off early (still rising,
											## jarring jump to a falling pose) or run long (stalls
											## an orb-combo chain waiting on a pose that's done)
