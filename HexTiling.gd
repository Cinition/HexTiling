@tool

extends MeshInstance3D

@export var hex_shader: ShaderMaterial:
	set( _hex_shader ):
		if( _hex_shader != hex_shader ):
			hex_shader = _hex_shader;
			mesh.surface_set_material( 0, hex_shader );

@export var texture: Texture2D:
	set( _texture ):
		if( not hex_shader ):
			push_error( "Shader has to be set before adding a texture." )

		if( _texture != texture ):
			texture = _texture;
			hex_shader.set_shader_parameter( "IN_TEXTURE", texture );

@export_category("Shader Parameters")

@export var toggle_hex_sampling: bool:
	set( _toggle_hex_sampling):
		if( not hex_shader ):
			push_error( "Shader has to be set before setting the toggle." );

		if( _toggle_hex_sampling != toggle_hex_sampling ):
			toggle_hex_sampling = _toggle_hex_sampling;
			hex_shader.set_shader_parameter( "IN_TOGGLE_HEX_TILING", toggle_hex_sampling );

@export var toggle_hex_weights: bool:
	set( _toggle_hex_weights ):
		if( not hex_shader ):
			push_error( "Shader has to be set before setting the toggle." );

		if( _toggle_hex_weights != toggle_hex_weights ):
			toggle_hex_weights = _toggle_hex_weights;
			hex_shader.set_shader_parameter( "IN_TOGGLE_WEIGHTS", toggle_hex_weights );

@export_range( 0.01, 0.99 ) var contraint: float:
	set( _contraint ):
		if( not hex_shader ):
			push_error( "Shader has to be set before setting the constraint." );

		if( _contraint != contraint ):
			contraint = _contraint;
			hex_shader.set_shader_parameter( "IN_CONSTRAINT", contraint );

@export_range( 0, 90 ) var rotation_offset: float:
	set( _rotation_offset ):
		if( not hex_shader ):
			push_error( "Shader has to be set before setting the rotation." );

		if( _rotation_offset != rotation_offset ):
			rotation_offset = _rotation_offset;
			hex_shader.set_shader_parameter( "IN_ROTATION", rotation_offset );

@export_range( 1, 100 ) var scale_multiplier: float:
	set( _scale_multiplier ):
		if( not hex_shader ):
			push_error( "Shader has to be set before setting the scale multiplier." );

		if( _scale_multiplier != scale_multiplier ):
			scale_multiplier = _scale_multiplier;
			hex_shader.set_shader_parameter( "IN_SCALE_MULTIPLIER", scale_multiplier );
