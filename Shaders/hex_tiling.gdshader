shader_type spatial;

uniform sampler2D IN_TEXTURE;
uniform float     IN_ROTATION;
uniform float     IN_CONSTRAINT;
uniform float     IN_SCALE_MULTIPLIER;
uniform bool      IN_TOGGLE_HEX_TILING;
uniform bool      IN_TOGGLE_WEIGHTS;

varying vec3 world_position;

void triangle_grid(
	vec2 sampling_coord,
	out float w1, out float w2, out float w3, out ivec2 vertex1, out ivec2 vertex2, out ivec2 vertex3
)
{
	sampling_coord *= 2.0 * sqrt(3);
	vec2 skewed_coord = sampling_coord * mat2( vec2( 1.0, -0.57735026 ), vec2( 0.0, 1.15470052 ) );
	
	ivec2 base_id = ivec2( floor( skewed_coord ) );
	vec3 temp = vec3( fract( skewed_coord ), 0.0 );
	temp.z = ( 1.0 - temp.x ) - temp.y;
	
	float s  = step( 0.0, -temp.z );
	float s2 = ( 2.0 * s ) - 1.0;

	w1 = ( -temp.z ) * s2;
	w2 = s - ( temp.y * s2 );
	w3 = s - ( temp.x * s2 );

   vertex1 = base_id + ivec2( int( s ), int( s ) );
   vertex2 = base_id + ivec2( int( s ), int( 1.0 - s ) );
   vertex3 = base_id + ivec2( int( 1.0 - s ), int( s ) );
}

mat2 get_mat2_rotation( ivec2 idx, float rotation_offset )
{
	float angle = float( abs( idx.x * idx.y ) + abs( idx.x + idx.y ) ) + PI;
	angle = mod( angle, 2.0 * PI );

	if( angle < 0.0 )
		angle += 2.0 * PI;
	if( angle > PI )
		angle -= 2.0 * PI;

	angle *= rotation_offset;
	float cos_angle = cos( angle );
	float sin_angle = sin( angle );
	return mat2( vec2( cos_angle, -sin_angle ), vec2( sin_angle, cos_angle ) );
}

vec2 create_center_coord( ivec2 vertex )
{
	mat2 inverted_skewed_matrix = mat2( vec2( 1.0, 0.5 ), vec2( 0.0, 0.86602538 ) );
	return ( vec2( vertex ) * inverted_skewed_matrix ) / vec2( 3.46410155 );
}

vec2 hash( vec2 p )
{
	float arbitrary_offset = 43758.5453;
	vec2 r = p * mat2( vec2( 127.1, 311.7 ), vec2( 269.5, 183.3 ) );
	return fract( sin( r ) * arbitrary_offset );
}

vec3 gain3( vec3 x, float r )
{
	float k = log( 1.0 - r ) / ( -0.69314718 );
	vec3 s = step( vec3( 0.5 ), x ) * 2.0;
	vec3 m = ( vec3( 1.0 ) - s ) * 2.0;
	vec3 res = ( s * 0.5 ) + ( ( m * 0.25 ) * pow( max( vec3( 0.0 ), s + ( x * m ) ), vec3( k ) ) );
	return res / vec3( ( res.x + res.y ) + res.z );
}

vec3 produce_hex_weights( vec3 w, ivec2 vertex1, ivec2 vertex2, ivec2 vertex3 )
{
	vec3 res = vec3( 0.0 );
	
	int v1 = ( int( vertex1.x - vertex1.y ) ) % 3;
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

	vec2 coords1 = ( ( rot1 * ( sampling_coord - cen1 ) ) + cen1 ) + hash( vec2( vertex1 ) );
	vec2 coords2 = ( ( rot2 * ( sampling_coord - cen2 ) ) + cen2 ) + hash( vec2( vertex2 ) );
	vec2 coords3 = ( ( rot3 * ( sampling_coord - cen3 ) ) + cen3 ) + hash( vec2( vertex3 ) );

	vec4 c1 = textureGrad( sampled_texture, coords1, rot1 * point_derivative_x, rot1 * point_derivative_y );
	vec4 c2 = textureGrad( sampled_texture, coords2, rot2 * point_derivative_x, rot2 * point_derivative_y );
	vec4 c3 = textureGrad( sampled_texture, coords3, rot3 * point_derivative_x, rot3 * point_derivative_y );

	vec3 Lw = vec3( 0.299, 0.587, 0.114 );
	vec3 Dw = vec3( dot( c1.xyz, Lw ), dot( c2.xyz, Lw ), dot( c3.xyz, Lw ) );
	Dw = mix( vec3( 1.0 ), Dw, vec3( fall_off_constrast ) );

	vec3 W = Dw * pow( vec3( w1, w2, w3 ), vec3( exponent ) );
	W /= ( ( W.x + W.y ) + W.z );

	if( mix_contrast != 0.5 )
		W = gain3( W, mix_contrast );
	
	color = ( ( W.x * c1 ) + ( W.y * c2 ) ) + ( W.z * c3 );
	weights = produce_hex_weights( W, vertex1, vertex2, vertex3 );
}

void TriangleGrid(out float w1, out float w2, out float w3, out ivec2 vertex1, out ivec2 vertex2, out ivec2 vertex3, vec2 st)
{
	st *= 2.0 * sqrt(3);
    vec2 skewedCoord = st * mat2(vec2(1.0, -0.57735025882720947265625), vec2(0.0, 1.1547005176544189453125));
    ivec2 baseId = ivec2(floor(skewedCoord));
    vec3 temp = vec3(fract(skewedCoord), 0.0);
    temp.z = (1.0 - temp.x) - temp.y;
    float s = step(0.0, -temp.z);
    float s2 = (2.0 * s) - 1.0;
    w1 = (-temp.z) * s2;
    w2 = s - (temp.y * s2);
    w3 = s - (temp.x * s2);
    vertex1 = baseId + ivec2(int(s), int(s));
    vertex2 = baseId + ivec2(int(s), int(1.0 - s));
    vertex3 = baseId + ivec2(int(1.0 - s), int(s));
}

mat2 LoadRot2x2(ivec2 idx, float rotStrength)
{
    float angle = float(abs(idx.x * idx.y) + abs(idx.x + idx.y)) + 3.1415927410125732421875;
    angle = mod(angle, 6.283185482025146484375);
    if (angle < 0.0)
    {
        angle += 6.283185482025146484375;
    }
    if (angle > 3.1415927410125732421875)
    {
        angle -= 6.283185482025146484375;
    }
    angle *= rotStrength;
    float cs = cos(angle);
    float si = sin(angle);
    return mat2(vec2(cs, -si), vec2(si, cs));
}

vec2 MakeCenST(ivec2 Vertex)
{
    mat2 invSkewMat = mat2(vec2(1.0, 0.5), vec2(0.0, 0.866025388240814208984375));
    return (vec2(Vertex) * invSkewMat) / vec2(3.4641015529632568359375);
}

vec3 Gain3(vec3 x, float r)
{
    float k = log(1.0 - r) / (-0.693147182464599609375);
    vec3 s = step(vec3(0.5), x) * 2.0;
    vec3 m = (vec3(1.0) - s) * 2.0;
    vec3 res = (s * 0.5) + ((m * 0.25) * pow(max(vec3(0.0), s + (x * m)), vec3(k)));
    return res / vec3((res.x + res.y) + res.z);
}

vec3 ProduceHexWeights(vec3 W, ivec2 vertex1, ivec2 vertex2, ivec2 vertex3)
{
    vec3 res = vec3(0.0);
    int v1 = (vertex1.x - vertex1.y) % 3;
    if (v1 < 0)
    {
        v1 += 3;
    }
    int vh = (v1 < 2) ? (v1 + 1) : 0;
    int vl = (v1 > 0) ? (v1 - 1) : 2;
    int v2 = (vertex1.x < vertex3.x) ? vl : vh;
    int v3 = (vertex1.x < vertex3.x) ? vh : vl;
    res.x = (v3 == 0) ? W.z : ((v2 == 0) ? W.y : W.x);
    res.y = (v3 == 1) ? W.z : ((v2 == 1) ? W.y : W.x);
    res.z = (v3 == 2) ? W.z : ((v2 == 2) ? W.y : W.x);
    return res;
}

void hex2colTex(out vec4 color, out vec3 weights, vec2 st, float rotStrength, float r, sampler2D SPIRV_Cross_Combinedtexsamp)
{
    vec2 dSTdx = dFdx(st);
    vec2 dSTdy = dFdy(st);
    vec2 param_6 = st;
    float param;
    float param_1;
    float param_2;
    ivec2 param_3;
    ivec2 param_4;
    ivec2 param_5;
    TriangleGrid(param, param_1, param_2, param_3, param_4, param_5, param_6);
    float w1 = param;
    float w2 = param_1;
    float w3 = param_2;
    ivec2 vertex1 = param_3;
    ivec2 vertex2 = param_4;
    ivec2 vertex3 = param_5;
    ivec2 param_7 = vertex1;
    float param_8 = rotStrength;
    mat2 rot1 = LoadRot2x2(param_7, param_8);
    ivec2 param_9 = vertex2;
    float param_10 = rotStrength;
    mat2 rot2 = LoadRot2x2(param_9, param_10);
    ivec2 param_11 = vertex3;
    float param_12 = rotStrength;
    mat2 rot3 = LoadRot2x2(param_11, param_12);
    ivec2 param_13 = vertex1;
    vec2 cen1 = MakeCenST(param_13);
    ivec2 param_14 = vertex2;
    vec2 cen2 = MakeCenST(param_14);
    ivec2 param_15 = vertex3;
    vec2 cen3 = MakeCenST(param_15);
    vec2 param_16 = vec2(vertex1);
    vec2 st1 = ((rot1 * (st - cen1)) + cen1) + hash(param_16);
    vec2 param_17 = vec2(vertex2);
    vec2 st2 = ((rot2 * (st - cen2)) + cen2) + hash(param_17);
    vec2 param_18 = vec2(vertex3);
    vec2 st3 = ((rot3 * (st - cen3)) + cen3) + hash(param_18);
    vec4 c1 = textureGrad(SPIRV_Cross_Combinedtexsamp, st1, rot1 * dSTdx, rot1 * dSTdy);
    vec4 c2 = textureGrad(SPIRV_Cross_Combinedtexsamp, st2, rot2 * dSTdx, rot2 * dSTdy);
    vec4 c3 = textureGrad(SPIRV_Cross_Combinedtexsamp, st3, rot3 * dSTdx, rot3 * dSTdy);
    vec3 Lw = vec3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625);
    vec3 Dw = vec3(dot(c1.xyz, Lw), dot(c2.xyz, Lw), dot(c3.xyz, Lw));
    Dw = mix(vec3(1.0), Dw, vec3(0.60000002384185791015625));
    vec3 W = Dw * pow(vec3(w1, w2, w3), vec3(7.0));
    W /= vec3((W.x + W.y) + W.z);
    if (!(r == 0.5))
    {
        vec3 param_19 = W;
        float param_20 = r;
        W = Gain3(param_19, param_20);
    }
    color = ((c1 * W.x) + (c2 * W.y)) + (c3 * W.z);
    vec3 param_21 = W;
    ivec2 param_22 = vertex1;
    ivec2 param_23 = vertex2;
    ivec2 param_24 = vertex3;
    weights = ProduceHexWeights(param_21, param_22, param_23, param_24);
}

void normal_sampling( 
	in sampler2D sampled_texture, in vec2 sampling_coord,
	out vec4 color )
{
	color = texture( sampled_texture, sampling_coord );
}

void vertex() 
{
	//world_position = ( vec4( VERTEX, 1.0 ) * MODEL_MATRIX ).xyz;
	world_position = VERTEX;
}

void fragment() 
{
	vec4 color;
	vec3 weights;
	vec2 coords = vec2( world_position.x, world_position.z );

	if( IN_TOGGLE_HEX_TILING )
		texture_2_color( IN_TEXTURE, coords, IN_ROTATION, IN_CONSTRAINT, color, weights );
		//hex2colTex( color, weights, coords, IN_ROTATION, IN_CONSTRAINT, IN_TEXTURE );
	else
		normal_sampling( IN_TEXTURE, coords, color );

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