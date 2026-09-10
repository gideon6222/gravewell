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
uniform float lamp_cos;        // cosine of the half-angle of the beam
uniform float ambient_floor : hint_range(0.0, 1.0) = 0.035;
uniform float density = 0.05;  // the air, which eats the far end of the light

uniform sampler2D rock_normal : filter_linear_mipmap, hint_normal;
uniform float normal_strength : hint_range(0.0, 4.0) = 2.2;
uniform float normal_scale = 0.45;
uniform bool has_normal = false;

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

	// Distance falloff, per pixel from the lamp's exact position. Dense air eats
	// the far end of it, which is the same number that thickens the fog and
	// shortens the reach, so the picture and the rules cannot disagree.
	float reach = lamp_reach / (1.0 + density * 0.45);
	float falloff = clamp(1.0 - dist / max(reach, 0.001), 0.0, 1.0);

	// The beam. A soft shoulder rather than a hard cone edge, and a generous
	// floor, because a surface is lit by being NEAR a lit space and the space
	// beside the ship is lit whichever way the drill happens to point. A tight
	// floor here makes the tunnel behind the ship vanish, which is the way home.
	vec2 to = dist > 0.0001 ? away / dist : lamp_dir;
	float beam = smoothstep(lamp_cos - 0.35, lamp_cos + 0.12, dot(to, lamp_dir));
	beam = mix(0.55, 1.0, beam);

	// The soft, omnidirectional half gets its OWN falloff: longer reach, much
	// gentler curve. Sharing the beam's pool makes the glow behind the player
	// end exactly where the beam does, with the same hard edge, which is the one
	// thing the soft half must not do. Combined with max(), never by multiplying
	// two floors: multiplying "survives behind the player" by "survives in
	// shadow" lands anywhere that is both on the product, which is black.
	float soft = clamp(1.0 - dist / max(reach * 1.7, 0.001), 0.0, 1.0);
	float lit = max(f.g * falloff * beam, f.g * soft * 0.55);

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
		vec3 nm = texture(rock_normal, p * normal_scale).rgb * 2.0 - 1.0;
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
