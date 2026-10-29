shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// The orb's cel outline for a HOLLOW core. A plain inverted hull also covers
// the middle of the sphere (its far wall shows through the see-through core
// and makes the orb look solid), so this discards every fragment whose view
// ray passes through the core: only the rim outside the core's silhouette is
// drawn. The core is assumed to be a sphere centred on the node's origin.

uniform float grow = 0.055;          // how far the hull is inflated (local units)
uniform float core_radius = 0.4;     // local radius of the core sphere
uniform float alpha = 1.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	vec3 center = (VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float radius = core_radius * length(MODEL_MATRIX[0].xyz);
	vec3 dir = normalize(VERTEX);   // view-space ray from the camera through this pixel
	if (length(cross(dir, center)) < radius * 0.995) {
		discard;
	}
	ALBEDO = outline_color.rgb;
	ALPHA = alpha;
}
