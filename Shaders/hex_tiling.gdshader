shader_type spatial;

uniform sampler2D IN_TEXTURE;
uniform float     IN_ROTATION;
uniform float     IN_SCALE_MULTIPLIER;
uniform bool      IN_TOGGLE_HEX_TILING;
uniform bool      IN_TOGGLE_WEIGHTS;

void triangle_grid( 
	vec2 sampling_coord,
	out float w1, out float w2, out float w3, out ivec2 vertex1, out ivec2 vertex2, out ivec2 vertex3
)
{
	float sqrt_of_3 = 1.73205;
	mat2 grid_to_skewed_grid = mat2( vec2( 1.0, -0.57735027 ), vec2( 0.0, 1.15470054 ) );

	vec2 skewed_coord = grid_to_skewed_grid * sampling_coord;
	ivec2 base_id = ivec2( floor( skewed_coord ) );
	vec2 fractional_coords = fract( skewed_coord );
	vec3 temp = vec3( fractional_coords, 1.0 - fractional_coords.x - fractional_coords.y );

	float s = step( 0.0, -temp.z );
	float s2 = 2.0 * s - 1.0;

	w1 =   -temp.z * s2;
	w2 = s -temp.y * s2;
	w3 = s -temp.x * s2;

	vertex1 = base_id + ivec2( int( s ), int( s ) );
	vertex2 = base_id + ivec2( int( s ), 1 - int( s ) );
	vertex3 = base_id + ivec2( 1 - int( s ), int( s ) );
}

mat2 get_mat2_rotation( ivec2 idx, float rotation_offset )
{
	float pi = 3.1415926538;
	float angle = abs( float( idx.x ) * float( idx.y ) ) + abs( float( idx.x ) + float( idx.y ) ) + pi;
	angle = mod( angle, 2.0 * pi );

	if( angle < 0.0 )
		angle += 2.0 * pi;
	if( angle > pi )
		angle -= 2.0 * pi;

	angle *= rotation_offset;
	float cos_angle = cos( angle );
	float sin_angle = sin( angle );
	return mat2( vec2( cos_angle, -sin_angle ), vec2( sin_angle, cos_angle ) );
}

vec2 create_center_coord( ivec2 vertex )
{
	float sqrt_of_3 = 1.73205;
	mat2 inverted_skewed_matrix = mat2( vec2( 1.0, 0.5 ), vec2( 0.0, 1.0 / 1.15470054 ) );
	return inverted_skewed_matrix * vec2( vertex ) / ( 2.0 * sqrt_of_3 );
}

vec2 hash( ivec2 p )
{
	float arbitrary_offset = 43758.5453;
	vec2 r = mat2( vec2( 127.1, 311.7 ), vec2( 269.5, 183.3 ) ) * vec2( p );
	return fract( sin( r ) * arbitrary_offset );
}

vec3 gain3( vec3 x, float r )
{
	// Increase contrast when r > 0.5 and
	// reduce contrast if less.
	float k = log( 1.0 - r ) / log( 0.5 );
	vec3 s = 2.0 * step( vec3( 0.5 ), x );
	vec3 m = 2.0 * ( 1.0 - s );
	vec3 res = 0.5 * s + 0.25 * m + pow( max( vec3( 0.0 ), s + x * m ), vec3( k ) );
	return res.xyx / ( res.x + res.y + res.z );
}

vec3 produce_hex_weights( vec3 w, ivec2 vertex1, ivec2 vertex2, ivec2 vertex3 )
{
	vec3 res = vec3( 0.0 );
	
	int v1 = ( vertex1.x - vertex1.y ) % 3;
	if( v1 < 0 )
		v1 += 3;

	int vh = v1 < 2 ? ( v1 + 1 ) : 0;
	int vl = v1 > 0 ? ( v1 - 1 ) : 2;

	int v2 = vertex1.x < vertex3.x ? vl : vh;
	int v3 = vertex1.x < vertex3.x ? vh : vl;

	res.x = v3 == 0 ? w.z : ( v2 == 0 ? w.y : w.x );
	res.y = v3 == 1 ? w.z : ( v2 == 1 ? w.y : w.x );
	res.z = v3 == 2 ? w.z : ( v2 == 2 ? w.y : w.x );
	return res;
}

void texture_2_color( 
	in sampler2D sampled_texture, in vec2 sampling_coord,
	float rotate_offset, float mix_contrast,
	out vec4 color, out vec3 weights
)
{
	float fall_off_constrast = 0.6;
	float exponent = 7.0;

	vec2 point_derivative_x = dFdx( sampling_coord );
	vec2 point_derivative_y = dFdy( sampling_coord );

	// Get Triangle Info
	float w1, w2, w3;
	ivec2 vertex1, vertex2, vertex3;

	triangle_grid( sampling_coord, w1, w2, w3, vertex1, vertex2, vertex3 );

	mat2 rot1 = get_mat2_rotation( vertex1, rotate_offset );
	mat2 rot2 = get_mat2_rotation( vertex2, rotate_offset );
	mat2 rot3 = get_mat2_rotation( vertex3, rotate_offset );

	vec2 cen1 = create_center_coord( vertex1 );
	vec2 cen2 = create_center_coord( vertex2 );
	vec2 cen3 = create_center_coord( vertex3 );

	vec2 coords1 = ( sampling_coord - cen1 ) * rot1 + cen1 + hash( vertex1 );
	vec2 coords2 = ( sampling_coord - cen2 ) * rot2 + cen2 + hash( vertex2 );
	vec2 coords3 = ( sampling_coord - cen3 ) * rot3 + cen3 + hash( vertex3 );

	// Fetch input
	vec4 c1 = textureGrad( sampled_texture, coords1, point_derivative_x * rot1, point_derivative_y * rot1 );
	vec4 c2 = textureGrad( sampled_texture, coords2, point_derivative_x * rot2, point_derivative_y * rot2 );
	vec4 c3 = textureGrad( sampled_texture, coords3, point_derivative_x * rot3, point_derivative_y * rot3 );

	// Use Luminance as weight
	vec3 Lw = vec3( 0.299, 0.587, 0.114 );
	vec3 Dw = vec3( dot( c1.xyz, Lw ), dot( c2.xyz, Lw ), dot( c3.xyz, Lw ) );
	Dw.x = mix( 1.0, Dw.x, fall_off_constrast );
	Dw.y = mix( 1.0, Dw.y, fall_off_constrast );
	Dw.z = mix( 1.0, Dw.z, fall_off_constrast );

	vec3 W = Dw * pow( vec3( w1, w2, w3 ), vec3( exponent ) );
	W /= ( W.x + W.y + W.z );

	if( mix_contrast != 0.5 )
		W = gain3( W, mix_contrast );
	
	color = W.x * c1 + W.y * c2 + W.z * c3;
	weights = produce_hex_weights( W.xyz, vertex1, vertex2, vertex3 );
}

void normal_sampling( 
	in sampler2D sampled_texture, in vec2 sampling_coord,
	out vec4 color )
{
	color = texture( sampled_texture, sampling_coord );
}

void fragment() {
	vec4 color;
	vec3 weights;
	vec2 uniform_scaled_uv = UV * vec2( MODEL_MATRIX[0].x, MODEL_MATRIX[1].y ) / IN_SCALE_MULTIPLIER;

	if( IN_TOGGLE_HEX_TILING )
		texture_2_color( IN_TEXTURE, uniform_scaled_uv, IN_ROTATION, 0.5, color, weights );
	else
		normal_sampling( IN_TEXTURE, uniform_scaled_uv, color );

	if( IN_TOGGLE_WEIGHTS && IN_TOGGLE_HEX_TILING )
	{
		ALBEDO.r = weights.r;
		ALBEDO.g = weights.g;
		ALBEDO.b = weights.b;
	}
	else
	{
		ALBEDO.r = color.r;
		ALBEDO.g = color.g;
		ALBEDO.b = color.b;
	}
}