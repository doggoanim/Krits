shader_type canvas_item;

/// Draws solid black everywhere outside a circle of `radius` centered on the
/// screen, and fully transparent inside it — the "hole" a cartoon iris wipe
/// closes down to a point through (and reopens back out of), rather than a
/// decorative shape floating on top of an already-opaque screen. See
/// LoadingScreen, which animates `radius` from fully-open to 0 and back.
///
/// `aspect` (x/y of the viewport, set from code — see
/// LoadingScreen._update_aspect()) keeps the hole a true circle instead of
/// stretching into an ellipse on a non-square viewport: UV itself just runs
/// 0..1 across whatever the rect's actual width/height happen to be, with no
/// idea of the real aspect ratio on its own.
uniform float radius : hint_range(0.0, 1.5) = 1.3;
uniform vec2 aspect = vec2(1.0, 1.0);
// A hard edge reads as a jagged circle at screen resolution.
uniform float edge_softness : hint_range(0.0, 0.1) = 0.015;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * aspect;
	float dist = length(centered);
	float alpha = smoothstep(radius - edge_softness, radius, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
