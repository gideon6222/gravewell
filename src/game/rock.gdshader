shader_type spatial;
render_mode cull_disabled, unshaded;

// The rock. Its own lighting, because the game's light is a solved field rather
// than a lamp the renderer knows about.
//
// The split the whole thing rests on: **visibility and occlusion are properties
// of the geometry and belong in a solved field uploaded as a texture; smooth
// distance falloff and per-pixel position belong here.** Leave the falloff in
// the grid and the pool of light steps a whole metre at a time as the ship
// flies; put the visibility in the shader and it cannot know the rock is there.
//
// Two lights, not one:
//
//     SURFACE = spill * falloff * beam        <- this shader
//     AIR     = flood * falloff * beam * shadow  <- the additive haze quad
//
// A surface is lit by being NEAR a lit space. The air in a corridor is lit by
// light travelling along it, which a corner can block. Sharing one number
// between them is what made every side passage in Coreward read as a hole.
//
// ## Why `unshaded`, and why this shader does its own diffuse
//
// `ALBEDO` is a base colour that Godot's LIGHTS multiply. The rock is
// deliberately excluded from the only light in the scene - the world's light is
// an upgrade and must not brighten the hull - so with a lit shader the rock had
// nothing to be lit BY and rendered black at every setting. The field was
// solved correctly, uploaded correctly and sampled correctly the whole time;
// rendering the field straight to EMISSION as a diagnostic showed it exactly
// where it belonged.
//
// So the light model IS this shader. It computes its own diffuse term from the
// world normal and the direction to the lamp, which is also what lets the normal
// map mean anything: a normal map with no moving light on it is just noise.

// The solved field. R is the flood (light in open cells), G is the spill (the
// same light carried onto the rock faces beside it). RGBA8 rather than a float
// format: 256 levels is far more than a light field needs after the curve, and
// it is the format every mobile GPU is certain to filter.
uniform sampler2D field : filter_linear, source_color, hint_default_black;
uniform vec2 field_origin;     // world (x, y) of the field's centre cell
uniform float field_side;      // cells across the field
uniform float field_radius;    // (field_side - 1) / 2

uniform vec2 lamp_pos;         // world (x, y)
uniform vec2 lamp_dir;         // unit, the way the drill points
uniform float lamp_reach;
// The beam's angular profile, shared with the air term so the light in the
// tunnel and the pool it lands in are one light.
uniform float cone_lo = -0.35;
uniform float cone_hi = 0.75;
uniform float beam_floor : hint_range(0.0, 0.6) = 0.06;

// The second light: proximity on the rock face, with no direction at all.
uniform float prox_reach_mult : hint_range(0.1, 2.0) = 0.34;
uniform float prox_gain : hint_range(0.0, 2.0) = 0.42;

// The third term: the WHOLE tunnel, on the propagated spill alone.
//
// Its reach is deliberately longer than the solved window, so across any frame
// it is nearly flat and the falloff doing the work is the spill's own. That is
// the difference between "the walls near the ship are lit" and "the tunnel is
// lit": a radius centred on the lamp reads as belonging to the lamp however
// gently it falls, which is what he named twice.
uniform float wash_reach_mult : hint_range(0.1, 6.0) = 4.0;
uniform float wash_gain : hint_range(0.0, 1.0) = 0.34;
uniform float ambient_floor : hint_range(0.0, 1.0) = 0.035;
uniform float density = 0.05;  // the air, which eats the far end of the light

uniform sampler2D rock_normal : filter_linear_mipmap, hint_normal;
uniform float normal_strength : hint_range(0.0, 4.0) = 2.2;
uniform float normal_scale = 0.45;
uniform bool has_normal = false;
// The z of the terrain's front face, from `Terrain.HALF`. One fact in two files,
// so `main.gd` sets it from the constant rather than the shader guessing.
uniform float face_z = 0.5;

// How far toward the camera the lamp sits. A light exactly in the rock plane
// reaches none of the faces the camera can see.
uniform float lamp_height = 1.6;
uniform float gain : hint_range(0.0, 8.0) = 1.7;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Sample the solved field by WORLD POSITION, with linear filtering, so light
// fades across a rock face instead of stepping at cell edges.
vec2 sample_field(vec2 p) {
	vec2 uv = (p - field_origin + vec2(field_radius)) / field_side;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec2(0.0);
	}
	return texture(field, uv).rg;
}

void fragment() {
	// Sim y is depth, positive downward; the scene draws it as -y. Everything
	// that talks to the field converts here and nowhere else.
	vec2 p = vec2(world_pos.x, -world_pos.y);
	vec2 f = sample_field(p);

	vec2 away = p - lamp_pos;
	float dist = length(away);
	vec2 to = dist > 0.0001 ? away / dist : lamp_dir;
	float forward = dot(to, lamp_dir);

	// ── the BEAM on the rock ──────────────────────────────────────────────
	// Dispersed, matching the air term's cone so the beam you can see in the
	// tunnel and the pool it lands in are one light rather than two that have to
	// be kept in agreement by hand.
	float reach = lamp_reach / (1.0 + density * 0.35);
	float cone = smoothstep(cone_lo, cone_hi, forward);
	cone *= cone;
	float beam_fall = clamp(1.0 - dist / max(reach, 0.001), 0.0, 1.0);
	float lit_beam = f.g * mix(beam_floor, 1.0, cone) * beam_fall;

	// ── the SECOND light: proximity on the rock face ──────────────────────
	//
	// His ask, verbatim: "there should be a secondary light source that shows on
	// the face of the rocks when the ship is near them."
	//
	// **It has no direction at all.** That is the whole point of it: a wall
	// beside the ship is lit because the ship is beside it, not because the
	// drill happens to be pointing that way. Sharing the beam's direction is
	// what made every surface in the game brighten and dim as the player turned,
	// which reads as the world flickering rather than as a lamp moving.
	//
	// Its own falloff, much shorter and much softer, and combined with `max()`
	// rather than multiplied: multiplying two floors lands anywhere that is both
	// on the product, which is black.
	float prox = clamp(1.0 - dist / max(reach * prox_reach_mult, 0.001), 0.0, 1.0);
	prox *= prox;
	float lit_prox = f.g * prox * prox_gain;

	// ── the WASH: the rest of the tunnel behind ───────────────────────────
	// The second light is a NEAR light: a third of the lamp's reach, so it only
	// touches walls the ship is beside. That left everything further back on the
	// beam's floor alone, and the shaft the player came down went black, which
	// throws away the way home. This is what keeps it readable, and it rides the
	// propagated spill `f.g` rather than raw distance, so it only reaches faces
	// the light could actually have got to.
	float wash = clamp(1.0 - dist / max(reach * wash_reach_mult, 0.001), 0.0, 1.0);
	float lit_wash = f.g * wash * wash_gain;

	// `max()` of three, never a product. Multiplying floors lands anywhere that
	// is dim for two reasons on the product, which is black.
	float lit = max(max(lit_beam, lit_prox), lit_wash);

	// A lighting multiplier is linear and then sRGB-encoded, so its dark end
	// lifts. Squaring it puts the darkness back where it was aimed. Squared
	// ONCE: doing it here and in the falloff too is a fourth power, which
	// measured as a black screen with a thin cone in it.
	lit = lit * lit;

	// The world normal, perturbed by the rock map. The front faces are almost
	// exactly +Z, so the map's tangent basis is the world basis and the
	// perturbation needs no TBN; the tunnel walls are seen at a grazing angle
	// where the difference does not read.
	vec3 n = normalize(world_normal);
	if (has_normal) {
		// Sampled by WORLD position, so the pattern belongs to the rock rather
		// than to the mesh, and a chunk rebuilt after a dig cannot make the
		// texture swim.
		//
		// **Two projections, chosen by which way the face points.** The terrain
		// is an extrusion along Z: the front face looks down -Z and takes the XY
		// projection, but every tunnel WALL and CEILING is parallel to it, so its
		// whole 3 m of depth collapses onto one line of texels and the map comes
		// out as vertical streaks. That was invisible for as long as those faces
		// were black; it is the first thing you see once the tunnel is lit all
		// the way through, which is how it was found.
		//
		// A wall's own plane is (arc length along it, depth into the screen), and
		// `(-n.y, n.x)` is the along-wall direction. Blended rather than switched,
		// or the seam moves to wherever `facing` crosses the threshold.
		// **Choose the projection from the GEOMETRY, not from the normal.**
		// `generate_normals()` smooths across the crease where the front face
		// meets the extruded wall, so a tunnel ceiling measures 0.87 on
		// `abs(n.z)`: almost facing the camera. A selector built on the normal
		// therefore picks the face projection for every wall in the game, and
		// the streaks survive the fix. Found by rendering `abs(n.z)` straight to
		// ALBEDO rather than by reading the mesh builder.
		//
		// The front face is a plane at z = `face_z` and the walls run back from
		// it, so z says which surface a pixel is on and nothing can smooth that
		// away. The blend is over the first 0.35 m of wall, which is behind the
		// silhouette edge and never seen straight on.
		float facing = smoothstep(face_z - 0.35, face_z - 0.02, world_pos.z);
		vec2 uv_face = p * normal_scale;
		vec2 uv_wall = vec2(dot(world_pos.xy, vec2(-n.y, n.x)), world_pos.z) * normal_scale;
		vec3 nm = mix(texture(rock_normal, uv_wall).rgb,
			texture(rock_normal, uv_face).rgb,
			facing) * 2.0 - 1.0;
		n = normalize(n + vec3(nm.x, -nm.y, 0.0) * normal_strength);
	}

	// The lamp sits slightly toward the camera so the faces the player can see
	// actually catch it. A light exactly in the rock plane lights only the
	// backs of things, which in a 2.5D scene is every face except the ones on
	// screen.
	vec3 lamp_world = vec3(lamp_pos.x, -lamp_pos.y, lamp_height);
	vec3 l = normalize(lamp_world - world_pos);
	// A floor rather than a clamp to zero: a face turned away from the lamp is
	// dim, not absent, because a tunnel is full of bounced light.
	float diffuse = mix(0.35, 1.0, clamp(dot(n, l), 0.0, 1.0));

	vec3 base = COLOR.rgb * lit * diffuse * gain;
	base += COLOR.rgb * ambient_floor;

	// Emissive is exempt from the field on purpose and runs on a gentler curve:
	// a glowing seam deep in the dark is the whole find-the-ore mechanic, and
	// putting it through the surface curve switches it off exactly when it
	// matters. A square root over a small floor keeps the near ones bright and
	// pushes the distant ones to a smudge.
	float glow = COLOR.a;
	if (glow > 0.001) {
		float g = sqrt(max(f.g, 0.12)) * clamp(1.0 - dist / (reach * 2.4), 0.06, 1.0);
		base += COLOR.rgb * glow * g * 1.5;
	}

	ALBEDO = base;
}
