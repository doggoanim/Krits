shader_type spatial;
// The ink outline of a cel-shaded convex shape: a copy of the mesh pushed
// outward from `center_y` on its axis and drawn back-faces only, so just a
// rim around the silhouette shows. Used as `next_pass` of cel_crystal.gdshader.
// (Pushing radially from the centre instead of along the normals keeps flat-
// shaded facets from splitting apart at their edges.)
render_mode unshaded, cull_front, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.02, 0.04, 0.12, 1.0);
uniform float width = 0.04;       // outline thickness in the mesh's own units
uniform float center_y = 0.25;    // where, along the mesh's Y axis, "outward" is measured from

void vertex() {
	vec3 from_centre = VERTEX - vec3(0.0, center_y, 0.0);
	VERTEX += normalize(from_centre) * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
