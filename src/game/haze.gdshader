shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

// **Light in the AIR**: the beam you can see, the fill behind it, the shadows
// corners throw, and the thickness of the air it travels through.
//
// A dug cell contains no geometry, so the space itself stays dead however well
// the walls around it are lit: the tunnel reads as a black slot with bright
// edges. This quad sits behind the ship and behind the rock's front face, so
// both occlude it, and it puts light INTO the tunnel volume.
//
// ## What this is built to, in his words
//
//   "forward light creates a dispersed beam, but also fills the rest of the
//    tunnel behind. as you pass corners, it should create shadows. the air
//    should start looking thick in the tunnels."
//
// Four things, and each is its own term below:
//
//   BEAM    a wide soft cone along the drill. Dispersed, not a spotlight.
//   FILL    omnidirectional, shorter, weaker: the rest of the tunnel behind.
//   SHADOW  the ray fan. A corner throws a wedge into the passage behind it.
//   THICK   the air itself, scaling with depth, with motes moving in it.
//
// ## What the previous version got wrong, measured rather than guessed
//
// Rendering each term to the screen on its own showed two faults at once.
//
// **The beam was not directional.** `mix(0.18, 1.0, smoothstep(...))` over a
// 2.4-radian cone saturated almost everywhere, so the term came out near-flat
// across the whole tunnel and there was no forward shape at all.
//
// **The near-field ramp ran to 1.8 m**, which is most of a ship's length, so the
// nearest visible air light began well BEHIND the drill. Combined with a shaft
// that is open behind and solid rock ahead, the composite read as a lamp
// pointing backwards, which is exactly what it was reported as.
//
// ## The two rules this file exists to obey
//
// **Combine the beam and the fill with `max()`, never by multiplying two
// floors.** Multiplying "how much survives behind the player" by "how much
// survives in shadow" lands anywhere that is both on the product, which is
// black, and that erases the shaft the player came down: the way home.
//
// **Give the fill its OWN falloff.** Sharing the beam's pool makes the glow
// behind the player end exactly where the beam does, with the same hard edge,
// which is the one thing the soft half must not do.

uniform sampler2D field : filter_linear, source_color, hint_default_black;
uniform vec2 field_origin;
uniform float field_side;
uniform float field_radius;

// Per bearing, how far light gets before something stops it, normalised against
// `fan_reach` and NOT against the lamp's reach. Those were different numbers:
// the fan was cast to 1.8x the lamp's reach and decoded with 1x, so every shadow
// began at 55% of its true distance and the lit pool was cut short everywhere.
// One number, passed in, used at both ends.
uniform sampler2D fan : filter_linear, source_color, hint_default_white;
uniform float fan_reach = 12.0;

uniform vec2 lamp_pos;
uniform vec2 lamp_dir;
uniform float lamp_reach;
uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.82);
uniform float strength : hint_range(0.0, 4.0) = 1.9;
uniform float density = 0.05;

// The beam is DISPERSED: a wide, soft angular profile rather than a cone with an
// edge. These are dot products with the heading, so -1 is directly behind.
uniform float cone_lo = -0.35;
uniform float cone_hi = 0.75;
uniform float beam_floor : hint_range(0.0, 0.5) = 0.05;

// The fill: the rest of the tunnel behind. LONGER than the beam and far
// weaker, which is the opposite of what it was.
//
// Measured on the junction frame with the first version of this: the air up the
// shaft read 150 of 255 while the rock the beam was actually pointing at read
// 103, and it ended in a cliff 140 px up. The brightest thing on screen was
// behind the ship and it had an edge, which is the report word for word: "the
// light seems to be coming from the back of the ship in a small beam."
//
// So the fill is not a second beam with a shorter barrel. It is a long, dim,
// edgeless presence that says the way home is still open.
uniform float fill_reach_mult = 1.05;
uniform float fill_gain : hint_range(0.0, 1.0) = 0.07;

// How much thicker the air looks per unit of density, and how strongly the
// motes drifting in it read.
uniform float thick_gain = 0.32;
uniform float mote_gain : hint_range(0.0, 1.0) = 0.35;

// **Term isolation, kept rather than hacked in twice.** 0 is the game; 1..5
// render one term on its own so a fault can be SEEN instead of argued about.
// `scripts/shot_term.gd` drives it. Both faults this file has had were found
// this way and neither was visible by reading the code: a beam that turned out
// not to be directional at all, and a black stretch of shaft that turned out to
// be a real ceiling four cells up rather than a broken shadow.
uniform int debug_term : hint_range(0, 5) = 0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = vec2(world_pos.x, -world_pos.y);

	// Godot does not allow `return` in the fragment processor, so the
	// out-of-field case is a multiply rather than an early out.
	vec2 uv = (p - field_origin + vec2(field_radius)) / field_side;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	// R is the flood: light in OPEN cells. The air term reads this and never the
	// spill, so a rock face never adds glow to the space in front of it.
	float flood = texture(field, clamp(uv, vec2(0.0), vec2(1.0))).r * inside;

	vec2 away = p - lamp_pos;
	float dist = length(away);
	vec2 to = dist > 0.0001 ? away / dist : lamp_dir;
	float forward = dot(to, lamp_dir);

	// ── SHADOW: what a corner throws ──────────────────────────────────────
	// Sampled the way the fan was built: the bearing indexes the texture and
	// linear filtering blends the two nearest rays, which is what the headless
	// test reproduces when it asserts the lit-face fraction.
	float ang = atan(away.y, away.x);
	float fan_u = fract(ang / 6.2831853 + 1.0);
	float occ = texture(fan, vec2(fan_u, 0.5)).r * fan_reach;
	// A soft edge rather than a step: a hard binary shadow on a 1080-wide phone
	// aliases into a staircase along every wedge.
	float shadow = 1.0 - smoothstep(occ - 0.30, occ + 0.30, dist);

	// ── BEAM: dispersed, forward ──────────────────────────────────────────
	// Squared, so the middle of the cone is genuinely brighter than its edge and
	// the beam has a SHAPE rather than being a lit region with a boundary.
	float cone = smoothstep(cone_lo, cone_hi, forward);
	cone *= cone;
	float beam_reach = lamp_reach / (1.0 + density * 0.35);
	float beam_fall = clamp(1.0 - dist / max(beam_reach, 0.001), 0.0, 1.0);
	beam_fall *= beam_fall;
	float beam = mix(beam_floor, 1.0, cone) * beam_fall;

	// ── FILL: the rest of the tunnel behind, on its OWN falloff ───────────
	float fill_reach = beam_reach * fill_reach_mult;
	float fill = clamp(1.0 - dist / max(fill_reach, 0.001), 0.0, 1.0);
	fill = fill * fill * fill_gain;

	float lit = max(beam, fill) * flood * shadow;

	// ── THICK: the air itself ─────────────────────────────────────────────
	// The same density that thickens the fog, shortens the lamp and drags the
	// ship makes the tunnel air visibly scatter. The motes are anchored to the
	// WORLD and drift slowly, so they read as air the ship is moving through
	// rather than as dirt on the lens.
	float thick = 1.0 + density * thick_gain;
	float motes = noise(p * 0.55 + vec2(0.0, TIME * 0.11))
		* noise(p * 1.3 - vec2(TIME * 0.07, 0.0));
	// The motes scale with the SAME density, so the surface air is nearly clear
	// and the deep is soup. A constant grain everywhere is dirt on the lens; a
	// grain that arrives as you descend is the air getting thick.
	float grit = mote_gain * clamp(0.30 + density * 0.55, 0.30, 1.6);
	lit *= thick * (1.0 - grit * 0.5 + grit * motes * 1.6);

	// A very SHORT ramp, only enough that the quad cannot wash the hull at a
	// grazing angle. At 1.8 m it put the nearest visible light behind the drill.
	lit *= smoothstep(0.0, 0.55, dist);

	// Each branch replaces the composite with ONE term, unscaled by the others,
	// which is the whole point: a term that is wrong is usually wrong flat.
	if (debug_term == 1) { lit = beam; }
	else if (debug_term == 2) { lit = fill; }
	else if (debug_term == 3) { lit = flood; }
	else if (debug_term == 4) { lit = shadow * flood; }
	else if (debug_term == 5) { lit = (thick - 1.0) * 0.5; }

	ALBEDO = tint * lit * strength;
	ALPHA = 1.0;
}
