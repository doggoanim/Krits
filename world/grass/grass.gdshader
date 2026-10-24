shader_type spatial;
render_mode cull_disabled, diffuse_toon, depth_prepass_alpha;
// Billboard grass blade: always faces the camera around the Y axis (stays
// rooted upright) while bending away from anything carrying a TrampleMarker
// and swaying in a constant ambient "wind".
//
// Godot's spatial shaders have no render_mode for billboarding - that's a
// StandardMaterial3D-only feature - so the Y-axis facing below is done by
// hand: build a basis whose forward vector points horizontally at the
// camera (camera position minus this instance's position, Y zeroed out)
// and whose up vector stays world-up, then feed that into MODELVIEW_MATRIX
// ourselves instead of the engine's default.
//
// See world/grass/trample_map.gd for how the bending data gets here - this
// shader only ever reads it through the global uniforms below.

uniform sampler2D albedo_texture : source_color;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float blade_height = 1.0;      // local-space quad height, base at y=0
uniform float trample_strength : hint_range(0.0, 1.0) = 0.85;
uniform float wind_strength = 0.12;
uniform float wind_scale = 0.35;       // world units per wind wave
uniform float wind_speed = 1.4;

// Published every frame by TrampleMap — never assigned directly on a
// material instance.
global uniform sampler2D trample_map;
global uniform vec3 trample_center;
global uniform float trample_area_size = 24.0;

void vertex() {
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	// 0 at the blade's root, 1 at its tip, eased so the base stays planted.
	float tip = clamp(VERTEX.y / max(blade_height, 0.001), 0.0, 1.0);
	tip *= tip;

	vec2 offset_from_center = world_origin.xz - trample_center.xz;
	vec2 uv = offset_from_center / trample_area_size + 0.5;
	float trample_amount = 0.0;
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
		trample_amount = texture(trample_map, uv).r;
	}

	float wind = sin((world_origin.x + world_origin.z) * wind_scale + TIME * wind_speed) * wind_strength;

	// Flatten toward the ground when trampled; sway/lean at the tip.
	VERTEX.y -= VERTEX.y * trample_amount * trample_strength;
	VERTEX.x += (wind - trample_amount * 0.3) * tip;

	// Y-axis billboard. Each MultiMesh instance can have its own scale, so
	// pull that out of MODEL_MATRIX first and reapply it to the new basis
	// rather than assuming every blade is the same size.
	vec3 scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
	vec3 to_camera = cam_pos - world_origin;
	to_camera.y = 0.0;
	float to_camera_len = length(to_camera);
	vec3 forward = to_camera_len > 0.0001 ? to_camera / to_camera_len : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 up = vec3(0.0, 1.0, 0.0);

	mat4 billboard_model = mat4(
		vec4(right * scale.x, 0.0),
		vec4(up * scale.y, 0.0),
		vec4(forward * scale.z, 0.0),
		vec4(world_origin, 1.0)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
