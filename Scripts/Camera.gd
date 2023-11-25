extends Node3D


@export var speed_multiplier: float;
@onready var camera = $Camera3D;


var movement_input: Vector3;


func _input(event):
	# Mouse Event
	if event is InputEventMouseMotion:
		rotate_y( -event.relative.x * 0.005)
		camera.rotate_x( -event.relative.y * 0.005 )


func _process(delta):
	# Keyboard Event
	movement_input = Vector3( 0, 0, 0 );
	
	if Input.is_action_pressed( "Backward" ):
		movement_input.z += 1;
	if Input.is_action_pressed( "Forward" ):
		movement_input.z -= 1;
	if Input.is_action_pressed( "Right" ):
		movement_input.x += 1;
	if Input.is_action_pressed( "Left" ):
		movement_input.x -= 1;
	if Input.is_action_pressed( "Up" ):
		movement_input.y += 1;
	if Input.is_action_pressed( "Down" ):
		movement_input.y -= 1;
	
	# Process movement
	translate( movement_input.normalized() * 0.1 * speed_multiplier );
